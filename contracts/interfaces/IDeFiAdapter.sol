// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IDeFiAdapter
 * @dev AAVE V3协议适配器接口，提供统一的DeFi操作接口
 */
interface IDeFiAdapter {
    // ========== 事件定义 ==========
    
    /**
     * @notice 用户存款事件
     * @param user 用户地址
     * @param amount 存款金额
     * @param shares 获得的份额
     */
    event DepositToAave(address indexed user, uint256 amount, uint256 shares);
    
    /**
     * @notice 用户提现事件
     * @param user 用户地址
     * @param amount 提现金额
     * @param shares 使用的份额
     */
    event WithdrawFromAave(address indexed user, uint256 amount, uint256 shares);
    
    /**
     * @notice 资金预留事件
     * @param caller 调用者地址
     * @param user 用户地址
     * @param amount 预留金额
     */
    event FundsReserved(address indexed caller, address indexed user, uint256 amount);
    
    /**
     * @notice 资金释放事件
     * @param caller 调用者地址
     * @param user 用户地址
     * @param amount 释放金额
     */
    event FundsReleased(address indexed caller, address indexed user, uint256 amount);
    
    // ========== 错误定义 ==========
    
    /// @notice 不支持的代币
    error UnsupportedToken(address token);
    
    /// @notice 存款金额无效
    error InvalidDepositAmount(uint256 amount);
    
    /// @notice 提现金额无效  
    error InvalidWithdrawAmount(uint256 amount);
    
    /// @notice 余额不足
    error InsufficientBalance(address user, uint256 requested, uint256 available);
    
    /// @notice DeFi协议操作失败
    error DeFiOperationFailed(string operation);
    
    // ========== 核心功能接口 ==========
    
    /**
     * @notice 存款到AAVE V3协议
     * @param amount 存款金额
     * @return shares 获得的份额
     */
    function deposit(uint256 amount) external returns (uint256 shares);
    
    /**
     * @notice 从AAVE V3协议提现
     * @param shares 要提现的份额
     * @return amount 实际提现金额
     */
    function withdraw(uint256 shares) external returns (uint256 amount);
    
    /**
     * @notice 预留用户资金
     * @param user 用户地址
     * @param amount 预留金额
     * @dev 只能被授权合约调用
     */
    function reserveFunds(address user, uint256 amount) external;
    
    /**
     * @notice 释放预留资金
     * @param user 用户地址
     * @param amount 释放金额
     * @dev 只能被授权合约调用
     */
    function releaseFunds(address user, uint256 amount) external;
    
    /**
     * @notice 从用户余额中扣费
     * @param user 用户地址
     * @param amount 扣费金额
     * @return success 是否成功
     * @dev 只能被授权合约调用
     */
    function deductFromBalance(address user, uint256 amount) external returns (bool success);
    
    // ========== 查询接口 ==========
    
    /**
     * @notice 获取用户余额（包含收益）
     * @param user 用户地址
     * @return balance 用户余额
     */
    function getBalance(address user) external view returns (uint256 balance);
    
    /**
     * @notice 获取用户预留资金
     * @param user 用户地址
     * @return reserved 预留金额
     */
    function getReservedFunds(address user) external view returns (uint256 reserved);
    
    /**
     * @notice 将资产金额转换为份额
     * @param assets 资产金额
     * @return shares 份额
     */
    function convertToShares(uint256 assets) external view returns (uint256 shares);
    
    /**
     * @notice 将份额转换为资产金额
     * @param shares 份额
     * @return assets 资产金额
     */
    function convertToAssets(uint256 shares) external view returns (uint256 assets);
} 