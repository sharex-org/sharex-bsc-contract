// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IPancakeSwapV3
 * @dev Interfaces for PancakeSwap V3 protocol integration
 */
interface IPancakeV3Pool {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );

    function liquidity() external view returns (uint128);
    function fee() external view returns (uint24);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function tickSpacing() external view returns (int24);
}

interface IPancakeV3NonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function mint(MintParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    function increaseLiquidity(IncreaseLiquidityParams calldata params)
        external
        payable
        returns (uint128 liquidity, uint256 amount0, uint256 amount1);

    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1);

    function collect(CollectParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1);

    function burn(uint256 tokenId) external payable;

    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    function ownerOf(uint256 tokenId) external view returns (address owner);
}

interface IMasterChefV3 {
    struct PoolInfo {
        uint256 allocPoint;
        address v3Pool;
        address token0;
        address token1;
        uint24 fee;
        uint256 totalLiquidity;
        uint256 totalBoostLiquidity;
    }

    function poolLength() external view returns (uint256);
    function poolInfo(uint256 pid) external view returns (PoolInfo memory);
    function v3PoolAddressPid(address poolAddress) external view returns (uint256);

    function deposit(uint256 tokenId, address to) external;
    function withdraw(uint256 tokenId, address to) external returns (uint256 reward);
    function harvest(uint256 tokenId, address to) external returns (uint256 reward);

    function pendingCake(uint256 tokenId) external view returns (uint256 reward);
    function balanceOf(address owner) external view returns (uint256);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
}

interface IPancakeV3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee)
        external
        view
        returns (address pool);
    function createPool(address tokenA, address tokenB, uint24 fee)
        external
        returns (address pool);
}

interface ISmartRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        returns (uint256 amountOut);
}
