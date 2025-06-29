# ShareX PayFi Solution

[![Tests](https://github.com/sharex-org/sharex-bsc-contract/actions/workflows/test.yml/badge.svg)](https://github.com/sharex-org/sharex-bsc-contract/actions/workflows/test.yml)
[![Coverage](https://github.com/sharex-org/sharex-bsc-contract/actions/workflows/coverage.yml/badge.svg)](https://github.com/sharex-org/sharex-bsc-contract/actions/workflows/coverage.yml)
[![Security Checks](https://github.com/sharex-org/sharex-bsc-contract/actions/workflows/checks.yml/badge.svg)](https://github.com/sharex-org/sharex-bsc-contract/actions/workflows/checks.yml)
[![Docs](https://github.com/sharex-org/sharex-bsc-contract/actions/workflows/docs.yml/badge.svg)](https://github.com/sharex-org/sharex-bsc-contract/actions/workflows/docs.yml)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/sharex-org/sharex-bsc-contract)

A comprehensive blockchain-based payment infrastructure solution built on Solidity 0.8.24, providing secure, upgradeable smart contracts for managing partner ecosystems, merchant onboarding, device management, and transaction processing in a unified PayFi platform.

## 📚 Documentation

**📖 [Auto-Generated Contract Documentation](https://sharex-org.github.io/sharex-bsc-contract/)** - Complete API documentation auto-generated from NatSpec comments using Foundry's `forge doc` command. Includes detailed contract interfaces, function signatures, parameter descriptions, and usage examples extracted directly from the source code.

### Generate Documentation Locally
```bash
# Generate documentation from NatSpec comments
forge doc

# Serve documentation locally
forge doc --serve --port 3000

# Build documentation for deployment
forge doc --build
```

The documentation includes:
- **Contract APIs**: Auto-generated from NatSpec comments in source code
- **Function Signatures**: Complete interface documentation with parameters and return values
- **Integration Examples**: Code samples extracted from contract comments
- **Deployment Guides**: Based on the deployment scripts and configurations

## 📍 Deployed Contracts

### BSC Testnet (Chain ID: 97)

| Contract                 | Address                                      | BSCScan                                                                                | Type           | Description                       |
| ------------------------ | -------------------------------------------- | -------------------------------------------------------------------------------------- | -------------- | --------------------------------- |
| **ShareXVault**          | `0xB5Ae51A7b0A4654147561F7b9e94E875514e3C0A` | [View](https://testnet.bscscan.com/address/0xB5Ae51A7b0A4654147561F7b9e94E875514e3C0A) | Implementation | Main PayFi vault logic contract   |
| **ShareXVaultProxy**     | `0xb8607B8Bb9Bd25837147667C3bCfFde08A457BE1` | [View](https://testnet.bscscan.com/address/0xb8607B8Bb9Bd25837147667C3bCfFde08A457BE1) | Proxy          | Upgradeable proxy for ShareXVault |
| **YieldVault**           | `0xd9F886Ca7264eD40D01421f5f54218aaeBeC91ef` | [View](https://testnet.bscscan.com/address/0xd9F886Ca7264eD40D01421f5f54218aaeBeC91ef) | Implementation | Yield generation vault logic      |
| **YieldVaultProxy**      | `0x37118bF6979486cC6F4BE45d26d3Cdac42685baD` | [View](https://testnet.bscscan.com/address/0x37118bF6979486cC6F4BE45d26d3Cdac42685baD) | Proxy          | Upgradeable proxy for YieldVault  |
| **PancakeSwapV3Adapter** | `0x50bDD9459dd66a42f2020A5E2aFDf357Fe88A6D2` | [View](https://testnet.bscscan.com/address/0x50bDD9459dd66a42f2020A5E2aFDf357Fe88A6D2) | Adapter        | DeFi adapter for PancakeSwap V3   |

## 🏗️ Architecture Overview

The ShareX PayFi Solution is built with a secure, upgradeable proxy architecture:

```text
├── ShareXVault.sol             # Main upgradeable vault contract
├── interfaces/                 # Interface definitions
│   └── IShareXVault.sol        # Main vault interface
├── libraries/                  # Shared utilities
│   ├── DataTypes.sol           # Data structures for PayFi entities
│   ├── Errors.sol              # Custom error definitions
│   └── Events.sol              # Event definitions for tracking
├── script/                     # Deployment and upgrade scripts
│   └── Deploy.s.sol            # Foundry deployment script
└── deploy-config/              # Network-specific configurations
    ├── local.json              # Local development config
    ├── bsc-testnet.json        # BSC Testnet config
    └── devnet.json             # Development network config
```

## 🚀 Key Features

### Upgradeable Proxy Architecture
- **TransparentUpgradeableProxy**: Secure upgrade mechanism with role separation
- **Proxy Admin Owner**: Controls proxy upgrades and admin functions
- **Vault Admin**: Controls business logic and operational functions
- **Implementation Contracts**: Upgradeable business logic layer

### Partner Ecosystem Management
- **Partner Registration**: Complete partner onboarding with verification
- **Partner Profiles**: Business type, country, and verification tracking
- **Batch Operations**: Efficient bulk partner management
- **Partner Analytics**: Comprehensive tracking and reporting

### Merchant Management System
- **Merchant Onboarding**: Streamlined merchant registration process
- **Location Management**: Geographic and location-based organization
- **Merchant Types**: Support for various business categories
- **Verification System**: Built-in verification and compliance tracking

### Device & Payment Infrastructure
- **Device Registration**: POS and payment device management
- **Device Types**: Support for multiple device categories
- **Device Status Tracking**: Active/inactive device monitoring
- **Batch Device Operations**: Efficient device management at scale

### Transaction Processing Engine
- **Batch Transaction Processing**: High-throughput transaction handling
- **Transaction Validation**: Comprehensive data validation and verification
- **Event-Driven Architecture**: Real-time transaction tracking and analytics
- **Data Integrity**: Immutable transaction records on blockchain

### Security & Access Control
- **Role-Based Access Control**: Granular permission system with multiple roles
- **Emergency Pausing**: System-wide safety measures for critical situations
- **Reentrancy Protection**: Comprehensive attack prevention mechanisms
- **Input Validation**: Robust parameter checking and data sanitization
- **Upgrade Security**: Secure contract upgrade procedures with proper authorization

## 🔧 Core Data Structures

### Partner Management
- **Partner Registration**: Comprehensive partner onboarding with verification codes
- **Business Classification**: Support for various business types and categories
- **Geographic Coverage**: Country-specific partner management with ISO2 codes
- **Verification System**: Built-in compliance and verification tracking

### Merchant Infrastructure
- **Merchant Profiles**: Complete merchant information and categorization
- **Location Management**: Geographic organization with location IDs and descriptions
- **Merchant Types**: Flexible categorization system for different business models
- **Status Tracking**: Active merchant monitoring and management

### Device Ecosystem
- **Device Registration**: Comprehensive device onboarding and management
- **Device Categories**: Support for POS terminals, mobile devices, and payment hardware
- **Status Management**: Real-time device status tracking and monitoring
- **Batch Operations**: Efficient bulk device management capabilities

### Transaction Processing
- **Batch Processing**: High-throughput transaction handling and validation
- **Data Validation**: Comprehensive transaction data verification
- **Immutable Records**: Blockchain-based transaction history and audit trails
- **Event Tracking**: Real-time transaction monitoring and analytics

## 🔧 Usage Examples

### ShareX PayFi Platform Integration

```solidity
// Deploy ShareX vault with proxy
ShareXVault vault = ShareXVault(proxyAddress);

// Register a payment partner
PartnerParams memory partner = PartnerParams({
    partnerCode: "PAYFI001",
    partnerName: "PayFi Solutions Inc",
    iso2: "US",
    verification: "KYB12345",
    description: "Digital payment infrastructure provider",
    businessType: "Fintech"
});
vault.registerPartner(partner);

// Register merchants under the partner
MerchantParams memory merchant = MerchantParams({
    merchantName: "Coffee Shop Downtown",
    merchantId: "MERCHANT_CS001",
    description: "Coffee and pastry retail shop",
    iso2: "US",
    locationId: "NYC_DOWNTOWN_001",
    location: "123 Main St, New York, NY",
    merchantType: "Retail_Food",
    verification: "MER_VER_001"
});
vault.registerMerchant(merchant);

// Register payment devices
DeviceParams memory device = DeviceParams({
    deviceId: "POS_TERMINAL_001",
    deviceType: "POS_Terminal",
    merchantId: "MERCHANT_CS001",
    description: "Main counter POS terminal",
    status: "Active"
});
vault.registerDevice(device);
```

### Batch Operations for Scale

```solidity
// Batch register multiple countries
CountryParams[] memory countries = new CountryParams[](3);
countries[0] = CountryParams("US", "United States", "USD");
countries[1] = CountryParams("CA", "Canada", "CAD");
countries[2] = CountryParams("GB", "United Kingdom", "GBP");
vault.batchRegisterCountries(countries);

// Batch process transactions
TransactionBatch memory batch = TransactionBatch({
    batchId: "BATCH_20240101_001",
    partnerId: "PAYFI001",
    transactionCount: 100,
    totalAmount: 15000000, // Total amount in smallest currency unit
    currency: "USD",
    processedAt: block.timestamp,
    merchantIds: merchantIdArray,
    deviceIds: deviceIdArray,
    transactionData: encryptedTransactionData
});
vault.processBatch(batch);
```

### Contract Upgrade Process

```solidity
// Deploy new implementation
ShareXVault newImplementation = new ShareXVault();

// Upgrade proxy (only proxy admin can execute)
ITransparentUpgradeableProxy(proxyAddress).upgradeToAndCall(
    address(newImplementation),
    abi.encodeWithSignature("initializeV2()")
);

// Verify upgrade success
require(
    ShareXVault(proxyAddress).getVersion() > previousVersion,
    "Upgrade failed"
);
```

## 🧪 Testing

The ShareX PayFi Solution includes comprehensive test suites covering all contract functionality:

```bash
# Run all tests with optimization
make foundry-test

# Run specific test contracts
forge test --match-contract ShareXVault -vvv

# Run with gas reporting
forge test --gas-report

# Generate coverage reports
forge coverage
```

### Test Structure
```text
test/
├── ShareXVault.t.sol                # Core vault functionality tests (15 tests)
├── ShareXVaultPartner.t.sol         # Partner management tests (7 tests)
├── ShareXVaultMerchant.t.sol        # Merchant management tests (10 tests)
├── ShareXVaultDevice.t.sol          # Device management tests (11 tests)
├── ShareXVaultCountry.t.sol         # Country registration tests (13 tests)
├── ShareXVaultTransaction.t.sol     # Transaction processing tests (5 tests)
└── foundry/                         # Foundry-specific test utilities
    └── ShareXVaultFoundry.t.sol     # Foundry integration tests
```

### Test Categories
- **Unit Tests**: Individual contract function validation
- **Integration Tests**: Multi-component interaction testing
- **Access Control Tests**: Role-based permission validation
- **Upgrade Tests**: Proxy upgrade mechanism verification
- **Edge Case Testing**: Boundary condition and error handling
- **Gas Optimization Tests**: Performance and efficiency validation

**Total: 61 tests** providing comprehensive coverage of the PayFi platform functionality.

## 🔒 Security Considerations

### Access Control Roles
- `DEFAULT_ADMIN_ROLE`: Complete system administration and role management
- `UPGRADER_ROLE`: Contract upgrade authorization and implementation
- `OPERATOR_ROLE`: Day-to-day PayFi operations and transaction processing
- `EMERGENCY_ROLE`: Emergency pause and critical system functions

### Proxy Security Architecture
- **TransparentUpgradeableProxy**: Secure upgrade mechanism with admin separation
- **Proxy Admin Owner**: Isolated proxy upgrade control
- **Implementation Security**: Storage layout protection and initialization guards
- **Role Separation**: Clear boundaries between proxy and business logic control

### Risk Management
- **Input Validation**: Comprehensive parameter validation and bounds checking
- **Reentrancy Protection**: SafeReentrancyGuard on all state-changing functions
- **Emergency Pausing**: System-wide pause capability for critical situations
- **Data Integrity**: Immutable transaction records and audit trails
- **Access Control**: Granular role-based permissions with proper inheritance
- **Counter Management**: Secure incrementing counters for unique ID generation
- **Batch Processing Security**: Transaction validation and data consistency checks

## 📊 Performance Metrics

### Gas Optimization
- **Efficient Data Structures**: Optimized struct packing and storage patterns
- **Batch Operations**: Reduced transaction costs through bulk processing
- **Minimal External Calls**: Streamlined contract interactions
- **Strategic Storage**: Cost-effective state variable management

### Scalability Features
- **High-Throughput Processing**: Efficient batch transaction handling
- **Optimized Queries**: Fast data retrieval and partner/merchant lookups
- **Event-Driven Architecture**: Comprehensive event emission for off-chain analytics
- **Upgradeable Design**: Future-proof architecture for continuous improvements

### Expected Performance (Network Dependent)
- **Transaction Processing**: 1000+ transactions per batch
- **Partner Onboarding**: Sub-second registration with verification
- **Device Management**: Real-time status updates and monitoring
- **Query Performance**: Efficient data retrieval across all entity types

*Note: Performance metrics vary based on network congestion, gas prices, and batch sizes. The system is optimized for high-throughput PayFi operations.*

## 🛠️ Deployment

### Prerequisites
```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Clone and setup project
git clone <repository-url>
cd sharex-contracts
forge install
```

### Build and Test
```bash
# Clean and build contracts
make clean && make build

# Run comprehensive tests
make foundry-test

# Generate ABI files
make abi
```

### Local Development
```bash
# Start local Anvil node
anvil

# Deploy to local network (dry run first)
DEPLOYMENT_CONTEXT=local forge script script/Deploy.s.sol:Deploy --ffi -vvv

# Deploy with broadcast
DEPLOYMENT_CONTEXT=local forge script script/Deploy.s.sol:Deploy \
  --rpc-url http://localhost:8545 \
  --private-key $PRIVATE_KEY \
  --broadcast --ffi -vvv
```

### BSC Testnet Deployment
```bash
# Set environment variables
export DEPLOYMENT_CONTEXT="bsc-testnet"
export RPC_URL="https://data-seed-prebsc-1-s1.binance.org:8545/"
export PRIVATE_KEY="your_private_key"
export ETHERSCAN_API_KEY="your_bscscan_api_key"

# Deploy with verification
forge script script/Deploy.s.sol:Deploy \
  --chain-id 97 \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --verify --etherscan-api-key $ETHERSCAN_API_KEY \
  --broadcast --ffi -vvv
```

### Supported Networks
- **Local**: Anvil development network for testing
- **BSC Testnet**: Binance Smart Chain testnet (Chain ID: 97)
- **BSC Mainnet**: Production deployment target
- **Devnet**: Custom development network for staging

### Deployment Artifacts
- Contract addresses stored in `deployments/[network]/.deploy`
- Chain ID configuration in `deployments/[network]/.chainId`
- Network-specific configs in `deploy-config/[network].json`

## 🔄 Contract Upgrades

### Upgrade Architecture
The ShareX PayFi Solution uses **TransparentUpgradeableProxy** with clear role separation:
- **Proxy Admin Owner**: Controls proxy upgrades and admin functions
- **Vault Admin**: Controls business logic and operational functions

### Upgrade Process
```bash
# 1. Deploy new implementation
forge script script/Deploy.s.sol:Deploy --broadcast

# 2. Get contract addresses
export PROXY_ADDRESS=$(jq -r '.ShareXVaultProxy' deployments/bsc-testnet/.deploy)
export NEW_IMPL=$(jq -r '.ShareXVault' deployments/bsc-testnet/.deploy)

# 3. Perform upgrade (proxy admin only)
cast send $PROXY_ADMIN "upgradeToAndCall(address,address,bytes)" \
  $PROXY_ADDRESS $NEW_IMPL "0x" --rpc-url $RPC_URL --private-key $KEY

# 4. Verify upgrade
cast call $PROXY_ADDRESS "getVersion()" --rpc-url $RPC_URL
```

### Upgrade Safety
- **Storage Layout**: Never modify existing storage variable order
- **Initialization**: Use separate `initializeV2()` functions for new versions
- **Testing**: Always test upgrades on testnet first
- **Multi-sig**: Use multi-signature wallets for production upgrades

## 🤝 Contributing

We welcome contributions to the ShareX PayFi Solution! Please follow our development guidelines:

### Development Workflow
1. Fork the repository and create a feature branch
2. Write comprehensive tests for new functionality
3. Ensure all tests pass (`make foundry-test`)
4. Follow Solidity coding standards and security best practices
5. Update documentation and examples as needed
6. Submit a pull request with detailed description

### Coding Standards
- Follow Solidity 0.8.24 best practices
- Use NatSpec documentation for all public functions
- Implement proper access control and input validation
- Write comprehensive unit and integration tests
- Maintain gas efficiency and optimization

### Security Guidelines
- Never modify storage layout in upgrades
- Always validate inputs and check access controls
- Use established patterns for reentrancy protection
- Test upgrade scenarios on testnet before mainnet

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**⚠️ Disclaimer**: This software is provided as-is for payment infrastructure purposes. While designed with security best practices, users should conduct thorough testing and audits before production deployment. Use at your own risk and ensure compliance with applicable financial regulations.
