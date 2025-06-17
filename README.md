# ShareX Vault Smart Contract

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity Version](https://img.shields.io/badge/solidity-^0.8.20-lightgrey.svg)](https://docs.soliditylang.org/)

## Overview

The ShareX Vault is a robust, upgradeable, and gas-efficient smart contract designed to serve as a central on-chain registry for the ShareX ecosystem. It provides a secure and structured way to manage foundational data, including countries, partners, merchants, and devices, as well as to record high-level transaction batch information.

The contract is built with a strong emphasis on role-based access control, clear data separation, and operational security, making it a reliable backbone for decentralized applications requiring structured data management.

---

## Core Features

-   **Multi-Entity Registry**: Manages four core entities: Countries, Partners, Merchants, and Devices.
-   **Transaction Data Logging**: Records essential metadata for transaction batches, such as total amount and order count, while emitting detailed transaction data as events to save on-chain storage costs.
-   **Role-Based Access Control (RBAC)**: Implements granular permissions for different user types (Admin, Operator, Merchant, Reader, Upgrader).
-   **High Gas Efficiency**: Utilizes direct type-casting (e.g., `bytes32`) for identifiers instead of more expensive hashing operations (`keccak256`), significantly reducing transaction costs.
-   **Paginated Data Retrieval**: All list functions (e.g., `listCountries`, `getDevicesByPartner`) support `offset` and `limit` parameters for efficient data handling.
-   **UUPS Upgradeable**: Follows the UUPS (Universal Upgradeable Proxy Standard) pattern, allowing the contract logic to be upgraded without losing state.
-   **Emergency Controls**: Features `Pausable` functionality, a maintenance mode, and emergency withdrawal to give administrators control during critical situations.
-   **Comprehensive On-Chain Stats**: Provides a `getStats()` function for a real-time overview of registered entity counts and the contract balance.
-   **Batch Processing**: Supports batch registration and uploads for partners, devices, and transaction batches to enhance efficiency.

---

## Access Control Roles

Access to contract functions is strictly controlled by the following roles:

-   `DEFAULT_ADMIN_ROLE`: The highest level of authority. This role can grant and revoke all other roles, set the maintenance mode, manage funds, and perform system-level functions like upgrading the contract version and pausing the contract.
-   `UPGRADER_ROLE`: Specifically authorized to upgrade the contract's implementation to a new address.
-   `OPERATOR_ROLE`: Responsible for managing the core registries. This role can register countries, partners, merchants, and devices.
-   `MERCHANT_ROLE`: Authorized to upload transaction batch data associated with their registered devices.
-   `READER_ROLE`: A read-only role that provides access to all public data retrieval functions (`get...`, `list...`, `export...`, etc.). Ideal for off-chain services or front-ends that only need to display data.

---

## Data Entities

The contract manages the following data structures:

#### 1. CountryInfo
Represents a country record.
-   `iso2`: `bytes2` - The ISO2 country code (e.g., "CN", "US").
-   `timestamp`: `uint256` - Registration timestamp.

#### 2. PartnerInfo
Represents a business partner in the ecosystem.
-   `id`: `uint256` - Internal auto-incrementing ID.
-   `partnerCode`: `bytes32` - The unique identifier for the partner.
-   `partnerName`: `string` - The partner's name.
-   `iso2`: `bytes2` - The country code where the partner is based.
-   `verification`: `bytes32` - A verification code issued by ShareX.
-   `description`: `string` - A service description.
-   `businessType`: `string` - The type of business.
-   `timestamp`: `uint256` - Registration timestamp.

#### 3. MerchantInfo
Represents an end-point merchant operating under a partner.
-   `id`: `uint256` - Internal auto-incrementing ID.
-   `merchantName`: `bytes32` - A `bytes32` representation of the merchant's name.
-   `merchantId`: `bytes32` - The unique identifier for the merchant.
-   `description`: `bytes` - A description.
-   `iso2`: `bytes2` - The country code.
-   `locationId`: `bytes32` - A city or area code.
-   `location`: `bytes32` - Location information.
-   `merchantType`: `bytes32` - The scene or merchant type.
-   `verification`: `bytes32` - A verification code.
-   `timestamp`: `uint256` - Registration timestamp.

#### 4. DeviceInfo
Represents a physical or virtual device (e.g., a POS terminal) assigned to a merchant.
-   `id`: `uint256` - Internal auto-incrementing ID.
-   `deviceId`: `bytes32` - The unique identifier for the device.
-   `deviceType`: `bytes32` - The type of the device.
-   `partnerCode`: `bytes32` - Links the device to a registered partner.
-   `merchantId`: `bytes32` - Links the device to a registered merchant.
-   `timestamp`: `uint256` - Registration timestamp.

#### 5. TransactionBatch
A summary of a batch of transactions.
-   `id`: `uint256` - Internal auto-incrementing ID.
-   `basicInfo`: `BasicTransactionInfo` - The basic transaction data structure.
    - `deviceId`: `bytes32` - The ID of the device that generated the transactions.
    - `orderCount`: `uint32` - The total number of orders in the batch.
    - `totalAmount`: `uint256` - The total transaction amount in the batch.
    - `dateComparable`: `uint256` - A `YYYYMMDD` formatted integer for date-based queries.
-   `batchTimestamp`: `uint256` - The timestamp of the batch upload.

#### 6. TransactionDetail (Emitted via Event)
Detailed information for a single transaction. This is not stored on-chain to save costs but is emitted via the `TransactionDetailUploaded` event.
-   `userId`: `bytes32` - The user ID.
-   `sharexId`: `bytes32` - The ShareX ID.
-   `transactionAmount`: `bytes32` - The transaction amount.
-   `itemCount`: `uint32` - The number of items/services in the order.
-   `timestamp`: `uint256` - The timestamp when the transaction occurred.
-   `additionalData`: `string` - Additional data (e.g., a JSON formatted string).

---

## Key Functionality

### Registration (OPERATOR_ROLE)
-   `registerCountry(string calldata countryCode)`: Registers a new country.
-   `registerPartner(PartnerParams calldata params)`: Registers a new partner.
    - `params`: A `PartnerParams` struct containing `partnerCode`, `partnerName`, `iso2`, `verification`, `description`, `businessType`.
-   `registerMultiplePartners(PartnerParams[] calldata params)`: Batch registers multiple partners.
-   `registerMerchant(MerchantParams calldata params)`: Registers a new merchant.
    - `params`: A `MerchantParams` struct containing `merchantName`, `merchantId`, `description`, `iso2`, `locationId`, `location`, `merchantType`, `verification`.
-   `registerDevice(DeviceParams calldata params)`: Registers a new device.
    - `params`: A `DeviceParams` struct containing `deviceId`, `deviceType`, `partnerCode`, `merchantId`.
-   `registerMultipleDevices(DeviceParams[] calldata params)`: Batch registers multiple devices.

### Data Upload (MERCHANT_ROLE)
-   `uploadTransactionBatch(UploadBatchParams calldata params)`: Uploads a single transaction batch.
    - `params`: An `UploadBatchParams` struct containing `deviceId`, `dateComparable`, `orderCount`, `totalAmount`, and an array of `TransactionDetail[]`.
-   `uploadMultipleTransactionBatches(UploadBatchParams[] calldata params)`: Uploads multiple transaction batches.

### Data Retrieval (READER_ROLE)
The contract provides a rich set of query functions:
-   **Direct Lookups by ID**:
    - `getCountryInfo(string calldata countryCode)`
    - `getPartnerInfo(string calldata partnerCode)`
    - `getMerchantInfo(string calldata merchantId)`
    - `getDeviceInfo(string calldata deviceId)`
-   **Paginated Lists by Relationship**:
    - `listCountries(uint256 offset, uint256 limit)`
    - `getMerchantsByCountry(string calldata iso2, uint256 offset, uint256 limit)`
    - `getMerchantsByPartner(string calldata partnerCode, uint256 offset, uint256 limit)`
    - `getDevicesByPartner(string calldata partnerCode, uint256 offset, uint256 limit)`
    - `getDevicesByMerchant(string calldata merchantId, uint256 offset, uint256 limit)`
    - `getTransactionBatchesByDevice(string calldata deviceId, uint256 offset, uint256 limit)`
-   **Data Exports**:
    - `exportAllPartners(uint256 offset, uint256 limit)`
    - `exportAllDevices(uint256 offset, uint256 limit)`
-   **Statistics and Summaries**:
    - `getStats()`: Returns a `StatsInfo` struct with counts of all entities and the contract balance.
    - `getTransactionSummary(string calldata deviceId, uint256 startDate, uint256 endDate)`: Returns a transaction summary for a device within a date range.
    - `getMerchantsCountByCountry(string calldata iso2)`
    - `getMerchantsCountByPartner(string calldata partnerCode)`
    - `getDevicesCountByPartner(string calldata partnerCode)`
    - `getDevicesCountByMerchant(string calldata merchantId)`
-   **System State**:
    - `getSystemState()`: Returns a `SystemState` struct containing version, upgrade timestamp, and maintenance mode status.
    - `version()`: Returns the current contract version as an `x.y.z` string.

### System Management (DEFAULT_ADMIN_ROLE)
-   `upgradeVersion(uint8 major, uint8 minor, uint8 patch)`: Manually updates the contract's version number.
-   `setMaintenanceMode(bool enabled)`: Enables or disables the maintenance mode.
-   `emergencyPause()`: Pauses all state-changing functions and activates maintenance mode.
-   `unpause()`: Lifts the pause and deactivates maintenance mode.

### Fund Management (DEFAULT_ADMIN_ROLE)
-   `withdraw(uint256 amount, address payable recipient)`: Withdraws a specified amount of funds from the contract.
-   `emergencyWithdrawAll(address payable recipient)`: Withdraws all funds from the contract during maintenance mode.

---

## Events

The contract emits the following events upon key actions:
-   `CountryRegistered`: When a country is registered.
-   `PartnerRegistered`: When a partner is registered.
-   `MerchantRegistered`: When a merchant is registered.
-   `DeviceRegistered`: When a device is registered.
-   `TransactionBatchUploaded`: When a transaction batch summary is uploaded.
-   `TransactionDetailUploaded`: Emitted for each transaction detail within an uploaded batch.
-   `SystemUpgraded`: When the version is upgraded.
-   `MaintenanceModeChanged`: When the maintenance mode status changes.

---

## Architecture and Security

-   **Upgradability**: Implemented using OpenZeppelin's `UUPSUpgradeable`, ensuring a secure and standard way to evolve the contract's logic over time.
-   **Reentrancy Protection**: Uses `ReentrancyGuardUpgradeable` to protect fund management functions against reentrancy attacks.
-   **Input Validation**: All registration functions use `validStringLength` modifiers to prevent data corruption from oversized inputs.
-   **Error Handling**: Uses custom errors (e.g., `EntityNotFound`, `EntityAlreadyExists`, `InvalidStringLength`) for clear and gas-efficient error reporting.

---

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
