// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Constants
 * @dev System constants definition, containing core configuration parameters for DeFi power bank rental platform
 */
library Constants {
    // ========== System Constants ==========
    
    // Deposit amount (100 USDT)
    uint256 public constant DEPOSIT_AMOUNT = 100 * 10**18;
    
    // Platform fee rate (1%)
    uint256 public constant PLATFORM_FEE_RATE = 100; // Base is 10000, i.e. 1%
    uint256 public constant FEE_BASE = 10000;
    
    // ========== BSC Network Addresses ==========
    
    // BSC mainnet chain ID
    uint256 public constant BSC_CHAIN_ID = 56;
    
    // USDT contract address (BSC mainnet)
    address public constant USDT_ADDRESS = 0x55d398326f99059fF775485246999027B3197955;
    
    // BUSD contract address (BSC mainnet) - Deprecated, but kept for legacy data
    address public constant BUSD_ADDRESS = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    
    // ========== AAVE V3 BSC Deployment Addresses ==========
    
    // AAVE V3 PoolAddressesProvider (BSC mainnet)
    // Note: This is a temporary address, needs to be updated to actual address after official deployment
    address public constant AAVE_POOL_ADDRESSES_PROVIDER = 0x2e8F4bdbE3d47d7d7DE490437AeA9915D930F1A3;
    
    // AAVE V3 Pool (BSC mainnet) - Dynamically obtained through PoolAddressesProvider
    // This is a preset address, should be obtained through getPool() in actual use
    address public constant AAVE_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    
    // ========== Permission Roles ==========
    
    // System administrator role
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    // Operator role (can execute daily operations)
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    
    // Settler role (can settle orders)
    bytes32 public constant SETTLER_ROLE = keccak256("SETTLER_ROLE");
    
    // DeFi manager role (can manage DeFi related operations)
    bytes32 public constant DEFI_MANAGER_ROLE = keccak256("DEFI_MANAGER_ROLE");
    
    // Emergency role (can pause system)
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    // ========== Business Configuration ==========
    
    // Maximum rental duration (24 hours)
    uint256 public constant MAX_RENTAL_DURATION = 24 * 3600;
    
    // Minimum rental duration (1 hour)
    uint256 public constant MIN_RENTAL_DURATION = 3600;
    
    // Overtime fee rate (2% per hour)
    uint256 public constant OVERTIME_FEE_RATE = 200; // Base is 10000, i.e. 2%
    
    // ===== Device Related Constants =====
    
    /// @notice USDC token contract address (BSC Testnet)  
    address public constant USDC_ADDRESS = 0x64544969ed7EBf5f083679233325356EbE738930;
    
    /// @notice WBNB token contract address (BSC Testnet)
    address public constant WBNB_ADDRESS = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;
    
    // ===== Order Status Enumeration =====
    
    /// @notice Device rental order status
    enum OrderStatus {
        PENDING,    // Pending confirmation
        ACTIVE,     // In progress
        COMPLETED,  // Completed
        CANCELLED   // Cancelled
    }
    
    // ===== Time Related Constants =====
    
    /// @notice Seconds per hour
    uint256 public constant SECONDS_PER_HOUR = 3600;
    
    /// @notice Seconds per day  
    uint256 public constant SECONDS_PER_DAY = 86400;
    
    /// @notice Device manager role identifier
    bytes32 public constant DEVICE_MANAGER_ROLE = keccak256("DEVICE_MANAGER_ROLE");
} 