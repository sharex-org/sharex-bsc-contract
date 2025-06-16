# ShareX Vault Smart Contract

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity Version](https://img.shields.io/badge/solidity-^0.8.20-lightgrey.svg)](https://docs.soliditylang.org/)

## Overview

The ShareX Vault is a robust, upgradeable, and gas-efficient smart contract designed to serve as a central on-chain registry for the ShareX ecosystem. It provides a secure and structured way to manage foundational data, including countries, partners, merchants, and devices, as well as to record high-level transaction batch information.

The contract is built with a strong emphasis on role-based access control, clear data separation, and operational security, making it a reliable backbone for decentralized applications requiring structured data management.

---

## Core Features

-   **Multi-Entity Registry**: Manages four core entities: Countries, Partners, Merchants, and Devices.
-   **Transaction Data Logging**: Records essential metadata for transaction batches, such as total amount and order count, while emitting detailed transaction data as events to save storage costs.
-   **Role-Based Access Control (RBAC)**: Implements granular permissions for different user types (Admin, Operator, Merchant, Reader, Upgrader).
-   **High Gas Efficiency**: Utilizes direct type-casting (`bytes32`) for identifiers instead of more expensive hashing operations (`keccak256`), significantly reducing transaction costs.
-   **Paginated Data Retrieval**: All list functions (`listCountries`, `getDevicesByPartner`, etc.) support pagination with `offset` and `limit` parameters for efficient data handling.
-   **UUPS Upgradeable**: Follows the UUPS (Universal Upgradeable Proxy Standard) pattern, allowing for the contract logic to be upgraded without losing state.
-   **Emergency Controls**: Features `Pausable` functionality, enabling administrators to halt all state-changing operations in case of an emergency.
-   **Comprehensive On-Chain Stats**: Provides a `getStats()` function for a real-time overview of registered entities and contract balance.

---

## Access Control Roles

Access to contract functions is strictly controlled by the following roles:

-   `DEFAULT_ADMIN_ROLE`: The highest level of authority. This role can grant and revoke all other roles, set the maintenance mode, manage funds, and perform system-level upgrades.
-   `UPGRADER_ROLE`: Specifically authorized to upgrade the contract's implementation to a new address.
-   `OPERATOR_ROLE`: Responsible for managing the core registries. This role can register countries, partners, merchants, and devices.
-   `MERCHANT_ROLE`: Authorized to upload transaction batch data associated with their registered devices.
-   `READER_ROLE`: A read-only role that provides access to all public data retrieval functions (`get...`, `list...`, `export...`, etc.). This is ideal for off-chain services or front-ends that only need to display data.

---

## Data Entities

The contract manages the following data structures:

#### 1. Country
A simple record representing a country, identified by its ISO2 code.
-   `iso2`: The `bytes2` country code (e.g., "CN", "US").
-   `timestamp`: Registration timestamp.

#### 2. Partner
Represents a business partner in the ecosystem.
-   `partnerCode`: The unique `bytes32` identifier for the partner.
-   `partnerName`: The partner's name.
-   `iso2`: The country where the partner is based.
-   `verification`, `description`, `businessType`: Additional metadata.

#### 3. Merchant
Represents an end-point merchant operating under a partner.
-   `merchantId`: The unique `bytes32` identifier for the merchant.
-   `merchantName`: A `bytes32` representation of the merchant's name.
-   `iso2`, `locationId`, `location`, `merchantType`: Geographic and categorical information.

#### 4. Device
Represents a physical or virtual device (e.g., POS terminal) assigned to a merchant.
-   `deviceId`: The unique `bytes32` identifier for the device.
-   `partnerKey`: Links the device to a registered partner.
-   `merchantKey`: Links the device to a registered merchant.

#### 5. Transaction Batch
A summary of a batch of transactions, typically uploaded periodically.
-   `deviceHash`: The ID of the device that generated the transactions.
-   `dateComparable`: A `YYYYMMDD` formatted integer for date-based queries.
-   `orderCount`, `totalAmount`: Aggregated statistics for the batch.

---

## Key Functionality

### Registration (Operator Role)
-   `registerCountry(string calldata countryCode)`
-   `registerPartner(PartnerParams calldata params)`
-   `registerMerchant(MerchantParams calldata params)`
-   `registerDevice(DeviceParams calldata params)`
-   Batch registration functions are available for partners (`registerMultiplePartners`) and devices (`registerMultipleDevices`).

### Data Upload (Merchant Role)
-   `uploadTransactionBatch(UploadBatchParams calldata params)`
-   A batch version `uploadMultipleTransactionBatches` is also available.

### Data Retrieval (Reader Role)
The contract provides a rich set of query functions, including:
-   Direct lookups by ID: `getCountryInfo`, `getPartnerInfo`, `getMerchantInfo`, `getDeviceInfo`.
-   Paginated lists by relationship: `getDevicesByPartner`, `getMerchantsByPartner`, `getDevicesByMerchant`, `getTransactionBatchesByDevice`.
-   Comprehensive exports: `exportAllPartners`, `exportAllDevices`.
-   Statistical summaries: `getStats`, `getTransactionSummary`.

---

## Architecture and Security

-   **Upgradability**: Implemented using OpenZeppelin's `UUPSUpgradeable`, ensuring a secure and standard way to evolve the contract's logic over time.
-   **Reentrancy Protection**: Uses `ReentrancyGuardUpgradeable` to protect fund management functions against reentrancy attacks.
-   **Input Validation**: All registration functions use `validStringLength` modifiers to prevent data corruption from oversized inputs.
-   **Error Handling**: Uses custom errors for clear and gas-efficient error reporting (e.g., `EntityNotFound`, `EntityAlreadyExists`).

---

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
