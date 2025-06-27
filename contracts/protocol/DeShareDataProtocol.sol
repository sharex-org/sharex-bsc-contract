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
 * @title DeShare Data Protocol Smart Contract
 * @dev A smart contract for managing partner, merchant, device, and transaction data attestation.
 * @author DeShare Team
 * @notice This is an upgradeable smart contract for data management in the DeShare ecosystem.
 * @custom:security-contact security@deshare.com
 */
contract DeShareDataProtocol is 
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
    
    // ===== State Variables =====
    
    // Using mappings to store primary data.
    mapping(bytes2 => CountryInfo) internal _countries;
    mapping(bytes32 => PartnerInfo) internal _partners;
    mapping(bytes32 => MerchantInfo) internal _merchants;
    mapping(bytes32 => DeviceInfo) internal _devices;
    mapping(bytes32 => mapping(uint256 => TransactionBatch)) internal _transactionBatches;
    
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
    
    // ===== Custom Errors =====
    
    error EntityNotFound(string entityType, bytes32 key);
    error EntityAlreadyExists(string entityType, bytes32 key);
    error InvalidStringLength(string paramName, uint256 actualLength, uint256 minLength, uint256 maxLength);
    error InvalidParameter(string paramName);
    error MaintenanceModeActive();
    error InsufficientBalance(uint256 required, uint256 available);
    error TransactionBatchNotFound(bytes32 deviceId, uint256 dateComparable);
    
    // ===== Modifiers =====
    
    modifier notInMaintenance() {
        if (_systemState.maintenanceMode) {
            revert MaintenanceModeActive();
        }
        _;
    }
    
    modifier validStringLength(string memory str, uint256 minLength, uint256 maxLength, string memory paramName) {
        uint256 length = bytes(str).length;
        if (length < minLength || length > maxLength) {
            revert InvalidStringLength(paramName, length, minLength, maxLength);
        }
        _;
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

    // ========== Constructor Disabled ==========
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ========== Initialization Function ==========
    
    /**
     * @dev Initialization function
     * @param _initialOwner Initial admin address
     */
    function initialize(address _initialOwner) public initializer {
        require(_initialOwner != address(0), "DeShareDataProtocol: Invalid initial owner");
        
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, _initialOwner);
        _grantRole(OPERATOR_ROLE, _initialOwner);
        _grantRole(MERCHANT_ROLE, _initialOwner);
        _grantRole(READER_ROLE, _initialOwner);
        _grantRole(UPGRADER_ROLE, _initialOwner);
        
        // Initialize system state
        _systemState.version = Version({major: 1, minor: 0, patch: 0});
        _systemState.previousVersion = Version({major: 0, minor: 0, patch: 0});
        _systemState.upgradeTimestamp = block.timestamp;
        _systemState.maintenanceMode = false;
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
        require(newImplementation != address(0), "DeShareDataProtocol: Invalid implementation");
        require(newImplementation.code.length > 0, "DeShareDataProtocol: Invalid implementation");
    }

    // Note: This is a template - the full implementation would include all the original
    // data management functions from DeShareProtocol.sol (partners, merchants, devices, transactions)
    // but without the DeFi record functionality to reduce contract size.
    
    // ===== Storage Gap =====
    
    /**
     * @dev Reserved storage slots for future upgrades to prevent storage collisions.
     */
    uint256[50] private __gap;
} 