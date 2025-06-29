// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title Constants
 * @dev Library containing system constants and role definitions
 */
library Constants {
    // ========== Role Definitions ==========

    /// @dev Default admin role - can manage all other roles
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /// @dev Operator role - can perform standard operations
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @dev DeFi manager role - can manage DeFi strategies and adapters
    bytes32 public constant DEFI_MANAGER_ROLE = keccak256("DEFI_MANAGER_ROLE");

    /// @dev Emergency role - can pause contracts and perform emergency actions
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    /// @dev Upgrader role - can upgrade contracts
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // ========== System Constants ==========

    /// @dev Maximum slippage tolerance in basis points (500 = 5%)
    uint256 public constant MAX_SLIPPAGE_BPS = 500;

    /// @dev Minimum investment amount to avoid dust
    uint256 public constant MIN_INVESTMENT_AMOUNT = 1e6; // 1 USDT (6 decimals)

    /// @dev Maximum number of positions per strategy
    uint256 public constant MAX_POSITIONS_PER_STRATEGY = 10;

    /// @dev Default deadline for transactions (5 minutes)
    uint256 public constant DEFAULT_DEADLINE_OFFSET = 300;

    /// @dev Basis points denominator (10000 = 100%)
    uint256 public constant BASIS_POINTS = 10000;

    /// @dev Maximum fee percentage in basis points (100 = 1%)
    uint256 public constant MAX_FEE_BPS = 100;

    // ========== PancakeSwap Constants ==========

    /// @dev Default pool fee for USDT/BUSD pair (0.01% = 100)
    uint24 public constant PANCAKE_DEFAULT_FEE = 100;

    /// @dev Default tick spacing for concentrated liquidity
    int24 public constant DEFAULT_TICK_SPACING = 1;

    /// @dev Default price range in ticks (±60 ticks ≈ ±1%)
    int24 public constant DEFAULT_TICK_RANGE = 60;
}
