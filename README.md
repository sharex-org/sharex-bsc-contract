# ShareX DeFi Yield Vault

A professional, extensible DeFi yield aggregation system built on Solidity 0.8.24 with a clean, modular architecture designed for easy integration of multiple DeFi protocols.

## 🏗️ Architecture Overview

The system is designed with clear separation of concerns:

```text
├── YieldVault.sol              # Main vault for DeFi yield generation
├── ShareXVault.sol             # Business transaction processing
├── adapters/                   # DeFi protocol integrations
│   ├── BaseAdapter.sol         # Abstract base for all adapters
│   └── PancakeSwapV3Adapter.sol # PancakeSwap V3 LP + MasterChef farming
├── interfaces/                 # Clean interface definitions
│   ├── IYieldVault.sol         # Main vault interface
│   ├── IShareXVault.sol        # Business vault interface
│   ├── IAdapter.sol            # Base adapter interface
│   ├── ILiquidityAdapter.sol   # Liquidity-specific adapter interface
│   └── IPancakeSwapV3.sol      # PancakeSwap V3 protocol interfaces
└── libraries/                  # Shared utilities and constants
    ├── Constants.sol           # System-wide constants and roles
    ├── DataTypes.sol           # Common data structures
    ├── Errors.sol              # Custom error definitions
    └── Events.sol              # Event definitions
```

## 🚀 Key Features

### Multi-Adapter Architecture
- **Extensible Design**: Easy to add new DeFi protocols
- **Risk Diversification**: Automatic distribution across multiple strategies
- **Weight-Based Allocation**: Configurable investment distribution
- **Emergency Controls**: Individual adapter pause/emergency exit

### Yield Vault Features
- **Auto-Investment**: Configurable automatic fund deployment
- **Reward Harvesting**: Automated yield collection across adapters
- **Rebalancing**: Dynamic reallocation based on performance
- **Share-Based Accounting**: Fair distribution of rewards

### Business Transaction Vault (ShareX)
- **Partner & Merchant Management**: Complete entity registration system
- **Device Registration**: POS and payment device tracking
- **Transaction Processing**: Batch upload and processing capabilities
- **Country & Location Support**: Geographic data management
- **Access Control**: Role-based permissions for operations

### Security & Access Control
- **Role-Based Permissions**: Granular access control
- **Emergency Pausing**: System-wide safety measures
- **Reentrancy Protection**: Comprehensive attack prevention
- **Input Validation**: Robust parameter checking

## 📋 Supported Protocols

### Currently Integrated
- **PancakeSwap V3**: Fully functional concentrated liquidity provision with active position management, automated CAKE farming via MasterChef V3, and comprehensive fee collection

### Easy to Add
- **Uniswap V3**: Similar concentrated liquidity model
- **Compound**: Lending protocol integration
- **Aave**: Multi-asset lending and borrowing
- **Venus**: BSC-based lending protocol
- **Beefy Finance**: Yield optimization strategies

## 🔧 Usage Examples

### Basic Yield Vault Usage

```solidity
// Deploy vault
YieldVault vault = new YieldVault(USDT_ADDRESS, admin);

// Add DeFi adapters with weights
vault.addAdapter(pancakeSwapAdapter, 4000); // 40% weight
vault.addAdapter(compoundAdapter, 6000);    // 60% weight

// User deposits with auto-investment
IERC20(USDT).approve(address(vault), 1000e6);
uint256 shares = vault.deposit(1000e6, true);

// Harvest rewards across all adapters
uint256 rewards = vault.harvestAllRewards();

// Withdraw funds
uint256 amount = vault.withdraw(shares);
```

### ShareX Business Vault Usage

```solidity
// Deploy ShareX vault
ShareXVault vault = new ShareXVault(admin);

// Register a partner
PartnerParams memory partner = PartnerParams({
    partnerCode: "PARTNER001",
    partnerName: "Test Partner",
    iso2: "US",
    verification: "VER123",
    description: "Test Description",
    businessType: "Retail"
});
vault.registerPartner(partner);

// Register a merchant
MerchantParams memory merchant = MerchantParams({
    merchantName: "Test Merchant",
    merchantId: "MERCHANT001",
    description: "Test merchant",
    iso2: "US",
    locationId: "NYC001",
    location: "New York City",
    merchantType: "Retail",
    verification: "VER123"
});
vault.registerMerchant(merchant);
```

### Adding a New Adapter

