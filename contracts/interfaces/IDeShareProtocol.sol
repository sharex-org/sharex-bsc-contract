// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../utils/Constants.sol";

/**
 * @title IDeShareProtocol
 * @dev DeShare协议接口，管理充电宝设备信息和租借记录的区块链存证
 */
interface IDeShareProtocol {
    // ===== 结构体定义 =====
    
    /// @notice 充电宝设备信息
    struct Device {
        uint256 deviceId;           // 设备唯一ID
        string deviceCode;          // 设备编码（如二维码）
        address owner;              // 设备所有者
        string location;            // 设备位置信息
        bool isActive;              // 设备是否激活
        bool isAvailable;           // 设备是否可租借
        uint256 batteryCapacity;    // 电池容量(mAh)
        uint256 dailyRate;          // 日租金费率
        uint256 createdAt;          // 设备注册时间
        uint256 lastMaintenanceAt;  // 最后维护时间
    }
    
    /// @notice 租借订单信息
    struct RentalOrder {
        uint256 orderId;            // 订单ID
        uint256 deviceId;           // 设备ID
        address user;               // 租借用户
        uint256 depositAmount;      // 实际押金金额
        uint256 startTime;          // 开始时间
        uint256 endTime;            // 结束时间（为0表示进行中）
        uint256 totalAmount;        // 总费用金额
        Constants.OrderStatus status; // 订单状态
        string startLocation;       // 取用位置
        string endLocation;         // 归还位置
        uint256 createdAt;          // 订单创建时间
        uint256 settledAt;          // 订单结算时间
    }
    
    // ===== 事件定义 =====
    
    /**
     * @notice 设备注册事件
     * @param deviceId 设备ID
     * @param deviceCode 设备编码
     * @param owner 设备所有者
     * @param location 设备位置
     */
    event DeviceRegistered(
        uint256 indexed deviceId,
        string deviceCode,
        address indexed owner,
        string location
    );
    
    /**
     * @notice 设备状态更新事件
     * @param deviceId 设备ID
     * @param isActive 是否激活
     * @param isAvailable 是否可用
     */
    event DeviceStatusUpdated(
        uint256 indexed deviceId,
        bool isActive,
        bool isAvailable
    );
    
    /**
     * @notice 租借订单创建事件
     * @param orderId 订单ID
     * @param deviceId 设备ID
     * @param user 用户地址
     * @param depositAmount 押金金额
     */
    event RentalOrderCreated(
        uint256 indexed orderId,
        uint256 indexed deviceId,
        address indexed user,
        uint256 depositAmount
    );
    
    /**
     * @notice 租借订单结算事件
     * @param orderId 订单ID
     * @param totalAmount 总费用
     * @param status 最终状态
     */
    event RentalOrderSettled(
        uint256 indexed orderId,
        uint256 totalAmount,
        Constants.OrderStatus status
    );
    
    /**
     * @notice 设备位置更新事件
     * @param deviceId 设备ID
     * @param oldLocation 旧位置
     * @param newLocation 新位置
     */
    event DeviceLocationUpdated(
        uint256 indexed deviceId,
        string oldLocation,
        string newLocation
    );
    
    // ===== 错误定义 =====
    
    /// @notice 设备不存在
    error DeviceNotFound(uint256 deviceId);
    
    /// @notice 设备不可用
    error DeviceNotAvailable(uint256 deviceId);
    
    /// @notice 订单不存在
    error OrderNotFound(uint256 orderId);
    
    /// @notice 无权限操作设备
    error UnauthorizedDeviceOperation(uint256 deviceId, address caller);
    
    /// @notice 无权限操作订单
    error UnauthorizedOrderOperation(uint256 orderId, address caller);
    
    /// @notice 设备编码已存在
    error DeviceCodeAlreadyExists(string deviceCode);
    
    /// @notice 订单状态无效
    error InvalidOrderStatus(uint256 orderId, Constants.OrderStatus currentStatus);
    
