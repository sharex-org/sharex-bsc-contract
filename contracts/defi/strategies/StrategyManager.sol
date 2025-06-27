// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../interfaces/IStrategy.sol";
import "../../utils/Constants.sol";

/**
 * @title StrategyManager
 * @dev Manages the allocation and execution of multiple investment strategies.
 */
contract StrategyManager is 
    Ownable,
    AccessControl,
    ReentrancyGuard,
    Pausable
{
    using SafeERC20 for IERC20;

    // ========== Data Structures ==========
    
    struct StrategyInfo {
        IStrategy strategy;          // The strategy contract address.
        uint256 allocation;          // The allocation percentage (basis 10000).
        uint256 maxAllocation;       // The maximum allocation amount.
        uint256 currentInvested;     // The currently invested amount.
        bool isActive;               // Whether the strategy is active.
        uint256 lastRebalance;       // The timestamp of the last rebalance.
    }
    
    struct StrategyPerformance {
        uint256 totalInvested;       // The total amount invested.
        uint256 totalValue;          // The current total value.
        uint256 totalRewards;        // The cumulative rewards.
        uint256 apy;                 // The annualized percentage yield.
        uint8 riskLevel;             // The risk level.
    }

    // ========== State Variables ==========
    
    /// @notice The token being managed (USDT).
    IERC20 public immutable token;
    
    /// @notice The list of strategies.
    StrategyInfo[] public strategies;
    
    /// @notice Mapping from strategy address to its index in the array.
    mapping(address => uint256) public strategyIndex;
    
    /// @notice Whether a strategy is registered.
    mapping(address => bool) public isRegistered;
    
    /// @notice The total funds.
    uint256 public totalFunds;
    
    /// @notice The total invested amount.
    uint256 public totalInvested;
    
    /// @notice The maximum number of strategies.
    uint256 public constant MAX_STRATEGIES = 10;
    
    /// @notice The rebalance interval in seconds.
    uint256 public rebalanceInterval = 24 hours;
    
    /// @notice The timestamp of the last rebalance.
    uint256 public lastRebalanceTime;
    
    /// @notice The minimum investment amount.
    uint256 public minInvestAmount = 100 * 1e6; // 100 USDT
    
    /// @notice The emergency withdrawal fee rate (basis 10000).
    uint256 public emergencyFee = 100; // 1%

    // ========== Events ==========
    
    event StrategyAdded(address indexed strategy, uint256 allocation, uint256 maxAllocation);
    event StrategyRemoved(address indexed strategy);
    event StrategyUpdated(address indexed strategy, uint256 newAllocation, uint256 newMaxAllocation);
    event FundsInvested(address indexed strategy, uint256 amount);
    event FundsWithdrawn(address indexed strategy, uint256 amount);
    event RewardsHarvested(address indexed strategy, uint256 amount);
    event Rebalanced(uint256 totalValue, uint256 timestamp);
    event EmergencyWithdraw(address indexed user, uint256 amount, uint256 fee);

    // ========== Modifiers ==========
    
    modifier onlyValidStrategy(address _strategy) {
        require(isRegistered[_strategy], "StrategyManager: Strategy not registered");
        _;
    }
    
    modifier whenRebalanceNeeded() {
        require(
            block.timestamp >= lastRebalanceTime + rebalanceInterval,
            "StrategyManager: Rebalance not needed yet"
        );
        _;
    }

    // ========== Constructor ==========
    
    /**
     * @notice Constructor
     * @param _token The address of the token being managed (USDT).
     * @param _initialOwner The address of the initial owner.
     */
    constructor(
        address _token,
        address _initialOwner
    ) Ownable(_initialOwner) {
        require(_token != address(0), "StrategyManager: Invalid token address");
        require(_initialOwner != address(0), "StrategyManager: Invalid initial owner");
        
        token = IERC20(_token);
        lastRebalanceTime = block.timestamp;
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, _initialOwner);
        _grantRole(Constants.DEFI_MANAGER_ROLE, _initialOwner);
        _grantRole(Constants.EMERGENCY_ROLE, _initialOwner);
    }

    // ========== Strategy Management ==========
    
    /**
     * @notice Add a new strategy.
     * @param _strategy The address of the strategy contract.
     * @param _allocation The allocation percentage (basis 10000).
     * @param _maxAllocation The maximum allocation amount.
     */
    function addStrategy(
        address _strategy,
        uint256 _allocation,
        uint256 _maxAllocation
    ) external onlyRole(Constants.DEFI_MANAGER_ROLE) {
        require(_strategy != address(0), "StrategyManager: Invalid strategy address");
        require(!isRegistered[_strategy], "StrategyManager: Strategy already registered");
        require(strategies.length < MAX_STRATEGIES, "StrategyManager: Too many strategies");
        require(_allocation <= 10000, "StrategyManager: Invalid allocation");
        
        // Check that total allocation does not exceed 100%
        uint256 totalAllocation = _allocation;
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].isActive) {
                totalAllocation += strategies[i].allocation;
            }
        }
        require(totalAllocation <= 10000, "StrategyManager: Total allocation exceeds 100%");
        
        IStrategy strategy = IStrategy(_strategy);
        require(strategy.isActive(), "StrategyManager: Strategy not active");
        
        strategies.push(StrategyInfo({
            strategy: strategy,
            allocation: _allocation,
            maxAllocation: _maxAllocation,
            currentInvested: 0,
            isActive: true,
            lastRebalance: block.timestamp
        }));
        
        strategyIndex[_strategy] = strategies.length - 1;
        isRegistered[_strategy] = true;
        
        emit StrategyAdded(_strategy, _allocation, _maxAllocation);
    }
    
    /**
     * @notice Remove a strategy.
     * @param _strategy The address of the strategy contract.
     */
    function removeStrategy(address _strategy) 
        external 
        onlyRole(Constants.DEFI_MANAGER_ROLE) 
        onlyValidStrategy(_strategy) 
    {
        uint256 index = strategyIndex[_strategy];
        StrategyInfo storage strategyInfo = strategies[index];
        
        // If there are investments, withdraw everything first.
        if (strategyInfo.currentInvested > 0) {
            _withdrawFromStrategy(index, 0); // 0 means withdraw all
        }
        
        // Move the last strategy to the current position.
        if (index != strategies.length - 1) {
            strategies[index] = strategies[strategies.length - 1];
            strategyIndex[address(strategies[index].strategy)] = index;
        }
        
        strategies.pop();
        delete strategyIndex[_strategy];
        delete isRegistered[_strategy];
        
        emit StrategyRemoved(_strategy);
    }
    
    /**
     * @notice Update a strategy's configuration.
     * @param _strategy The address of the strategy contract.
     * @param _allocation The new allocation percentage.
     * @param _maxAllocation The new maximum allocation amount.
     */
    function updateStrategy(
        address _strategy,
        uint256 _allocation,
        uint256 _maxAllocation
    ) external onlyRole(Constants.DEFI_MANAGER_ROLE) onlyValidStrategy(_strategy) {
        require(_allocation <= 10000, "StrategyManager: Invalid allocation");
        
        uint256 index = strategyIndex[_strategy];
        StrategyInfo storage strategyInfo = strategies[index];
        
        // Check that total allocation does not exceed 100%
        uint256 totalAllocation = _allocation;
        for (uint256 i = 0; i < strategies.length; i++) {
            if (i != index && strategies[i].isActive) {
                totalAllocation += strategies[i].allocation;
            }
        }
        require(totalAllocation <= 10000, "StrategyManager: Total allocation exceeds 100%");
        
        strategyInfo.allocation = _allocation;
        strategyInfo.maxAllocation = _maxAllocation;
        
        emit StrategyUpdated(_strategy, _allocation, _maxAllocation);
    }
    
    /**
     * @notice Activate/deactivate a strategy.
     * @param _strategy The address of the strategy contract.
     * @param _active Whether to activate the strategy.
     */
    function setStrategyActive(address _strategy, bool _active) 
        external 
        onlyRole(Constants.DEFI_MANAGER_ROLE) 
        onlyValidStrategy(_strategy) 
    {
        uint256 index = strategyIndex[_strategy];
        strategies[index].isActive = _active;
        
        if (!_active && strategies[index].currentInvested > 0) {
            // When deactivating a strategy, withdraw all funds.
            _withdrawFromStrategy(index, 0);
        }
    }

    // ========== Investment Management ==========
    
    /**
     * @notice Invest funds into strategies.
     * @param amount The amount to invest.
     */
    function invest(uint256 amount) 
        external 
        onlyRole(Constants.DEFI_MANAGER_ROLE) 
        nonReentrant 
        whenNotPaused 
    {
        require(amount >= minInvestAmount, "StrategyManager: Amount too small");
        
        // Transfer tokens in.
        token.safeTransferFrom(msg.sender, address(this), amount);
        totalFunds += amount;
        
        // Invest into strategies based on allocation.
        _investToStrategies(amount);
    }
    
    /**
     * @notice Withdraw funds from strategies.
     * @param amount The amount to withdraw (0 means all).
     */
    function withdraw(uint256 amount) 
        external 
        onlyRole(Constants.DEFI_MANAGER_ROLE) 
        nonReentrant 
        returns (uint256 actualAmount) 
    {
        if (amount == 0) {
            amount = totalInvested;
        }
        
        require(amount <= totalInvested, "StrategyManager: Insufficient invested funds");
        
        actualAmount = _withdrawFromStrategies(amount);
        totalFunds -= actualAmount;
        
        // Transfer to the caller.
        token.safeTransfer(msg.sender, actualAmount);
    }
    
    /**
     * @notice Harvest rewards from all strategies.
     */
    function harvestAll() 
        public 
        onlyRole(Constants.DEFI_MANAGER_ROLE) 
        nonReentrant 
        returns (uint256 totalRewards) 
    {
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].isActive && strategies[i].currentInvested > 0) {
                (bool success, uint256 rewardAmount) = strategies[i].strategy.harvest();
                if (success && rewardAmount > 0) {
                    totalRewards += rewardAmount;
                    emit RewardsHarvested(address(strategies[i].strategy), rewardAmount);
                }
            }
        }
        
        if (totalRewards > 0) {
            totalFunds += totalRewards;
        }
    }
    
    /**
     * @notice Rebalance all strategies.
     */
    function rebalance() 
        external 
        onlyRole(Constants.DEFI_MANAGER_ROLE) 
        nonReentrant 
        whenRebalanceNeeded 
    {
        // First, harvest all rewards.
        harvestAll();
        
        // Calculate the current total value.
        uint256 totalValue = getTotalValue();
        
        // Reallocate funds.
        _rebalanceStrategies(totalValue);
        
        lastRebalanceTime = block.timestamp;
        emit Rebalanced(totalValue, block.timestamp);
    }

    // ========== Query Functions ==========
    
    /**
     * @notice Get the number of strategies.
     */
    function getStrategyCount() external view returns (uint256) {
        return strategies.length;
    }
    
    /**
     * @notice Get information for a specific strategy.
     * @param index The index of the strategy.
     */
    function getStrategyInfo(uint256 index) external view returns (
        address strategyAddress,
        string memory name,
        uint256 allocation,
        uint256 maxAllocation,
        uint256 currentInvested,
        bool isActive
    ) {
        require(index < strategies.length, "StrategyManager: Invalid index");
        
        StrategyInfo storage info = strategies[index];
        return (
            address(info.strategy),
            info.strategy.strategyName(),
            info.allocation,
            info.maxAllocation,
            info.currentInvested,
            info.isActive
        );
    }
    
    /**
     * @notice Get performance data for a specific strategy.
     * @param index The index of the strategy.
     */
    function getStrategyPerformance(uint256 index) external view returns (
        StrategyPerformance memory performance
    ) {
        require(index < strategies.length, "StrategyManager: Invalid index");
        
        StrategyInfo storage info = strategies[index];
        
        performance.totalInvested = info.strategy.getTotalInvested();
        performance.totalValue = info.strategy.getTotalValue();
        performance.totalRewards = performance.totalValue > performance.totalInvested 
            ? performance.totalValue - performance.totalInvested 
            : 0;
        performance.apy = info.strategy.getAPY();
        performance.riskLevel = info.strategy.riskLevel();
    }
    
    /**
     * @notice Get the total value of invested funds.
     */
    function getTotalValue() public view returns (uint256 totalValue) {
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].isActive) {
                totalValue += strategies[i].strategy.getTotalValue();
            }
        }
        
        // Add un-invested funds.
        totalValue += token.balanceOf(address(this));
    }
    
    /**
     * @notice Get total pending rewards from all strategies.
     */
    function getTotalPendingRewards() external view returns (uint256 totalPending) {
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].isActive) {
                totalPending += strategies[i].strategy.getPendingRewards();
            }
        }
    }
    
    /**
     * @notice Get the portfolio's weighted average APY.
     */
    function getPortfolioAPY() external view returns (uint256 weightedAPY) {
        uint256 totalValue = getTotalValue();
        if (totalValue == 0) return 0;
        
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].isActive) {
                uint256 strategyValue = strategies[i].strategy.getTotalValue();
                uint256 strategyAPY = strategies[i].strategy.getAPY();
                weightedAPY += (strategyValue * strategyAPY) / totalValue;
            }
        }
    }
    
    /**
     * @notice Get the portfolio's weighted average risk level.
     */
    function getPortfolioRiskLevel() external view returns (uint256 weightedRisk) {
        uint256 totalValue = getTotalValue();
        if (totalValue == 0) return 0;
        
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].isActive) {
                uint256 strategyValue = strategies[i].strategy.getTotalValue();
                uint256 strategyRisk = strategies[i].strategy.riskLevel();
                weightedRisk += (strategyValue * strategyRisk) / totalValue;
            }
        }
    }

    // ========== Internal Functions ==========
    
    /**
     * @notice Invest into strategies based on allocation.
     * @param amount The total amount to invest.
     */
    function _investToStrategies(uint256 amount) internal {
        for (uint256 i = 0; i < strategies.length; i++) {
            StrategyInfo storage strategyInfo = strategies[i];
            
            if (!strategyInfo.isActive) continue;
            
            uint256 allocatedAmount = (amount * strategyInfo.allocation) / 10000;
            
            // Check max allocation limit.
            if (strategyInfo.maxAllocation > 0 && 
                strategyInfo.currentInvested + allocatedAmount > strategyInfo.maxAllocation) {
                allocatedAmount = strategyInfo.maxAllocation - strategyInfo.currentInvested;
            }
            
            if (allocatedAmount > 0) {
                // Approve and invest.
                token.forceApprove(address(strategyInfo.strategy), allocatedAmount);
                (bool success, uint256 actualAmount) = strategyInfo.strategy.invest(allocatedAmount);
                
                if (success) {
                    strategyInfo.currentInvested += actualAmount;
                    totalInvested += actualAmount;
                    emit FundsInvested(address(strategyInfo.strategy), actualAmount);
                }
            }
        }
    }
    
    /**
     * @notice Withdraw funds from strategies.
     * @param amount The amount to withdraw.
     */
    function _withdrawFromStrategies(uint256 amount) internal returns (uint256 totalWithdrawn) {
        uint256 remaining = amount;
        
        // Withdraw from each strategy proportionally.
        for (uint256 i = 0; i < strategies.length && remaining > 0; i++) {
            StrategyInfo storage strategyInfo = strategies[i];
            
            if (!strategyInfo.isActive || strategyInfo.currentInvested == 0) continue;
            
            uint256 withdrawAmount = (remaining * strategyInfo.currentInvested) / totalInvested;
            withdrawAmount = withdrawAmount > strategyInfo.currentInvested 
                ? strategyInfo.currentInvested 
                : withdrawAmount;
            
            if (withdrawAmount > 0) {
                (bool success, uint256 actualAmount) = strategyInfo.strategy.divest(withdrawAmount);
                
                if (success) {
                    strategyInfo.currentInvested -= actualAmount;
                    totalInvested -= actualAmount;
                    totalWithdrawn += actualAmount;
                    remaining -= withdrawAmount;
                    
                    emit FundsWithdrawn(address(strategyInfo.strategy), actualAmount);
                }
            }
        }
    }
    
    /**
     * @notice Withdraw funds from a single strategy.
     * @param index The index of the strategy.
     * @param amount The amount to withdraw (0 for all).
     */
    function _withdrawFromStrategy(uint256 index, uint256 amount) internal {
        StrategyInfo storage strategyInfo = strategies[index];
        
        if (amount == 0) {
            amount = strategyInfo.currentInvested;
        }
        
        if (amount > 0) {
            (bool success, uint256 actualAmount) = strategyInfo.strategy.divest(amount);
            
            if (success) {
                strategyInfo.currentInvested -= actualAmount;
                totalInvested -= actualAmount;
                totalFunds += actualAmount;
                
                emit FundsWithdrawn(address(strategyInfo.strategy), actualAmount);
            }
        }
    }
    
    /**
     * @notice Rebalance strategy allocations.
     * @param totalValue The current total value.
     */
    function _rebalanceStrategies(uint256 totalValue) internal {
        // First, withdraw all funds.
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].isActive && strategies[i].currentInvested > 0) {
                _withdrawFromStrategy(i, 0);
            }
        }
        
        // Re-invest proportionally.
        if (totalValue > 0) {
            _investToStrategies(totalValue);
        }
    }

    // ========== Admin Functions ==========
    
    /**
     * @notice Set the rebalance interval.
     * @param _interval The new interval in seconds.
     */
    function setRebalanceInterval(uint256 _interval) 
        external 
        onlyRole(Constants.DEFI_MANAGER_ROLE) 
    {
        require(_interval >= 1 hours, "StrategyManager: Interval too short");
        rebalanceInterval = _interval;
    }
    
    /**
     * @notice Set the minimum investment amount.
     * @param _minAmount The new minimum investment amount.
     */
    function setMinInvestAmount(uint256 _minAmount) 
        external 
        onlyRole(Constants.DEFI_MANAGER_ROLE) 
    {
        minInvestAmount = _minAmount;
    }
    
    /**
     * @notice Set the emergency withdrawal fee.
     * @param _fee The fee rate (basis 10000).
     */
    function setEmergencyFee(uint256 _fee) 
        external 
        onlyRole(Constants.DEFI_MANAGER_ROLE) 
    {
        require(_fee <= 1000, "StrategyManager: Fee too high"); // Max 10%
        emergencyFee = _fee;
    }
    
    /**
     * @notice Pause the contract.
     */
    function pause() external onlyRole(Constants.EMERGENCY_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause the contract.
     */
    function unpause() external onlyRole(Constants.EMERGENCY_ROLE) {
        _unpause();
    }
    
    /**
     * @notice Emergency withdraw all funds from all strategies.
     */
    function emergencyWithdrawAll() 
        external 
        onlyRole(Constants.EMERGENCY_ROLE) 
        whenPaused 
    {
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i].currentInvested > 0) {
                _withdrawFromStrategy(i, 0);
            }
        }
    }

    // ========== User Emergency Functions ==========
    
    /**
     * @notice User emergency withdrawal (incurs a fee).
     * @param amount The amount to withdraw.
     */
    function userEmergencyWithdraw(uint256 amount) 
        external 
        nonReentrant 
        whenPaused 
    {
        require(amount > 0, "StrategyManager: Invalid amount");
        require(amount <= totalFunds, "StrategyManager: Insufficient funds");
        
        uint256 fee = (amount * emergencyFee) / 10000;
        uint256 userAmount = amount - fee;
        
        totalFunds -= amount;
        
        // Transfer to user.
        token.safeTransfer(msg.sender, userAmount);
        
        // The fee remains in the contract.
        emit EmergencyWithdraw(msg.sender, userAmount, fee);
    }
} 