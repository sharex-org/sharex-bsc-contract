// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IShareX.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IDeShareProtocol.sol";
import "../utils/Constants.sol";

/**
 * @title ShareX
 * @dev 核心ShareX合约，实现充电宝租借的支付逻辑
 */
contract ShareX is 
    IShareX, 
    Initializable,
    OwnableUpgradeable, 
    AccessControlUpgradeable, 
    ReentrancyGuardUpgradeable, 
    PausableUpgradeable,
    UUPSUpgradeable 
{
    using SafeERC20 for IERC20;

    // ===== 权限角色定义 =====
    bytes32 public constant SETTLER_ROLE = keccak256("SETTLER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // State variables
    IERC20 public usdt;
    IVault public depositVault;
    IDeShareProtocol public deShareProtocol;
    
    // Order management
    mapping(uint256 => Order) public orders;
    mapping(address => uint256[]) public userOrders;
    uint256 private _orderIdCounter;
    
    // Settlement details tracking
    mapping(uint256 => SettlementDetail) public settlements;
    
    // Deposit status tracking
    mapping(address => DepositStatus) public userDepositStatus;

    // Events are defined in IPaymentManager interface

    // ========== 构造函数禁用 ==========
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ========== 初始化函数 ==========
    
    /**
     * @dev 初始化函数
     * @param _usdt USDT代币地址
     * @param _depositVault 存款管理合约地址
     * @param _shareXVault ShareX存证合约地址
     * @param _owner 初始所有者地址
     */
    function initialize(
        address _usdt,
        address _depositVault,
        address _shareXVault,
        address _owner
    ) public initializer {
        require(_usdt != address(0), "ShareX: Invalid USDT address");
        require(_depositVault != address(0), "ShareX: Invalid DepositVault address");
        require(_shareXVault != address(0), "ShareX: Invalid ShareXVault address");
        require(_owner != address(0), "ShareX: Invalid owner address");
        
        __Ownable_init(_owner);
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        
        usdt = IERC20(_usdt);
        depositVault = IVault(_depositVault);
        deShareProtocol = IDeShareProtocol(_shareXVault);
        
        // 设置默认角色
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(SETTLER_ROLE, _owner);
        _grantRole(OPERATOR_ROLE, _owner);
        _grantRole(EMERGENCY_ROLE, _owner);
        _grantRole(UPGRADER_ROLE, _owner);
    }

    // ========== 升级授权 ==========
    
    /**
     * @notice 授权合约升级
     * @param newImplementation 新实现合约地址
     */
    function _authorizeUpgrade(address newImplementation) 
        internal 
        view
        override 
        onlyRole(UPGRADER_ROLE) 
    {
        require(newImplementation != address(0), "ShareX: Invalid implementation");
        require(newImplementation.code.length > 0, "ShareX: Invalid implementation");
    }

    // ==================== 押金检查功能 ====================

    /**
     * @dev 检查用户需要补充的押金数量
     * @param user 用户地址
     * @return 需要补充的押金数量
     */
    function checkDepositRequired(address user) public view override returns (uint256) {
        require(user != address(0), "ShareX: Invalid user address");
        
        // 获取用户在AAVE的余额
        uint256 aaveBalance = depositVault.getTotalBalance(user, address(usdt));
        
        // 计算需要补充的押金
        if (aaveBalance >= Constants.DEPOSIT_AMOUNT) {
            return 0;
        }
        
        return Constants.DEPOSIT_AMOUNT - aaveBalance;
    }

    /**
     * @dev 获取用户押金状态
     * @param user 用户地址
     * @return 押金状态信息
     */
    function getUserDepositStatus(address user) external view override returns (DepositStatus memory) {
        return userDepositStatus[user];
    }

    // ==================== 租借功能 ====================

    /**
     * @dev 租借充电宝
     * @param deviceId 设备ID（字符串）
     * @return orderId 订单ID
     */
    function rentPowerBank(string memory deviceId) external override nonReentrant whenNotPaused returns (uint256 orderId) {
        require(bytes(deviceId).length > 0, "ShareX: Invalid device ID");
        
        address user = msg.sender;
        
        // 检查需要补充的押金
        uint256 requiredDeposit = checkDepositRequired(user);
        uint256 paidDeposit = 0;
        
        // 如果需要补充押金，从用户转入USDT
        if (requiredDeposit > 0) {
            usdt.safeTransferFrom(user, address(this), requiredDeposit);
            paidDeposit = requiredDeposit;
            
            // 将补充的押金存入DepositVault（记录在用户名下）
            usdt.forceApprove(address(depositVault), requiredDeposit);
            depositVault.depositFor(user, address(usdt), requiredDeposit, true);
            
            // 更新用户押金状态
            userDepositStatus[user].totalSupplemented += requiredDeposit;
            userDepositStatus[user].lastSupplementTime = block.timestamp;
            
            emit DepositSupplemented(user, requiredDeposit, userDepositStatus[user].totalSupplemented);
        }
        
        // 创建订单
        orderId = ++_orderIdCounter;
        
        orders[orderId] = Order({
            id: orderId,
            user: user,
            deviceId: _stringToBytes32(deviceId),
            startTime: block.timestamp,
            paidDeposit: paidDeposit,
            isActive: true
        });
        
        userOrders[user].push(orderId);
        
        // 预留资金用于此订单
        depositVault.reserveFunds(user, address(usdt), Constants.DEPOSIT_AMOUNT, "powerbank_rental");
        
        // TODO: 记录到ShareXVault - 需要根据实际接口实现
        // deShareProtocol.recordRental(user, deviceId, Constants.REQUIRED_DEPOSIT, 0);
        // deShareProtocol.recordDeposit(user, paidDeposit, true);
        
        emit OrderCreated(orderId, user, orderId, paidDeposit, Constants.DEPOSIT_AMOUNT);
        
        return orderId;
    }

    /**
     * @dev 取消订单（归还设备但未使用）
     * @param orderId 订单ID
     */
    function cancelOrder(uint256 orderId) external override nonReentrant {
        require(orderId > 0 && orderId <= _orderIdCounter, "ShareX: Invalid order ID");
        
        Order storage order = orders[orderId];
        require(order.user == msg.sender, "ShareX: Not order owner");
        require(order.isActive, "ShareX: Order not active");
        
        // 标记订单为非活跃
        order.isActive = false;
        
        // 释放预留资金
        depositVault.releaseFunds(order.user, address(usdt), Constants.DEPOSIT_AMOUNT, "order_cancelled");
        
        // 退还补充的押金
        uint256 refundAmount = order.paidDeposit;
        if (refundAmount > 0) {
            depositVault.withdrawFor(order.user, address(usdt), refundAmount, order.user);
            
            // 更新用户押金状态
            userDepositStatus[order.user].totalSupplemented -= refundAmount;
        }
        
        emit OrderCancelled(orderId, order.user, refundAmount);
    }

    // ==================== 订单结算功能 ====================

    /**
     * @dev 结算订单（管理员调用）
     * @param orderId 订单ID
     * @param feeAmount 费用金额（由线下计算）
     */
    function settleOrder(uint256 orderId, uint256 feeAmount) external override onlyRole(SETTLER_ROLE) nonReentrant {
        require(orderId > 0 && orderId <= _orderIdCounter, "ShareX: Invalid order ID");
        require(feeAmount > 0, "ShareX: Fee amount must be greater than 0");
        
        Order storage order = orders[orderId];
        require(order.isActive, "ShareX: Order not active");
        
        address user = order.user;
        uint256 totalFee = feeAmount;
        uint256 fromPaidDeposit = 0;
        uint256 fromAAVE = 0;
        uint256 refundAmount = 0;
        
        // 按PRD简化扣费逻辑：先扣补充押金，不足从AAVE扣除
        
        // 步骤1：从补充的押金中扣费
        if (order.paidDeposit > 0) {
            if (totalFee <= order.paidDeposit) {
                // 补充押金足够支付全部费用
                fromPaidDeposit = totalFee;
                refundAmount = order.paidDeposit - totalFee;
                totalFee = 0;
            } else {
                // 补充押金不够，全部用于支付
                fromPaidDeposit = order.paidDeposit;
                totalFee -= order.paidDeposit;
            }
        }
        
        // 步骤2：不足部分从AAVE余额扣除
        if (totalFee > 0) {
            fromAAVE = totalFee;
            depositVault.deductFunds(user, address(usdt), totalFee, owner());
        }
        
        // 释放预留资金
        depositVault.releaseFunds(user, address(usdt), Constants.DEPOSIT_AMOUNT, "order_settled");
        
        // 如果有退款，返还给用户
        if (refundAmount > 0) {
            depositVault.withdrawFor(user, address(usdt), refundAmount, user);
            
            // 更新用户押金状态
            userDepositStatus[user].totalSupplemented -= refundAmount;
        }
        
        // 标记订单为完成
        order.isActive = false;
        
        // 记录结算详情
        settlements[orderId] = SettlementDetail({
            orderId: orderId,
            totalFee: feeAmount,
            fromPaidDeposit: fromPaidDeposit,
            fromAAVE: fromAAVE,
            refundAmount: refundAmount,
            settlementTime: block.timestamp
        });
        
        // TODO: 记录到ShareXVault - 需要根据实际接口实现
        // deShareProtocol.recordReturn(orderId, feeAmount);
        // if (refundAmount > 0) {
        //     deShareProtocol.recordDeposit(user, refundAmount, false); // 记录为提现
        // }
        
        emit OrderSettled(orderId, user, feeAmount, fromPaidDeposit, fromAAVE, refundAmount);
    }

    // ==================== 查询功能 ====================

    /**
     * @dev 获取订单信息
     * @param orderId 订单ID
     * @return 订单信息
     */
    function getOrder(uint256 orderId) external view override returns (Order memory) {
        require(orderId > 0 && orderId <= _orderIdCounter, "ShareX: Invalid order ID");
        return orders[orderId];
    }

    /**
     * @dev 获取用户的订单列表
     * @param user 用户地址
     * @return 订单ID数组
     */
    function getUserOrders(address user) external view override returns (uint256[] memory) {
        require(user != address(0), "ShareX: Invalid user address");
        return userOrders[user];
    }

    /**
     * @dev 获取用户的活跃订单
     * @param user 用户地址
     * @return 活跃订单ID数组
     */
    function getUserActiveOrders(address user) external view override returns (uint256[] memory) {
        require(user != address(0), "ShareX: Invalid user address");
        
        uint256[] storage userOrderList = userOrders[user];
        uint256 activeCount = 0;
        
        // 第一遍：计算活跃订单数量
        for (uint256 i = 0; i < userOrderList.length; i++) {
            if (orders[userOrderList[i]].isActive) {
                activeCount++;
            }
        }
        
        // 第二遍：收集活跃订单ID
        uint256[] memory activeOrders = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < userOrderList.length; i++) {
            if (orders[userOrderList[i]].isActive) {
                activeOrders[index] = userOrderList[i];
                index++;
            }
        }
        
        return activeOrders;
    }

    /**
     * @dev 获取结算详情
     * @param orderId 订单ID
     * @return 结算详情
     */
    function getSettlementDetail(uint256 orderId) external view override returns (SettlementDetail memory) {
        require(orderId > 0 && orderId <= _orderIdCounter, "ShareX: Invalid order ID");
        return settlements[orderId];
    }

    /**
     * @dev 获取总订单数
     * @return 总订单数
     */
    function getTotalOrderCount() external view override returns (uint256) {
        return _orderIdCounter;
    }

    // ==================== 管理员功能 ====================

    /**
     * @dev 更新DepositVault地址
     * @param _depositVault 新的DepositVault地址
     */
    function updateDepositVault(address _depositVault) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_depositVault != address(0), "ShareX: Invalid DepositVault address");
        depositVault = IVault(_depositVault);
    }

    /**
     * @dev 更新ShareXVault地址
     * @param _shareXVault 新的ShareXVault地址
     */
    function updateShareXVault(address _shareXVault) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_shareXVault != address(0), "ShareX: Invalid ShareXVault address");
        deShareProtocol = IDeShareProtocol(_shareXVault);
    }

    /**
     * @dev 暂停合约
     */
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    /**
     * @dev 恢复合约
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev 紧急提现（仅限管理员）
     * @param token 代币地址
     * @param amount 提现金额
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyRole(EMERGENCY_ROLE) {
        require(amount > 0, "ShareX: Amount must be greater than 0");
        IERC20(token).safeTransfer(owner(), amount);
    }
    
    /**
     * @dev 设置授权结算者
     */
    function grantSettlerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(SETTLER_ROLE, account);
    }
    
    /**
     * @dev 撤销结算者权限
     */
    function revokeSettlerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(SETTLER_ROLE, account);
    }

    // ==================== 辅助函数 ====================

    /**
     * @dev 将字符串转换为bytes32
     * @param source 源字符串
     * @return result bytes32结果
     */
    function _stringToBytes32(string memory source) internal pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }
        
        assembly {
            result := mload(add(source, 32))
        }
    }

    /**
     * @dev 将bytes32转换为字符串
     * @param _bytes32 源bytes32
     * @return 字符串结果
     */
    function _bytes32ToString(bytes32 _bytes32) internal pure returns (string memory) {
        uint8 i = 0;
        while(i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }

    // ==================== 查看函数 ====================

    /**
     * @dev 检查用户是否有活跃订单
     * @param user 用户地址
     * @return 是否有活跃订单
     */
    function hasActiveOrder(address user) external view returns (bool) {
        require(user != address(0), "ShareX: Invalid user address");
        
        uint256[] storage userOrderList = userOrders[user];
        for (uint256 i = 0; i < userOrderList.length; i++) {
            if (orders[userOrderList[i]].isActive) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev 获取用户订单统计
     * @param user 用户地址
     * @return totalOrders 总订单数
     * @return activeOrders 活跃订单数
     * @return completedOrders 已完成订单数
     */
    function getUserOrderStats(address user) external view returns (
        uint256 totalOrders,
        uint256 activeOrders,
        uint256 completedOrders
    ) {
        require(user != address(0), "ShareX: Invalid user address");
        
        uint256[] storage userOrderList = userOrders[user];
        totalOrders = userOrderList.length;
        
        for (uint256 i = 0; i < userOrderList.length; i++) {
            if (orders[userOrderList[i]].isActive) {
                activeOrders++;
            } else {
                completedOrders++;
            }
        }
    }
    
    // ===== AccessControl覆盖 =====
    
    /**
     * @notice 支持接口检查
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControlUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
} 