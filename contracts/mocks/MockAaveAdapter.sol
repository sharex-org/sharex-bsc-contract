// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IDeFiProtocol.sol";

/**
 * @title MockAaveAdapter
 * @dev Mock AAVE adapter for testing purposes
 */
contract MockAaveAdapter is IDeFiProtocol {
    using SafeERC20 for IERC20;
    
    IERC20 public immutable token;
    address public immutable owner;
    
    mapping(address => uint256) private _deposits;
    uint256 private _totalDeposits;
    uint256 private _currentAPY = 500; // 5%
    bool private _isHealthy = true;
    string private _version = "1.0.0";
    
    event MockDeposit(address indexed user, uint256 amount);
    event MockWithdraw(address indexed user, uint256 amount);
    event MockAPYChanged(uint256 newAPY);
    
    constructor(address _token, address _owner) {
        token = IERC20(_token);
        owner = _owner;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    // ========== IDeFiProtocol Implementation ==========
    
    function protocolName() external pure override returns (string memory) {
        return "Mock AAVE";
    }
    
    function protocolVersion() external view override returns (string memory) {
        return _version;
    }
    
    function protocolDeposit(uint256 amount) external override returns (bool success) {
        require(amount > 0, "Invalid amount");
        
        token.safeTransferFrom(msg.sender, address(this), amount);
        _deposits[msg.sender] += amount;
        _totalDeposits += amount;
        
        emit MockDeposit(msg.sender, amount);
        emit ProtocolDeposit(msg.sender, amount);
        
        return true;
    }
    
    function protocolWithdraw(uint256 amount) external override returns (uint256 actualAmount) {
        require(amount > 0, "Invalid amount");
        require(_deposits[msg.sender] >= amount, "Insufficient balance");
        
        _deposits[msg.sender] -= amount;
        _totalDeposits -= amount;
        token.safeTransfer(msg.sender, amount);
        
        emit MockWithdraw(msg.sender, amount);
        emit ProtocolWithdraw(msg.sender, amount);
        
        return amount;
    }
    
    function getCurrentAPY() external view override returns (uint256) {
        return _currentAPY;
    }
    
    function isHealthy() external view override returns (bool) {
        return _isHealthy;
    }
    
    function getProtocolTotalAssets() external view override returns (uint256 totalAssets) {
        return _totalDeposits;
    }
    
    // ========== Additional Helper Functions ==========
    
    function getBalance(address user) external view returns (uint256) {
        return _deposits[user];
    }
    
    function getTotalDeposits() external view returns (uint256) {
        return _totalDeposits;
    }
    
    // ========== Test Helper Functions ==========
    
    function setAPY(uint256 newAPY) external onlyOwner {
        _currentAPY = newAPY;
        emit MockAPYChanged(newAPY);
    }
    
    function setHealthy(bool healthy) external onlyOwner {
        _isHealthy = healthy;
    }
    
    function setVersion(string memory newVersion) external onlyOwner {
        _version = newVersion;
    }
    
    function simulateYield(address user, uint256 yieldAmount) external onlyOwner {
        // Simulate earning yield
        _deposits[user] += yieldAmount;
        _totalDeposits += yieldAmount;
    }
    
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        if (balance > 0) {
            token.safeTransfer(owner, balance);
        }
    }
} 