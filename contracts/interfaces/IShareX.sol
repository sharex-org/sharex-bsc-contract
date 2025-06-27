// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../utils/Constants.sol";

/**
 * @title IShareX  
 * @dev Payment management contract interface, handling power bank rental fee settlement and deposit management
 */
interface IShareX {
    // ===== Struct Definitions =====
    
    /// @notice Order information
    struct Order {
        uint256 id;                 // Order ID
        address user;               // User address
        bytes32 deviceId;           // Device ID (stored as bytes32)
        uint256 startTime;          // Start time
        uint256 paidDeposit;        // Supplemented deposit amount
        bool isActive;              // Whether active
    }
    
    /// @notice Settlement detail information
    struct SettlementDetail {
        uint256 orderId;            // Order ID
        uint256 totalFee;           // Total fee amount
        uint256 fromPaidDeposit;    // Amount deducted from supplemented deposit
        uint256 fromAAVE;           // Amount deducted from AAVE balance
        uint256 refundAmount;       // Refund amount
        uint256 settlementTime;     // Settlement timestamp
    }
    
    /// @notice Deposit status information
    struct DepositStatus {
        uint256 totalSupplemented;  // Total supplemented deposit
        uint256 lastSupplementTime; // Last supplement time
    }
    
    // ===== Event Definitions =====
    
    /**
     * @notice Order creation event
     * @param orderId Order ID
     * @param user User address
     * @param deviceId Device ID
     * @param paidDeposit Supplemented deposit
     * @param requiredDeposit Required total deposit
     */
    event OrderCreated(
        uint256 indexed orderId,
        address indexed user,
        uint256 indexed deviceId,
        uint256 paidDeposit,
        uint256 requiredDeposit
    );
    
    /**
     * @notice Order settlement event
     * @param orderId Order ID
     * @param user User address
     * @param totalFee Total fee
     * @param fromPaidDeposit Amount deducted from supplemented deposit
     * @param fromAAVE Amount deducted from AAVE balance
     * @param refundAmount Refund amount
     */
    event OrderSettled(
        uint256 indexed orderId,
        address indexed user,
        uint256 totalFee,
        uint256 fromPaidDeposit,
        uint256 fromAAVE,
        uint256 refundAmount
    );
    
    /**
     * @notice Order cancellation event
     * @param orderId Order ID
     * @param user User address
     * @param refundAmount Refund amount
     */
    event OrderCancelled(
        uint256 indexed orderId,
        address indexed user,
        uint256 refundAmount
    );
    
    /**
     * @notice Deposit supplement event
     * @param user User address
     * @param amount Supplement amount
     * @param newTotalDeposit New total deposit
     */
    event DepositSupplemented(
        address indexed user,
        uint256 amount,
        uint256 newTotalDeposit
    );
    
    // ===== Core Function Interfaces =====
    
    /**
     * @notice Check the amount of deposit the user needs to supplement
     * @param user User address
     * @return Amount of deposit to be supplemented
     */
    function checkDepositRequired(address user) external view returns (uint256);
    
    /**
     * @notice Get user deposit status
     * @param user User address
     * @return Deposit status information
     */
    function getUserDepositStatus(address user) external view returns (DepositStatus memory);
    
    /**
     * @notice Rent power bank
     * @param deviceId Device ID
     * @return orderId Order ID
     */
    function rentPowerBank(string memory deviceId) external returns (uint256 orderId);
    
    /**
     * @notice Cancel order (return device but unused)
     * @param orderId Order ID
     */
    function cancelOrder(uint256 orderId) external;
    
    /**
     * @notice Settle order (called by admin)
     * @param orderId Order ID
     * @param feeAmount Fee amount (calculated offline)
     */
    function settleOrder(uint256 orderId, uint256 feeAmount) external;
    
    // ===== Query Function Interfaces =====
    
    /**
     * @notice Get order information
     * @param orderId Order ID
     * @return Order information
     */
    function getOrder(uint256 orderId) external view returns (Order memory);
    
    /**
     * @notice Get user's order list
     * @param user User address
     * @return Array of order IDs
     */
    function getUserOrders(address user) external view returns (uint256[] memory);
    
    /**
     * @notice Get user's active orders
     * @param user User address
     * @return Array of active order IDs
     */
    function getUserActiveOrders(address user) external view returns (uint256[] memory);
    
    /**
     * @notice Get settlement details
     * @param orderId Order ID
     * @return Settlement details
     */
    function getSettlementDetail(uint256 orderId) external view returns (SettlementDetail memory);
    
    /**
     * @notice Get total order count
     * @return Total order count
     */
    function getTotalOrderCount() external view returns (uint256);
} 