```solidity
contract MyProtocolAdapter is BaseAdapter {
    constructor(address asset, address admin)
        BaseAdapter(asset, admin) {}

    function totalAssets() public view override returns (uint256) {
        // Return total assets under management from protocol
        return _calculateTotalAssetsFromProtocol();
    }

    function _deposit(uint256 amount)
        internal override returns (uint256 shares) {
        // Deploy assets to the protocol (e.g., lend to Compound)
        _deployToProtocol(amount);
        return amount; // Return shares (typically 1:1 for lending protocols)
    }

    function _withdraw(uint256 shares)
        internal override returns (uint256 amount) {
        // Withdraw from protocol (e.g., redeem from Compound)
        amount = _withdrawFromProtocol(shares);
        return amount;
    }

    function _harvest()
        internal override returns (uint256 rewardAmount) {
        // Claim protocol rewards (e.g., COMP tokens)
        rewardAmount = _claimProtocolRewards();
        return rewardAmount;
    }

    function getAdapterInfo()
        external pure override
        returns (string memory, string memory, uint8) {
        return ("MyProtocol", "Lending", 2);
    }
}
```

## 🧪 Testing

The project includes comprehensive test suites with a clean, focused structure:

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-path test/YieldVault.t.sol

# Run with gas reporting
forge test --gas-report

# Run with coverage
forge coverage
```

### Test Structure
```text
test/
├── YieldVault.t.sol                 # Core yield vault functionality (27 tests)
├── MockAdapter.t.sol                # Adapter testing framework (24 tests)
├── ShareXVault.t.sol                # Core ShareX vault tests (15 tests)
├── ShareXVaultPartner.t.sol         # Partner management tests (7 tests)
├── ShareXVaultMerchant.t.sol        # Merchant management tests (10 tests)
├── ShareXVaultDevice.t.sol          # Device management tests (11 tests)
├── ShareXVaultCountry.t.sol         # Country registration tests (13 tests)
└── ShareXVaultTransaction.t.sol     # Transaction processing tests (5 tests)
```

### Test Categories
- **Unit Tests**: Individual contract functionality
- **Integration Tests**: Multi-contract interactions
- **Edge Case Testing**: Boundary condition validation
- **Access Control Tests**: Permission and security validation

**Total: 112 tests** providing comprehensive coverage of all functionality.

## 🔒 Security Considerations

### Access Control
- `DEFAULT_ADMIN_ROLE`: Complete system control
- `DEFI_MANAGER_ROLE`: Adapter and strategy management
- `OPERATOR_ROLE`: Day-to-day operations (ShareX)
- `EMERGENCY_ROLE`: Emergency pause and exit functions

### Risk Management
- Maximum adapter weights to prevent over-concentration
- Emergency pause mechanisms at vault and adapter levels
- Slippage protection for DEX trades and LP position management
- Input validation and parameter bounds checking
- Reentrancy protection on all state-changing functions
- Real DeFi integration risk mitigation with proper error handling
- Position management safeguards for concentrated liquidity ranges

## 📊 Performance Metrics

### Gas Optimization
- Efficient storage patterns and packed structs
- Minimal external calls and batch operations
- Optimized loops and calculations
- Strategic use of immutable variables

### Expected APY (Market Dependent)
- **PancakeSwap V3 USDT/BUSD**: 8-15% APY (trading fees + CAKE rewards)
- **Conservative Strategy**: 8-12% APY (stable pair liquidity provision)
- **Balanced Strategy**: 12-18% APY (mixed stable and volatile pairs)
- **Aggressive Strategy**: 18-25% APY (concentrated ranges on volatile pairs)

*Note: APY varies based on market conditions, trading volume, and liquidity incentives. PancakeSwap V3 yields depend on fee tier selection and price range efficiency.*

## 🛠️ Deployment

### Prerequisites
```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install dependencies
forge install
```

### Local Development
```bash
# Start local node
anvil

# Deploy to local network
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

### Testnet Deployment
```bash
# Deploy to BSC Testnet
forge script script/Deploy.s.sol \
  --rpc-url $BSC_TESTNET_RPC \
  --broadcast \
  --verify \
  --etherscan-api-key $BSCSCAN_API_KEY
```

### Available Networks
- **Local**: Anvil development network
- **BSC Testnet**: Binance Smart Chain testnet with verified PancakeSwap V3 contracts
- **BSC Mainnet**: Production deployment target with full DeFi ecosystem

## 🤝 Contributing

We welcome contributions! Please follow our development guidelines:

### Development Workflow
1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass (`forge test`)
5. Follow our coding standards
6. Submit a pull request

### Coding Standards
- Follow Solidity style guide
- Write comprehensive tests
- Use descriptive variable and function names
- Include NatSpec documentation
- Maintain security best practices

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**⚠️ Disclaimer**: This software is provided as-is without any guarantees. DeFi investments carry risks including but not limited to smart contract vulnerabilities, market volatility, and potential loss of funds. Use at your own risk and only invest what you can afford to lose.