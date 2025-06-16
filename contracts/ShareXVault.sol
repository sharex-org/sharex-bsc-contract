// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title ShareX Vault Smart Contract V3
 * @dev A smart contract for managing partner, merchant, device, and transaction data.
 * @author ShareX Team
 * @notice This is an upgradeable smart contract for data management in the ShareX ecosystem.
 * @custom:security-contact security@sharex.com
 */
contract ShareXVault is 
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable 
{
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Strings for uint256;
    
    // ===== Roles =====
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant MERCHANT_ROLE = keccak256("MERCHANT_ROLE");
    bytes32 public constant READER_ROLE = keccak256("READER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    // ===== Constants =====
    uint256 public constant MAX_TRANSACTION_DETAILS_PER_BATCH = 100;
    uint256 public constant MAX_DESCRIPTION_LENGTH = 1024;
    uint256 public constant MAX_BATCH_SIZE = 50;
    
    // String Length Constants
    uint256 public constant MAX_COUNTRY_CODE_LENGTH = 2;
    uint256 public constant MAX_PARTNER_CODE_LENGTH = 32;
    uint256 public constant MAX_PARTNER_NAME_LENGTH = 100;
    uint256 public constant MAX_BUSINESS_TYPE_LENGTH = 32;
    uint256 public constant MAX_VERIFICATION_LENGTH = 32;
    uint256 public constant MIN_MERCHANT_ID_LENGTH = 2;
    uint256 public constant MAX_MERCHANT_ID_LENGTH = 16;
    uint256 public constant MAX_LOCATION_ID_LENGTH = 64;
    uint256 public constant MAX_LOCATION_LENGTH = 64;
    uint256 public constant MAX_MERCHANT_TYPE_LENGTH = 64;
    uint256 public constant MAX_MERCHANT_NAME_LENGTH = 32;
    uint256 public constant MAX_DEVICE_ID_LENGTH = 32;
    uint256 public constant MAX_DEVICE_TYPE_LENGTH = 32;

    // Entity Type Constants
    bytes32 private constant PARTNER_TYPE = keccak256("partner");
    bytes32 private constant MERCHANT_TYPE = keccak256("merchant");
    bytes32 private constant DEVICE_TYPE = keccak256("device");
    bytes32 private constant COUNTRY_TYPE = keccak256("country");
    
    // ===== Counters =====
    uint256 private _partnerIdCounter;
    uint256 private _merchantIdCounter;
    uint256 private _deviceIdCounter;
    uint256 private _transactionBatchIdCounter;
    
    // ===== Data Structures =====
    
    /**
     * @dev Version information structure.
     */
    struct Version {
        uint8 major;
        uint8 minor;
        uint8 patch;
    }
    
    /**
     * @dev Country information structure.
     */
    struct CountryInfo {
        bytes2 iso2;        // ISO2 country code (using bytes2 to save gas).
        uint256 timestamp;  // Registration timestamp.
    }
    
    /**
     * @dev Partner information structure.
     */
    struct PartnerInfo {
        uint256 id;             // Internal ID.
        bytes32 partnerKey;     // Partner hash key (keccak256(partnerCode)).
        string partnerName;     // Partner name.
        bytes2 iso2;           // ISO2 country code.
        bytes32 verification;   // Verification number issued by ShareX.
        string description;     // Service description.
        string businessType;    // Business type.
        uint256 timestamp;      // Registration timestamp.
    }
    
    /**
     * @dev Merchant information structure.
     */
    struct MerchantInfo {
        uint256 id;                      // Internal ID.
        bytes32 merchantName;            // Merchant name.
        bytes32 merchantKey;             // Merchant hash key (keccak256(merchantId)).
        bytes description;               // Description.
        bytes2 iso2;                     // Country code.
        bytes32 locationId;              // City code.
        bytes32 location;                // Location.
        bytes32 merchantType;            // Scene type.
        bytes32 verification;            // Verification number.
        uint256 timestamp;               // Registration timestamp.
    }
    
    /**
     * @dev Device information structure.
     */
    struct DeviceInfo {
        uint256 id;             // Internal ID.
        bytes32 deviceKey;      // Device hash key (keccak256(deviceId)).
        bytes32 deviceType;     // Device type.
        bytes32 partnerKey;     // Partner hash key.
        bytes32 merchantKey;    // Merchant hash key.
        uint256 timestamp;      // Registration timestamp.
    }
    
    /**
     * @dev Basic transaction information structure.
     */
    struct BasicTransactionInfo {
        bytes32 deviceHash;     // Device hash.
        uint32 orderCount;     // Order count.
        uint256 totalAmount;   // Total transaction amount.
        uint256 dateComparable; // Date in YYYYMMDD format, for comparison.
    }
    
    /**
     * @dev Transaction detail structure.
     */
    struct TransactionDetail {
        bytes32 userId;                      // User ID.
        bytes32 sharexId;                    // ShareX ID.
        bytes32 transactionAmount;           // Transaction amount.
        uint32 itemCount;                    // Number of items/services in the order.
        uint256 timestamp;                   // Transaction timestamp.
        string additionalData;               // Additional data (JSON formatted string).
    }
    
    /**
     * @dev Transaction batch structure.
     */
    struct TransactionBatch {
        uint256 id;                          // Internal ID.
        BasicTransactionInfo basicInfo;      // Basic transaction data.
        uint256 batchTimestamp;              // Batch timestamp.
    }
    
    /**
     * @dev System state structure.
     */
    struct SystemState {
        Version version;                // Current contract version.
        Version previousVersion;        // Previous version.
        uint256 upgradeTimestamp;       // Last upgrade timestamp.
        bool maintenanceMode;           // Maintenance mode.
    }
    
    /**
     * @dev Statistics information structure.
     */
    struct StatsInfo {
        uint256 partnersCount;           // Total number of partners.
        uint256 merchantsCount;          // Total number of merchants.
        uint256 devicesCount;            // Total number of devices.
        uint256 transactionBatchesCount; // Total number of transaction batches.
        uint256 countriesCount;          // Total number of countries.
        uint256 contractBalance;         // Contract balance.
    }
    
    /**
     * @dev Parameters structure for registering a partner.
     */
    struct PartnerParams {
        string partnerCode;
        string partnerName;
        string iso2;
        string verification;
        string description;
        string businessType;
    }

    /**
     * @dev Parameters structure for registering a merchant.
     */
    struct MerchantParams {
        string merchantName;
        string merchantId;
        bytes description;
        string iso2;
        string locationId;
        string location;
        string merchantType;
        string verification;
    }

    /**
     * @dev Parameters structure for registering a device.
     */
    struct DeviceParams {
        string deviceId;
        string deviceType;
        string partnerCode;
        string merchantId;
    }
    
    /**
     * @dev Parameters structure for uploading a transaction batch.
     */
    struct UploadBatchParams {
        string deviceHash;
        uint256 dateComparable; // Date in YYYYMMDD format.
        uint32 orderCount;
        uint256 totalAmount;
        TransactionDetail[] transactionDetails;
    }
    
    // ===== State Variables =====
    
    // Using mappings to store primary data.
    mapping(bytes2 => CountryInfo) internal _countries;
    mapping(bytes32 => PartnerInfo) internal _partners;
    mapping(bytes32 => MerchantInfo) internal _merchants;
    mapping(bytes32 => DeviceInfo) internal _devices;
    mapping(bytes32 => TransactionBatch) internal _transactionBatches;
    
    // Reverse mapping, used to restore original value from hash.
    mapping(bytes32 => bytes2) private _hashToCountryCode;
    
    // Using EnumerableSet to manage key sets.
    EnumerableSet.Bytes32Set private _countryKeys;
    EnumerableSet.Bytes32Set private _partnerKeys;
    EnumerableSet.Bytes32Set private _merchantKeys;
    EnumerableSet.Bytes32Set private _deviceKeys;
    EnumerableSet.Bytes32Set private _transactionBatchKeys;
    
    // System state.
    SystemState private _systemState;
    
    // Index mappings - for fast lookups.
    mapping(bytes2 => EnumerableSet.Bytes32Set) private _merchantsByCountry;
    mapping(bytes32 => EnumerableSet.Bytes32Set) private _merchantsByPartner;
    mapping(bytes32 => EnumerableSet.Bytes32Set) private _devicesByMerchant;
    mapping(bytes32 => EnumerableSet.Bytes32Set) private _devicesByPartner;
    mapping(bytes32 => EnumerableSet.Bytes32Set) private _transactionsByDevice;
    
    // ===== Protected Accessor Functions (for inherited contracts only) =====
    
    /**
     * @dev Gets the system state (for inherited contracts only).
     */
    function _getSystemState() internal view returns (SystemState storage) {
        return _systemState;
    }
    
    /**
     * @dev Gets the partner key set (for inherited contracts only).
     */
    function _getPartnerKeys() internal view returns (EnumerableSet.Bytes32Set storage) {
        return _partnerKeys;
    }
    
    /**
     * @dev Gets the merchant key set by partner (for inherited contracts only).
     */
    function _getMerchantsByPartner() internal view returns (mapping(bytes32 => EnumerableSet.Bytes32Set) storage) {
        return _merchantsByPartner;
    }
    
    /**
     * @dev Updates the system state (for inherited contracts only).
     */
    function _updateSystemState(
        Version memory newVersion,
        Version memory previousVersion,
        uint256 upgradeTimestamp
    ) internal {
        _systemState.version = newVersion;
        _systemState.previousVersion = previousVersion;
        _systemState.upgradeTimestamp = upgradeTimestamp;
    }
    
    // ===== Events =====
    
    event CountryRegistered(
        bytes2 indexed iso2, 
        uint256 indexed timestamp
    );
    
    event PartnerRegistered(
        bytes32 indexed partnerKey, 
        string partnerName, 
        bytes2 iso2,
        uint256 indexed timestamp
    );
    
    event MerchantRegistered(
        bytes32 indexed merchantKey, 
        bytes2 indexed iso2,
        bytes32 indexed locationId,
        uint256 timestamp
    );
    
    event DeviceRegistered(
        bytes32 indexed deviceKey, 
        bytes32 indexed partnerKey, 
        bytes32 indexed merchantKey, 
        uint256 timestamp
    );
    
    event TransactionBatchUploaded(
        bytes32 indexed deviceHash, 
        uint256 indexed dateComparable, 
        uint32 orderCount,
        uint256 totalAmount,
        uint256 indexed timestamp
    );
    
    event TransactionDetailUploaded(
        bytes32 indexed transactionKey,
        bytes32 indexed userId,
        bytes32 sharexId,
        bytes32 transactionAmount,
        uint32 itemCount,
        uint256 timestamp,
        string additionalData
    );
    
    event SystemUpgraded(
        Version indexed newVersion, 
        uint256 indexed timestamp
    );
    
    event MaintenanceModeChanged(
        bool indexed enabled,
        uint256 indexed timestamp
    );
    
    // ===== Errors =====
    
    error EntityAlreadyExists(string entityType, bytes32 entityId);
    error EntityNotFound(string entityType, bytes32 entityId);
    error InvalidStringLength(string field, uint256 min, uint256 max);
    error InvalidRole(address user, bytes32 role);
    error MaintenanceModeActive();
    error InsufficientBalance(uint256 requested, uint256 available);
    error TransferFailed();
    error BatchSizeExceeded(uint256 provided, uint256 maximum);
    error ArrayLengthMismatch();
    error InvalidImplementation();
    error StartDateAfterEndDate();
    error InvalidAdminAddress();
    error EmptyTransactionDetails();
    error TooManyTransactionDetails();
    error OrderCountMismatch();
    error InvalidEntityType();
    error InvalidRecipientAddress();
    error NotInMaintenanceMode();
    
    // ===== Modifiers =====
    
    /**
     * @dev Checks if not in maintenance mode.
     */
    modifier notInMaintenance() {
        if (_systemState.maintenanceMode) {
            revert MaintenanceModeActive();
        }
        _;
    }
    
    /**
     * @dev Validates string length.
     */
    modifier validStringLength(string memory str, uint256 min, uint256 max) {
        if (bytes(str).length == 0 && (min != 0)) { // Handle empty string separately.
            revert InvalidStringLength("string", min, max);
        }
        if (bytes(str).length < min || bytes(str).length > max) {
            revert InvalidStringLength("string", min, max);
        }
        _;
    }
    
    // ===== Initializer =====
    
    /**
     * @dev Initializes the contract.
     * @param admin The administrator address.
     */
    function initialize(address admin) public initializer {
        if (admin == address(0)) {
            revert InvalidAdminAddress();
        }
        
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        
        // Set up roles.
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        
        // Initialize system state.
        _systemState = SystemState({
            version: Version({major: 1, minor: 0, patch: 0}),
            previousVersion: Version({major: 0, minor: 0, patch: 0}),
            upgradeTimestamp: block.timestamp,
            maintenanceMode: false
        });
    }
    
    // ===== Upgrade Authorization =====
    
    /**
     * @dev Authorizes contract upgrade.
     * @param newImplementation The new implementation address.
     */
    function _authorizeUpgrade(address newImplementation) 
        internal 
        view
        override 
        onlyRole(UPGRADER_ROLE) 
    {
        if (newImplementation == address(0)) {
            revert InvalidImplementation();
        }
        
        if (newImplementation.code.length == 0) {
            revert InvalidImplementation();
        }
    }
    
    // ===== Utility Functions =====
    
    /**
     * @dev Generates a key for a transaction batch.
     */
    function _generateTransactionKey(
        bytes32 deviceKey, 
        uint256 dateComparable
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(deviceKey, dateComparable));
    }

    // ===== Country Management Functions =====
    
    /**
     * @dev Registers a country.
     * @param countryCode The ISO2 country code.
     */
    function registerCountry(string calldata countryCode) 
        external 
        onlyRole(OPERATOR_ROLE) 
        whenNotPaused
        notInMaintenance
        validStringLength(countryCode, MAX_COUNTRY_CODE_LENGTH, MAX_COUNTRY_CODE_LENGTH)
    {
        bytes2 iso2 = bytes2(bytes(countryCode));
        bytes32 key = bytes32(iso2); // Use bytes2 as the key, but cast to bytes32 for the set
        
        if (_countryKeys.contains(key)) {
            revert EntityAlreadyExists("country", key);
        }
        
        _countries[iso2] = CountryInfo({
            iso2: iso2,
            timestamp: block.timestamp
        });
        
        _countryKeys.add(key);
        
        emit CountryRegistered(iso2, block.timestamp);
    }
    
    /**
     * @dev Gets country information.
     */
    function getCountryInfo(string calldata countryCode) 
        external 
        view 
        onlyRole(READER_ROLE) 
        returns (CountryInfo memory) 
    {
        bytes2 iso2 = bytes2(bytes(countryCode));
        bytes32 key = bytes32(iso2); // Use bytes2 as the key, but cast to bytes32 for the set
        if (!_countryKeys.contains(key)) {
            revert EntityNotFound("country", key);
        }
        return _countries[iso2];
    }
    
    /**
     * @dev Lists all countries (with pagination).
     */
    function listCountries(uint256 offset, uint256 limit) 
        external 
        view 
        onlyRole(READER_ROLE) 
        returns (CountryInfo[] memory countries) 
    {
        uint256 length = _countryKeys.length();
        if (offset >= length) {
            return new CountryInfo[](0);
        }

        uint256 count = (offset + limit > length) ? (length - offset) : limit;
        countries = new CountryInfo[](count);
        
        for (uint256 i = 0; i < count; i++) {
            bytes32 key = _countryKeys.at(offset + i);
            countries[i] = _countries[bytes2(key)];
        }
    }
    
    // ===== Partner Management Functions =====
    
    /**
     * @dev Registers a partner.
     */
    function registerPartner(PartnerParams calldata params)
        external
        onlyRole(OPERATOR_ROLE)
        whenNotPaused
        notInMaintenance
        validStringLength(params.partnerCode, 1, MAX_PARTNER_CODE_LENGTH)
        validStringLength(params.partnerName, 1, MAX_PARTNER_NAME_LENGTH)
        validStringLength(params.description, 0, MAX_DESCRIPTION_LENGTH)
        validStringLength(params.businessType, 1, MAX_BUSINESS_TYPE_LENGTH)
        validStringLength(params.verification, 1, MAX_VERIFICATION_LENGTH)
    {
        _registerPartnerInternal(params);
    }
    
    /**
     * @dev Registers multiple partners in a batch.
     */
    function registerMultiplePartners(PartnerParams[] calldata params)
        external
        onlyRole(OPERATOR_ROLE)
        whenNotPaused
        notInMaintenance
    {
        uint256 length = params.length;
        if (length == 0 || length > MAX_BATCH_SIZE) {
            revert BatchSizeExceeded(length, MAX_BATCH_SIZE);
        }
        
        for (uint256 i = 0; i < length; i++) {
            _registerPartnerInternal(params[i]);
        }
    }

    function _registerPartnerInternal(PartnerParams memory params) private {
        bytes32 key = bytes32(bytes(params.partnerCode));
        bytes2 iso2Bytes = bytes2(bytes(params.iso2));
        
        // Check if the country exists.
        if (!_countryKeys.contains(bytes32(iso2Bytes))) {
            revert EntityNotFound("country", bytes32(iso2Bytes));
        }
        
        if (_partnerKeys.contains(key)) {
            revert EntityAlreadyExists("partner", key);
        }
        
        _partnerIdCounter++;
        uint256 partnerId = _partnerIdCounter;
        
        _partners[key] = PartnerInfo({
            id: partnerId,
            partnerKey: key,
            partnerName: params.partnerName,
            iso2: iso2Bytes,
            verification: bytes32(bytes(params.verification)),
            description: params.description,
            businessType: params.businessType,
            timestamp: block.timestamp
        });
        
        _partnerKeys.add(key);
        
        emit PartnerRegistered(key, params.partnerName, iso2Bytes, block.timestamp);
    }
    
    /**
     * @dev Gets partner information.
     */
    function getPartnerInfo(string calldata partnerCode) 
        external 
        view 
        onlyRole(READER_ROLE) 
        returns (PartnerInfo memory) 
    {
        bytes32 key = bytes32(bytes(partnerCode));
        if (!_partnerKeys.contains(key)) {
            revert EntityNotFound("partner", key);
        }
        return _partners[key];
    }
    
    // ===== Merchant Management Functions =====
    
    /**
     * @dev Registers a merchant.
     */
    function registerMerchant(MerchantParams calldata params)
        external
        onlyRole(OPERATOR_ROLE)
        whenNotPaused
        notInMaintenance
        validStringLength(params.merchantId, MIN_MERCHANT_ID_LENGTH, MAX_MERCHANT_ID_LENGTH)
        validStringLength(params.locationId, 1, MAX_LOCATION_ID_LENGTH)
        validStringLength(params.location, 1, MAX_LOCATION_LENGTH)
        validStringLength(params.merchantType, 1, MAX_MERCHANT_TYPE_LENGTH)
        validStringLength(params.merchantName, 1, MAX_MERCHANT_NAME_LENGTH)
        validStringLength(params.verification, 1, MAX_VERIFICATION_LENGTH)
    {
        _registerMerchantInternal(params);
    }

    function _registerMerchantInternal(MerchantParams memory params) private {
        bytes32 key = bytes32(bytes(params.merchantId));
        bytes2 iso2Bytes = bytes2(bytes(params.iso2));
        
        // Check if the country exists.
        if (!_countryKeys.contains(bytes32(iso2Bytes))) {
            revert EntityNotFound("country", bytes32(iso2Bytes));
        }
        
        if (_merchantKeys.contains(key)) {
            revert EntityAlreadyExists("merchant", key);
        }
        
        _merchantIdCounter++;
        uint256 internalMerchantId = _merchantIdCounter;
        bytes32 locationIdKey = bytes32(bytes(params.locationId));
        
        _merchants[key] = MerchantInfo({
            id: internalMerchantId,
            merchantName: bytes32(bytes(params.merchantName)),
            merchantKey: key,
            description: params.description,
            iso2: iso2Bytes,
            locationId: locationIdKey,
            location: bytes32(bytes(params.location)),
            merchantType: bytes32(bytes(params.merchantType)),
            verification: bytes32(bytes(params.verification)),
            timestamp: block.timestamp
        });
        
        _merchantKeys.add(key);
        _merchantsByCountry[iso2Bytes].add(key);
        
        emit MerchantRegistered(key, iso2Bytes, locationIdKey, block.timestamp);
    }
    
    /**
     * @dev Gets merchant information.
     */
    function getMerchantInfo(string calldata merchantId) 
        external 
        view 
        onlyRole(READER_ROLE) 
        returns (MerchantInfo memory) 
    {
        bytes32 key = bytes32(bytes(merchantId));
        if (!_merchantKeys.contains(key)) {
            revert EntityNotFound("merchant", key);
        }
        return _merchants[key];
    }
    
    // ===== Device Management Functions =====
    
    /**
     * @dev Registers a device.
     */
    function registerDevice(DeviceParams calldata params)
        external
        onlyRole(OPERATOR_ROLE)
        whenNotPaused
        notInMaintenance
        validStringLength(params.deviceId, 1, MAX_DEVICE_ID_LENGTH)
        validStringLength(params.deviceType, 1, MAX_DEVICE_TYPE_LENGTH)
    {
        _registerDeviceInternal(params);
    }

    function _registerDeviceInternal(DeviceParams memory params) private {
        bytes32 deviceKey = bytes32(bytes(params.deviceId));
        bytes32 partnerKey = bytes32(bytes(params.partnerCode));
        bytes32 merchantKey = bytes32(bytes(params.merchantId));
        
        // Check if the partner exists and is active.
        if (!_partnerKeys.contains(partnerKey)) {
            revert EntityNotFound("partner", partnerKey);
        }
        
        if (_deviceKeys.contains(deviceKey)) {
            revert EntityAlreadyExists("device", deviceKey);
        }
        
        _deviceIdCounter++;
        uint256 internalDeviceId = _deviceIdCounter;
        
        _devices[deviceKey] = DeviceInfo({
            id: internalDeviceId,
            deviceKey: deviceKey,
            deviceType: bytes32(bytes(params.deviceType)),
            partnerKey: partnerKey,
            merchantKey: merchantKey,
            timestamp: block.timestamp
        });
        
        _deviceKeys.add(deviceKey);
        _merchantsByPartner[partnerKey].add(merchantKey);
        _devicesByMerchant[merchantKey].add(deviceKey);
        _devicesByPartner[partnerKey].add(deviceKey);
        
        emit DeviceRegistered(deviceKey, partnerKey, merchantKey, block.timestamp);
    }
    
    /**
     * @dev Registers multiple devices in a batch.
     */
    function registerMultipleDevices(DeviceParams[] calldata params)
        external
        onlyRole(OPERATOR_ROLE)
        whenNotPaused
        notInMaintenance
    {
        uint256 length = params.length;
        if (length == 0 || length > MAX_BATCH_SIZE) {
            revert BatchSizeExceeded(length, MAX_BATCH_SIZE);
        }
        
        for (uint256 i = 0; i < length; i++) {
            _registerDeviceInternal(params[i]);
        }
    }
    
    /**
     * @dev Gets device information.
     */
    function getDeviceInfo(string calldata deviceId) 
        external 
        view 
        onlyRole(READER_ROLE) 
        returns (DeviceInfo memory) 
    {
        bytes32 deviceKey = bytes32(bytes(deviceId));
        if (!_deviceKeys.contains(deviceKey)) {
            revert EntityNotFound("device", deviceKey);
        }
        return _devices[deviceKey];
    }
    
    /**
     * @dev Gets the device count by partner.
     */
    function getDevicesCountByPartner(string calldata partnerCode) 
        external 
        view 
        onlyRole(READER_ROLE) 
        returns (uint256) 
    {
        bytes32 partnerKey = bytes32(bytes(partnerCode));
        return _devicesByPartner[partnerKey].length();
    }
    
    /**
     * @dev Gets all devices by partner.
     */
    function getDevicesByPartner(string calldata partnerCode, uint256 offset, uint256 limit) 
        external 
        view 
        onlyRole(READER_ROLE) 
        returns (DeviceInfo[] memory) 
    {
        bytes32 partnerKey = bytes32(bytes(partnerCode));
        EnumerableSet.Bytes32Set storage deviceKeys = _devicesByPartner[partnerKey];
        uint256 length = deviceKeys.length();

        if (offset >= length) {
            return new DeviceInfo[](0);
        }
        
        uint256 count = (offset + limit > length) ? (length - offset) : limit;
        DeviceInfo[] memory devices = new DeviceInfo[](count);
        for (uint256 i = 0; i < count; i++) {
            bytes32 key = deviceKeys.at(offset + i);
            devices[i] = _devices[key];
        }
        
        return devices;
    }
    
    /**
     * @dev Gets device count by merchant.
     */
    function getDevicesCountByMerchant(string calldata merchantId) 
        external 
        view 
        onlyRole(READER_ROLE) 
        returns (uint256) 
    {
        bytes32 merchantKey = bytes32(bytes(merchantId));
        return _devicesByMerchant[merchantKey].length();
    }
    
    /**
     * @dev Gets device list by merchant (with pagination).
     */
    function getDevicesByMerchant(string calldata merchantId, uint256 offset, uint256 limit)
        external
        view
        onlyRole(READER_ROLE)
        returns (DeviceInfo[] memory)
    {
        bytes32 merchantKey = bytes32(bytes(merchantId));
        EnumerableSet.Bytes32Set storage deviceKeys = _devicesByMerchant[merchantKey];
        uint256 length = deviceKeys.length();

        if (offset >= length) {
            return new DeviceInfo[](0);
        }
        
        uint256 count = (offset + limit > length) ? (length - offset) : limit;
        DeviceInfo[] memory devices = new DeviceInfo[](count);
        for (uint256 i = 0; i < count; i++) {
            bytes32 key = deviceKeys.at(offset + i);
            devices[i] = _devices[key];
        }
        
        return devices;
    }
    
    // ===== Transaction Management Functions =====
    
    /**
     * @dev Uploads a transaction batch.
     */
    function uploadTransactionBatch(UploadBatchParams calldata params) 
        external 
        onlyRole(MERCHANT_ROLE) 
        whenNotPaused
        notInMaintenance
        nonReentrant
    {
        _uploadTransactionBatchInternal(params);
    }
    
    /**
     * @dev Uploads multiple transaction batches.
     */
    function uploadMultipleTransactionBatches(UploadBatchParams[] calldata params)
        external 
        onlyRole(MERCHANT_ROLE) 
        whenNotPaused
        notInMaintenance
        nonReentrant
    {
        uint256 length = params.length;
        if (length == 0 || length > MAX_BATCH_SIZE) {
            revert BatchSizeExceeded(length, MAX_BATCH_SIZE);
        }
        
        for (uint256 i = 0; i < length; i++) {
            _uploadTransactionBatchInternal(params[i]);
        }
    }

    /**
     * @dev Internal core logic for uploading a transaction batch.
     */
    function _uploadTransactionBatchInternal(UploadBatchParams memory params) private {
        if (params.transactionDetails.length == 0) {
            revert EmptyTransactionDetails();
        }
        if (params.transactionDetails.length > MAX_TRANSACTION_DETAILS_PER_BATCH) {
            revert TooManyTransactionDetails();
        }
        if (params.orderCount != params.transactionDetails.length) {
            revert OrderCountMismatch();
        }
        
        bytes32 deviceKey = bytes32(bytes(params.deviceHash));
        bytes32 key = _generateTransactionKey(deviceKey, params.dateComparable);
        
        if (_transactionBatchKeys.contains(key)) {
            revert EntityAlreadyExists("transaction_batch", key);
        }
        
        _transactionBatchIdCounter++;
        uint256 batchId = _transactionBatchIdCounter;
        
        // Store basic information.
        _transactionBatches[key] = TransactionBatch({
            id: batchId,
            basicInfo: BasicTransactionInfo({
                deviceHash: deviceKey,
                orderCount: params.orderCount,
                totalAmount: params.totalAmount,
                dateComparable: params.dateComparable
            }),
            batchTimestamp: block.timestamp
        });
        
        // Emit transaction detail events instead of storing them.
        for (uint256 i = 0; i < params.transactionDetails.length; i++) {
            TransactionDetail memory detail = params.transactionDetails[i];
            emit TransactionDetailUploaded(
                key,
                detail.userId,
                detail.sharexId,
                detail.transactionAmount,
                detail.itemCount,
                detail.timestamp,
                detail.additionalData
            );
        }
        
        _transactionBatchKeys.add(key);
        _transactionsByDevice[deviceKey].add(key);
        
        emit TransactionBatchUploaded(
            deviceKey, 
            params.dateComparable, 
            params.orderCount,
            params.totalAmount,
            block.timestamp
        );
    }
    
    /**
     * @dev Gets basic information of a transaction batch.
     */
    function getTransactionBatchBasicInfo(
        string calldata deviceHash, 
        uint256 dateComparable
    ) 
        external 
        view 
        onlyRole(READER_ROLE) 
        returns (BasicTransactionInfo memory) 
    {
        bytes32 deviceKey = bytes32(bytes(deviceHash));
        bytes32 key = _generateTransactionKey(deviceKey, dateComparable);
        
        if (!_transactionBatchKeys.contains(key)) {
            revert EntityNotFound("transaction_batch", key);
        }
        
        return _transactionBatches[key].basicInfo;
    }
    
    /**
     * @dev Gets all transaction batches for a device (with pagination).
     */
    function getTransactionBatchesByDevice(string calldata deviceHash, uint256 offset, uint256 limit)
        external
        view
        onlyRole(READER_ROLE)
        returns (TransactionBatch[] memory)
    {
        bytes32 deviceKey = bytes32(bytes(deviceHash));
        EnumerableSet.Bytes32Set storage batchKeys = _transactionsByDevice[deviceKey];
        uint256 length = batchKeys.length();

        if (offset >= length) {
            return new TransactionBatch[](0);
        }
        
        uint256 count = (offset + limit > length) ? (length - offset) : limit;
        TransactionBatch[] memory batches = new TransactionBatch[](count);
        for (uint256 i = 0; i < count; i++) {
            bytes32 key = batchKeys.at(offset + i);
            batches[i] = _transactionBatches[key];
        }
        
        return batches;
    }
    
    // ===== Statistics Query Functions =====
    
    /**
     * @dev Gets comprehensive statistics.
     */
    function getStats() external view onlyRole(READER_ROLE) returns (StatsInfo memory) {
        return StatsInfo({
            partnersCount: _partnerKeys.length(),
            merchantsCount: _merchantKeys.length(),
            devicesCount: _deviceKeys.length(),
            transactionBatchesCount: _transactionBatchKeys.length(),
            countriesCount: _countryKeys.length(),
            contractBalance: address(this).balance
        });
    }
    
    /**
     * @dev Gets merchant count by country.
     */
    function getMerchantsCountByCountry(string calldata iso2) 
        external 
        view 
        onlyRole(READER_ROLE) 
        returns (uint256) 
    {
        bytes2 iso2Bytes = bytes2(bytes(iso2));
        return _merchantsByCountry[iso2Bytes].length();
    }
    
    /**
     * @dev Gets merchant list by country.
     */
    function getMerchantsByCountry(string calldata iso2, uint256 offset, uint256 limit)
        external
        view
        onlyRole(READER_ROLE)
        returns (MerchantInfo[] memory)
    {
        bytes2 iso2Bytes = bytes2(bytes(iso2));
        EnumerableSet.Bytes32Set storage merchantKeys = _merchantsByCountry[iso2Bytes];
        uint256 length = merchantKeys.length();

        if (offset >= length) {
            return new MerchantInfo[](0);
        }
        
        uint256 count = (offset + limit > length) ? (length - offset) : limit;
        MerchantInfo[] memory merchants = new MerchantInfo[](count);
        for (uint256 i = 0; i < count; i++) {
            bytes32 key = merchantKeys.at(offset + i);
            merchants[i] = _merchants[key];
        }
        
        return merchants;
    }
    
    /**
     * @dev Gets merchant count by partner.
     */
    function getMerchantsCountByPartner(string calldata partnerCode) 
        external 
        view 
        onlyRole(READER_ROLE) 
        returns (uint256) 
    {
        bytes32 partnerKey = bytes32(bytes(partnerCode));
        return _merchantsByPartner[partnerKey].length();
    }
    
    /**
     * @dev Gets merchant list by partner (with pagination).
     */
    function getMerchantsByPartner(string calldata partnerCode, uint256 offset, uint256 limit)
        external
        view
        onlyRole(READER_ROLE)
        returns (MerchantInfo[] memory)
    {
        bytes32 partnerKey = bytes32(bytes(partnerCode));
        EnumerableSet.Bytes32Set storage merchantKeys = _merchantsByPartner[partnerKey];
        uint256 length = merchantKeys.length();

        if (offset >= length) {
            return new MerchantInfo[](0);
        }
        
        uint256 count = (offset + limit > length) ? (length - offset) : limit;
        MerchantInfo[] memory merchants = new MerchantInfo[](count);
        for (uint256 i = 0; i < count; i++) {
            bytes32 key = merchantKeys.at(offset + i);
            merchants[i] = _merchants[key];
        }
        
        return merchants;
    }
    
    /**
     * @dev Gets a transaction summary.
     */
    function getTransactionSummary(
        string calldata deviceHash,
        uint256 startDate,
        uint256 endDate
    )
        external
        view
        onlyRole(READER_ROLE)
        returns (uint256 totalBatches, uint256 totalOrders, uint256 totalAmount)
    {
        bytes32 deviceKey = bytes32(bytes(deviceHash));
        EnumerableSet.Bytes32Set storage batchKeys = _transactionsByDevice[deviceKey];
        
        if (startDate > endDate) {
            revert StartDateAfterEndDate();
        }
        
        for (uint256 i = 0; i < batchKeys.length(); i++) {
            bytes32 key = batchKeys.at(i);
            TransactionBatch storage batch = _transactionBatches[key];
            
            if (batch.basicInfo.dateComparable >= startDate && batch.basicInfo.dateComparable <= endDate) {
                totalBatches++;
                totalOrders += batch.basicInfo.orderCount;
                totalAmount += batch.basicInfo.totalAmount;
            }
        }
    }
    
    // ===== System Management Functions =====
    
    /**
     * @dev Upgrades the system version.
     */
    function upgradeVersion(uint8 major, uint8 minor, uint8 patch) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        _systemState.previousVersion = _systemState.version;
        _systemState.version = Version({
            major: major,
            minor: minor,
            patch: patch
        });
        _systemState.upgradeTimestamp = block.timestamp;
        
        emit SystemUpgraded(_systemState.version, block.timestamp);
    }

    /**
     * @dev Sets the maintenance mode.
     */
    function setMaintenanceMode(bool enabled) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        _systemState.maintenanceMode = enabled;
        emit MaintenanceModeChanged(enabled, block.timestamp);
    }
    
    /**
     * @dev Gets the system state.
     */
    function getSystemState() 
        external 
        view 
        onlyRole(READER_ROLE) 
        returns (SystemState memory) 
    {
        return _systemState;
    }
    
    // ===== Fund Management Functions =====
    
    /**
     * @dev Receives BNB.
     */
    receive() external payable {
        // The contract can receive BNB.
    }
    
    /**
     * @dev Withdraws the contract balance.
     */
    function withdraw(uint256 amount, address payable recipient) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
        nonReentrant 
    {
        if (recipient == address(0)) {
            revert InvalidRecipientAddress();
        }
        
        uint256 balance = address(this).balance;
        if (amount > balance) {
            revert InsufficientBalance(amount, balance);
        }
        
        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert TransferFailed();
        }
    }
    
    /**
     * @dev Emergency withdrawal of the entire balance.
     */
    function emergencyWithdrawAll(address payable recipient)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        if (recipient == address(0)) {
            revert InvalidRecipientAddress();
        }
        if (!_systemState.maintenanceMode) {
            revert NotInMaintenanceMode();
        }
        
        uint256 balance = address(this).balance;
        (bool success, ) = recipient.call{value: balance}("");
        if (!success) {
            revert TransferFailed();
        }
    }
    
    // ===== Emergency Control Functions =====
    
    /**
     * @dev Emergency pause.
     */
    function emergencyPause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
        _systemState.maintenanceMode = true;
        emit MaintenanceModeChanged(true, block.timestamp);
    }
    
    /**
     * @dev Resumes operation.
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
        _systemState.maintenanceMode = false;
        emit MaintenanceModeChanged(false, block.timestamp);
    }
    
    // ===== Data Export Functions =====
    
    /**
     * @dev Exports all partner data.
     */
    function exportAllPartners(uint256 offset, uint256 limit)
        external
        view
        onlyRole(READER_ROLE)
        returns (PartnerInfo[] memory)
    {
        uint256 length = _partnerKeys.length();
        if (offset >= length) {
            return new PartnerInfo[](0);
        }

        uint256 count = (offset + limit > length) ? (length - offset) : limit;
        PartnerInfo[] memory partners = new PartnerInfo[](count);
        
        for (uint256 i = 0; i < count; i++) {
            bytes32 key = _partnerKeys.at(offset + i);
            partners[i] = _partners[key];
        }
        
        return partners;
    }
    
    /**
     * @dev Exports all device data.
     */
    function exportAllDevices(uint256 offset, uint256 limit)
        external
        view
        onlyRole(READER_ROLE)
        returns (DeviceInfo[] memory)
    {
        uint256 length = _deviceKeys.length();
        if (offset >= length) {
            return new DeviceInfo[](0);
        }
        
        uint256 count = (offset + limit > length) ? (length - offset) : limit;
        DeviceInfo[] memory devices = new DeviceInfo[](count);
        
        for (uint256 i = 0; i < count; i++) {
            bytes32 key = _deviceKeys.at(offset + i);
            devices[i] = _devices[key];
        }
        
        return devices;
    }
    
    // ===== Version Information =====
    
    /**
     * @dev Gets the contract version as a string.
     */
    function version() external view virtual returns (string memory) {
        return string(abi.encodePacked(
            uint256(_systemState.version.major).toString(),
            ".",
            uint256(_systemState.version.minor).toString(),
            ".",
            uint256(_systemState.version.patch).toString()
        ));
    }
    
    // ===== Storage Gap =====
    
    /**
     * @dev Reserved storage slots for future upgrades to prevent storage collisions.
     */
    uint256[50] private __gap;
}
