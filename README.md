# ShareX Vault Smart Contract

A versatile and upgradeable smart contract for managing partner, merchant, device, and transaction data.

## Overview

`ShareXVault` is a sophisticated, Ethereum-based data management solution designed for enterprise-level applications that demand high security and flexibility. Built upon OpenZeppelin's battle-tested components, it implements Role-Based Access Control (RBAC), UUPS upgradeability, a pausable mechanism, and re-entrancy guards, providing a solid foundation for on-chain data management.

The contract is organized around several key entities: countries, partners, merchants, and devices, and is capable of recording transaction data in a highly efficient, gas-saving manner.

## Core Features

- **Role-Based Access Control (RBAC)**: Pre-defined roles such as admin, operator, merchant, upgrader, and reader ensure that different parties can only access their authorized functions.
- **Core Entity Management**: Supports on-chain registration, querying, and batch operations for core business data entities like countries, partners, merchants, and devices.
- **Gas-Efficient Transaction Logging**: Utilizes an event-based approach for transaction details. Instead of storing them in the contract's state, details are emitted as events, which significantly saves gas costs while ensuring data traceability.
- **Upgradeable & Pausable**: Based on the UUPS proxy pattern, it allows for secure upgrades of the contract logic without data loss. The admin can also pause critical contract functions in case of an emergency.
- **Batch Processing**: Supports batch registration of partners and devices, as well as batch uploads of transaction data, improving efficiency when handling large datasets.
- **Multi-Dimensional Data Statistics**: Provides a rich set of query interfaces for multi-dimensional statistical analysis, such as querying the number of merchants in a country or listing all devices under a partner.
- **Secure Fund Management**: Includes built-in fund withdrawal and emergency withdrawal functions, protected by the admin role and re-entrancy guards to ensure the safety of funds within the contract.

## Contract Architecture

- **Base Framework**: Inherits from OpenZeppelin Contracts, including `AccessControlUpgradeable`, `ReentrancyGuardUpgradeable`, `PausableUpgradeable`, and `UUPSUpgradeable`.
- **Data Structures**:
  - `mapping`: Used for storing core entity data, enabling rapid O(1) complexity for reads and writes.
  - `EnumerableSet`: A library from OpenZeppelin used to store key sets for various entities, allowing them to be enumerated and paginated.
  - `struct`: Defines complex data structures like `PartnerInfo`, `MerchantInfo`, and `TransactionBatch`.
- **On-Chain Data Strategy**:
  - **Core Entity Data**: Stored directly in the contract's state to ensure data persistence and consistency.
  - **Transaction Details**: Emitted as `event`s. The advantage of this approach is its extremely low cost, while allowing off-chain services (like The Graph or other indexers) to capture these events and build a complete transaction history database, balancing cost with usability.

## Roles and Permissions

The contract's access control is defined by the following roles:

- `DEFAULT_ADMIN_ROLE`: **Default Admin**. The highest privilege role, capable of granting/revoking any role, managing funds, setting maintenance mode, and pausing/unpausing the contract.
- `OPERATOR_ROLE`: **Operator**. Responsible for daily data entry operations, such as registering countries, partners, merchants, and devices.
- `MERCHANT_ROLE`: **Merchant**. The most restricted operational role, specifically for uploading transaction data under their name.
- `READER_ROLE`: **Reader**. Can call all `view` and `pure` functions to query contract data but cannot make any state changes. Suitable for data analysis, frontend displays, etc.
- `UPGRADER_ROLE`: **Upgrader**. The only role authorized to perform contract upgrades.

## Core Workflow

1.  **Initialization**: When deploying the contract, an `admin` address must be provided, which will be granted the `DEFAULT_ADMIN_ROLE` and `UPGRADER_ROLE`.
2.  **Role Assignment**: The admin (`admin`) assigns roles like `OPERATOR_ROLE`, `MERCHANT_ROLE`, and `READER_ROLE` to appropriate external accounts or contracts as needed.
3.  **Base Data Entry**: The operator (`OPERATOR_ROLE`) calls functions like `registerCountry` and `registerPartner` to input base data into the system.
4.  **Transaction Data Upload**: After a transaction occurs, the merchant (`MERCHANT_ROLE`) calls the `uploadTransactionBatch` function to upload the transaction data in batches.
5.  **Data Query & Analysis**: Frontend applications or backend services use an account with `READER_ROLE` permissions to call various `get` and `list` functions to read and display data.
6.  **System Maintenance**: The admin can pause the contract, set maintenance mode, or perform a contract upgrade as needed.

## Key Function Interface

Below are some of the core functions commonly used by each role:

#### Admin Operations (`DEFAULT_ADMIN_ROLE`)
- `grantRole(bytes32 role, address account)`: Grants a role.
- `revokeRole(bytes32 role, address account)`: Revokes a role.
- `setMaintenanceMode(bool enabled)`: Enables/disables maintenance mode.
- `emergencyPause()`: Pauses the contract in an emergency.
- `unpause()`: Resumes a paused contract.
- `withdraw(uint256 amount, address payable recipient)`: Withdraws funds from the contract.

#### Operator Operations (`OPERATOR_ROLE`)
- `registerCountry(string calldata countryCode)`: Registers a country.
- `registerPartner(PartnerParams calldata params)`: Registers a single partner.
- `registerMultiplePartners(PartnerParams[] calldata params)`: Registers partners in a batch.
- `registerMerchant(MerchantParams calldata params)`: Registers a merchant.
- `registerDevice(DeviceParams calldata params)`: Registers a device.
- `registerMultipleDevices(DeviceParams[] calldata params)`: Registers devices in a batch.

#### Merchant Operations (`MERCHANT_ROLE`)
- `uploadTransactionBatch(UploadBatchParams calldata params)`: Uploads a single transaction batch.
- `uploadMultipleTransactionBatches(UploadBatchParams[] calldata params)`: Uploads multiple transaction batches.

#### Read/Query Operations (`READER_ROLE`)
- `getPartnerInfo(string calldata partnerCode)`: Gets partner information.
- `getMerchantInfo(string calldata merchantId)`: Gets merchant information.
- `getDeviceInfo(string calldata deviceId)`: Gets device information.
- `getMerchantsByCountry(...)`: Lists merchants by country (with pagination).
- `getDevicesByPartner(...)`: Lists devices by partner (with pagination).
- `getTransactionSummary(...)`: Gets a transaction summary for a device within a date range.
- `getStats()`: Gets comprehensive contract statistics.

## Installation and Deployment

This is a standard Hardhat project. You can use the following commands to compile, test, and deploy it.

### Prerequisites
- Node.js (>= 18.x)
- Yarn or Npm

### Installation

```bash
git clone <your-repository-url>
cd <repository-name>
npm install
```

### Compiling the Contract
```bash
npx hardhat compile
```

### Running Tests
```bash
npx hardhat test
```

### Deployment
1.  Configure your private key and RPC node URL in the `.env` file.
2.  Create a deployment script (e.g., `scripts/deploy.js`).
3.  Run the deployment command:
    ```bash
    npx hardhat run scripts/deploy.js --network <your-network-name>
    ```

## Security and Disclaimer
- This contract employs standard security practices from OpenZeppelin, including re-entrancy protection and a pausable mechanism.
- Custom errors are used throughout the contract to optimize gas usage.
- While efforts have been made to ensure the code's security, a comprehensive audit by an independent third-party security firm is strongly recommended before deploying to a mainnet and handling real assets.
