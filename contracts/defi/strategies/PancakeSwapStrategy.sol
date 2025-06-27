// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BaseStrategy.sol";

// ========== Interface Definitions ==========

interface IPancakeV3Pool {
    function slot0() external view returns (
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
    function harvest(uint256 _tokenId, address _to) external returns (uint256 reward);
    function pendingCake(uint256 _tokenId) external view returns (uint256 reward);
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
    
    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }
    
    function mint(MintParams calldata params) external payable returns (
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );
    
    function collect(CollectParams calldata params) external payable returns (
        uint256 amount0,
        uint256 amount1
    );
    
    function decreaseLiquidity(
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 deadline
    ) external payable returns (uint256 amount0, uint256 amount1);
    
    function positions(uint256 tokenId) external view returns (
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
}

interface IMasterChefV3 {
    function deposit(uint256 _tokenId, address _to) external;
    function withdraw(uint256 _tokenId, address _to) external returns (uint256 reward);
    function harvest(uint256 _tokenId, address _to) external returns (uint256 reward);
    function pendingCake(uint256 _tokenId) external view returns (uint256 reward);
}

/**
 * @title PancakeSwapStrategy
 * @dev PancakeSwap V3 liquidity mining strategy.
 * @notice This is an example implementation to demonstrate integration with a DEX protocol.
 * @dev TODO: This strategy contains simplified logic and is not recommended for production use without further development.
 */
contract PancakeSwapStrategy is BaseStrategy {
    using SafeERC20 for IERC20;

    // ========== State Variables ==========
    
    /// @notice The paired token for USDT (e.g., BUSD).
    IERC20 public immutable pairedToken;
    
    /// @notice PancakeSwap V3 Position Manager.
    IPancakeV3NonfungiblePositionManager public immutable positionManager;
    
    /// @notice PancakeSwap V3 Pool.
    IPancakeV3Pool public immutable pool;
    
    /// @notice MasterChef V3 for farming.
    IMasterChefV3 public immutable masterChef;
    
    /// @notice The fee of the liquidity pool.
    uint24 public immutable poolFee;
    
    /// @notice The currently held NFT Position ID.
    uint256 public currentPositionId;
    
    /// @notice Price range settings (tick).
    int24 public tickLower;
    int24 public tickUpper;
    
    /// @notice Total harvested CAKE rewards.
    uint256 public totalCakeRewards;

    // ========== Events ==========
    
    event PositionMinted(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
    event PositionBurned(uint256 indexed tokenId, uint256 amount0, uint256 amount1);
    event FeesCollected(uint256 indexed tokenId, uint256 amount0, uint256 amount1);
    event CakeHarvested(uint256 indexed tokenId, uint256 cakeAmount);

    // ========== Constructor ==========
    
    /**
     * @notice Constructor
     * @param _token The address of the USDT token.
     * @param _pairedToken The address of the paired token (e.g., BUSD).
     * @param _positionManager The address of the PancakeSwap V3 Position Manager.
     * @param _pool The address of the PancakeSwap V3 Pool.
     * @param _masterChef The address of the MasterChef V3.
     * @param _poolFee The fee of the pool.
     * @param _initialOwner The address of the initial owner.
     */
    constructor(
        address _token,
        address _pairedToken,
        address _positionManager,
        address _pool,
        address _masterChef,
        uint24 _poolFee,
        address _initialOwner
    ) BaseStrategy(_token, _initialOwner) {
        require(_pairedToken != address(0), "PancakeSwapStrategy: Invalid paired token");
        require(_positionManager != address(0), "PancakeSwapStrategy: Invalid position manager");
        require(_pool != address(0), "PancakeSwapStrategy: Invalid pool");
        require(_masterChef != address(0), "PancakeSwapStrategy: Invalid master chef");
        
        pairedToken = IERC20(_pairedToken);
        positionManager = IPancakeV3NonfungiblePositionManager(_positionManager);
        pool = IPancakeV3Pool(_pool);
        masterChef = IMasterChefV3(_masterChef);
        poolFee = _poolFee;
        
        // Pre-approve tokens for the Position Manager
        token.forceApprove(_positionManager, type(uint256).max);
        pairedToken.forceApprove(_positionManager, type(uint256).max);
        
        // Set default price range. 
        // @dev TODO: This is a simplified approach. In a real scenario, this should be set dynamically based on the current price.
        tickLower = -60; // Approx -1%
        tickUpper = 60;  // Approx +1%
    }

    // ========== Strategy Info ==========
    
    /**
     * @notice Get the strategy name.
     */
    function strategyName() public pure override returns (string memory) {
        return "PancakeSwap V3 Liquidity Mining Strategy";
    }
    
    /**
     * @notice Get the strategy description.
     */
    function strategyDescription() public pure override returns (string memory) {
        return "Provides liquidity to PancakeSwap V3 USDT/BUSD pool and farms CAKE rewards";
    }
    
    /**
     * @notice Get the strategy risk level (1-5, 1 is the lowest risk).
     */
    function riskLevel() public pure override returns (uint8) {
        return 4; // Medium-high risk, includes impermanent loss risk.
    }

    // ========== Strategy Implementation ==========
    
    /**
     * @notice Execute providing liquidity.
     * @param amount The amount of USDT to invest.
     */
    function _executeInvest(uint256 amount) 
        internal 
        override 
        returns (bool success, uint256 actualAmount) 
    {
        // @dev TODO: Simplified implementation assuming 1:1 pairing.
        // In a real scenario, should be calculated based on the current price.
        uint256 pairedAmount = amount;
        
        // @dev TODO: Check paired token balance. This is a simplified check.
        // In a real scenario, it might require swapping tokens via a DEX.
        if (pairedToken.balanceOf(address(this)) < pairedAmount) {
            return (false, 0);
        }
        
        try positionManager.mint(
            IPancakeV3NonfungiblePositionManager.MintParams({
                token0: address(token) < address(pairedToken) ? address(token) : address(pairedToken),
                token1: address(token) < address(pairedToken) ? address(pairedToken) : address(token),
                fee: poolFee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: address(token) < address(pairedToken) ? amount : pairedAmount,
                amount1Desired: address(token) < address(pairedToken) ? pairedAmount : amount,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp + 300
            })
        ) returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        ) {
            currentPositionId = tokenId;
            
            // Deposit to MasterChef for farming
            masterChef.deposit(tokenId, address(this));
            
            emit PositionMinted(tokenId, liquidity, amount0, amount1);
            
            // Return the actual amount of USDT used
            uint256 actualUsdt = address(token) < address(pairedToken) ? amount0 : amount1;
            return (true, actualUsdt);
            
        } catch {
            return (false, 0);
        }
    }
    
    /**
     * @notice Execute liquidity withdrawal.
     * @param amount The amount to withdraw.
     */
    function _executeDivest(uint256 amount) 
        internal 
        override 
        returns (bool success, uint256 actualAmount) 
    {
        if (currentPositionId == 0) {
            return (false, 0);
        }
        
        try masterChef.withdraw(currentPositionId, address(this)) {
            // Get position information
            (,,,,,,,uint128 liquidity,,,,) = positionManager.positions(currentPositionId);
            
            if (liquidity == 0) {
                return (false, 0);
            }
            
            // Reduce liquidity (simplified, all withdrawn)
            (uint256 amount0, uint256 amount1) = positionManager.decreaseLiquidity(
                currentPositionId,
                liquidity,
                0,
                0,
                block.timestamp + 300
            );
            
            // Collect tokens
            positionManager.collect(
                IPancakeV3NonfungiblePositionManager.CollectParams({
                    tokenId: currentPositionId,
                    recipient: address(this),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                })
            );
            
            emit PositionBurned(currentPositionId, amount0, amount1);
            
            currentPositionId = 0;
            
            // Return the actual amount of USDT obtained
            uint256 actualUsdt = address(token) < address(pairedToken) ? amount0 : amount1;
            return (true, actualUsdt);
            
        } catch {
            return (false, 0);
        }
    }
    
    /**
     * @notice Harvest CAKE mining rewards and fees.
     */
    function _executeHarvest() 
        internal 
        override 
        returns (bool success, uint256 rewardAmount) 
    {
        if (currentPositionId == 0) {
            return (true, 0);
        }
        
        uint256 totalRewards = 0;
        
        try masterChef.harvest(currentPositionId, address(this)) returns (uint256 cakeReward) {
            totalCakeRewards += cakeReward;
            totalRewards += cakeReward; // Simplified: directly add CAKE reward
            
            emit CakeHarvested(currentPositionId, cakeReward);
            
            // Collect transaction fees
            (uint256 amount0, uint256 amount1) = positionManager.collect(
                IPancakeV3NonfungiblePositionManager.CollectParams({
                    tokenId: currentPositionId,
                    recipient: address(this),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                })
            );
            
            emit FeesCollected(currentPositionId, amount0, amount1);
            
            // Add USDT fees from fees to reward
            uint256 usdtFees = address(token) < address(pairedToken) ? amount0 : amount1;
            totalRewards += usdtFees;
            
            return (true, totalRewards);
            
        } catch {
            return (false, 0);
        }
    }

    // ========== Query Functions ==========
    
    /**
     * @notice Calculate the current total value of the strategy.
     */
    function _calculateTotalValue() internal view override returns (uint256) {
        if (currentPositionId == 0) {
            return 0;
        }
        
        // Simplified implementation: return the USDT balance in the contract as valuation
        // In a real scenario, should calculate the value of liquidity
        return token.balanceOf(address(this));
    }
    
    /**
     * @notice Calculate pending rewards.
     */
    function _calculatePendingRewards() internal view override returns (uint256) {
        if (currentPositionId == 0) {
            return 0;
        }
        
        try masterChef.pendingCake(currentPositionId) returns (uint256 pendingCake) {
            // Simplified processing: directly return CAKE amount
            // In a real scenario, should convert to USDT value
            return pendingCake;
        } catch {
            return 0;
        }
    }
    
    /**
     * @notice Estimate exit cost.
     * @param amount The amount to exit.
     */
    function _estimateExitCost(uint256 amount) internal view override returns (uint256) {
        // DEX exit may have slippage and impermanent loss
        // Simplified processing, return 1% cost
        return amount / 100;
    }
    
    /**
     * @notice Get annualized return rate (simplified implementation).
     */
    function getAPY() public view override returns (uint256) {
        // Should combine CAKE mining rewards and fee income to calculate
        // Simplified return fixed value
        return 1200; // 12%
    }

    // ========== PancakeSwap Specific Functions ==========
    
    /**
     * @notice Get current liquidity position information.
     */
    function getPositionInfo() external view returns (
        uint256 tokenId,
        uint128 liquidity,
        uint256 tokensOwed0,
        uint256 tokensOwed1
    ) {
        if (currentPositionId == 0) {
            return (0, 0, 0, 0);
        }
        
        (,,,,,,,liquidity,,tokensOwed0,tokensOwed1,) = positionManager.positions(currentPositionId);
        return (currentPositionId, liquidity, tokensOwed0, tokensOwed1);
    }
    
    /**
     * @notice Get pool information.
     */
    function getPoolInfo() external view returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint128 liquidity
    ) {
        (sqrtPriceX96, tick,,,,,) = pool.slot0();
        liquidity = pool.liquidity();
    }
    
    /**
     * @notice Get pending CAKE rewards.
     */
    function getPendingCakeRewards() external view returns (uint256) {
        if (currentPositionId == 0) {
            return 0;
        }
        return masterChef.pendingCake(currentPositionId);
    }

    // ========== Admin Functions ==========
    
    /**
     * @notice Set price range.
     * @param _tickLower Lower tick.
     * @param _tickUpper Upper tick.
     */
    function setPriceRange(int24 _tickLower, int24 _tickUpper) 
        external 
        onlyRole(Constants.DEFI_MANAGER_ROLE) 
    {
        require(_tickLower < _tickUpper, "PancakeSwapStrategy: Invalid tick range");
        tickLower = _tickLower;
        tickUpper = _tickUpper;
    }
    
    /**
     * @notice Emergency exit all liquidity.
     */
    function emergencyExitLiquidity() 
        external 
        onlyRole(Constants.EMERGENCY_ROLE) 
        whenPaused 
    {
        if (currentPositionId != 0) {
            _executeDivest(0); // All withdrawn
        }
    }
} 