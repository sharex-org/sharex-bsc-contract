// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../interfaces/external/IAAVE.sol";
import "../../interfaces/IDeFiProtocol.sol";
import "../../utils/Constants.sol";

/**
 * @title AaveAdapter
 * @dev AAVE V3 protocol dedicated adapter
 * 
 * Implements IDeFiProtocol interface, specifically handles AAVE V3 protocol interactions
 * Not called directly by external users, but managed uniformly through DeFiAdapter
 */
contract AaveAdapter is 
    IDeFiProtocol,
    Ownable,
    AccessControl,
    ReentrancyGuard,
    Pausable
{
    using SafeERC20 for IERC20;

    // ========== Storage Variables ==========
    
    /// @notice AAVE V3 Pool addresses provider
    IPoolAddressesProvider public immutable addressesProvider;
    
    /// @notice AAVE V3 Pool contract
    IPool public pool;
    
    /// @notice Supported token (currently only supports USDT)
    IERC20 public immutable token;
    
    /// @notice aToken contract (yield certificate)
    IERC20 public aToken;

    // ========== Event Definitions ==========
    
    event PoolUpdated(address indexed oldPool, address indexed newPool);
    event ATokenUpdated(address indexed oldAToken, address indexed newAToken);

    // ========== Constructor ==========
    
    /**
     * @notice Constructor
     * @param _addressesProvider AAVE V3 PoolAddressesProvider address
     * @param _token Supported token address (USDT)
     * @param _initialOwner Initial owner address
     */
    constructor(
        address _addressesProvider,
        address _token,
        address _initialOwner
    ) Ownable(_initialOwner) {
        require(_addressesProvider != address(0), "AaveAdapter: Invalid addresses provider");
        require(_token != address(0), "AaveAdapter: Invalid token address");
        require(_initialOwner != address(0), "AaveAdapter: Invalid initial owner");
        
        addressesProvider = IPoolAddressesProvider(_addressesProvider);
        token = IERC20(_token);
        
        // Initialize Pool and aToken addresses
        _updatePoolAndAToken();
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, _initialOwner);
        _grantRole(Constants.DEFI_MANAGER_ROLE, _initialOwner);
        _grantRole(Constants.EMERGENCY_ROLE, _initialOwner);
    }

    // ========== Admin Functions ==========
    
    /**
     * @notice Update Pool and aToken addresses
     * @dev Get latest addresses from AddressProvider
     */
    function updatePoolAndAToken() external onlyRole(Constants.DEFI_MANAGER_ROLE) {
        _updatePoolAndAToken();
    }
    
    /**
     * @notice Internal function: Update Pool and aToken addresses
     */
    function _updatePoolAndAToken() internal {
        address oldPool = address(pool);
        address newPool = addressesProvider.getPool();
        require(newPool != address(0), "AaveAdapter: Invalid pool address");
        
        pool = IPool(newPool);
        emit PoolUpdated(oldPool, newPool);
        
        // Get aToken address
        DataTypes.ReserveData memory reserveData = pool.getReserveData(address(token));
        address newAToken = reserveData.aTokenAddress;
        require(newAToken != address(0), "AaveAdapter: Invalid aToken address");
        
        address oldAToken = address(aToken);
        aToken = IERC20(newAToken);
        emit ATokenUpdated(oldAToken, newAToken);
    }

    /**
     * @notice Emergency pause contract
     */
    function pause() external onlyRole(Constants.EMERGENCY_ROLE) {
        _pause();
    }

    /**
     * @notice Resume contract operation
     */
    function unpause() external onlyRole(Constants.EMERGENCY_ROLE) {
        _unpause();
    }

    // ========== IDeFiProtocol Interface Implementation ==========
    
    /**
     * @notice Get protocol name
     */
    function protocolName() public pure override returns (string memory) {
        return "AAVE V3";
    }
    
    /**
     * @notice Get protocol version
     */
    function protocolVersion() public pure override returns (string memory) {
        return "3.0";
    }
    
    /**
     * @notice Check if protocol is running healthily
     */
    function isHealthy() public view override returns (bool) {
        try pool.getReserveData(address(token)) returns (DataTypes.ReserveData memory reserveData) {
            return reserveData.aTokenAddress != address(0);
        } catch {
            return false;
        }
    }
    
    /**
     * @notice Get current APY
     * @return apy Annual percentage yield (base 10000)
     */
    function getCurrentAPY() public view override returns (uint256 apy) {
        try pool.getReserveData(address(token)) returns (DataTypes.ReserveData memory reserveData) {
            // AAVE's interest rate is in ray units (1e27), needs to be converted to percentage with base 10000
            uint256 liquidityRate = reserveData.currentLiquidityRate;
            // Convert: ray -> percentage with base 10000
            return (liquidityRate * 10000) / 1e27;
        } catch {
            return 0;
        }
    }

    /**
     * @notice Deposit to AAVE V3 protocol
     * @param amount Deposit amount
     * @return success Whether successful
     */
    function protocolDeposit(uint256 amount) external override onlyRole(Constants.DEFI_MANAGER_ROLE) nonReentrant whenNotPaused returns (bool success) {
        require(amount > 0, "AaveAdapter: Amount must be positive");
        
        // Transfer in token
        token.safeTransferFrom(msg.sender, address(this), amount);
        
        // Authorize and deposit into AAVE V3
        token.forceApprove(address(pool), amount);
        pool.supply(address(token), amount, address(this), 0);
        
        emit ProtocolDeposit(msg.sender, amount);
        return true;
    }

    /**
     * @notice Withdraw from AAVE V3 protocol
     * @param amount Withdraw amount
     * @return actualAmount Actual withdraw amount
     */
    function protocolWithdraw(uint256 amount) external override onlyRole(Constants.DEFI_MANAGER_ROLE) nonReentrant whenNotPaused returns (uint256 actualAmount) {
        require(amount > 0, "AaveAdapter: Amount must be positive");
        
        // Withdraw from AAVE V3
        actualAmount = pool.withdraw(address(token), amount, msg.sender);
        require(actualAmount > 0, "AaveAdapter: Withdrawal failed");
        
        emit ProtocolWithdraw(msg.sender, actualAmount);
        return actualAmount;
    }

    /**
     * @notice Get total assets in the protocol
     * @return totalAssets Total assets amount
     */
    function getProtocolTotalAssets() public view override returns (uint256 totalAssets) {
        if (address(aToken) == address(0)) {
            return 0;
        }
        
        // aToken balance is the total assets in AAVE (including yield)
        return aToken.balanceOf(address(this));
    }

    // ========== Emergency Functions ==========
    
    /**
     * @notice Emergency withdraw all funds
     * @dev Only to be used in emergency situations
     */
    function emergencyWithdrawAll() external onlyRole(Constants.EMERGENCY_ROLE) whenPaused {
        if (address(aToken) != address(0)) {
            uint256 aTokenBalance = aToken.balanceOf(address(this));
            if (aTokenBalance > 0) {
                pool.withdraw(address(token), type(uint256).max, owner());
            }
        }
    }

    // ========== Query Functions ==========
    
    /**
     * @notice Get current deposit balance in AAVE
     * @return balance aToken balance
     */
    function getAaveBalance() external view returns (uint256 balance) {
        if (address(aToken) == address(0)) {
            return 0;
        }
        return aToken.balanceOf(address(this));
    }
    
    /**
     * @notice Get supported token address
     * @return Token address
     */
    function getSupportedToken() external view returns (address) {
        return address(token);
    }
} 