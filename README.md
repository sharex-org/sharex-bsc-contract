# ShareX Vault Smart Contract

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity Version](https://img.shields.io/badge/solidity-^0.8.24-lightgrey.svg)](https://docs.soliditylang.org/)

## Overview

The ShareX Vault is a robust and gas-efficient smart contract designed to serve as a central on-chain registry for the ShareX ecosystem. It provides a secure and structured way to manage foundational data, including countries, partners, merchants, and devices, as well as to record detailed transaction batch information.

The contract is built with a strong emphasis on role-based access control, clear data separation, and operational security, making it a reliable backbone for decentralized applications requiring structured data management.

---

## Core Features

-   **Multi-Entity Registry**: Manages four core entities: Countries, Partners, Merchants, and Devices.
-   **Transaction Data Storage**: Records comprehensive transaction batch information including detailed transaction data stored on-chain.
-   **Role-Based Access Control (RBAC)**: Implements granular permissions for administrators and operators.
-   **High Gas Efficiency**: Utilizes direct type-casting (e.g., `bytes32`) for identifiers instead of more expensive hashing operations (`keccak256`), significantly reducing transaction costs.
-   **Emergency Controls**: Features `Pausable` functionality and maintenance mode to give administrators control during critical situations.
-   **Comprehensive On-Chain Stats**: Provides a `getStats()` function for a real-time overview of registered entity counts and the contract balance.
-   **ETH Management**: Supports ETH deposits and controlled withdrawals by administrators.

---

## Access Control Roles

Access to contract functions is strictly controlled by the following roles:

-   `DEFAULT_ADMIN_ROLE`: The highest level of authority. This role can grant and revoke the operator role, set the maintenance mode, manage funds, pause/unpause the contract, and perform all administrative functions.
-   `OPERATOR_ROLE`: Responsible for managing the core registries. This role can register countries, partners, merchants, devices, and upload transaction batch data.

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

#### 6. TransactionDetail
Detailed information for a single transaction stored on-chain and also emitted via events.
-   `userId`: `bytes32` - The user ID.
-   `sharexId`: `bytes32` - The ShareX ID.
-   `transactionAmount`: `bytes32` - The transaction amount.
-   `itemCount`: `uint32` - The number of items/services in the order.
-   `timestamp`: `uint256` - The timestamp when the transaction occurred.
-   `additionalData`: `string` - Additional data (e.g., a JSON formatted string).

---

## Key Functionality

### Registration (OPERATOR_ROLE)
-   `registerCountry(string calldata iso2)`: Registers a new country using ISO2 code.
-   `registerPartner(PartnerParams calldata params)`: Registers a new partner.
    - `params`: A `PartnerParams` struct containing `partnerCode`, `partnerName`, `iso2`, `verification`, `description`, `businessType`.
-   `registerMerchant(MerchantParams calldata params)`: Registers a new merchant.
    - `params`: A `MerchantParams` struct containing `merchantName`, `merchantId`, `description`, `iso2`, `locationId`, `location`, `merchantType`, `verification`.
-   `registerDevice(DeviceParams calldata params)`: Registers a new device.
    - `params`: A `DeviceParams` struct containing `deviceId`, `deviceType`, `partnerCode`, `merchantId`.

### Data Upload (OPERATOR_ROLE)
-   `uploadTransactionBatch(UploadBatchParams calldata params)`: Uploads a transaction batch with detailed transaction data.
    - `params`: An `UploadBatchParams` struct containing `deviceId`, `dateComparable`, `orderCount`, `totalAmount`, and an array of `TransactionDetail[]`.

### Data Retrieval (Public/View Functions)
The contract provides the following query functions:
-   **Direct Lookups by ID**:
    - `getCountry(bytes2 iso2)`: Get country information by ISO2 code.
    - `getPartner(uint256 partnerId)`: Get partner information by internal ID.
    - `getPartnerByCode(bytes32 partnerCode)`: Get partner information by partner code.
    - `getMerchant(uint256 merchantId)`: Get merchant information by internal ID.
    - `getMerchantById(bytes32 merchantId)`: Get merchant information by merchant ID.
    - `getDevice(uint256 deviceId)`: Get device information by internal ID.
    - `getDeviceById(bytes32 deviceId)`: Get device information by device ID.
    - `getTransactionBatch(uint256 batchId)`: Get transaction batch by ID.
    - `getTransactionDetails(uint256 batchId)`: Get all transaction details for a batch.
-   **Existence Checks**:
    - `countryExists(bytes2 iso2)`: Check if a country is registered.
    - `partnerExists(bytes32 partnerCode)`: Check if a partner exists.
    - `merchantExists(bytes32 merchantId)`: Check if a merchant exists.
    - `deviceExists(bytes32 deviceId)`: Check if a device exists.
-   **Statistics and System Information**:
    - `getStats()`: Returns a `StatsInfo` struct with counts of all entities and the contract balance.
    - `getSystemState()`: Returns a `SystemState` struct containing version and maintenance mode status.
    - `getVersion()`: Returns the current contract version as a `Version` struct.

### System Management (DEFAULT_ADMIN_ROLE)
-   `setMaintenanceMode(bool enabled)`: Enables or disables the maintenance mode.
-   `emergencyPause()`: Pauses all state-changing functions.
-   `unpause()`: Lifts the pause and deactivates maintenance mode.

### Fund Management (DEFAULT_ADMIN_ROLE)
-   `withdrawEth(address payable recipient, uint256 amount)`: Withdraws a specified amount of ETH from the contract.
-   `receive()`: Allows the contract to receive ETH directly, emitting `EthDeposited` events.

---

## Events

The contract emits the following events upon key actions:
-   `ContractInitialized`: When the contract is deployed and initialized.
-   `CountryRegistered`: When a country is registered.
-   `PartnerRegistered`: When a partner is registered.
-   `MerchantRegistered`: When a merchant is registered.
-   `DeviceRegistered`: When a device is registered.
-   `TransactionBatchUploaded`: When a transaction batch summary is uploaded.
-   `TransactionDetailsUploaded`: When transaction details are stored.
-   `MaintenanceModeToggled`: When the maintenance mode status changes.
-   `EthDeposited`: When ETH is received by the contract.
-   `EthWithdrawn`: When ETH is withdrawn from the contract.
-   `EmergencyActionTaken`: When emergency actions like pause are executed.

---

## Architecture and Security

-   **Access Control**: Implemented using OpenZeppelin's `AccessControl` with two distinct roles for administrative and operational functions.
-   **Reentrancy Protection**: Uses `ReentrancyGuard` to protect fund management functions against reentrancy attacks.
-   **Pausable Operations**: Implements `Pausable` functionality to halt operations during emergencies.
-   **Input Validation**: All registration functions validate string lengths to prevent data corruption from oversized inputs.
-   **Error Handling**: Uses custom errors (e.g., `EntityNotFound`, `EntityAlreadyExists`, `InvalidStringLength`) for clear and gas-efficient error reporting.
-   **Maintenance Mode**: Provides additional operational control through maintenance mode that can restrict certain functions.

---

## Constants

-   `MAX_BATCH_SIZE`: 1000 - Maximum number of transaction details allowed in a single batch.
-   `MAX_STRING_LENGTH`: 256 - Maximum length for string parameters.
-   `MIN_STRING_LENGTH`: 1 - Minimum length for string parameters.

---

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.