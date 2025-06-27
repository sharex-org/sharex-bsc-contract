// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title MockDeShareProtocol
 * @dev Simplified ShareXVault contract for testing
 */
contract MockDeShareProtocol is AccessControl {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    struct AssetRecord {
        uint256 amount;
        string description;
        uint256 timestamp;
    }

    mapping(address => uint256) private userAssets;
    mapping(address => uint256) private userYield;
    mapping(address => AssetRecord[]) private assetRecords;
    
    uint256 public userShare = 6000; // 60%
    uint256 public platformShare = 3000; // 30%
    uint256 public riskReserveShare = 1000; // 10%
    
    address public feeReceiver;
    bool private initialized;

    event AssetRecorded(address indexed user, uint256 amount, string description);
    event DeFiYieldUpdated(address indexed user, uint256 amount, string description);

    constructor() {
        // Empty constructor, using initialize pattern
    }

    function initialize(address admin) external {
        require(!initialized, "Already initialized");
        require(admin != address(0), "Invalid admin address");
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        
        initialized = true;
    }

    function recordAsset(uint256 amount, string memory description) external {
        require(amount > 0, "Amount must be greater than 0");
        require(bytes(description).length > 0, "Description cannot be empty");

        userAssets[msg.sender] += amount;
        assetRecords[msg.sender].push(AssetRecord({
            amount: amount,
            description: description,
            timestamp: block.timestamp
        }));

        emit AssetRecorded(msg.sender, amount, description);
    }

    function updateDeFiYield(address user, uint256 amount, string memory description) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(user != address(0), "Invalid user address");
        require(amount > 0, "Amount must be greater than 0");

        userAssets[user] += amount;
        assetRecords[user].push(AssetRecord({
            amount: amount,
            description: description,
            timestamp: block.timestamp
        }));

        emit DeFiYieldUpdated(user, amount, description);
    }

    function distributeYield(address user, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(user != address(0), "Invalid user address");
        require(amount > 0, "Amount must be greater than 0");

        uint256 userYieldAmount = (amount * userShare) / 10000;
        userYield[user] += userYieldAmount;
    }

    function batchUpdateYield(
        address[] memory users, 
        uint256[] memory amounts, 
        string[] memory descriptions
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(users.length == amounts.length, "Arrays length mismatch");
        require(users.length == descriptions.length, "Arrays length mismatch");

        for (uint256 i = 0; i < users.length; i++) {
            userAssets[users[i]] += amounts[i];
            userYield[users[i]] += (amounts[i] * userShare) / 10000;
            
            assetRecords[users[i]].push(AssetRecord({
                amount: amounts[i],
                description: descriptions[i],
                timestamp: block.timestamp
            }));
        }
    }

    function getUserAssets(address user) external view returns (uint256) {
        return userAssets[user];
    }

    function getUserYield(address user) external view returns (uint256) {
        return userYield[user];
    }

    function getAssetRecords(address user) external view returns (AssetRecord[] memory) {
        return assetRecords[user];
    }

    function setUserShare(uint256 share) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(share <= 10000, "Share cannot exceed 100%");
        userShare = share;
    }

    function setPlatformShare(uint256 share) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(share <= 10000, "Share cannot exceed 100%");
        platformShare = share;
    }

    function setRiskReserveShare(uint256 share) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(share <= 10000, "Share cannot exceed 100%");
        riskReserveShare = share;
    }

    function setFeeReceiver(address receiver) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(receiver != address(0), "Invalid receiver address");
        feeReceiver = receiver;
    }
} 