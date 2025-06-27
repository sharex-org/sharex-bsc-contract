// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IStrategy
 * @dev 投资策略接口，定义所有策略必须实现的标准功能
 */
interface IStrategy {
    // ========== 策略信息 ==========
    
    /**
     * @notice 获取策略名称
     * @return 策略名称
     */
    function strategyName() external view returns (string memory);
    
    /**
     * @notice 获取策略描述
     * @return 策略描述
     */
    function strategyDescription() external view returns (string memory);
    
    /**
     * @notice 获取策略风险等级 (1-5, 1最低风险)
     * @return 风险等级
     */
    function riskLevel() external view returns (uint8);
    
    /**
     * @notice 检查策略是否可用
     * @return 是否可用
     */
    function isActive() external view returns (bool);
    
    // ========== 策略执行 ==========
    
    /**
     * @notice 执行投资策略
     * @param amount 投资金额
     * @return success 是否成功
     * @return actualAmount 实际投资金额
     */
    function invest(uint256 amount) external returns (bool success, uint256 actualAmount);
    
    /**
     * @notice 退出投资策略
     * @param amount 退出金额 (0表示全部退出)
     * @return success 是否成功
     * @return actualAmount 实际退出金额
     */
    function divest(uint256 amount) external returns (bool success, uint256 actualAmount);
    
    /**
     * @notice 收获收益
     * @return success 是否成功
     * @return rewardAmount 收获的收益金额
     */
    function harvest() external returns (bool success, uint256 rewardAmount);
    
    // ========== 策略查询 ==========
    
    /**
     * @notice 获取策略总投资金额
     * @return totalInvested 总投资金额
     */
    function getTotalInvested() external view returns (uint256 totalInvested);
    
    /**
     * @notice 获取策略当前价值（包含收益）
     * @return totalValue 当前总价值
     */
    function getTotalValue() external view returns (uint256 totalValue);
    
    /**
     * @notice 获取策略收益率 (基数10000，如500表示5%)
     * @return apy 年化收益率
     */
    function getAPY() external view returns (uint256 apy);
    
    /**
     * @notice 获取可提取的收益
     * @return pendingRewards 待收获收益
     */
    function getPendingRewards() external view returns (uint256 pendingRewards);
    
    /**
     * @notice 估算退出成本（滑点、手续费等）
     * @param amount 退出金额
     * @return exitCost 退出成本
     */
    function estimateExitCost(uint256 amount) external view returns (uint256 exitCost);
    
    // ========== 事件定义 ==========
    
    /**
     * @notice 投资事件
     * @param user 用户地址
     * @param amount 投资金额
     * @param actualAmount 实际投资金额
     */
    event Invested(address indexed user, uint256 amount, uint256 actualAmount);
    
    /**
     * @notice 退出投资事件
     * @param user 用户地址
     * @param amount 退出金额
     * @param actualAmount 实际退出金额
     */
    event Divested(address indexed user, uint256 amount, uint256 actualAmount);
    
    /**
     * @notice 收获收益事件
     * @param user 用户地址
     * @param rewardAmount 收益金额
     */
    event Harvested(address indexed user, uint256 rewardAmount);
    
    /**
     * @notice 策略状态变更事件
     * @param isActive 新的激活状态
     * @param reason 变更原因
     */
    event StrategyStatusChanged(bool isActive, string reason);
} 