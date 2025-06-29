// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IYieldVault
 * @dev Interface for the main yield generation vault
 * @notice Manages user deposits and automatically invests in DeFi strategies for yield
 */
interface IYieldVault {
    // ========== Events ==========

    event UserDeposited(address indexed user, uint256 amount, uint256 shares);
    event UserWithdrawn(address indexed user, uint256 amount, uint256 shares);
    event FundsInvested(address indexed adapter, uint256 amount, uint256 shares);
    event FundsDivested(address indexed adapter, uint256 shares, uint256 amount);
    event RewardsHarvested(address indexed adapter, uint256 amount);
    event AdapterAdded(address indexed adapter, uint256 weight);
    event AdapterRemoved(address indexed adapter);
    event AdapterWeightUpdated(address indexed adapter, uint256 oldWeight, uint256 newWeight);
    event InvestmentConfigUpdated(uint256 investmentRatio, uint256 minInvestmentAmount);
    event RewardDistributed(address indexed user, uint256 amount);

    // ========== Core Vault Functions ==========

    /**
     * @notice Deposit assets into the vault for yield generation
     * @param amount Amount to deposit
     * @param autoInvest Whether to automatically invest funds across adapters
     * @return shares Number of vault shares received
     */
    function deposit(uint256 amount, bool autoInvest) external returns (uint256 shares);

    /**
     * @notice Withdraw assets from the vault
     * @param shares Number of vault shares to redeem
     * @return amount Amount of assets received
     */
    function withdraw(uint256 shares) external returns (uint256 amount);

    /**
     * @notice Harvest rewards from all active adapters
     * @return totalRewards Total amount of rewards harvested
     */
    function harvestAllRewards() external returns (uint256 totalRewards);

    /**
     * @notice Rebalance investments across adapters based on weights
     */
    function rebalance() external;

    // ========== View Functions ==========

    /**
     * @notice Get the underlying asset token
     * @return asset The asset token address
     */
    function asset() external view returns (IERC20);

    /**
     * @notice Get user's vault balance
     * @param user User address
     * @return balance User's balance including accrued rewards
     */
    function balanceOf(address user) external view returns (uint256 balance);

    /**
     * @notice Get total assets under management
     * @return totalAssets Total assets across all adapters and vault
     */
    function totalAssets() external view returns (uint256 totalAssets);

    /**
     * @notice Get vault statistics
     * @return totalDeposits Total amount deposited by users
     * @return totalInvested Total amount invested across adapters
     * @return totalShares Total vault shares issued
     * @return averageAPY Weighted average APY across adapters
     */
    function getVaultStats()
        external
        view
        returns (
            uint256 totalDeposits,
            uint256 totalInvested,
            uint256 totalShares,
            uint256 averageAPY
        );

    /**
     * @notice Get list of active adapters with their allocations
     * @return adapters Array of adapter addresses
     * @return weights Array of corresponding weights
     */
    function getActiveAdapters()
        external
        view
        returns (address[] memory adapters, uint256[] memory weights);
}
