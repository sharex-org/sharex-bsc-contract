// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @dev Entity already exists
error EntityAlreadyExists(string entityType, bytes32 entityId);

/// @dev Entity not found
error EntityNotFound(string entityType, bytes32 entityId);

/// @dev Invalid string length
error InvalidStringLength(string field, uint256 min, uint256 max);

/// @dev Invalid role
error InvalidRole(address user, bytes32 role);

/// @dev Maintenance mode is active
error MaintenanceModeActive();

/// @dev Insufficient balance
error InsufficientBalance(uint256 requested, uint256 available);

/// @dev Transfer failed
error TransferFailed();

/// @dev Batch size exceeded
error BatchSizeExceeded(uint256 provided, uint256 maximum);

/// @dev Array length mismatch
error ArrayLengthMismatch();

/// @dev Invalid implementation
error InvalidImplementation();

/// @dev Start date after end date
error StartDateAfterEndDate();

/// @dev Invalid admin address
error InvalidAdminAddress();

/// @dev Empty transaction details
error EmptyTransactionDetails();

/// @dev Too many transaction details
error TooManyTransactionDetails();

/// @dev Order count mismatch
error OrderCountMismatch();

/// @dev Invalid entity type
error InvalidEntityType();

/// @dev Invalid recipient address
error InvalidRecipientAddress();

/// @dev Not in maintenance mode
error NotInMaintenanceMode();
