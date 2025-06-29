// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IAdapter} from "./interfaces/IAdapter.sol";
import {IYieldVault} from "./interfaces/IYieldVault.sol";
import {Constants} from "./libraries/Constants.sol";

/**
 * @title YieldVault
 * @dev Main vault contract for yield generation through multiple DeFi adapters
 * @notice Manages user deposits and automatically diversifies across DeFi strategies
 */
contract YieldVault is IYieldVault, Initializable, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // ========== State Variables ==========

    /// @dev The underlying asset token (USDT)
    IERC20 private immutable _ASSET;

    /// @dev Array of active adapters
    address[] public adapters;

    /// @dev Mapping from adapter to its weight (in basis points)
    mapping(address adapter => uint256 weight) public adapterWeights;

    /// @dev Mapping to check if adapter is active
    mapping(address adapter => bool active) public isAdapterActive;

    /// @dev User vault shares
    mapping(address user => uint256 shares) public vaultShares;

    /// @dev Total vault shares issued
    uint256 public totalVaultShares;

    /// @dev Investment configuration
    uint256 public investmentRatio; // Percentage to invest (basis points)
    uint256 public minInvestmentAmount; // Minimum amount to trigger investment

    /// @dev Performance tracking
    uint256 public totalDeposits;
    uint256 public totalInvested;
    uint256 public totalRewardsHarvested;
    uint256 public lastRebalanceTime;

    // ========== Constructor ==========

    /**
     * @dev Constructor that disables initializers to prevent implementation initialization
     * @param assetAddress Address of the underlying asset token
     * @param admin Address that will receive admin roles
     */
    constructor(address assetAddress, address admin) {
        require(assetAddress != address(0), "YieldVault: Invalid asset");
        require(admin != address(0), "YieldVault: Invalid admin");

        _ASSET = IERC20(assetAddress);

        // Setup roles for implementation (not used when deployed behind proxy)
        _grantRole(Constants.DEFAULT_ADMIN_ROLE, admin);
        _grantRole(Constants.DEFI_MANAGER_ROLE, admin);
        _grantRole(Constants.OPERATOR_ROLE, admin);
        _grantRole(Constants.EMERGENCY_ROLE, admin);

        // Default configuration
        investmentRatio = 9000; // 90% investment ratio
        minInvestmentAmount = Constants.MIN_INVESTMENT_AMOUNT * 10;

        // Disable initializers for the implementation contract
        _disableInitializers();
    }

    /**
     * @dev Initialize the yield vault proxy
     * @param assetAddress Address of the underlying asset token
     * @param admin Address that will receive admin roles
     */
    function initialize(address assetAddress, address admin) external initializer {
        require(assetAddress != address(0), "YieldVault: Invalid asset");
        require(admin != address(0), "YieldVault: Invalid admin");

        // Note: _ASSET is immutable and set in constructor, not here

        // Setup roles for proxy
        _grantRole(Constants.DEFAULT_ADMIN_ROLE, admin);
        _grantRole(Constants.DEFI_MANAGER_ROLE, admin);
        _grantRole(Constants.OPERATOR_ROLE, admin);
        _grantRole(Constants.EMERGENCY_ROLE, admin);

        // Default configuration
        investmentRatio = 9000; // 90% investment ratio
        minInvestmentAmount = Constants.MIN_INVESTMENT_AMOUNT * 10;
    }

    // ========== Core Vault Functions ==========

    /**
     * @inheritdoc IYieldVault
     */
    function asset() external view override returns (IERC20) {
        return _ASSET;
    }

    /**
     * @inheritdoc IYieldVault
     */
    function balanceOf(address user) external view override returns (uint256) {
        if (totalVaultShares == 0) return 0;
        return vaultShares[user].mulDiv(totalAssets(), totalVaultShares, Math.Rounding.Floor);
    }

    /**
     * @inheritdoc IYieldVault
     */
    function deposit(uint256 amount, bool autoInvest)
        external
        override
        nonReentrant
        whenNotPaused
        returns (uint256 shares)
    {
        require(amount > 0, "YieldVault: Amount must be positive");
        require(amount >= Constants.MIN_INVESTMENT_AMOUNT, "YieldVault: Amount too small");

        // Transfer assets from user
        _ASSET.safeTransferFrom(msg.sender, address(this), amount);

        // Calculate vault shares to issue
        shares = _calculateVaultShares(amount);

        // Update user and total shares
        vaultShares[msg.sender] += shares;
        totalVaultShares += shares;
        totalDeposits += amount;

        // Auto-invest if requested
        if (autoInvest && adapters.length > 0) {
            _autoInvestFunds();
        }

        emit UserDeposited(msg.sender, amount, shares);
        return shares;
    }

    /**
     * @inheritdoc IYieldVault
     */
    function withdraw(uint256 shares)
        external
        override
        nonReentrant
        whenNotPaused
        returns (uint256 amount)
    {
        require(shares > 0, "YieldVault: Shares must be positive");
        require(vaultShares[msg.sender] >= shares, "YieldVault: Insufficient shares");

        // Calculate withdrawal amount
        amount = _calculateWithdrawalAmount(shares);

        // Check if we need to divest from adapters
        uint256 vaultBalance = _ASSET.balanceOf(address(this));
        if (vaultBalance < amount) {
            uint256 needed = amount - vaultBalance;
            _divestFromAdapters(needed);
        }

        // Update user shares and totals
        vaultShares[msg.sender] -= shares;
        totalVaultShares -= shares;
        if (totalDeposits >= amount) {
            totalDeposits -= amount;
        } else {
            totalDeposits = 0;
        }

        // Transfer assets to user
        _ASSET.safeTransfer(msg.sender, amount);

        emit UserWithdrawn(msg.sender, amount, shares);
        return amount;
    }

    /**
     * @inheritdoc IYieldVault
     */
    function harvestAllRewards()
        external
        override
        nonReentrant
        onlyRole(Constants.DEFI_MANAGER_ROLE)
        returns (uint256 totalRewards)
    {
        for (uint256 i = 0; i < adapters.length; i++) {
            if (isAdapterActive[adapters[i]]) {
                try IAdapter(adapters[i]).harvest() returns (uint256 rewards) {
                    totalRewards += rewards;
                    emit RewardsHarvested(adapters[i], rewards);
                } catch {
                    // Continue if harvest fails for one adapter
                }
            }
        }

        totalRewardsHarvested += totalRewards;
        return totalRewards;
    }

    /**
     * @inheritdoc IYieldVault
     */
    function rebalance() external override onlyRole(Constants.DEFI_MANAGER_ROLE) {
        _rebalanceAdapters();
        lastRebalanceTime = block.timestamp;
    }

    // ========== View Functions ==========

    /**
     * @inheritdoc IYieldVault
     */
    function totalAssets() public view override returns (uint256) {
        uint256 total = _ASSET.balanceOf(address(this)); // Idle funds

        // Add assets from all adapters
        for (uint256 i = 0; i < adapters.length; i++) {
            if (isAdapterActive[adapters[i]]) {
                total += IAdapter(adapters[i]).totalAssets();
            }
        }

        return total;
    }

    /**
     * @inheritdoc IYieldVault
     */
    function getVaultStats()
        external
        view
        override
        returns (
            uint256 totalDepositsAmount,
            uint256 totalInvestedAmount,
            uint256 totalSharesAmount,
            uint256 averageAPYValue
        )
    {
        totalDepositsAmount = totalDeposits;
        totalSharesAmount = totalVaultShares;

        // Calculate total invested across adapters
        for (uint256 i = 0; i < adapters.length; i++) {
            if (isAdapterActive[adapters[i]]) {
                totalInvestedAmount += IAdapter(adapters[i]).totalAssets();
            }
        }

        // Calculate weighted average APY
        averageAPYValue = _calculateWeightedAPY();
    }

    /**
     * @inheritdoc IYieldVault
     */
    function getActiveAdapters()
        external
        view
        override
        returns (address[] memory activeAdapterList, uint256[] memory weights)
    {
        // Count active adapters
        uint256 activeCount = 0;
        for (uint256 i = 0; i < adapters.length; i++) {
            if (isAdapterActive[adapters[i]]) {
                activeCount++;
            }
        }

        // Fill arrays
        activeAdapterList = new address[](activeCount);
        weights = new uint256[](activeCount);

        uint256 index = 0;
        for (uint256 i = 0; i < adapters.length; i++) {
            if (isAdapterActive[adapters[i]]) {
                activeAdapterList[index] = adapters[i];
                weights[index] = adapterWeights[adapters[i]];
                index++;
            }
        }
    }

    // ========== Adapter Management ==========

    /**
     * @notice Add a new adapter to the vault
     * @param adapter Address of the adapter contract
     * @param weight Weight for this adapter (in basis points)
     */
    function addAdapter(address adapter, uint256 weight)
        external
        onlyRole(Constants.DEFI_MANAGER_ROLE)
    {
        require(adapter != address(0), "YieldVault: Invalid adapter");
        require(!isAdapterActive[adapter], "YieldVault: Adapter already added");
        require(weight > 0, "YieldVault: Weight must be positive");

        adapters.push(adapter);
        adapterWeights[adapter] = weight;
        isAdapterActive[adapter] = true;

        // Approve adapter for token transfers
        _ASSET.forceApprove(adapter, type(uint256).max);

        emit AdapterAdded(adapter, weight);
    }

    /**
     * @notice Remove an adapter from the vault
     * @param adapter Address of the adapter to remove
     */
    function removeAdapter(address adapter) external onlyRole(Constants.DEFI_MANAGER_ROLE) {
        require(isAdapterActive[adapter], "YieldVault: Adapter not active");

        // Emergency exit from adapter
        try IAdapter(adapter).emergencyExit() {
            // Success
        } catch {
            // Continue even if emergency exit fails
        }

        // Mark as inactive and remove approval
        isAdapterActive[adapter] = false;
        adapterWeights[adapter] = 0;
        _ASSET.forceApprove(adapter, 0);

        emit AdapterRemoved(adapter);
    }

    /**
     * @notice Update adapter weight
     * @param adapter Address of the adapter
     * @param newWeight New weight for the adapter
     */
    function updateAdapterWeight(address adapter, uint256 newWeight)
        external
        onlyRole(Constants.DEFI_MANAGER_ROLE)
    {
        require(isAdapterActive[adapter], "YieldVault: Adapter not active");
        require(newWeight > 0, "YieldVault: Weight must be positive");

        uint256 oldWeight = adapterWeights[adapter];
        adapterWeights[adapter] = newWeight;

        emit AdapterWeightUpdated(adapter, oldWeight, newWeight);
    }

    // ========== Internal Functions ==========

    function _calculateVaultShares(uint256 amount) internal view returns (uint256) {
        if (totalVaultShares == 0 || totalAssets() == 0) {
            return amount; // 1:1 for first deposit
        }
        return amount.mulDiv(totalVaultShares, totalAssets(), Math.Rounding.Floor);
    }

    function _calculateWithdrawalAmount(uint256 shares) internal view returns (uint256) {
        if (totalVaultShares == 0) return 0;
        return shares.mulDiv(totalAssets(), totalVaultShares, Math.Rounding.Floor);
    }

    function _autoInvestFunds() internal {
        uint256 vaultBalance = _ASSET.balanceOf(address(this));
        if (vaultBalance < minInvestmentAmount) return;

        uint256 investAmount =
            vaultBalance.mulDiv(investmentRatio, Constants.BASIS_POINTS, Math.Rounding.Floor);

        if (investAmount >= minInvestmentAmount) {
            _distributeToAdapters(investAmount);
        }
    }

    function _distributeToAdapters(uint256 amount) internal {
        uint256 totalWeight = _getTotalAdapterWeights();
        if (totalWeight == 0) return;

        for (uint256 i = 0; i < adapters.length; i++) {
            address adapter = adapters[i];
            if (isAdapterActive[adapter]) {
                uint256 adapterAmount =
                    amount.mulDiv(adapterWeights[adapter], totalWeight, Math.Rounding.Floor);

                if (adapterAmount > 0) {
                    try IAdapter(adapter).deposit(adapterAmount) returns (uint256 shares) {
                        totalInvested += adapterAmount;
                        emit FundsInvested(adapter, adapterAmount, shares);
                    } catch {
                        // Continue if deposit fails for one adapter
                    }
                }
            }
        }
    }

    function _divestFromAdapters(uint256 needed) internal {
        uint256 remaining = needed;

        for (uint256 i = 0; i < adapters.length && remaining > 0; i++) {
            address adapter = adapters[i];
            if (isAdapterActive[adapter]) {
                uint256 adapterAssets = IAdapter(adapter).totalAssets();
                if (adapterAssets > 0) {
                    uint256 sharesToWithdraw =
                        IAdapter(adapter).convertToShares(Math.min(remaining, adapterAssets));

                    try IAdapter(adapter).withdraw(sharesToWithdraw) returns (uint256 amount) {
                        if (remaining >= amount) {
                            remaining -= amount;
                        } else {
                            remaining = 0;
                        }
                        if (totalInvested >= amount) {
                            totalInvested -= amount;
                        } else {
                            totalInvested = 0;
                        }
                        emit FundsDivested(adapter, sharesToWithdraw, amount);
                    } catch {
                        // Continue if withdrawal fails
                    }
                }
            }
        }
    }

    function _rebalanceAdapters() internal {
        // Simple rebalancing: withdraw all and redistribute
        for (uint256 i = 0; i < adapters.length; i++) {
            address adapter = adapters[i];
            if (isAdapterActive[adapter]) {
                uint256 adapterShares = IAdapter(adapter).totalShares();
                if (adapterShares > 0) {
                    try IAdapter(adapter).withdraw(adapterShares) {
                        // Success
                    } catch {
                        // Continue if withdrawal fails
                    }
                }
            }
        }

        // Redistribute available funds
        uint256 availableFunds = _ASSET.balanceOf(address(this));
        if (availableFunds >= minInvestmentAmount) {
            _distributeToAdapters(availableFunds);
        }
    }

    function _getTotalAdapterWeights() internal view returns (uint256) {
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < adapters.length; i++) {
            if (isAdapterActive[adapters[i]]) {
                totalWeight += adapterWeights[adapters[i]];
            }
        }
        return totalWeight;
    }

    function _calculateWeightedAPY() internal view returns (uint256) {
        uint256 totalWeight = 0;
        uint256 weightedAPY = 0;

        for (uint256 i = 0; i < adapters.length; i++) {
            address adapter = adapters[i];
            if (isAdapterActive[adapter]) {
                uint256 weight = adapterWeights[adapter];
                uint256 apy = IAdapter(adapter).getAPY();

                weightedAPY += apy.mulDiv(weight, Constants.BASIS_POINTS, Math.Rounding.Floor);
                totalWeight += weight;
            }
        }

        return totalWeight > 0
            ? weightedAPY.mulDiv(Constants.BASIS_POINTS, totalWeight, Math.Rounding.Floor)
            : 0;
    }

    // ========== Admin Functions ==========

    /**
     * @notice Update investment configuration
     * @param newInvestmentRatio New investment ratio in basis points
     * @param newMinInvestmentAmount New minimum investment amount
     */
    function updateInvestmentConfig(uint256 newInvestmentRatio, uint256 newMinInvestmentAmount)
        external
        onlyRole(Constants.DEFI_MANAGER_ROLE)
    {
        require(newInvestmentRatio <= Constants.BASIS_POINTS, "YieldVault: Invalid ratio");
        require(newMinInvestmentAmount > 0, "YieldVault: Invalid min amount");

        investmentRatio = newInvestmentRatio;
        minInvestmentAmount = newMinInvestmentAmount;

        emit InvestmentConfigUpdated(newInvestmentRatio, newMinInvestmentAmount);
    }

    /**
     * @notice Pause the vault
     */
    function pause() external onlyRole(Constants.EMERGENCY_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the vault
     */
    function unpause() external onlyRole(Constants.EMERGENCY_ROLE) {
        _unpause();
    }

    /**
     * @notice Emergency withdrawal from all adapters
     */
    function emergencyWithdrawAll() external onlyRole(Constants.EMERGENCY_ROLE) {
        for (uint256 i = 0; i < adapters.length; i++) {
            if (isAdapterActive[adapters[i]]) {
                try IAdapter(adapters[i]).emergencyExit() {
                    // Success
                } catch {
                    // Continue even if emergency exit fails
                }
            }
        }
    }
}
