// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IAdapter} from "../interfaces/IAdapter.sol";
import {Constants} from "../libraries/Constants.sol";

/**
 * @title BaseAdapter
 * @dev Abstract base contract for all DeFi protocol adapters
 * @notice Provides common functionality and access controls for adapters
 */
abstract contract BaseAdapter is IAdapter, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // ========== State Variables ==========

    /// @dev The underlying asset token
    IERC20 public immutable ASSET_TOKEN;

    /// @dev Total strategy shares issued
    uint256 public strategyShares;

    /// @dev Emergency mode flag
    bool public emergencyMode;

    // ========== Modifiers ==========

    modifier onlyVault() {
        require(
            hasRole(Constants.DEFI_MANAGER_ROLE, msg.sender), "BaseAdapter: Only vault can call"
        );
        _;
    }

    modifier notInEmergency() {
        require(!emergencyMode, "BaseAdapter: Emergency mode active");
        _;
    }

    // ========== Constructor ==========

    /**
     * @dev Initialize the base adapter
     * @param assetToken Address of the underlying asset
     * @param admin Address that will receive admin roles
     */
    constructor(address assetToken, address admin) {
        require(assetToken != address(0), "BaseAdapter: Invalid asset");
        require(admin != address(0), "BaseAdapter: Invalid admin");

        ASSET_TOKEN = IERC20(assetToken);

        // Setup roles
        _grantRole(Constants.DEFAULT_ADMIN_ROLE, admin);
        _grantRole(Constants.DEFI_MANAGER_ROLE, admin);
        _grantRole(Constants.EMERGENCY_ROLE, admin);
    }

    // ========== IAdapter Implementation ==========

    /**
     * @inheritdoc IAdapter
     */
    function asset() external view override returns (address) {
        return address(ASSET_TOKEN);
    }

    /**
     * @inheritdoc IAdapter
     */
    function totalShares() external view override returns (uint256) {
        return strategyShares;
    }

    /**
     * @inheritdoc IAdapter
     */
    function isActive() external view override returns (bool) {
        return !emergencyMode && !paused();
    }

    /**
     * @inheritdoc IAdapter
     */
    function maxDeposit() external view override returns (uint256) {
        if (emergencyMode || paused()) {
            return 0;
        }
        return _getMaxDeposit();
    }

    /**
     * @inheritdoc IAdapter
     */
    function maxWithdraw() external view override returns (uint256) {
        return totalAssets();
    }

    /**
     * @inheritdoc IAdapter
     */
    function convertToShares(uint256 assets) external view override returns (uint256 shares) {
        uint256 totalAssetBalance = totalAssets();
        if (totalAssetBalance == 0 || strategyShares == 0) {
            return assets;
        }
        return assets.mulDiv(strategyShares, totalAssetBalance, Math.Rounding.Floor);
    }

    /**
     * @inheritdoc IAdapter
     */
    function convertToAssets(uint256 shares) external view override returns (uint256 assets) {
        uint256 totalAssetBalance = totalAssets();
        if (totalAssetBalance == 0 || strategyShares == 0) {
            return shares;
        }
        return shares.mulDiv(totalAssetBalance, strategyShares, Math.Rounding.Floor);
    }

    // ========== Abstract Functions ==========

    /**
     * @dev Get the total assets managed by this adapter
     * @return Total assets under management
     */
    function totalAssets() public view virtual override returns (uint256);

    /**
     * @dev Internal deposit implementation
     * @param amount Amount to deposit
     * @return shares Strategy shares received
     */
    function _deposit(uint256 amount) internal virtual returns (uint256 shares);

    /**
     * @dev Internal withdraw implementation
     * @param shares Strategy shares to withdraw
     * @return amount Assets received
     */
    function _withdraw(uint256 shares) internal virtual returns (uint256 amount);

    /**
     * @dev Internal harvest implementation
     * @return rewardAmount Rewards harvested
     */
    function _harvest() internal virtual returns (uint256 rewardAmount);

    /**
     * @dev Internal emergency exit implementation
     * @return amount Assets withdrawn
     */
    function _emergencyExit() internal virtual returns (uint256 amount);

    /**
     * @dev Get the maximum deposit amount specific to the protocol
     * @return Maximum deposit amount
     */
    function _getMaxDeposit() internal view virtual returns (uint256) {
        return type(uint256).max;
    }

    // ========== Public Functions ==========

    /**
     * @inheritdoc IAdapter
     */
    function deposit(uint256 amount)
        external
        override
        onlyVault
        nonReentrant
        whenNotPaused
        notInEmergency
        returns (uint256 shares)
    {
        require(amount > 0, "BaseAdapter: Amount must be positive");
        require(amount >= Constants.MIN_INVESTMENT_AMOUNT, "BaseAdapter: Amount too small");

        // Transfer assets from vault
        ASSET_TOKEN.safeTransferFrom(msg.sender, address(this), amount);

        // Execute protocol-specific deposit
        shares = _deposit(amount);

        // Update total shares
        strategyShares += shares;

        emit Invested(amount, shares);
        return shares;
    }

    /**
     * @inheritdoc IAdapter
     */
    function withdraw(uint256 shares)
        external
        override
        onlyVault
        nonReentrant
        whenNotPaused
        returns (uint256 amount)
    {
        require(shares > 0, "BaseAdapter: Shares must be positive");
        require(shares <= strategyShares, "BaseAdapter: Insufficient shares");

        // Execute protocol-specific withdrawal
        amount = _withdraw(shares);

        // Update total shares
        strategyShares -= shares;

        // Transfer assets to vault
        ASSET_TOKEN.safeTransfer(msg.sender, amount);

        emit Divested(shares, amount);
        return amount;
    }

    /**
     * @inheritdoc IAdapter
     */
    function harvest()
        external
        override
        onlyVault
        nonReentrant
        whenNotPaused
        notInEmergency
        returns (uint256 rewardAmount)
    {
        rewardAmount = _harvest();

        if (rewardAmount > 0) {
            emit RewardsHarvested(rewardAmount);
        }

        return rewardAmount;
    }

    /**
     * @inheritdoc IAdapter
     */
    function emergencyExit()
        external
        override
        onlyRole(Constants.EMERGENCY_ROLE)
        nonReentrant
        returns (uint256 amount)
    {
        emergencyMode = true;

        amount = _emergencyExit();

        if (amount > 0) {
            // Transfer all available assets to admin
            ASSET_TOKEN.safeTransfer(msg.sender, amount);
        }

        emit EmergencyExit(amount);
        return amount;
    }

    // ========== Admin Functions ==========

    /**
     * @notice Pause the adapter
     */
    function pause() external onlyRole(Constants.EMERGENCY_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the adapter
     */
    function unpause() external onlyRole(Constants.EMERGENCY_ROLE) {
        _unpause();
    }

    /**
     * @notice Reset emergency mode
     */
    function resetEmergencyMode() external onlyRole(Constants.DEFAULT_ADMIN_ROLE) {
        emergencyMode = false;
    }
}
