// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BaseStrategy.sol";
import "../../interfaces/external/IAAVE.sol";

/**
 * @title AaveStrategy
 * @dev AAVE V3 lending protocol investment strategy
 */
contract AaveStrategy is BaseStrategy {
    using SafeERC20 for IERC20;

    // ========== State Variables ==========
    
    /// @notice AAVE Pool Addresses Provider
    IPoolAddressesProvider public immutable aaveProvider;
    
    /// @notice AAVE Pool
    IPool public immutable aavePool;
    
    /// @notice aToken address (AAVE deposit receipt)
    IERC20 public immutable aToken;
    
    /// @notice Last recorded aToken balance
    uint256 public lastATokenBalance;

    // ========== Constructor ==========
    
    /**
     * @notice Constructor
     * @param _token USDT token address
     * @param _aaveProvider AAVE Pool Addresses Provider address
     * @param _aToken aUSDT token address
     * @param _initialOwner Initial owner
     */
    constructor(
        address _token,
        address _aaveProvider,
        address _aToken,
        address _initialOwner
    ) BaseStrategy(_token, _initialOwner) {
        require(_aaveProvider != address(0), "AaveStrategy: Invalid AAVE provider");
        require(_aToken != address(0), "AaveStrategy: Invalid aToken");
        
        aaveProvider = IPoolAddressesProvider(_aaveProvider);
        aavePool = IPool(aaveProvider.getPool());
        aToken = IERC20(_aToken);
        
        // Pre-approve AAVE Pool to use USDT
        token.forceApprove(address(aavePool), type(uint256).max);
    }

    // ========== Strategy Info ==========
    
    /**
     * @notice Get strategy name
     */
    function strategyName() public pure override returns (string memory) {
        return "AAVE V3 Lending Strategy";
    }
    
    /**
     * @notice Get strategy description
     */
    function strategyDescription() public pure override returns (string memory) {
        return "Deposits USDT into AAVE V3 protocol to earn lending interest";
    }
    
    /**
     * @notice Get strategy risk level (1-5, 1 is lowest risk)
     */
    function riskLevel() public pure override returns (uint8) {
        return 2; // Low risk, AAVE is a mature lending protocol
    }

    // ========== Strategy Implementation ==========
    
    /**
     * @notice Execute AAVE deposit
     * @param amount Deposit amount
     */
    function _executeInvest(uint256 amount) 
        internal 
        override 
        returns (bool success, uint256 actualAmount) 
    {
        try aavePool.supply(
            address(token),
            amount,
            address(this),
            0 // referralCode
        ) {
            // Update aToken balance record
            uint256 newBalance = aToken.balanceOf(address(this));
            uint256 actualSupplied = newBalance - lastATokenBalance;
            lastATokenBalance = newBalance;
            
            return (true, actualSupplied);
        } catch {
            return (false, 0);
        }
    }
    
    /**
     * @notice Execute AAVE withdrawal
     * @param amount Withdrawal amount
     */
    function _executeDivest(uint256 amount) 
        internal 
        override 
        returns (bool success, uint256 actualAmount) 
    {
        try aavePool.withdraw(
            address(token),
            amount,
            address(this)
        ) returns (uint256 withdrawnAmount) {
            // Update aToken balance record
            lastATokenBalance = aToken.balanceOf(address(this));
            
            return (true, withdrawnAmount);
        } catch {
            return (false, 0);
        }
    }
    
    /**
     * @notice Harvest AAVE rewards (AAVE rewards are auto-compounded)
     * @dev In AAVE V3, aToken balance grows automatically, this mainly updates records
     */
    function _executeHarvest() 
        internal 
        override 
        returns (bool success, uint256 rewardAmount) 
    {
        uint256 currentBalance = aToken.balanceOf(address(this));
        
        if (currentBalance > lastATokenBalance) {
            uint256 earned = currentBalance - lastATokenBalance;
            lastATokenBalance = currentBalance;
            
            // AAVE rewards are already in aToken, no additional transfer needed
            // This returns theoretical rewards, actual rewards are already compounded
            return (true, earned);
        }
        
        return (true, 0);
    }

    // ========== Query Functions ==========
    
    /**
     * @notice Calculate current total value of strategy
     */
    function _calculateTotalValue() internal view override returns (uint256) {
        return aToken.balanceOf(address(this));
    }
    
    /**
     * @notice Calculate pending rewards
     */
    function _calculatePendingRewards() internal view override returns (uint256) {
        uint256 currentBalance = aToken.balanceOf(address(this));
        return currentBalance > lastATokenBalance ? currentBalance - lastATokenBalance : 0;
    }
    
    /**
     * @notice Estimate exit cost
     * @param amount Exit amount
     */
    function _estimateExitCost(uint256 amount) internal view override returns (uint256) {
        // AAVE withdrawal usually has no extra fees, but may have slight slippage
        // Simplified handling here, return 0
        amount; // Avoid unused parameter warning
        return 0;
    }
    
    /**
     * @notice Get AAVE APY
     */
    function getAPY() public view override returns (uint256) {
        try aavePool.getReserveData(address(token)) returns (
            DataTypes.ReserveData memory reserveData
        ) {
            // AAVE rates are in ray units (27 decimals)
            // Convert to basis points (10000 base)
            return reserveData.currentLiquidityRate / 1e23; // Convert from ray to basis points
        } catch {
            return 0;
        }
    }

    // ========== AAVE Specific Functions ==========
    
    /**
     * @notice Get AAVE reserve data
     */
    function getReserveData() external view returns (
        uint256 liquidityRate,
        uint256 variableBorrowRate,
        uint256 stableBorrowRate,
        uint256 totalATokenSupply,
        uint256 availableLiquidity
    ) {
        DataTypes.ReserveData memory data = aavePool.getReserveData(address(token));
        
        return (
            data.currentLiquidityRate,
            data.currentVariableBorrowRate,
            data.currentStableBorrowRate,
            IERC20(data.aTokenAddress).totalSupply(),
            token.balanceOf(data.aTokenAddress)
        );
    }
    
    /**
     * @notice Get user's deposit balance in AAVE
     */
    function getATokenBalance() external view returns (uint256) {
        return aToken.balanceOf(address(this));
    }
    
    /**
     * @notice Get health factor for USDT in AAVE
     */
    function getHealthFactor() external view returns (uint256) {
        try aavePool.getUserAccountData(address(this)) returns (
            uint256, // totalCollateralBase
            uint256, // totalDebtBase
            uint256, // availableBorrowsBase
            uint256, // currentLiquidationThreshold
            uint256, // ltv
            uint256 healthFactor
        ) {
            return healthFactor;
        } catch {
            return type(uint256).max; // Indicates no debt, infinite health factor
        }
    }

    // ========== Admin Functions ==========
    
    /**
     * @notice Emergency withdraw all funds directly from AAVE
     */
    function emergencyWithdrawFromAave() 
        external 
        onlyRole(Constants.EMERGENCY_ROLE) 
        whenPaused 
    {
        uint256 aTokenBalance = aToken.balanceOf(address(this));
        if (aTokenBalance > 0) {
            try aavePool.withdraw(
                address(token),
                type(uint256).max, // Withdraw all
                address(this)
            ) {
                lastATokenBalance = 0;
                totalFunds = token.balanceOf(address(this));
            } catch {
                // Withdrawal failed, log but do not revert
            }
        }
    }
    
    /**
     * @notice Update AAVE allowance
     */
    function updateAaveAllowance() external onlyRole(Constants.DEFI_MANAGER_ROLE) {
        token.forceApprove(address(aavePool), type(uint256).max);
    }
    
    /**
     * @notice Sync aToken balance record
     */
    function syncATokenBalance() external onlyRole(Constants.DEFI_MANAGER_ROLE) {
        lastATokenBalance = aToken.balanceOf(address(this));
    }
} 