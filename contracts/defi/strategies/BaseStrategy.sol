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
 * @title BaseStrategy
 * @dev Base class for investment strategies, providing common functionalities and security mechanisms.
 */
abstract contract BaseStrategy is 
    IStrategy,
    Ownable,
    AccessControl,
    ReentrancyGuard,
    Pausable
{
    using SafeERC20 for IERC20;

    // ========== State Variables ==========
    
    /// @notice The token used by the strategy.
    IERC20 public immutable token;
    
    /// @notice The total amount invested in the strategy.
    uint256 public totalInvested;
    
    /// @notice The total funds managed by the strategy.
    uint256 public totalFunds;
    
    /// @notice The last update timestamp.
    uint256 public lastUpdateTime;
    
    /// @notice Whether the strategy is active.
    bool public strategyActive;
    
    /// @notice Authorized callers (e.g., DeFiManager).
    mapping(address => bool) public authorizedCallers;

    // ========== Events ==========
    
    event AuthorizedCallerUpdated(address indexed caller, bool authorized);
    event StrategyActivated();
    event StrategyDeactivated(string reason);

    // ========== Modifiers ==========
    
    modifier onlyAuthorized() {
        require(
            authorizedCallers[msg.sender] || hasRole(Constants.DEFI_MANAGER_ROLE, msg.sender),
            "BaseStrategy: Not authorized"
        );
        _;
    }
    
    modifier whenActive() {
        require(strategyActive, "BaseStrategy: Strategy not active");
        _;
    }

    // ========== Constructor ==========
    
    /**
     * @notice Constructor
     * @param _token The address of the token used by the strategy.
     * @param _initialOwner The address of the initial owner.
     */
    constructor(
        address _token,
        address _initialOwner
    ) Ownable(_initialOwner) {
        require(_token != address(0), "BaseStrategy: Invalid token address");
        require(_initialOwner != address(0), "BaseStrategy: Invalid initial owner");
        
        token = IERC20(_token);
        strategyActive = true;
        lastUpdateTime = block.timestamp;
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, _initialOwner);
        _grantRole(Constants.DEFI_MANAGER_ROLE, _initialOwner);
        _grantRole(Constants.EMERGENCY_ROLE, _initialOwner);
    }

    // ========== Admin Functions ==========
    
    /**
     * @notice Set an authorized caller.
     * @param caller The address of the caller.
     * @param authorized Whether to authorize the caller.
     */
    function setAuthorizedCaller(address caller, bool authorized) 
        external 
        onlyRole(Constants.DEFI_MANAGER_ROLE) 
    {
        require(caller != address(0), "BaseStrategy: Invalid caller");
        authorizedCallers[caller] = authorized;
        emit AuthorizedCallerUpdated(caller, authorized);
    }

    /**
     * @notice Activate the strategy.
     */
    function activateStrategy() external onlyRole(Constants.DEFI_MANAGER_ROLE) {
        strategyActive = true;
        emit StrategyActivated();
        emit StrategyStatusChanged(true, "Strategy activated by admin");
    }

    /**
     * @notice Deactivate the strategy.
     * @param reason The reason for deactivation.
     */
    function deactivateStrategy(string memory reason) 
        external 
        onlyRole(Constants.DEFI_MANAGER_ROLE) 
    {
        strategyActive = false;
        emit StrategyDeactivated(reason);
        emit StrategyStatusChanged(false, reason);
    }

    /**
     * @notice Emergency pause the strategy.
     */
    function pause() external onlyRole(Constants.EMERGENCY_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the strategy.
     */
    function unpause() external onlyRole(Constants.EMERGENCY_ROLE) {
        _unpause();
    }

    // ========== IStrategy Implementation ==========
    
    /**
     * @notice Check if the strategy is available.
     */
    function isActive() public view override returns (bool) {
        return strategyActive && !paused();
    }

    /**
     * @notice Execute the investment strategy.
     * @param amount The amount to invest.
     */
    function invest(uint256 amount) 
        external 
        override
        onlyAuthorized 
        nonReentrant 
        whenNotPaused 
        whenActive 
        returns (bool success, uint256 actualAmount) 
    {
        require(amount > 0, "BaseStrategy: Amount must be positive");
        
        // Transfer token in
        token.safeTransferFrom(msg.sender, address(this), amount);
        
        // Call strategy-specific investment logic
        (success, actualAmount) = _executeInvest(amount);
        
        if (success) {
            totalInvested += actualAmount;
            totalFunds += actualAmount;
            lastUpdateTime = block.timestamp;
            
            emit Invested(msg.sender, amount, actualAmount);
        } else {
            // Investment failed, return tokens
            token.safeTransfer(msg.sender, amount);
        }
        
        return (success, actualAmount);
    }

    /**
     * @notice Exit the investment strategy.
     * @param amount The amount to exit.
     */
    function divest(uint256 amount) 
        external 
        override
        onlyAuthorized 
        nonReentrant 
        whenNotPaused 
        returns (bool success, uint256 actualAmount) 
    {
        require(amount > 0 || amount == 0, "BaseStrategy: Invalid amount");
        
        // If amount is 0, exit all funds
        uint256 divestAmount = amount == 0 ? totalFunds : amount;
        require(divestAmount <= totalFunds, "BaseStrategy: Insufficient funds");
        
        // Call strategy-specific exit logic
        (success, actualAmount) = _executeDivest(divestAmount);
        
        if (success) {
            totalInvested -= actualAmount;
            totalFunds -= actualAmount;
            lastUpdateTime = block.timestamp;
            
            // Transfer to caller
            token.safeTransfer(msg.sender, actualAmount);
            
            emit Divested(msg.sender, divestAmount, actualAmount);
        }
        
        return (success, actualAmount);
    }

    /**
     * @notice Harvest rewards.
     */
    function harvest() 
        external 
        override
        onlyAuthorized 
        nonReentrant 
        whenNotPaused 
        whenActive 
        returns (bool success, uint256 rewardAmount) 
    {
        // Call strategy-specific harvest logic
        (success, rewardAmount) = _executeHarvest();
        
        if (success && rewardAmount > 0) {
            lastUpdateTime = block.timestamp;
            
            // Transfer rewards to caller
            token.safeTransfer(msg.sender, rewardAmount);
            
            emit Harvested(msg.sender, rewardAmount);
        }
        
        return (success, rewardAmount);
    }

    // ========== Query Functions ==========
    
    /**
     * @notice Get the total amount invested in the strategy.
     */
    function getTotalInvested() external view override returns (uint256) {
        return totalInvested;
    }

    /**
     * @notice Get the current value of the strategy.
     */
    function getTotalValue() external view override returns (uint256) {
        return _calculateTotalValue();
    }

    /**
     * @notice Get the pending rewards.
     */
    function getPendingRewards() external view override returns (uint256) {
        return _calculatePendingRewards();
    }

    /**
     * @notice Estimate the exit cost.
     * @param amount The amount to exit.
     */
    function estimateExitCost(uint256 amount) external view override returns (uint256) {
        return _estimateExitCost(amount);
    }

    // ========== Abstract Functions - Subclasses must implement ==========
    
    /**
     * @notice Strategy-specific investment logic.
     * @param amount The amount to invest.
     * @return success Whether the investment was successful.
     * @return actualAmount The actual amount invested.
     */
    function _executeInvest(uint256 amount) internal virtual returns (bool success, uint256 actualAmount);
    
    /**
     * @notice Strategy-specific exit logic.
     * @param amount The amount to exit.
     * @return success Whether the exit was successful.
     * @return actualAmount The actual amount exited.
     */
    function _executeDivest(uint256 amount) internal virtual returns (bool success, uint256 actualAmount);
    
    /**
     * @notice Strategy-specific harvest logic.
     * @return success Whether the harvest was successful.
     * @return rewardAmount The amount of rewards harvested.
     */
    function _executeHarvest() internal virtual returns (bool success, uint256 rewardAmount);
    
    /**
     * @notice Calculate the current total value of the strategy.
     * @return totalValue The current total value.
     */
    function _calculateTotalValue() internal view virtual returns (uint256 totalValue);
    
    /**
     * @notice Calculate the pending rewards.
     * @return pendingRewards The pending rewards.
     */
    function _calculatePendingRewards() internal view virtual returns (uint256 pendingRewards);
    
    /**
     * @notice Estimate the exit cost.
     * @param amount The amount to exit.
     * @return exitCost The estimated exit cost.
     */
    function _estimateExitCost(uint256 amount) internal view virtual returns (uint256 exitCost);
    
    /**
     * @notice Get the strategy name.
     */
    function strategyName() public view virtual override returns (string memory);
    
    /**
     * @notice Get the strategy description.
     */
    function strategyDescription() public view virtual override returns (string memory);
    
    /**
     * @notice Get the strategy risk level.
     */
    function riskLevel() public view virtual override returns (uint8);
    
    /**
     * @notice Get the strategy APY.
     */
    function getAPY() public view virtual override returns (uint256);

    // ========== Emergency Functions ==========
    
    /**
     * @notice Emergency exit all funds.
     */
    function emergencyExit() external onlyRole(Constants.EMERGENCY_ROLE) whenPaused {
        if (totalFunds > 0) {
            (bool success, uint256 actualAmount) = _executeDivest(totalFunds);
            if (success) {
                totalInvested = 0;
                totalFunds = 0;
                // Funds remain in contract, awaiting admin processing
            }
        }
    }

    // ========== Interface Support Check ==========
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl)
        returns (bool)
    {
        return
            interfaceId == type(IStrategy).interfaceId ||
            super.supportsInterface(interfaceId);
    }
} 