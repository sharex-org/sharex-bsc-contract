// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IAdapter} from "../interfaces/IAdapter.sol";
import {ILiquidityAdapter} from "../interfaces/ILiquidityAdapter.sol";
import {
    IMasterChefV3,
    IPancakeV3Factory,
    IPancakeV3NonfungiblePositionManager,
    IPancakeV3Pool,
    ISmartRouter
} from "../interfaces/IPancakeSwapV3.sol";
import {Constants} from "../libraries/Constants.sol";
import {BaseAdapter} from "./BaseAdapter.sol";

/**
 * @title PancakeSwapV3Adapter
 * @dev Adapter for PancakeSwap V3 liquidity provision and farming
 * @notice Provides liquidity to PancakeSwap V3 pools and farms CAKE rewards
 */
contract PancakeSwapV3Adapter is BaseAdapter, ILiquidityAdapter {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // ========== Constants ==========

    /// @dev BSC Testnet contract addresses (updated from official docs)
    address private constant POSITION_MANAGER = 0x427bF5b37357632377eCbEC9de3626C71A5396c1;
    address private constant MASTER_CHEF_V3 = 0x4c650FB471fe4e0f476fD3437C3411B1122c4e3B;
    address private constant PANCAKE_FACTORY = 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865;
    address private constant SMART_ROUTER = 0x9a489505a00cE272eAa5e07Dba6491314CaE3796;

    /// @dev Token addresses on BSC Testnet
    address private constant USDT = 0x337610d27c682E347C9cD60BD4b3b107C9d34dDd;
    address private constant BUSD = 0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee;

    // ========== Immutable Variables ==========

    /// @dev The paired token for liquidity provision
    IERC20 private immutable _pairedToken;

    /// @dev PancakeSwap V3 contracts
    IPancakeV3NonfungiblePositionManager public immutable positionManager;
    IMasterChefV3 public immutable masterChef;
    IPancakeV3Factory public immutable factory;
    ISmartRouter public immutable smartRouter;

    /// @dev Pool information
    IPancakeV3Pool public immutable pool;
    uint24 public immutable poolFee;
    uint256 public immutable poolId;

    // ========== Events ==========

    event TokenSwapped(
        address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
    );
    event SwapFailed(
        address indexed tokenIn, address indexed tokenOut, uint256 amountIn, string reason
    );

    // ========== State Variables ==========

    /// @dev Active position management
    uint256[] private positionIds;
    mapping(uint256 => bool) private activePositions;

    /// @dev Strategy parameters
    int24 public tickLower;
    int24 public tickUpper;
    uint256 public slippageTolerance; // in basis points

    /// @dev Performance tracking
    uint256 public totalAssetsInvested;
    uint256 public totalRewardsHarvested;
    uint256 public lastHarvestTime;

    // ========== Constructor ==========

    /**
     * @dev Initialize the PancakeSwap V3 adapter
     * @param _admin Address that will receive admin roles
     * @param _poolFee Pool fee tier for the USDT/BUSD pair
     */
    constructor(address _admin, uint24 _poolFee) BaseAdapter(USDT, _admin) {
        require(_poolFee > 0, "PancakeSwapV3Adapter: Invalid pool fee");

        // Set immutable contracts
        _pairedToken = IERC20(BUSD);
        positionManager = IPancakeV3NonfungiblePositionManager(POSITION_MANAGER);
        masterChef = IMasterChefV3(MASTER_CHEF_V3);
        factory = IPancakeV3Factory(PANCAKE_FACTORY);
        smartRouter = ISmartRouter(SMART_ROUTER);

        // Initialize pool
        poolFee = _poolFee;
        pool = IPancakeV3Pool(factory.getPool(USDT, BUSD, _poolFee));
        require(address(pool) != address(0), "PancakeSwapV3Adapter: Pool not found");

        // Get pool ID from MasterChef
        poolId = masterChef.v3PoolAddressPid(address(pool));

        // Set default strategy parameters
        tickLower = -Constants.DEFAULT_TICK_RANGE;
        tickUpper = Constants.DEFAULT_TICK_RANGE;
        slippageTolerance = 100; // 1%

        // Approve tokens for contracts
        ASSET_TOKEN.forceApprove(POSITION_MANAGER, type(uint256).max);
        _pairedToken.forceApprove(POSITION_MANAGER, type(uint256).max);
        ASSET_TOKEN.forceApprove(SMART_ROUTER, type(uint256).max);
        _pairedToken.forceApprove(SMART_ROUTER, type(uint256).max);
    }

    // ========== BaseAdapter Implementation ==========

    /**
     * @inheritdoc BaseAdapter
     */
    function totalAssets() public view override(BaseAdapter, IAdapter) returns (uint256) {
        uint256 totalValue = 0;

        for (uint256 i = 0; i < positionIds.length; i++) {
            if (activePositions[positionIds[i]]) {
                totalValue += _getPositionValue(positionIds[i]);
            }
        }

        // Add any idle assets in the contract
        totalValue += ASSET_TOKEN.balanceOf(address(this));

        return totalValue;
    }

    /**
     * @inheritdoc BaseAdapter
     */
    function _deposit(uint256 amount) internal override returns (uint256 shares) {
        // Calculate paired amount needed (simplified 1:1 ratio for now)
        uint256 pairedAmount = amount;

        // Ensure we have enough paired assets or swap
        uint256 currentPairedBalance = _pairedToken.balanceOf(address(this));
        if (currentPairedBalance < pairedAmount) {
            uint256 swapAmount = pairedAmount - currentPairedBalance;
            _swapAssets(address(ASSET_TOKEN), address(_pairedToken), swapAmount);
        }

        // Add liquidity to pool
        shares = _addLiquidity(amount, pairedAmount);
        totalAssetsInvested += amount;

        return shares;
    }

    /**
     * @inheritdoc BaseAdapter
     */
    function _withdraw(uint256 shares) internal override returns (uint256 amount) {
        amount = _removeLiquidity(shares);

        if (amount <= totalAssetsInvested) {
            totalAssetsInvested -= amount;
        } else {
            totalAssetsInvested = 0;
        }

        return amount;
    }

    /**
     * @inheritdoc BaseAdapter
     */
    function _harvest() internal override returns (uint256 rewardAmount) {
        for (uint256 i = 0; i < positionIds.length; i++) {
            if (activePositions[positionIds[i]]) {
                try masterChef.harvest(positionIds[i], address(this)) returns (uint256 reward) {
                    rewardAmount += reward;
                } catch {
                    // Position might not be staked, continue with next position
                }

                // Also collect fees from the position
                try this.collectFeesFromSinglePosition(positionIds[i]) {
                    // Fees collected successfully
                } catch {
                    // Fee collection failed, continue
                }
            }
        }

        if (rewardAmount > 0) {
            totalRewardsHarvested += rewardAmount;
            lastHarvestTime = block.timestamp;
        }

        return rewardAmount;
    }

    /**
     * @dev Collect fees from a single position (external call for try-catch)
     */
    function collectFeesFromSinglePosition(uint256 positionId) external {
        require(msg.sender == address(this), "PancakeSwapV3Adapter: Only self");
        _collectFeesFromPosition(positionId);
    }

    /**
     * @inheritdoc BaseAdapter
     */
    function _emergencyExit() internal override returns (uint256 amount) {
        // Remove all liquidity positions
        for (uint256 i = 0; i < positionIds.length; i++) {
            if (activePositions[positionIds[i]]) {
                _removeSinglePosition(positionIds[i]);
            }
        }

        // Return all available assets
        amount = ASSET_TOKEN.balanceOf(address(this));
        return amount;
    }

    // ========== IAdapter Implementation ==========

    /**
     * @inheritdoc IAdapter
     */
    function getAPY() external view override returns (uint256 apy) {
        if (totalAssetsInvested == 0 || lastHarvestTime == 0) {
            return 1200; // Default 12% APY
        }

        uint256 timeElapsed = block.timestamp - lastHarvestTime;
        if (timeElapsed == 0) {
            return 1200;
        }

        // Annualized return calculation
        uint256 rewardRate = totalRewardsHarvested.mulDiv(
            Constants.BASIS_POINTS, totalAssetsInvested, Math.Rounding.Floor
        );
        return rewardRate.mulDiv(365 days, timeElapsed, Math.Rounding.Floor);
    }

    /**
     * @inheritdoc IAdapter
     */
    function getPendingRewards() external view override returns (uint256 pendingRewards) {
        for (uint256 i = 0; i < positionIds.length; i++) {
            if (activePositions[positionIds[i]]) {
                try masterChef.pendingCake(positionIds[i]) returns (uint256 pending) {
                    pendingRewards += pending;
                } catch {
                    // Position might not be staked, continue
                }
            }
        }
        return pendingRewards;
    }

    /**
     * @inheritdoc IAdapter
     */
    function getAdapterInfo()
        external
        pure
        override
        returns (string memory protocolName, string memory strategyType, uint8 riskLevel)
    {
        return ("PancakeSwap V3", "Liquidity Mining", 3);
    }

    // ========== ILiquidityAdapter Implementation ==========

    /**
     * @inheritdoc ILiquidityAdapter
     */
    function pairedToken() external view override returns (address) {
        return address(_pairedToken);
    }

    /**
     * @inheritdoc ILiquidityAdapter
     */
    function getPoolInfo()
        external
        view
        override
        returns (address poolAddress, uint24 fee, address token0, address token1)
    {
        return (address(pool), poolFee, pool.token0(), pool.token1());
    }

    /**
     * @inheritdoc ILiquidityAdapter
     */
    function getPositionInfo()
        external
        view
        override
        returns (
            uint256[] memory positionList,
            uint256[] memory liquidityAmounts,
            uint256 feeAccumulated
        )
    {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < positionIds.length; i++) {
            if (activePositions[positionIds[i]]) {
                activeCount++;
            }
        }

        positionList = new uint256[](activeCount);
        liquidityAmounts = new uint256[](activeCount);

        uint256 index = 0;
        for (uint256 i = 0; i < positionIds.length; i++) {
            if (activePositions[positionIds[i]]) {
                positionList[index] = positionIds[i];
                liquidityAmounts[index] = _getPositionLiquidity(positionIds[i]);
                index++;
            }
        }

        feeAccumulated = _getTotalFeesAccumulated();
        return (positionList, liquidityAmounts, feeAccumulated);
    }

    /**
     * @inheritdoc ILiquidityAdapter
     */
    function collectFees() external override onlyVault returns (uint256 amount0, uint256 amount1) {
        for (uint256 i = 0; i < positionIds.length; i++) {
            if (activePositions[positionIds[i]]) {
                (uint256 fees0, uint256 fees1) = _collectFeesFromPosition(positionIds[i]);
                amount0 += fees0;
                amount1 += fees1;
            }
        }

        emit FeesCollected(amount0, amount1);
        return (amount0, amount1);
    }

    /**
     * @inheritdoc ILiquidityAdapter
     */
    function rebalancePosition(int24 newLowerTick, int24 newUpperTick)
        external
        override
        onlyRole(Constants.DEFI_MANAGER_ROLE)
        returns (uint256 newPositionId)
    {
        require(newLowerTick < newUpperTick, "PancakeSwapV3Adapter: Invalid tick range");

        // Remove existing positions
        uint256 totalLiquidity = 0;
        for (uint256 i = 0; i < positionIds.length; i++) {
            if (activePositions[positionIds[i]]) {
                totalLiquidity += _removeSinglePosition(positionIds[i]);
            }
        }

        // Update tick range
        tickLower = newLowerTick;
        tickUpper = newUpperTick;

        // Create new position with collected assets
        if (totalLiquidity > 0) {
            uint256 assetBalance = ASSET_TOKEN.balanceOf(address(this));
            uint256 pairedBalance = _pairedToken.balanceOf(address(this));
            newPositionId = _createNewPosition(assetBalance, pairedBalance);
        }

        emit PositionRebalanced(0, newPositionId); // Using 0 as oldPositionId for simplicity
        return newPositionId;
    }

    // ========== Internal Functions ==========

    function _addLiquidity(uint256 amount0, uint256 amount1) internal returns (uint256 shares) {
        uint256 positionId = _createNewPosition(amount0, amount1);

        // Calculate shares based on the actual liquidity added
        uint256 liquidityAdded = _getPositionLiquidity(positionId);

        if (strategyShares == 0) {
            // First deposit: shares = liquidity
            shares = liquidityAdded;
        } else {
            // Subsequent deposits: shares proportional to liquidity added
            uint256 totalLiquidity = _getTotalLiquidity();
            if (totalLiquidity > 0) {
                shares = liquidityAdded.mulDiv(strategyShares, totalLiquidity, Math.Rounding.Floor);
            } else {
                shares = liquidityAdded;
            }
        }

        return shares;
    }

    /**
     * @dev Get total liquidity across all positions
     */
    function _getTotalLiquidity() internal view returns (uint256 totalLiquidity) {
        for (uint256 i = 0; i < positionIds.length; i++) {
            if (activePositions[positionIds[i]]) {
                totalLiquidity += _getPositionLiquidity(positionIds[i]);
            }
        }
        return totalLiquidity;
    }

    function _removeLiquidity(uint256 shares) internal returns (uint256 amount) {
        // Simplified: remove proportional liquidity from all positions
        uint256 proportionBPS =
            shares.mulDiv(Constants.BASIS_POINTS, strategyShares, Math.Rounding.Floor);

        for (uint256 i = 0; i < positionIds.length; i++) {
            if (activePositions[positionIds[i]]) {
                amount += _removeLiquidityFromPosition(positionIds[i], proportionBPS);
            }
        }

        return amount;
    }

    function _createNewPosition(uint256 amount0, uint256 amount1)
        internal
        returns (uint256 positionId)
    {
        require(amount0 > 0 || amount1 > 0, "PancakeSwapV3Adapter: Invalid amounts");

        // Ensure tokens are in correct order for the pool
        address token0 = pool.token0();
        address token1 = pool.token1();

        (uint256 amount0Desired, uint256 amount1Desired) =
            token0 == address(ASSET_TOKEN) ? (amount0, amount1) : (amount1, amount0);

        // Create mint parameters
        IPancakeV3NonfungiblePositionManager.MintParams memory params =
        IPancakeV3NonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: poolFee,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: amount0Desired,
            amount1Desired: amount1Desired,
            amount0Min: amount0Desired.mulDiv(
                Constants.BASIS_POINTS - slippageTolerance, Constants.BASIS_POINTS, Math.Rounding.Floor
            ),
            amount1Min: amount1Desired.mulDiv(
                Constants.BASIS_POINTS - slippageTolerance, Constants.BASIS_POINTS, Math.Rounding.Floor
            ),
            recipient: address(this),
            deadline: block.timestamp + 600 // 10 minutes
        });

        // Mint the position
        uint256 actualAmount0;
        uint256 actualAmount1;
        (positionId,, actualAmount0, actualAmount1) = positionManager.mint(params);

        // Add to tracking
        positionIds.push(positionId);
        activePositions[positionId] = true;

        // Stake in MasterChef V3 if pool is available
        try IERC721(address(positionManager)).approve(address(masterChef), positionId) {
            try masterChef.deposit(positionId, address(this)) {
                // Position successfully staked
            } catch {
                // Position created but not staked - still valid
            }
        } catch {
            // Approval failed but position still created
        }

        emit LiquidityAdded(actualAmount0, actualAmount1, actualAmount0 + actualAmount1);
        return positionId;
    }

    function _removeSinglePosition(uint256 positionId) internal returns (uint256 liquidity) {
        require(activePositions[positionId], "PancakeSwapV3Adapter: Position not active");

        // Try to withdraw from MasterChef V3 first
        try masterChef.withdraw(positionId, address(this)) {
            // Position withdrawn from staking
        } catch {
            // Position might not be staked, continue with removal
        }

        // Get position info to determine liquidity to remove
        (,,,,,,, uint128 positionLiquidity,,,,) = positionManager.positions(positionId);

        if (positionLiquidity > 0) {
            // Decrease liquidity parameters
            IPancakeV3NonfungiblePositionManager.DecreaseLiquidityParams memory decreaseParams =
            IPancakeV3NonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: positionId,
                liquidity: positionLiquidity,
                amount0Min: 0, // Accept any amount
                amount1Min: 0, // Accept any amount
                deadline: block.timestamp + 600
            });

            // Remove liquidity
            (uint256 amount0, uint256 amount1) = positionManager.decreaseLiquidity(decreaseParams);

            // Collect the tokens
            IPancakeV3NonfungiblePositionManager.CollectParams memory collectParams =
            IPancakeV3NonfungiblePositionManager.CollectParams({
                tokenId: positionId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

            positionManager.collect(collectParams);

            emit LiquidityRemoved(amount0, amount1, amount0 + amount1);
        }

        // Mark position as inactive
        activePositions[positionId] = false;

        return uint256(positionLiquidity);
    }

    function _removeLiquidityFromPosition(uint256 positionId, uint256 proportionBPS)
        internal
        returns (uint256 amount)
    {
        require(activePositions[positionId], "PancakeSwapV3Adapter: Position not active");
        require(proportionBPS <= Constants.BASIS_POINTS, "PancakeSwapV3Adapter: Invalid proportion");

        if (proportionBPS == 0) return 0;

        // Get current position liquidity
        (,,,,,,, uint128 positionLiquidity,,,,) = positionManager.positions(positionId);

        if (positionLiquidity == 0) return 0;

        // Calculate liquidity to remove
        uint128 liquidityToRemove = uint128(
            uint256(positionLiquidity).mulDiv(
                proportionBPS, Constants.BASIS_POINTS, Math.Rounding.Floor
            )
        );

        if (liquidityToRemove == 0) return 0;

        // Decrease liquidity parameters
        IPancakeV3NonfungiblePositionManager.DecreaseLiquidityParams memory decreaseParams =
        IPancakeV3NonfungiblePositionManager.DecreaseLiquidityParams({
            tokenId: positionId,
            liquidity: liquidityToRemove,
            amount0Min: 0, // Accept any amount due to slippage
            amount1Min: 0, // Accept any amount due to slippage
            deadline: block.timestamp + 600
        });

        // Remove partial liquidity
        (uint256 amount0, uint256 amount1) = positionManager.decreaseLiquidity(decreaseParams);

        // Collect the tokens
        IPancakeV3NonfungiblePositionManager.CollectParams memory collectParams =
        IPancakeV3NonfungiblePositionManager.CollectParams({
            tokenId: positionId,
            recipient: address(this),
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        });

        (uint256 collected0, uint256 collected1) = positionManager.collect(collectParams);

        // Convert to asset token equivalent (simplified)
        address token0 = pool.token0();
        amount = (token0 == address(ASSET_TOKEN)) ? collected0 : collected1;

        emit LiquidityRemoved(collected0, collected1, amount);
        return amount;
    }

    function _swapAssets(address tokenIn, address tokenOut, uint256 amountIn) internal {
        if (amountIn == 0 || tokenIn == tokenOut) return;

        // Ensure we have sufficient balance
        require(
            IERC20(tokenIn).balanceOf(address(this)) >= amountIn,
            "PancakeSwapV3Adapter: Insufficient balance"
        );

        // Calculate minimum amount out with slippage protection
        uint256 amountOutMin = _estimateSwapOutput(tokenIn, tokenOut, amountIn).mulDiv(
            Constants.BASIS_POINTS - slippageTolerance, Constants.BASIS_POINTS, Math.Rounding.Floor
        );

        // Prepare swap parameters
        ISmartRouter.ExactInputSingleParams memory params = ISmartRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: poolFee,
            recipient: address(this),
            amountIn: amountIn,
            amountOutMinimum: amountOutMin,
            sqrtPriceLimitX96: 0 // No price limit
        });

        // Execute the swap
        try smartRouter.exactInputSingle(params) returns (uint256 amountOut) {
            emit TokenSwapped(tokenIn, tokenOut, amountIn, amountOut);
        } catch Error(string memory reason) {
            // Log the error but don't revert to allow partial operations
            emit SwapFailed(tokenIn, tokenOut, amountIn, reason);
        } catch {
            // Log generic error
            emit SwapFailed(tokenIn, tokenOut, amountIn, "Unknown swap error");
        }
    }

    function _getPositionValue(uint256 positionId) internal view returns (uint256) {
        if (!activePositions[positionId]) return 0;

        // Get position details
        (
            ,
            ,
            ,
            ,
            ,
            int24 tickLowerPos,
            int24 tickUpperPos,
            uint128 liquidity,
            ,
            ,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = positionManager.positions(positionId);

        if (liquidity == 0) return 0;

        // Get current pool price and tick
        (uint160 sqrtPriceX96, int24 currentTick,,,,,) = pool.slot0();

        // Calculate amounts of tokens in the position
        (uint256 amount0, uint256 amount1) =
            _getAmountsForLiquidity(sqrtPriceX96, tickLowerPos, tickUpperPos, liquidity);

        // Add any owed tokens (fees)
        amount0 += uint256(tokensOwed0);
        amount1 += uint256(tokensOwed1);

        // Convert both amounts to asset token value
        address token0 = pool.token0();
        if (token0 == address(ASSET_TOKEN)) {
            // If asset token is token0, convert token1 to asset token
            uint256 token1InAssetToken =
                _estimateSwapOutput(address(_pairedToken), address(ASSET_TOKEN), amount1);
            return amount0 + token1InAssetToken;
        } else {
            // If asset token is token1, convert token0 to asset token
            uint256 token0InAssetToken =
                _estimateSwapOutput(address(_pairedToken), address(ASSET_TOKEN), amount0);
            return amount1 + token0InAssetToken;
        }
    }

    function _getPositionLiquidity(uint256 positionId) internal view returns (uint256) {
        if (!activePositions[positionId]) return 0;

        (,,,,,,, uint128 liquidity,,,,) = positionManager.positions(positionId);
        return uint256(liquidity);
    }

    /**
     * @dev Calculate token amounts for given liquidity and price range
     */
    function _getAmountsForLiquidity(
        uint160 sqrtPriceX96,
        int24 tickLowerParam,
        int24 tickUpperParam,
        uint128 liquidity
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        uint160 sqrtRatioAX96 = _getSqrtRatioAtTick(tickLowerParam);
        uint160 sqrtRatioBX96 = _getSqrtRatioAtTick(tickUpperParam);

        if (sqrtPriceX96 <= sqrtRatioAX96) {
            // Current price is below the range
            amount0 = _getAmount0ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity);
        } else if (sqrtPriceX96 < sqrtRatioBX96) {
            // Current price is within the range
            amount0 = _getAmount0ForLiquidity(sqrtPriceX96, sqrtRatioBX96, liquidity);
            amount1 = _getAmount1ForLiquidity(sqrtRatioAX96, sqrtPriceX96, liquidity);
        } else {
            // Current price is above the range
            amount1 = _getAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity);
        }
    }

    /**
     * @dev Get sqrt ratio at tick (simplified version)
     */
    function _getSqrtRatioAtTick(int24 tick) internal pure returns (uint160 sqrtPriceX96) {
        // Simplified calculation - in production, use TickMath library
        // This is an approximation for demonstration
        uint256 absTick = tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick));

        // Very simplified approximation - should use proper TickMath
        if (tick >= 0) {
            sqrtPriceX96 = uint160((1 << 96) * (1001 ** (absTick / 2)) / (1000 ** (absTick / 2)));
        } else {
            sqrtPriceX96 = uint160((1 << 96) * (1000 ** (absTick / 2)) / (1001 ** (absTick / 2)));
        }
    }

    /**
     * @dev Calculate amount0 for given liquidity and price range
     */
    function _getAmount0ForLiquidity(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount0) {
        if (sqrtRatioAX96 > sqrtRatioBX96) {
            (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        }

        return uint256(liquidity).mulDiv(
            sqrtRatioBX96 - sqrtRatioAX96, sqrtRatioBX96, Math.Rounding.Floor
        ).mulDiv(1, sqrtRatioAX96, Math.Rounding.Floor);
    }

    /**
     * @dev Calculate amount1 for given liquidity and price range
     */
    function _getAmount1ForLiquidity(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount1) {
        if (sqrtRatioAX96 > sqrtRatioBX96) {
            (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        }

        return
            uint256(liquidity).mulDiv(sqrtRatioBX96 - sqrtRatioAX96, 1 << 96, Math.Rounding.Floor);
    }

    /**
     * @dev Estimate swap output (simplified)
     */
    function _estimateSwapOutput(address tokenIn, address tokenOut, uint256 amountIn)
        internal
        view
        returns (uint256 amountOut)
    {
        if (amountIn == 0) return 0;

        // Simplified 1:1 estimation - in production, use proper price oracle or quoter
        // This should be replaced with actual price calculation
        return amountIn;
    }

    function _getTotalFeesAccumulated() internal view returns (uint256) {
        uint256 totalFees = 0;

        for (uint256 i = 0; i < positionIds.length; i++) {
            if (activePositions[positionIds[i]]) {
                (,,,,,,,,,, uint128 tokensOwed0, uint128 tokensOwed1) =
                    positionManager.positions(positionIds[i]);

                // Convert fees to asset token equivalent
                address token0 = pool.token0();
                if (token0 == address(ASSET_TOKEN)) {
                    totalFees += uint256(tokensOwed0);
                    totalFees += _estimateSwapOutput(
                        address(_pairedToken), address(ASSET_TOKEN), uint256(tokensOwed1)
                    );
                } else {
                    totalFees += uint256(tokensOwed1);
                    totalFees += _estimateSwapOutput(
                        address(_pairedToken), address(ASSET_TOKEN), uint256(tokensOwed0)
                    );
                }
            }
        }

        return totalFees;
    }

    function _collectFeesFromPosition(uint256 positionId) internal returns (uint256, uint256) {
        require(activePositions[positionId], "PancakeSwapV3Adapter: Position not active");

        // Prepare collect parameters to collect all available fees
        IPancakeV3NonfungiblePositionManager.CollectParams memory params =
        IPancakeV3NonfungiblePositionManager.CollectParams({
            tokenId: positionId,
            recipient: address(this),
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        });

        // Collect fees
        (uint256 amount0, uint256 amount1) = positionManager.collect(params);

        return (amount0, amount1);
    }
}
