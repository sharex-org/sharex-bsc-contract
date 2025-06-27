// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IVault
 * @dev 存款管理合约接口，处理用户资金存取和DeFi协议集成
 */
interface IVault {
    // ===== 结构体定义 =====
    
    /// @notice 用户存款信息
    struct UserDeposit {
        uint256 totalDeposited;     // 用户总存款
        uint256 defiBalance;        // DeFi协议中的余额（含收益）
        uint256 reservedAmount;     // 被预留的金额（用于押金）
        uint256 availableBalance;   // 可用余额
        uint256 lastUpdateTime;     // 最后更新时间
    }
    
    /// @notice 代币池状态
    struct TokenPool {
        address token;              // 代币地址
        uint256 totalDeposits;      // 总存款
        uint256 totalInDeFi;        // 在DeFi中的总额
        uint256 totalReserved;      // 总预留金额
        uint256 lastRebalanceTime;  // 最后重新平衡时间
        bool isActive;              // 是否激活
    }
    
    // ===== 事件定义 =====
    
    /**
     * @notice 用户存款事件
     * @param user 用户地址
     * @param token 代币地址
     * @param amount 存款金额
     * @param defiAmount 转入DeFi的金额
     */
    event UserDeposited(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 defiAmount
    );
    
    /**
     * @notice 用户提现事件
     * @param user 用户地址
     * @param token 代币地址
     * @param amount 提现金额
     * @param fromDefi DeFi提现金额
     */
    event UserWithdrawn(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 fromDefi
    );
    
    /**
     * @notice 资金预留事件
     * @param user 用户地址
     * @param token 代币地址
     * @param amount 预留金额
     * @param purpose 预留目的
     */
    event FundsReserved(
        address indexed user,
        address indexed token,
        uint256 amount,
        string purpose
    );
    
    /**
     * @notice 资金释放事件
     * @param user 用户地址
     * @param token 代币地址
     * @param amount 释放金额
     * @param purpose 释放目的
     */
    event FundsReleased(
        address indexed user,
        address indexed token,
        uint256 amount,
        string purpose
    );
    
    /**
     * @notice 池重新平衡事件
     * @param token 代币地址
     * @param totalInDeFi 总DeFi金额
     * @param newDefiAmount 新的DeFi金额
     */
    event PoolRebalanced(
        address indexed token,
        uint256 totalInDeFi,
        uint256 newDefiAmount
    );
    
    /**
     * @notice 收益分配事件
     * @param user 用户地址
     * @param token 代币地址
     * @param yieldAmount 收益金额
     */
    event YieldDistributed(
        address indexed user,
        address indexed token,
        uint256 yieldAmount
    );
    
    // ===== 错误定义 =====
    
    /// @notice 余额不足
    error InsufficientBalance(address user, uint256 requested, uint256 available);
    
    /// @notice 预留金额不足
    error InsufficientReservedFunds(address user, uint256 requested, uint256 reserved);
    
    /// @notice 不支持的代币
    error UnsupportedToken(address token);
    
    /// @notice 存款金额无效
    error InvalidDepositAmount(uint256 amount);
    
    /// @notice 提现金额无效
    error InvalidWithdrawAmount(uint256 amount);
    
    /// @notice 代币池未激活
    error TokenPoolNotActive(address token);
    
    /// @notice 重新平衡失败
    error RebalanceFailure(address token);
    
    // ===== 核心功能接口 =====
    
    /**
     * @notice 用户存款
     * @param token 代币地址
     * @param amount 存款金额
     * @param shouldDepositToDeFi 是否将资金投入DeFi（默认true）
     * @dev 用户需要先approve代币给本合约
     */
    function deposit(address token, uint256 amount, bool shouldDepositToDeFi) external;

    /**
     * @notice 代理存款（授权调用者为指定用户存款）
     * @param user 目标用户地址
     * @param token 代币地址
     * @param amount 存款金额
     * @param shouldDepositToDeFi 是否将资金投入DeFi
     * @dev 只能被授权合约调用，调用者需要先approve代币给本合约
     */
    function depositFor(address user, address token, uint256 amount, bool shouldDepositToDeFi) external;
    
    /**
     * @notice 用户提现
     * @param token 代币地址
     * @param amount 提现金额，使用type(uint256).max表示全部提现
     * @return actualAmount 实际提现金额
     */
    function withdraw(address token, uint256 amount) external returns (uint256 actualAmount);
    
    /**
     * @notice 代表用户提现（仅限授权合约）
     * @param user 用户地址
     * @param token 代币地址
     * @param amount 提现金额
     * @param to 接收地址
     * @return actualAmount 实际提现金额
     */
    function withdrawFor(address user, address token, uint256 amount, address to) external returns (uint256 actualAmount);
    
