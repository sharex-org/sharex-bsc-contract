// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IAdapter} from "./IAdapter.sol";

/**
 * @title ILiquidityAdapter
 * @dev Interface for liquidity provision adapters (AMM, DEX pools, etc.)
 * @notice Extends base adapter interface with liquidity-specific functions
 */
interface ILiquidityAdapter is IAdapter {
    // ========== Liquidity-Specific Events ==========

    event LiquidityAdded(uint256 amount0, uint256 amount1, uint256 liquidity);
    event LiquidityRemoved(uint256 liquidity, uint256 amount0, uint256 amount1);
    event FeesCollected(uint256 amount0, uint256 amount1);
    event PositionRebalanced(uint256 oldPositionId, uint256 newPositionId);

    // ========== Liquidity-Specific Functions ==========

    /**
     * @notice Get the paired token address (for LP pairs)
     * @return pairedToken Address of the paired token
     */
    function pairedToken() external view returns (address pairedToken);

    /**
     * @notice Get current pool information
     * @return poolAddress Address of the liquidity pool
     * @return fee Pool fee in basis points
     * @return token0 First token in the pair
     * @return token1 Second token in the pair
     */
    function getPoolInfo()
        external
        view
        returns (address poolAddress, uint24 fee, address token0, address token1);

    /**
     * @notice Get current position information
     * @return positionIds Array of active position IDs
     * @return liquidityAmounts Array of liquidity amounts per position
     * @return feeAccumulated Total fees accumulated across positions
     */
    function getPositionInfo()
        external
        view
        returns (
            uint256[] memory positionIds,
            uint256[] memory liquidityAmounts,
            uint256 feeAccumulated
        );

    /**
     * @notice Collect accumulated fees from positions
     * @return amount0 Amount of token0 fees collected
     * @return amount1 Amount of token1 fees collected
     */
    function collectFees() external returns (uint256 amount0, uint256 amount1);

    /**
     * @notice Rebalance liquidity positions based on current price
     * @param newLowerTick New lower tick for the position
     * @param newUpperTick New upper tick for the position
     * @return newPositionId ID of the new position created
     */
    function rebalancePosition(int24 newLowerTick, int24 newUpperTick)
        external
        returns (uint256 newPositionId);
}
