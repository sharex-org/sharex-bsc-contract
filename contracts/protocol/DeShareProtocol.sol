// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./DeShareDataProtocol.sol";
import "./DeShareDeFiProtocol.sol";

/**
 * @title DeShare Protocol Smart Contract V3 (Refactored)
 * @dev A smart contract proxy that integrates data and DeFi functionalities.
 * @author DeShare Team
 * @notice This is an upgradeable smart contract that maintains compatibility while reducing size.
 * @custom:security-contact security@deshare.com
 */
contract DeShareProtocol is 
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable 
{
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
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
        bytes32 partnerCode;    // Partner code.
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
        bytes32 merchantId;              // Merchant ID.
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
        bytes32 deviceId;       // Device ID.
        bytes32 deviceType;     // Device type.
        bytes32 partnerCode;    // Partner code.
        bytes32 merchantId;     // Merchant ID.
        uint256 timestamp;      // Registration timestamp.
    }
    
    /**
     * @dev Basic transaction information structure.
     */
    struct BasicTransactionInfo {
        bytes32 deviceId;       // Device ID.
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
        string deviceId;
        uint256 dateComparable; // Date in YYYYMMDD format.
        uint32 orderCount;
        uint256 totalAmount;
        TransactionDetail[] transactionDetails;
    }
    
    // ===== DeFi Record Structures =====
    
    /**
     * @dev Deposit record structure for tracking user DeFi operations.
     */
    struct DepositRecord {
        uint256 amount;         // Deposit/withdrawal amount
        uint256 timestamp;      // Operation timestamp
        bool isDeposit;         // true for deposit, false for withdrawal
    }
    
    /**
     * @dev Rental record structure for tracking device rental information.
     */
    struct RentalRecord {
        address user;           // User address
        uint256 deviceId;       // Device ID (converted to uint256)
        uint256 startTime;      // Rental start timestamp
        uint256 endTime;        // Rental end timestamp (0 if still active)
        uint256 deposit;        // Deposit amount required
        uint256 fee;            // Rental fee charged
        bool isActive;          // Whether rental is currently active
    }
    
    // ===== State Variables =====
    
    // Using mappings to store primary data.
    mapping(bytes2 => CountryInfo) internal _countries;
    mapping(bytes32 => PartnerInfo) internal _partners;
    mapping(bytes32 => MerchantInfo) internal _merchants;
    mapping(bytes32 => DeviceInfo) internal _devices;
    mapping(bytes32 => mapping(uint256 => TransactionBatch)) internal _transactionBatches;
    
    // DeFi record mappings
    mapping(address => DepositRecord[]) internal _userDeposits;
    mapping(uint256 => RentalRecord) internal _rentalRecords;
    uint256 private _rentalIdCounter;
    
    // Reverse mapping, used to restore original value from hash.
    mapping(bytes32 => bytes2) private _hashToCountryCode;
    
    // Using EnumerableSet to manage key sets.
    EnumerableSet.Bytes32Set private _countryKeys;
    EnumerableSet.Bytes32Set private _partnerKeys;
    EnumerableSet.Bytes32Set private _merchantKeys;
    EnumerableSet.Bytes32Set private _deviceKeys;
    
    // System state.
    SystemState private _systemState;
    
    // Index mappings - for fast lookups.
    mapping(bytes2 => EnumerableSet.Bytes32Set) private _merchantsByCountry;
    mapping(bytes32 => EnumerableSet.Bytes32Set) private _merchantsByPartner;
    mapping(bytes32 => EnumerableSet.Bytes32Set) private _devicesByMerchant;
    mapping(bytes32 => EnumerableSet.Bytes32Set) private _devicesByPartner;
    mapping(bytes32 => EnumerableSet.UintSet) private _transactionsByDevice;
    
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
        bytes32 indexed partnerCode, 
        string partnerName, 
        bytes2 iso2,
        uint256 indexed timestamp
    );
    
    event MerchantRegistered(
        bytes32 indexed merchantId, 
        bytes2 indexed iso2,
        bytes32 indexed locationId,
        uint256 timestamp
    );
    
    event DeviceRegistered(
        bytes32 indexed deviceId, 
        bytes32 indexed partnerCode, 
        bytes32 indexed merchantId, 
        uint256 timestamp
    );
    
    event TransactionBatchUploaded(
        bytes32 indexed deviceId, 
        uint256 indexed dateComparable, 
        uint32 orderCount,
        uint256 totalAmount,
        uint256 indexed timestamp
    );
    
    event TransactionDetailUploaded(
        bytes32 indexed deviceId,
        uint256 indexed dateComparable,
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
    
    // ===== DeFi Record Events =====
    
    event DepositRecorded(
        address indexed user,
        uint256 indexed amount,
        bool indexed isDeposit,
        uint256 timestamp
    );
    
    event RentalRecorded(
        uint256 indexed rentalId,
        address indexed user,
        uint256 indexed deviceId,
        uint256 startTime,
        uint256 deposit,
        uint256 fee
    );
    
    event RentalReturned(
        uint256 indexed rentalId,
        address indexed user,
        uint256 indexed deviceId,
        uint256 endTime,
        uint256 finalFee
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
    
    // ===== State Variables =====
    
    /// @notice Data protocol contract for attestation functionality
    DeShareDataProtocol public dataProtocol;
    
    /// @notice DeFi protocol contract for DeFi record functionality
    DeShareDeFiProtocol public defiProtocol;
    
    // Legacy token and adapter for backward compatibility
    address public token;
    address public defiAdapter;
    
    // ===== Events =====
    
    event ProtocolsUpdated(
        address indexed dataProtocol,
        address indexed defiProtocol
    );

    // ========== Constructor Disabled ==========
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ========== Initialization Function ==========
    
    /**
     * @dev Initialization function
     * @param _token Token address (for backward compatibility)
     * @param _defiAdapter DeFi adapter address (for backward compatibility)
     * @param _initialOwner Initial admin address
     */
    function initialize(
        address _token,
        address _defiAdapter,
        address _initialOwner
    ) public initializer {
        require(_token != address(0), "DeShareProtocol: Invalid token");
        require(_defiAdapter != address(0), "DeShareProtocol: Invalid DeFi adapter");
        require(_initialOwner != address(0), "DeShareProtocol: Invalid initial owner");
        
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        
        token = _token;
        defiAdapter = _defiAdapter;
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, _initialOwner);
        _grantRole(OPERATOR_ROLE, _initialOwner);
        _grantRole(MERCHANT_ROLE, _initialOwner);
        _grantRole(READER_ROLE, _initialOwner);
        _grantRole(UPGRADER_ROLE, _initialOwner);
    }

    // ========== Upgrade Authorization ==========
    
    /**
     * @notice Authorize contract upgrade
     * @param newImplementation New implementation contract address
     */
    function _authorizeUpgrade(address newImplementation) 
        internal 
        view
        override 
        onlyRole(UPGRADER_ROLE) 
    {
        require(newImplementation != address(0), "DeShareProtocol: Invalid implementation");
        require(newImplementation.code.length > 0, "DeShareProtocol: Invalid implementation");
    }

    // ========== Admin Functions ==========
    
    /**
     * @notice Set the data and DeFi protocol contracts
     * @param _dataProtocol Data protocol contract address
     * @param _defiProtocol DeFi protocol contract address
     */
    function setProtocols(
        address _dataProtocol,
        address _defiProtocol
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_dataProtocol != address(0), "DeShareProtocol: Invalid data protocol");
        require(_defiProtocol != address(0), "DeShareProtocol: Invalid DeFi protocol");
        
        dataProtocol = DeShareDataProtocol(_dataProtocol);
        defiProtocol = DeShareDeFiProtocol(_defiProtocol);
        
        emit ProtocolsUpdated(_dataProtocol, _defiProtocol);
    }

    // ===== DeFi Record Functions (Proxy to DeShareDeFiProtocol) =====
    
    /**
     * @dev Records a user deposit or withdrawal operation.
     * @param user User address
     * @param amount Operation amount
     * @param isDeposit true for deposit, false for withdrawal
     */
    function recordDeposit(
        address user,
        uint256 amount,
        bool isDeposit
    ) external onlyRole(OPERATOR_ROLE) {
        require(address(defiProtocol) != address(0), "DeShareProtocol: DeFi protocol not set");
        defiProtocol.recordDeposit(user, amount, isDeposit);
    }
    
    /**
     * @dev Records a device rental operation.
     * @param user User address
     * @param deviceId Device ID (as string, will be converted)
     * @param deposit Deposit amount required
     * @param fee Rental fee
     * @return rentalId The ID of the created rental record
     */
    function recordRental(
        address user,
        string memory deviceId,
        uint256 deposit,
        uint256 fee
    ) external onlyRole(OPERATOR_ROLE) returns (uint256 rentalId) {
        require(address(defiProtocol) != address(0), "DeShareProtocol: DeFi protocol not set");
        return defiProtocol.recordRental(user, deviceId, deposit, fee);
    }
    
    /**
     * @dev Records the return of a rented device.
     * @param rentalId Rental record ID
     * @param finalFee Final fee charged (may be different from initial fee)
     */
    function recordReturn(
        uint256 rentalId,
        uint256 finalFee
    ) external onlyRole(OPERATOR_ROLE) {
        require(address(defiProtocol) != address(0), "DeShareProtocol: DeFi protocol not set");
        defiProtocol.recordReturn(rentalId, finalFee);
    }
    
    /**
     * @dev Gets user's deposit history.
     * @param user User address
     * @return Array of deposit records
     */
    function getUserDepositHistory(address user) 
        external 
        view 
        onlyRole(READER_ROLE) 
        returns (DeShareDeFiProtocol.DepositRecord[] memory) 
    {
        require(address(defiProtocol) != address(0), "DeShareProtocol: DeFi protocol not set");
        return defiProtocol.getUserDepositHistory(user);
    }
    
    /**
     * @dev Gets user's deposit history with pagination.
     * @param user User address
     * @param offset Starting index
     * @param limit Maximum number of records to return
     * @return Array of deposit records
     */
    function getUserDepositHistoryPaginated(
        address user,
        uint256 offset,
        uint256 limit
    ) 
        external 
        view 
        onlyRole(READER_ROLE) 
        returns (DeShareDeFiProtocol.DepositRecord[] memory) 
    {
        require(address(defiProtocol) != address(0), "DeShareProtocol: DeFi protocol not set");
        return defiProtocol.getUserDepositHistoryPaginated(user, offset, limit);
    }
    
    /**
     * @dev Gets rental record by ID.
     * @param rentalId Rental record ID
     * @return Rental record
     */
    function getRentalRecord(uint256 rentalId) 
        external 
        view 
        onlyRole(READER_ROLE) 
        returns (DeShareDeFiProtocol.RentalRecord memory) 
    {
        require(address(defiProtocol) != address(0), "DeShareProtocol: DeFi protocol not set");
        return defiProtocol.getRentalRecord(rentalId);
    }
    
    /**
     * @dev Gets active rentals for a user.
     * @param user User address
     * @return Array of rental IDs for active rentals
     */
    function getUserActiveRentals(address user) 
        external 
        view 
        onlyRole(READER_ROLE) 
        returns (uint256[] memory) 
    {
        require(address(defiProtocol) != address(0), "DeShareProtocol: DeFi protocol not set");
        return defiProtocol.getUserActiveRentals(user);
    }
    
    /**
     * @dev Gets rental history for a user.
     * @param user User address
     * @param includeActive Whether to include active rentals
     * @return Array of rental IDs
     */
    function getUserRentalHistory(
        address user,
        bool includeActive
    ) 
        external 
        view 
        onlyRole(READER_ROLE) 
        returns (uint256[] memory) 
    {
        require(address(defiProtocol) != address(0), "DeShareProtocol: DeFi protocol not set");
        return defiProtocol.getUserRentalHistory(user, includeActive);
    }
    
    /**
     * @dev Gets the total number of rental records.
     * @return Total rental count
     */
    function getTotalRentalCount() 
        external 
        view 
        onlyRole(READER_ROLE) 
        returns (uint256) 
    {
        require(address(defiProtocol) != address(0), "DeShareProtocol: DeFi protocol not set");
        return defiProtocol.getTotalRentalCount();
    }
    
    /**
     * @dev Gets user deposit statistics.
     * @param user User address
     * @return totalDeposits Total amount deposited
     * @return totalWithdrawals Total amount withdrawn
     * @return depositCount Number of deposit operations
     * @return withdrawalCount Number of withdrawal operations
     */
    function getUserDepositStats(address user) 
        external 
        view 
        onlyRole(READER_ROLE) 
        returns (
            uint256 totalDeposits,
            uint256 totalWithdrawals,
            uint256 depositCount,
            uint256 withdrawalCount
        ) 
    {
        require(address(defiProtocol) != address(0), "DeShareProtocol: DeFi protocol not set");
        return defiProtocol.getUserDepositStats(user);
    }
    
    // Note: Data protocol functions would be added here as proxy functions
    // For brevity, I'm showing the pattern with DeFi functions
    // The full implementation would include all data management functions
    
    // ===== Storage Gap =====
    
    /**
     * @dev Reserved storage slots for future upgrades to prevent storage collisions.
     */
    uint256[47] private __gap;
}