    /**
     * @notice 预留用户资金（用于押金等）
     * @param user 用户地址
     * @param token 代币地址
     * @param amount 预留金额
     * @param purpose 预留目的
     * @dev 只能被授权合约调用
     */
    function reserveFunds(address user, address token, uint256 amount, string calldata purpose) external;
    
    /**
     * @notice 释放预留资金
     * @param user 用户地址
     * @param token 代币地址
     * @param amount 释放金额
     * @param purpose 释放目的
     * @dev 只能被授权合约调用
     */
    function releaseFunds(address user, address token, uint256 amount, string calldata purpose) external;
    
    /**
     * @notice 从用户账户扣除资金（用于支付费用）
     * @param user 用户地址
     * @param token 代币地址
     * @param amount 扣除金额
     * @param to 接收地址
     * @return actualAmount 实际扣除金额
     * @dev 优先从预留资金扣除，再从可用余额扣除
     */
    function deductFunds(address user, address token, uint256 amount, address to) 
        external returns (uint256 actualAmount);
    
    // ===== DeFi集成接口 =====
    
    /**
     * @notice 将资金投入DeFi协议
     * @param token 代币地址
     * @param amount 投入金额
     */
    function depositToDeFi(address token, uint256 amount) external;
    
    /**
     * @notice 从DeFi协议提现
     * @param token 代币地址  
     * @param amount 提现金额
     * @return actualAmount 实际提现金额
     */
    function withdrawFromDeFi(address token, uint256 amount) external returns (uint256 actualAmount);
    
    /**
     * @notice 重新平衡资金池（管理DeFi资金比例）
     * @param token 代币地址
     */
    function rebalancePool(address token) external;
    
    /**
     * @notice 分配DeFi收益给用户
     * @param token 代币地址
     */
    function distributeYield(address token) external;
    
    // ===== 管理员功能接口 =====
    
    /**
     * @notice 添加支持的代币（仅管理员）
     * @param token 代币地址
     * @param isActive 是否激活
     */
    function addSupportedToken(address token, bool isActive) external;
    
    /**
     * @notice 设置代币池状态（仅管理员）
     * @param token 代币地址
     * @param isActive 是否激活
     */
    function setTokenPoolStatus(address token, bool isActive) external;
    
    /**
     * @notice 设置DeFi适配器（仅管理员）
     * @param newAdapter 新的适配器地址
     */
    function setDeFiAdapter(address newAdapter) external;
    
    /**
     * @notice 设置授权合约（仅管理员）
     * @param contractAddr 合约地址
     * @param authorized 是否授权
     */
    function setAuthorizedContract(address contractAddr, bool authorized) external;
    
    /**
     * @notice 紧急暂停（仅管理员）
     * @param paused 是否暂停
     */
    function setPaused(bool paused) external;
    
    /**
     * @notice 紧急提现（仅管理员）
     * @param token 代币地址
     * @param amount 提现金额
     * @param to 接收地址
     */
    function emergencyWithdraw(address token, uint256 amount, address to) external;
    
    // ===== 查询接口 =====
    
    /**
     * @notice 获取用户存款信息
     * @param user 用户地址
     * @param token 代币地址
     * @return deposit 用户存款信息
     */
    function getUserDeposit(address user, address token) 
        external view returns (UserDeposit memory deposit);
    
    /**
     * @notice 获取用户可用余额
     * @param user 用户地址
     * @param token 代币地址
     * @return 可用余额
     */
    function getAvailableBalance(address user, address token) external view returns (uint256);
    
    /**
     * @notice 获取用户总余额（包含DeFi收益）
     * @param user 用户地址
     * @param token 代币地址
     * @return 总余额
     */
    function getTotalBalance(address user, address token) external view returns (uint256);
    
    /**
     * @notice 获取代币池状态
     * @param token 代币地址
     * @return pool 代币池状态
     */
    function getTokenPool(address token) external view returns (TokenPool memory pool);
    
    /**
     * @notice 检查代币是否受支持
     * @param token 代币地址
     * @return 是否支持
     */
    function isSupportedToken(address token) external view returns (bool);
    
    /**
     * @notice 检查合约是否被授权
     * @param contractAddr 合约地址
     * @return 是否授权
     */
    function isAuthorizedContract(address contractAddr) external view returns (bool);
    
    // paused() function is inherited from Pausable contract
    
    /**
     * @notice 获取所有支持的代币列表
     * @return 代币地址列表
     */
    function getSupportedTokens() external view returns (address[] memory);
} 