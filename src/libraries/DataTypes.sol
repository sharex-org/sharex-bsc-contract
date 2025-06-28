// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @dev Version information structure
struct Version {
    uint8 major;
    uint8 minor;
    uint8 patch;
}

/// @dev Country information structure
struct CountryInfo {
    bytes2 iso2; // ISO2 country code (using bytes2 to save gas)
    uint256 timestamp; // Registration timestamp
}

/// @dev Partner information structure
struct PartnerInfo {
    uint256 id; // Internal ID
    bytes32 partnerCode; // Partner code
    string partnerName; // Partner name
    bytes2 iso2; // ISO2 country code
    bytes32 verification; // Verification number issued by ShareX
    string description; // Service description
    string businessType; // Business type
    uint256 timestamp; // Registration timestamp
}

/// @dev Merchant information structure
struct MerchantInfo {
    uint256 id; // Internal ID
    bytes32 merchantName; // Merchant name
    bytes32 merchantId; // Merchant ID
    bytes description; // Description
    bytes2 iso2; // Country code
    bytes32 locationId; // City code
    bytes32 location; // Location
    bytes32 merchantType; // Scene type
    bytes32 verification; // Verification number
    uint256 timestamp; // Registration timestamp
}

/// @dev Device information structure
struct DeviceInfo {
    uint256 id; // Internal ID
    bytes32 deviceId; // Device ID
    bytes32 deviceType; // Device type
    bytes32 partnerCode; // Partner code
    bytes32 merchantId; // Merchant ID
    uint256 timestamp; // Registration timestamp
}

/// @dev Basic transaction information structure
struct BasicTransactionInfo {
    bytes32 deviceId; // Device ID
    uint32 orderCount; // Order count
    uint256 totalAmount; // Total transaction amount
    uint256 dateComparable; // Date in YYYYMMDD format, for comparison
}

/// @dev Transaction detail structure
struct TransactionDetail {
    bytes32 userId; // User ID
    bytes32 sharexId; // ShareX ID
    bytes32 transactionAmount; // Transaction amount
    uint32 itemCount; // Number of items/services in the order
    uint256 timestamp; // Transaction timestamp
    string additionalData; // Additional data (JSON formatted string)
}

/// @dev Transaction batch structure
struct TransactionBatch {
    uint256 id; // Internal ID
    BasicTransactionInfo basicInfo; // Basic transaction data
    uint256 batchTimestamp; // Batch timestamp
}

/// @dev System state structure
struct SystemState {
    Version version; // Current contract version
    bool maintenanceMode; // Maintenance mode
}

/// @dev Statistics information structure
struct StatsInfo {
    uint256 partnersCount; // Total number of partners
    uint256 merchantsCount; // Total number of merchants
    uint256 devicesCount; // Total number of devices
    uint256 transactionBatchesCount; // Total number of transaction batches
    uint256 countriesCount; // Total number of countries
    uint256 contractBalance; // Contract balance
}

/// @dev Parameters structure for registering a partner
struct PartnerParams {
    string partnerCode;
    string partnerName;
    string iso2;
    string verification;
    string description;
    string businessType;
}

/// @dev Parameters structure for registering a merchant
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

/// @dev Parameters structure for registering a device
struct DeviceParams {
    string deviceId;
    string deviceType;
    string partnerCode;
    string merchantId;
}

/// @dev Parameters structure for uploading a transaction batch
struct UploadBatchParams {
    string deviceId;
    uint256 dateComparable; // Date in YYYYMMDD format
    uint32 orderCount;
    uint256 totalAmount;
    TransactionDetail[] transactionDetails;
}
