# 🔋 ShareX DeFi Power Bank - BSC Smart Contracts

> DeFi-Driven Smart Charging Station Rental Platform Contract System

![Solidity](https://img.shields.io/badge/Solidity-0.8.20-blue)
![Hardhat](https://img.shields.io/badge/Hardhat-latest-yellow)
![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-5.0.2-green)
![BSC](https://img.shields.io/badge/BSC-Testnet-orange)
![License](https://img.shields.io/badge/License-MIT-purple)



## 🚀 Project Overview

ShareX DeFi Power Bank is a smart contract system for charging station rental running on BSC, implementing intelligent deposit management, yield sharing, and risk control through DeFi mechanisms.

### 🎯 Core Features

- **🏦 Smart Deposit Management**: Automatically adjusts deposit requirements based on users' DeFi assets
- **💰 Yield Sharing Mechanism**: Deposits generate yields through DeFi protocols
- **🛡️ Multi-layer Risk Control**: Credit assessment, real-time monitoring, emergency handling
- **🔄 Multi-protocol Support**: Supports AAVE, PancakeSwap and other DeFi protocols
- **⚡ Modular Architecture**: Clear contract layers and separation of responsibilities

## 🏗️ Contract Architecture

### 📊 System Architecture

```
📦 contracts/
├── 🎯 core/                    # Core Business Layer
│   └── ShareX.sol             # ShareX Core Business Logic
├── 📜 protocol/               # Protocol Layer
│   └── DeShareProtocol.sol    # DeShare Data Attestation Protocol
├── 💰 payfi/                  # Payment Finance Module
│   └── Vault.sol              # User Fund Management
├── 🔌 defi/                   # DeFi Infrastructure Layer
│   ├── adapters/              # DeFi Protocol Adapters
│   │   ├── DeFiAdapter.sol    # Main Adapter
│   │   └── AaveAdapter.sol    # AAVE Specialized Adapter
│   └── strategies/            # Investment Strategies
│       ├── StrategyManager.sol
│       ├── BaseStrategy.sol
│       ├── AaveStrategy.sol
│       └── PancakeSwapStrategy.sol
├── 🔗 interfaces/             # Interface Definitions
├── 🧪 mocks/                  # Test Mock Contracts
└── 🛠️ utils/                  # Utility Contracts
```

## 💼 Core Contract Functions

### 🎯 ShareX.sol - Core Business Contract

Responsible for core business logic of power bank rental:

```solidity
// Register device
function registerDevice(uint256 deviceId, string location) external;

// Rent device
function rentDevice(uint256 deviceId) external payable;

// Return device
function returnDevice(uint256 deviceId) external;

// Query device status
function getDeviceStatus(uint256 deviceId) external view returns (DeviceStatus);
```

### 📜 DeShareProtocol.sol - Data Attestation Protocol

Manages partner, merchant, device, and transaction data:

```solidity
// Data attestation functionality
function storeData(bytes32 dataHash, string metadata) external;

// Data verification
function verifyData(bytes32 dataHash) external view returns (bool);

// Permission management
function grantRole(bytes32 role, address account) external;
```

### 💰 Vault.sol - Fund Management Contract

Handles user fund deposits/withdrawals and DeFi investments:

```solidity
// Deposit
function deposit(uint256 amount) external;

// Withdraw
function withdraw(uint256 amount) external;

// Calculate smart deposit
function calculateSmartDeposit(address user) external view returns (uint256);
```

### 🔌 DeFiAdapter.sol - DeFi Adapter

Unified management of multiple DeFi protocols:

```solidity
// Add protocol support
function addProtocol(string protocolName, address adapter, uint256 weight) external;

// Smart deposit (automatically selects optimal protocol)
function deposit(uint256 amount) external returns (uint256 shares);

// Get best protocol
function getBestProtocol() external view returns (string, uint256 apy);
```

## 🔋 Smart Deposit Logic

The system intelligently calculates deposits based on users' assets in DeFi protocols:

   ```solidity
   // Deposit calculation logic
   if (user_AAVE_deposits >= 100 USDT) {
       deposit = 0;  // No deposit required
   } else {
       deposit = 100 USDT - user_AAVE_deposits;
   }
   ```

### 💰 Yield Distribution

```
📈 DeFi Yield Distribution (100%)
├── 👥 User Rewards (60%)
├── 🏢 Platform Revenue (30%)
└── 🛡️ Risk Reserve (10%)
```

## 🚦 Quick Start

### 📋 Requirements

- Node.js >= 16.0.0
- npm >= 7.0.0
- Hardhat >= 2.0.0

### 🔧 Installation and Compilation

```bash
# Clone the repository
git clone https://github.com/your-username/sharex-bsc-contract.git
cd sharex-bsc-contract

# Install dependencies
npm install

# Compile contracts
npx hardhat compile

# Run tests
npx hardhat test
```

### ⚙️ Configuration

Create `.env` file:

```bash
# BSC Network Configuration
BSC_TESTNET_RPC_URL=https://data-seed-prebsc-1-s1.binance.org:8545/
BSC_MAINNET_RPC_URL=https://bsc-dataseed1.binance.org/

# Deployment Private Key
DEPLOYER_PRIVATE_KEY=your_private_key_here

# BSCScan API Key
BSCSCAN_API_KEY=your_bscscan_api_key

# DeFi Protocol Addresses (BSC Mainnet)
AAVE_POOL_ADDRESSES_PROVIDER=0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb
USDT_ADDRESS=0x55d398326f99059fF775485246999027B3197955
```

### 🚀 Deployment

```bash
# Deploy to BSC Testnet
npx hardhat run scripts/deploy.js --network bscTestnet

# Verify contracts
npx hardhat verify --network bscTestnet <contract_address>
```

## 🧪 Testing

```bash
# Run all tests
npx hardhat test

# Run specific tests
npx hardhat test test/ShareXVault.test.js

# Generate coverage report
npx hardhat coverage
```

Test Coverage:
- ✅ Power bank device management
- ✅ Smart deposit calculation
- ✅ DeFi protocol integration
- ✅ Yield distribution mechanism
- ✅ Risk control mechanism

## 🛡️ Security Features

### 🔒 Security Mechanisms

- **Access Control**: OpenZeppelin-based role permission management
- **Reentrancy Protection**: Reentrancy protection for all state-changing functions
- **Pause Mechanism**: Contract operations can be paused in emergencies
- **Upgrade Mechanism**: Supports secure contract upgrades

### 🚨 Risk Parameters

```solidity
uint256 public constant MAX_DEPOSIT_RATIO = 80;     // Maximum deposit ratio 80%
uint256 public constant LIQUIDATION_THRESHOLD = 150; // Liquidation threshold 150%
uint256 public constant EMERGENCY_BUFFER = 20;      // Emergency buffer 20%
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**⚡ Next-Generation Power Bank Rental System Powered by DeFi ⚡**
