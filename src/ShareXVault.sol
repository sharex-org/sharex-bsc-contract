// SPDX-License-Identifier: MIT
// solhint-disable var-name-mixedcase,immutable-vars-naming
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IShareXVault} from "./interfaces/IShareXVault.sol";
import {
    BasicTransactionInfo,
    CountryInfo,
    DeviceInfo,
    DeviceParams,
    MerchantInfo,
    MerchantParams,
    PartnerInfo,
    PartnerParams,
    StatsInfo,
    SystemState,
    TransactionBatch,
    TransactionDetail,
    UploadBatchParams,
    Version
} from "./libraries/DataTypes.sol";
import {
    EmptyTransactionDetails,
    EntityAlreadyExists,
    EntityNotFound,
    InsufficientBalance,
    InvalidAdminAddress,
    InvalidRecipientAddress,
    InvalidStringLength,
    MaintenanceModeActive,
    OrderCountMismatch,
    TooManyTransactionDetails,
    TransferFailed
} from "./libraries/Errors.sol";
import {
    ContractInitialized,
    CountryRegistered,
    DeviceRegistered,
    EmergencyActionTaken,
    EthDeposited,
    EthWithdrawn,
    MaintenanceModeToggled,
    MerchantRegistered,
    PartnerRegistered,
    TransactionBatchUploaded,
    TransactionDetailsUploaded
} from "./libraries/Events.sol";

/**
 * @title ShareX Vault Contract
 * @dev Core business logic contract for ShareX ecosystem data management
 * @notice Handles partner, merchant, device registration and transaction processing
 * @custom:security-contact security@sharex.com
 */