    // ===== 设备管理接口 =====
    
    /**
     * @notice 注册新设备
     * @param deviceCode 设备编码
     * @param location 设备位置
     * @param batteryCapacity 电池容量
     * @param dailyRate 日租金费率
     * @return deviceId 设备ID
     */
    function registerDevice(
        string calldata deviceCode,
        string calldata location,
        uint256 batteryCapacity,
        uint256 dailyRate
    ) external returns (uint256 deviceId);
    
    /**
     * @notice 更新设备状态
     * @param deviceId 设备ID
     * @param isActive 是否激活
     * @param isAvailable 是否可用
     */
    function updateDeviceStatus(uint256 deviceId, bool isActive, bool isAvailable) external;
    
    /**
     * @notice 更新设备位置
     * @param deviceId 设备ID
     * @param newLocation 新位置
     */
    function updateDeviceLocation(uint256 deviceId, string calldata newLocation) external;
    
    /**
     * @notice 设备维护记录
     * @param deviceId 设备ID
     */
    function recordMaintenance(uint256 deviceId) external;
    
    // ===== 订单管理接口 =====
    
    /**
     * @notice 创建租借订单
     * @param deviceId 设备ID
     * @param user 租借用户
     * @param depositAmount 押金金额
     * @param startLocation 取用位置
     * @return orderId 订单ID
     */
    function createRentalOrder(
        uint256 deviceId,
        address user,
        uint256 depositAmount,
        string calldata startLocation
    ) external returns (uint256 orderId);
    
    /**
     * @notice 结算租借订单
     * @param orderId 订单ID
     * @param totalAmount 总费用
     * @param endLocation 归还位置
     * @param status 最终状态
     */
    function settleRentalOrder(
        uint256 orderId,
        uint256 totalAmount,
        string calldata endLocation,
        Constants.OrderStatus status
    ) external;
    
    /**
     * @notice 取消租借订单
     * @param orderId 订单ID
     */
    function cancelRentalOrder(uint256 orderId) external;
    
    // ===== 查询接口 =====
    
    /**
     * @notice 获取设备信息
     * @param deviceId 设备ID
     * @return device 设备信息
     */
    function getDevice(uint256 deviceId) external view returns (Device memory device);
    
    /**
     * @notice 根据设备编码获取设备信息
     * @param deviceCode 设备编码
     * @return device 设备信息
     */
    function getDeviceByCode(string calldata deviceCode) external view returns (Device memory device);
    
    /**
     * @notice 获取订单信息
     * @param orderId 订单ID
     * @return order 订单信息
     */
    function getRentalOrder(uint256 orderId) external view returns (RentalOrder memory order);
    
    /**
     * @notice 获取用户的租借历史
     * @param user 用户地址
     * @param offset 偏移量
     * @param limit 限制数量
     * @return orders 订单列表
     */
    function getUserRentalHistory(address user, uint256 offset, uint256 limit) 
        external view returns (RentalOrder[] memory orders);
    
    /**
     * @notice 获取设备的租借历史
     * @param deviceId 设备ID
     * @param offset 偏移量
     * @param limit 限制数量
     * @return orders 订单列表
     */
    function getDeviceRentalHistory(uint256 deviceId, uint256 offset, uint256 limit)
        external view returns (RentalOrder[] memory orders);
    
    /**
     * @notice 检查用户是否有进行中的订单
     * @param user 用户地址
     * @return hasActiveOrder 是否有进行中的订单
     * @return activeOrderId 进行中的订单ID（如果有）
     */
    function hasActiveRental(address user) external view returns (bool hasActiveOrder, uint256 activeOrderId);
    
    /**
     * @notice 获取下一个设备ID
     * @return 下一个设备ID
     */
    function getNextDeviceId() external view returns (uint256);
    
    /**
     * @notice 获取下一个订单ID
     * @return 下一个订单ID
     */
    function getNextOrderId() external view returns (uint256);
} 