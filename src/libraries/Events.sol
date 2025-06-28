// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Version} from "./DataTypes.sol";

/// @dev Emitted when a partner is registered
event PartnerRegistered(
    uint256 indexed id,
    bytes32 indexed partnerCode,
    string partnerName,
    bytes2 iso2,
    uint256 timestamp
);

/// @dev Emitted when a merchant is registered
event MerchantRegistered(
    uint256 indexed id,
    bytes32 indexed merchantName,
    bytes32 indexed merchantId,
    bytes2 iso2,
    uint256 timestamp
);

/// @dev Emitted when a device is registered
event DeviceRegistered(
    uint256 indexed id,
    bytes32 indexed deviceId,
    bytes32 deviceType,
    bytes32 partnerCode,
    bytes32 merchantId,
    uint256 timestamp
);

/// @dev Emitted when a transaction batch is uploaded
event TransactionBatchUploaded(
    uint256 indexed batchId,
    bytes32 indexed deviceId,
    uint32 orderCount,
    uint256 totalAmount,
    uint256 dateComparable,
    uint256 timestamp
);

/// @dev Emitted when transaction details are uploaded
event TransactionDetailsUploaded(uint256 indexed batchId, uint256 detailsCount, uint256 timestamp);

/// @dev Emitted when maintenance mode is toggled
event MaintenanceModeToggled(bool enabled, uint256 timestamp);

/// @dev Emitted when contract version is updated
event VersionUpdated(Version previousVersion, Version newVersion, uint256 timestamp);

/// @dev Emitted when ETH is withdrawn
event EthWithdrawn(address indexed recipient, uint256 amount, uint256 timestamp);

/// @dev Emitted when ETH is deposited
event EthDeposited(address indexed sender, uint256 amount, uint256 timestamp);

/// @dev Emitted when contract is initialized
event ContractInitialized(address indexed admin, Version version, uint256 timestamp);

/// @dev Emitted when contract is upgraded
event ContractUpgraded(
    address indexed oldImplementation,
    address indexed newImplementation,
    Version version,
    uint256 timestamp
);

/// @dev Emitted when a country is registered
event CountryRegistered(bytes2 indexed iso2, uint256 timestamp);

/// @dev Emitted when batch data is cleared
event BatchDataCleared(uint256 indexed batchId, uint256 timestamp);

/// @dev Emitted when emergency action is taken
event EmergencyActionTaken(string action, address indexed executor, uint256 timestamp);