contract ShareXVault is AccessControl, Pausable, ReentrancyGuard, IShareXVault {
    // Constants
    /// @dev Role identifier for operators who can register entities and upload transactions
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @dev Maximum number of transaction details allowed in a single batch
    uint256 public constant MAX_BATCH_SIZE = 1000;

    /// @dev Maximum length for string parameters
    uint256 public constant MAX_STRING_LENGTH = 256;

    /// @dev Minimum length for string parameters
    uint256 public constant MIN_STRING_LENGTH = 1;

    // State Variables
    /// @dev Core system state including version and maintenance mode
    SystemState private _systemState;

    /// @dev Counter for partner registrations
    uint256 private _partnerCounter;

    /// @dev Counter for merchant registrations
    uint256 private _merchantCounter;

    /// @dev Counter for device registrations
    uint256 private _deviceCounter;

    /// @dev Counter for transaction batches
    uint256 private _batchCounter;

    /// @dev Mapping from partner ID to partner information
    mapping(uint256 partnerId => PartnerInfo partner) private _partners;

    /// @dev Mapping from partner code hash to partner ID
    mapping(bytes32 partnerCode => uint256 partnerId) private _partnerCodeToId;

    /// @dev Mapping from merchant ID to merchant information
    mapping(uint256 merchantId => MerchantInfo merchant) private _merchants;

    /// @dev Mapping from merchant ID hash to internal ID
    mapping(bytes32 merchantId => uint256 id) private _merchantIdToId;

    /// @dev Mapping from device ID to device information
    mapping(uint256 deviceId => DeviceInfo device) private _devices;

    /// @dev Mapping from device ID hash to internal ID
    mapping(bytes32 deviceId => uint256 id) private _deviceIdToId;

    /// @dev Mapping from batch ID to transaction batch information
    mapping(uint256 batchId => TransactionBatch batch) private _transactionBatches;

    /// @dev Mapping from batch ID to array of transaction details
    mapping(uint256 batchId => TransactionDetail[] details) private _transactionDetails;

    /// @dev Mapping from ISO2 country code to country information
    mapping(bytes2 iso2 => CountryInfo country) private _countries;

    /**
     * @dev Initializes the ShareX Vault contract
     * @param admin Address that will be granted admin and operator roles
     */
    constructor(address admin) {
        if (admin == address(0)) {
            revert InvalidAdminAddress();
        }

        // Grant roles to admin
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);

        // Initialize system state
        _systemState.version = Version({major: 1, minor: 0, patch: 0});
        _systemState.maintenanceMode = false;

        emit ContractInitialized(admin, _systemState.version, block.timestamp);
    }

    /**
     * @dev Allows the contract to receive ETH directly
     * @notice This function cannot be part of an interface as it's a special Solidity function
     */
    /* solhint-disable comprehensive-interface */
    receive() external payable {
        emit EthDeposited(msg.sender, msg.value, block.timestamp);
    }
    /* solhint-enable comprehensive-interface */

    /**
     * @inheritdoc IShareXVault
     */
    function registerPartner(PartnerParams calldata params)
        external
        override
        onlyRole(OPERATOR_ROLE)
        whenNotPaused
    {
        _validateMaintenanceMode();
        _validateStringLength(params.partnerCode, "partnerCode");
        _validateStringLength(params.partnerName, "partnerName");
        _validateStringLength(params.iso2, "iso2");
        _validateStringLength(params.verification, "verification");
        _validateStringLength(params.description, "description");
        _validateStringLength(params.businessType, "businessType");

        bytes32 partnerCode = keccak256(abi.encodePacked(params.partnerCode));

        if (_partnerCodeToId[partnerCode] != 0) {
            revert EntityAlreadyExists("partner", partnerCode);
        }

        _partnerCounter++;
        uint256 partnerId = _partnerCounter;
        bytes2 iso2 = _stringToBytes2(params.iso2);

        _partners[partnerId] = PartnerInfo({
            id: partnerId,
            partnerCode: partnerCode,
            partnerName: params.partnerName,
            iso2: iso2,
            verification: keccak256(abi.encodePacked(params.verification)),
            description: params.description,
            businessType: params.businessType,
            timestamp: block.timestamp
        });

        _partnerCodeToId[partnerCode] = partnerId;

        emit PartnerRegistered(partnerId, partnerCode, params.partnerName, iso2, block.timestamp);
    }

    /**
     * @inheritdoc IShareXVault
     */
    function registerMerchant(MerchantParams calldata params)
        external
        override
        onlyRole(OPERATOR_ROLE)
        whenNotPaused
    {
        _validateMaintenanceMode();
        _validateStringLength(params.merchantName, "merchantName");
        _validateStringLength(params.merchantId, "merchantId");
        _validateStringLength(params.iso2, "iso2");
        _validateStringLength(params.locationId, "locationId");
        _validateStringLength(params.location, "location");
        _validateStringLength(params.merchantType, "merchantType");
        _validateStringLength(params.verification, "verification");

        bytes32 merchantId = keccak256(abi.encodePacked(params.merchantId));

        if (_merchantIdToId[merchantId] != 0) {
            revert EntityAlreadyExists("merchant", merchantId);
        }

        _merchantCounter++;
        uint256 id = _merchantCounter;
        bytes2 iso2 = _stringToBytes2(params.iso2);

        _merchants[id] = MerchantInfo({
            id: id,
            merchantName: keccak256(abi.encodePacked(params.merchantName)),
            merchantId: merchantId,
            description: params.description,
            iso2: iso2,
            locationId: keccak256(abi.encodePacked(params.locationId)),
            location: keccak256(abi.encodePacked(params.location)),
            merchantType: keccak256(abi.encodePacked(params.merchantType)),
            verification: keccak256(abi.encodePacked(params.verification)),
            timestamp: block.timestamp
        });

        _merchantIdToId[merchantId] = id;

        emit MerchantRegistered(
            id, keccak256(abi.encodePacked(params.merchantName)), merchantId, iso2, block.timestamp
        );
    }

    /**
     * @inheritdoc IShareXVault
     */
    function registerDevice(DeviceParams calldata params)
        external
        override
        onlyRole(OPERATOR_ROLE)
        whenNotPaused
    {
        _validateMaintenanceMode();
        _validateStringLength(params.deviceId, "deviceId");
        _validateStringLength(params.deviceType, "deviceType");
        _validateStringLength(params.partnerCode, "partnerCode");
        _validateStringLength(params.merchantId, "merchantId");

        bytes32 deviceId = keccak256(abi.encodePacked(params.deviceId));
        bytes32 partnerCode = keccak256(abi.encodePacked(params.partnerCode));
        bytes32 merchantId = keccak256(abi.encodePacked(params.merchantId));

        if (_deviceIdToId[deviceId] != 0) {
            revert EntityAlreadyExists("device", deviceId);
        }

        // Verify dependencies exist
        if (_partnerCodeToId[partnerCode] == 0) {
            revert EntityNotFound("partner", partnerCode);
        }
        if (_merchantIdToId[merchantId] == 0) {
            revert EntityNotFound("merchant", merchantId);
        }

        _deviceCounter++;
        uint256 id = _deviceCounter;

        _devices[id] = DeviceInfo({
            id: id,
            deviceId: deviceId,
            deviceType: keccak256(abi.encodePacked(params.deviceType)),
            partnerCode: partnerCode,
            merchantId: merchantId,
            timestamp: block.timestamp
        });

        _deviceIdToId[deviceId] = id;

        emit DeviceRegistered(
            id,
            deviceId,
            keccak256(abi.encodePacked(params.deviceType)),
            partnerCode,
            merchantId,
            block.timestamp
        );
    }

    /**
     * @inheritdoc IShareXVault
     */
    function uploadTransactionBatch(UploadBatchParams calldata params)
        external
        override
        onlyRole(OPERATOR_ROLE)
        whenNotPaused
        nonReentrant
    {
        _validateMaintenanceMode();
        _validateStringLength(params.deviceId, "deviceId");

        if (params.transactionDetails.length == 0) {
            revert EmptyTransactionDetails();
        }
        if (params.transactionDetails.length > MAX_BATCH_SIZE) {
            revert TooManyTransactionDetails();
        }
        if (params.orderCount != params.transactionDetails.length) {
            revert OrderCountMismatch();
        }

        bytes32 deviceId = keccak256(abi.encodePacked(params.deviceId));

        if (_deviceIdToId[deviceId] == 0) {
            revert EntityNotFound("device", deviceId);
        }

        _batchCounter++;
        uint256 batchId = _batchCounter;

        _transactionBatches[batchId] = TransactionBatch({
            id: batchId,
            basicInfo: BasicTransactionInfo({
                deviceId: deviceId,
                orderCount: params.orderCount,
                totalAmount: params.totalAmount,
                dateComparable: params.dateComparable
            }),
            batchTimestamp: block.timestamp
        });

        // Store transaction details
        for (uint256 i = 0; i < params.transactionDetails.length; i++) {
            _transactionDetails[batchId].push(params.transactionDetails[i]);
        }

        emit TransactionBatchUploaded(
            batchId,
            deviceId,
            params.orderCount,
            params.totalAmount,
            params.dateComparable,
            block.timestamp
        );

        emit TransactionDetailsUploaded(batchId, params.transactionDetails.length, block.timestamp);
    }

    /**
     * @inheritdoc IShareXVault
     */
    function registerCountry(string calldata iso2)
        external
        override
        onlyRole(OPERATOR_ROLE)
        whenNotPaused
    {
        _validateMaintenanceMode();
        _validateStringLength(iso2, "iso2");

        bytes2 iso2Bytes = _stringToBytes2(iso2);

        if (_countries[iso2Bytes].timestamp != 0) {
            revert EntityAlreadyExists("country", bytes32(iso2Bytes));
        }

        _countries[iso2Bytes] = CountryInfo({iso2: iso2Bytes, timestamp: block.timestamp});

        emit CountryRegistered(iso2Bytes, block.timestamp);
    }

    /**
     * @inheritdoc IShareXVault
     */
    function setMaintenanceMode(bool enabled) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _systemState.maintenanceMode = enabled;
        emit MaintenanceModeToggled(enabled, block.timestamp);
    }

    /**
     * @inheritdoc IShareXVault
     */
    function withdrawEth(address payable recipient, uint256 amount)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        if (recipient == address(0)) {
            revert InvalidRecipientAddress();
        }
        if (amount > address(this).balance) {
            revert InsufficientBalance(amount, address(this).balance);
        }

        (bool success,) = recipient.call{value: amount}("");
        if (!success) {
            revert TransferFailed();
        }

        emit EthWithdrawn(recipient, amount, block.timestamp);
    }

    /**
     * @inheritdoc IShareXVault
     */
    function emergencyPause() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
        emit EmergencyActionTaken("emergency_pause", msg.sender, block.timestamp);
    }

    /**
     * @inheritdoc IShareXVault
     */
    function unpause() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @inheritdoc IShareXVault
     */
    function getVersion() external view override returns (Version memory) {
        return _systemState.version;
    }

    /**
     * @inheritdoc IShareXVault
     */
    function getSystemState() external view override returns (SystemState memory) {
        return _systemState;
    }

    /**
     * @inheritdoc IShareXVault
     */
    function getStats() external view override returns (StatsInfo memory) {
        return StatsInfo({
            partnersCount: _partnerCounter,
            merchantsCount: _merchantCounter,
            devicesCount: _deviceCounter,
            transactionBatchesCount: _batchCounter,
            countriesCount: _getCountriesCount(),
            contractBalance: address(this).balance
        });
    }

    /**
     * @inheritdoc IShareXVault
     */
    function getPartner(uint256 partnerId) external view override returns (PartnerInfo memory) {
        if (partnerId == 0 || partnerId > _partnerCounter) {
            revert EntityNotFound("partner", bytes32(partnerId));
        }
        return _partners[partnerId];
    }

    /**
     * @inheritdoc IShareXVault
     */
    function getPartnerByCode(bytes32 partnerCode)
        external
        view
        override
        returns (PartnerInfo memory)
    {
        uint256 partnerId = _partnerCodeToId[partnerCode];
        if (partnerId == 0) {
            revert EntityNotFound("partner", partnerCode);
        }
        return _partners[partnerId];
    }

    /**
     * @inheritdoc IShareXVault
     */
    function partnerExists(bytes32 partnerCode) external view override returns (bool) {
        return _partnerCodeToId[partnerCode] != 0;
    }

    /**
     * @inheritdoc IShareXVault
     */
    function getMerchant(uint256 merchantId) external view override returns (MerchantInfo memory) {
        if (merchantId == 0 || merchantId > _merchantCounter) {
            revert EntityNotFound("merchant", bytes32(merchantId));
        }
        return _merchants[merchantId];
    }

    /**
     * @inheritdoc IShareXVault
     */
    function getMerchantById(bytes32 merchantId)
        external
        view
        override
        returns (MerchantInfo memory)
    {
        uint256 id = _merchantIdToId[merchantId];
        if (id == 0) {
            revert EntityNotFound("merchant", merchantId);
        }
        return _merchants[id];
    }

    /**
     * @inheritdoc IShareXVault
     */
    function merchantExists(bytes32 merchantId) external view override returns (bool) {
        return _merchantIdToId[merchantId] != 0;
    }

    /**
     * @inheritdoc IShareXVault
     */
    function getDevice(uint256 deviceId) external view override returns (DeviceInfo memory) {
        if (deviceId == 0 || deviceId > _deviceCounter) {
            revert EntityNotFound("device", bytes32(deviceId));
        }
        return _devices[deviceId];
    }

    /**
     * @inheritdoc IShareXVault
     */
    function getDeviceById(bytes32 deviceId) external view override returns (DeviceInfo memory) {
        uint256 id = _deviceIdToId[deviceId];
        if (id == 0) {
            revert EntityNotFound("device", deviceId);
        }
        return _devices[id];
    }

    /**
     * @inheritdoc IShareXVault
     */
    function deviceExists(bytes32 deviceId) external view override returns (bool) {
        return _deviceIdToId[deviceId] != 0;
    }

    /**
     * @inheritdoc IShareXVault
     */
    function getTransactionBatch(uint256 batchId)
        external
        view
        override
        returns (TransactionBatch memory)
    {
        if (batchId == 0 || batchId > _batchCounter) {
            revert EntityNotFound("batch", bytes32(batchId));
        }
        return _transactionBatches[batchId];
    }

    /**
     * @inheritdoc IShareXVault
     */
    function getTransactionDetails(uint256 batchId)
        external
        view
        override
        returns (TransactionDetail[] memory)
    {
        if (batchId == 0 || batchId > _batchCounter) {
            revert EntityNotFound("batch", bytes32(batchId));
        }
        return _transactionDetails[batchId];
    }

    /**
     * @inheritdoc IShareXVault
     */
    function getCountry(bytes2 iso2) external view override returns (CountryInfo memory) {
        if (_countries[iso2].timestamp == 0) {
            revert EntityNotFound("country", bytes32(iso2));
        }
        return _countries[iso2];
    }

    /**
     * @inheritdoc IShareXVault
     */
    function countryExists(bytes2 iso2) external view override returns (bool) {
        return _countries[iso2].timestamp != 0;
    }

    /**
     * @dev Validates that the contract is not in maintenance mode
     */
    function _validateMaintenanceMode() internal view {
        if (_systemState.maintenanceMode) {
            revert MaintenanceModeActive();
        }
    }

    /**
     * @dev Validates string length is within acceptable bounds
     * @param str The string to validate
     * @param field The field name for error reporting
     */
    function _validateStringLength(string memory str, string memory field) internal pure {
        uint256 length = bytes(str).length;
        if (length < MIN_STRING_LENGTH || length > MAX_STRING_LENGTH) {
            revert InvalidStringLength(field, MIN_STRING_LENGTH, MAX_STRING_LENGTH);
        }
    }

    /**
     * @dev Converts a 2-character string to bytes2
     * @param str The string to convert (must be exactly 2 characters)
     * @return The bytes2 representation
     */
    function _stringToBytes2(string memory str) internal pure returns (bytes2) {
        bytes memory strBytes = bytes(str);
        if (strBytes.length != 2) {
            revert InvalidStringLength("iso2", 2, 2);
        }
        return bytes2(strBytes);
    }

    /**
     * @dev Returns the count of registered countries
     * @return The number of registered countries
     */
    function _getCountriesCount() internal pure returns (uint256) {
        return 0;
    }
}
