// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IDeFiProtocol
 * @dev Generic DeFi protocol interface to standardize interactions with different protocols.
 * 
 * All protocol adapters must implement this interface, including:
 * - AAVE
 * - Compound  
 * - Uniswap
 * - Curve
 * - PancakeSwap
 * etc.
 */
interface IDeFiProtocol {
    // ========== Events ==========
    
    /**
     * @notice Event for protocol deposit
     * @param caller The address of the caller
     * @param amount The amount deposited
     */
    event ProtocolDeposit(address indexed caller, uint256 amount);
    
    /**
     * @notice Event for protocol withdrawal
     * @param caller The address of the caller
     * @param amount The amount withdrawn
     */
    event ProtocolWithdraw(address indexed caller, uint256 amount);
    
    // ========== Protocol Information Interfaces ==========
    
    /**
     * @notice Get the protocol name
     * @return name The name of the protocol (e.g., "AAVE V3", "Compound V3", "Uniswap V3")
     */
    function protocolName() external view returns (string memory name);
    
    /**
     * @notice Get the protocol version
     * @return version The version of the protocol
     */
    function protocolVersion() external view returns (string memory version);
    
    /**
     * @notice Check if the protocol is running healthily
     * @return healthy Whether the protocol is healthy
     */
    function isHealthy() external view returns (bool healthy);
    
    /**
     * @notice Get the current APY/yield
     * @return apy The annualized percentage yield (basis 10000, e.g., 500 means 5%)
     */
    function getCurrentAPY() external view returns (uint256 apy);
    
    // ========== Core Operation Interfaces ==========
    
    /**
     * @notice Deposit funds into the protocol
     * @param amount The amount to deposit
     * @return success Whether the deposit was successful
     */
    function protocolDeposit(uint256 amount) external returns (bool success);
    
    /**
     * @notice Withdraw funds from the protocol
     * @param amount The amount to withdraw
     * @return actualAmount The actual amount withdrawn
     */
    function protocolWithdraw(uint256 amount) external returns (uint256 actualAmount);
    
    /**
     * @notice Get the total assets in the protocol
     * @return totalAssets The total amount of assets
     */
    function getProtocolTotalAssets() external view returns (uint256 totalAssets);
    
    // ========== Error Definitions ==========
    
    /// @notice Protocol operation failed
    error ProtocolOperationFailed(string operation, string reason);
    
    /// @notice Protocol is unhealthy
    error ProtocolUnhealthy(string protocolName);
    
    /// @notice Operation is not supported
    error UnsupportedOperation(string operation);
} 