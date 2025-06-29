// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IAdapter
 * @dev Base interface for all DeFi protocol adapters
 * @notice Defines the standard interface for integrating with various DeFi protocols
 */
interface IAdapter {
    // ========== Events ==========

    event Invested(uint256 amount, uint256 shares);
    event Divested(uint256 shares, uint256 amount);
    event RewardsHarvested(uint256 amount);
    event EmergencyExit(uint256 amount);

    // ========== Core Functions ==========

    /**
     * @notice Deposit assets into the DeFi protocol
     * @param amount Amount of assets to deposit
     * @return shares Number of strategy shares received
     */
    function deposit(uint256 amount) external returns (uint256 shares);

    /**
     * @notice Withdraw assets from the DeFi protocol
     * @param shares Number of strategy shares to withdraw
     * @return amount Amount of assets received
     */
    function withdraw(uint256 shares) external returns (uint256 amount);

    /**
     * @notice Harvest rewards from the DeFi protocol
     * @return rewardAmount Amount of rewards harvested
     */
    function harvest() external returns (uint256 rewardAmount);

    /**
     * @notice Emergency withdrawal of all assets
     * @return amount Amount of assets withdrawn
     */
    function emergencyExit() external returns (uint256 amount);

    // ========== View Functions ==========

    /**
     * @notice Get the underlying asset token address
     * @return assetToken The asset token address
     */
    function asset() external view returns (address assetToken);

    /**
     * @notice Get the total amount of assets managed by this adapter
     * @return totalManagedAssets Total assets under management
     */
    function totalAssets() external view returns (uint256 totalManagedAssets);

    /**
     * @notice Get the total supply of strategy shares
     * @return totalStrategyShares Total strategy shares issued
     */
    function totalShares() external view returns (uint256 totalStrategyShares);

    /**
     * @notice Convert assets to strategy shares
     * @param assets Amount of assets
     * @return shares Equivalent number of strategy shares
     */
    function convertToShares(uint256 assets) external view returns (uint256 shares);

    /**
     * @notice Convert strategy shares to assets
     * @param shares Number of strategy shares
     * @return assets Equivalent amount of assets
     */
    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    /**
     * @notice Get the current APY (Annual Percentage Yield)
     * @return apy APY in basis points (e.g., 1200 = 12%)
     */
    function getAPY() external view returns (uint256 apy);

    /**
     * @notice Get pending rewards that can be harvested
     * @return pendingRewards Amount of pending rewards
     */
    function getPendingRewards() external view returns (uint256 pendingRewards);

    /**
     * @notice Get adapter metadata information
     * @return protocolName Name of the underlying protocol
     * @return strategyType Type of strategy (e.g., "Liquidity", "Lending", "Farming")
     * @return riskLevel Risk level (1-5, 1 being lowest risk)
     */
    function getAdapterInfo()
        external
        view
        returns (string memory protocolName, string memory strategyType, uint8 riskLevel);

    /**
     * @notice Check if the adapter is active and operational
     * @return isActive True if adapter can accept deposits/withdrawals
     */
    function isActive() external view returns (bool isActive);

    /**
     * @notice Get the maximum amount that can be deposited
     * @return maxDepositAmount Maximum deposit amount (0 if no limit)
     */
    function maxDeposit() external view returns (uint256 maxDepositAmount);

    /**
     * @notice Get the maximum amount that can be withdrawn
     * @return maxWithdrawAmount Maximum withdrawal amount
     */
    function maxWithdraw() external view returns (uint256 maxWithdrawAmount);
}
