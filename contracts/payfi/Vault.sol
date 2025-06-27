// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IDeFiAdapter.sol";
import "../utils/Constants.sol";

/**
 * @title Vault
 * @dev Deposit management contract, providing deposit, withdrawal, and management of user funds
 * Collaborates with DeFiAdapter to invest user funds into DeFi protocols for yield
 * Simplified version, implementing only core functionalities required by ShareX
 */
contract Vault is 
    Initializable,
    OwnableUpgradeable, 
    AccessControlUpgradeable, 
    ReentrancyGuardUpgradeable, 
    PausableUpgradeable,
    UUPSUpgradeable 
{
    using SafeERC20 for IERC20;

    // ========== Role Definitions ==========
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // ========== State Variables ==========
    
    /// @notice DeFi adapter contract
    IDeFiAdapter public defiAdapter;
    
    /// @notice User balance records
    mapping(address => mapping(address => uint256)) public userBalances;
    
    /// @notice Reserved funds records
    mapping(address => mapping(address => uint256)) public reservedFunds;
    
    /// @notice Authorized contracts that can call fund operations
    mapping(address => bool) public authorizedCallers;

    // ========== Event Definitions ==========
    
    event AuthorizedCallerUpdated(address indexed caller, bool authorized);
    event DeFiAdapterUpdated(address indexed oldAdapter, address indexed newAdapter);
    event UserDeposited(address indexed user, address indexed token, uint256 amount, uint256 defiAmount);
    event UserWithdrawn(address indexed user, address indexed token, uint256 amount, uint256 fromDefi);
    event FundsReserved(address indexed user, address indexed token, uint256 amount, string purpose);
    event FundsReleased(address indexed user, address indexed token, uint256 amount, string purpose);

    // ========== Modifiers ==========
    
    modifier onlyAuthorized() {
        require(
            authorizedCallers[msg.sender] || 
            hasRole(Constants.DEFI_MANAGER_ROLE, msg.sender) ||
            hasRole(Constants.OPERATOR_ROLE, msg.sender),
            "Vault: Not authorized"
        );
        _;
    }

    // ========== Constructor Disabled ==========
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ========== Initialization Function ==========
    
    /**
     * @notice Initialization function
     * @param _defiAdapter DeFi adapter address
     * @param _initialOwner Initial owner address
     */
    function initialize(
        address _defiAdapter,
        address _initialOwner
    ) public initializer {
        require(_defiAdapter != address(0), "Vault: Invalid DeFi adapter");
        require(_initialOwner != address(0), "Vault: Invalid initial owner");
        
        __Ownable_init(_initialOwner);
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        
        defiAdapter = IDeFiAdapter(_defiAdapter);
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, _initialOwner);
        _grantRole(Constants.DEFI_MANAGER_ROLE, _initialOwner);
        _grantRole(Constants.OPERATOR_ROLE, _initialOwner);
        _grantRole(Constants.EMERGENCY_ROLE, _initialOwner);
        _grantRole(UPGRADER_ROLE, _initialOwner);
    }

    // ========== Upgrade Authorization ==========
    
    /**
     * @notice Authorize contract upgrade
     * @param newImplementation New implementation contract address
     */
    function _authorizeUpgrade(address newImplementation) 
        internal 
        view
        override 
        onlyRole(UPGRADER_ROLE) 
    {
        require(newImplementation != address(0), "Vault: Invalid implementation");
        require(newImplementation.code.length > 0, "Vault: Invalid implementation");
    }

    // ========== Admin Functions ==========
    
    /**
     * @notice Set authorized caller
     * @param caller Caller address
     * @param authorized Whether to authorize
     */
    function setAuthorizedCaller(address caller, bool authorized) 
        external 
        onlyRole(Constants.DEFI_MANAGER_ROLE) 
    {
        require(caller != address(0), "Vault: Invalid caller");
        authorizedCallers[caller] = authorized;
        emit AuthorizedCallerUpdated(caller, authorized);
    }
    
    /**
     * @notice Update DeFi adapter
     * @param _newAdapter New adapter address
     */
    function setDeFiAdapter(address _newAdapter) 
        external 
        onlyRole(Constants.DEFI_MANAGER_ROLE) 
    {
        require(_newAdapter != address(0), "Vault: Invalid adapter");
        address oldAdapter = address(defiAdapter);
        defiAdapter = IDeFiAdapter(_newAdapter);
        emit DeFiAdapterUpdated(oldAdapter, _newAdapter);
    }

    /**
     * @notice Pause contract
     */
    function pause() external onlyRole(Constants.EMERGENCY_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause contract
     */
    function unpause() external onlyRole(Constants.EMERGENCY_ROLE) {
        _unpause();
    }

    // ========== Deposit/Withdrawal Functions ==========
    
    /**
     * @notice User deposit
     * @param token Token address
     * @param amount Deposit amount
     * @param depositToDeFi Whether to deposit to DeFi protocol
     * @return shares Shares received
     */
    function deposit(address token, uint256 amount, bool depositToDeFi) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256 shares) 
    {
        require(amount > 0, "Vault: Amount must be positive");
        require(token != address(0), "Vault: Invalid token");
        
        // Transfer tokens in
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        // Update user balance
        userBalances[msg.sender][token] += amount;
        
        if (depositToDeFi) {
            // Approve and deposit to DeFi protocol
            IERC20(token).forceApprove(address(defiAdapter), amount);
            shares = defiAdapter.deposit(amount);
        } else {
            shares = amount; // Simplified handling, 1:1 mapping
        }
        
        emit UserDeposited(msg.sender, token, amount, depositToDeFi ? amount : 0);
        return shares;
    }

    /**
     * @notice Proxy deposit (authorized caller deposits for specified user)
     * @param user Target user address
     * @param token Token address
     * @param amount Deposit amount
     * @param depositToDeFi Whether to deposit to DeFi protocol
     * @return shares Shares received
     */
    function depositFor(address user, address token, uint256 amount, bool depositToDeFi) 
        external 
        onlyAuthorized
        nonReentrant 
        whenNotPaused 
        returns (uint256 shares) 
    {
        require(amount > 0, "Vault: Amount must be positive");
        require(token != address(0), "Vault: Invalid token");
        require(user != address(0), "Vault: Invalid user");
        
        // Transfer tokens in (from caller)
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        // Update target user balance
        userBalances[user][token] += amount;
        
        if (depositToDeFi) {
            // Approve and deposit to DeFi protocol
            IERC20(token).forceApprove(address(defiAdapter), amount);
            shares = defiAdapter.deposit(amount);
        } else {
            shares = amount; // Simplified handling, 1:1 mapping
        }
        
        emit UserDeposited(user, token, amount, depositToDeFi ? amount : 0);
        return shares;
    }

    /**
     * @notice User withdrawal
     * @param token Token address
     * @param amount Withdrawal amount
     * @return actualAmount Actual withdrawal amount
     */
    function withdraw(address token, uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256 actualAmount) 
    {
        require(amount > 0, "Vault: Amount must be positive");
        require(token != address(0), "Vault: Invalid token");
        
        uint256 userBalance = userBalances[msg.sender][token];
        uint256 reserved = reservedFunds[msg.sender][token];
        uint256 availableBalance = userBalance - reserved;
        
        require(availableBalance >= amount, "Vault: Insufficient available balance");
        
        // Update user balance
        userBalances[msg.sender][token] -= amount;
        
        // Withdraw from DeFi protocol (if needed)
        uint256 contractBalance = IERC20(token).balanceOf(address(this));
        if (contractBalance < amount) {
            uint256 needFromDeFi = amount - contractBalance;
            uint256 shares = defiAdapter.convertToShares(needFromDeFi);
            actualAmount = defiAdapter.withdraw(shares);
        }
        
        // Transfer to user
        actualAmount = amount; // Simplified handling
        IERC20(token).safeTransfer(msg.sender, actualAmount);
        
        emit UserWithdrawn(msg.sender, token, actualAmount, 0);
        return actualAmount;
    }

    /**
     * @notice Withdraw on behalf of user (authorized contracts only)
     * @param user User address
     * @param token Token address
     * @param amount Withdrawal amount
     * @param to Recipient address
     * @return actualAmount Actual withdrawal amount
     */
    function withdrawFor(address user, address token, uint256 amount, address to) 
        external 
        onlyAuthorized
        nonReentrant 
        whenNotPaused 
        returns (uint256 actualAmount) 
    {
        require(amount > 0, "Vault: Amount must be positive");
        require(token != address(0), "Vault: Invalid token");
        require(user != address(0), "Vault: Invalid user");
        require(to != address(0), "Vault: Invalid recipient");
        
        uint256 userBalance = userBalances[user][token];
        uint256 reserved = reservedFunds[user][token];
        uint256 availableBalance = userBalance - reserved;
        
        require(availableBalance >= amount, "Vault: Insufficient available balance");
        
        // Update user balance
        userBalances[user][token] -= amount;
        
        // Withdraw from DeFi protocol (if needed)
        uint256 contractBalance = IERC20(token).balanceOf(address(this));
        if (contractBalance < amount) {
            uint256 needFromDeFi = amount - contractBalance;
            uint256 shares = defiAdapter.convertToShares(needFromDeFi);
            actualAmount = defiAdapter.withdraw(shares);
        }
        
        // Transfer to recipient address
        actualAmount = amount; // Simplified handling
        IERC20(token).safeTransfer(to, actualAmount);
        
        emit UserWithdrawn(user, token, actualAmount, 0);
        return actualAmount;
    }

    // ========== Balance Query Functions ==========
    
    /**
     * @notice Get user balance
     * @param user User address
     * @param token Token address
     * @return balance User balance
     */
    function getUserBalance(address user, address token) 
        external 
        view 
        returns (uint256 balance) 
    {
        return userBalances[user][token];
    }
    
    /**
     * @notice Get user available balance (excluding reserved funds)
     * @param user User address
     * @param token Token address
     * @return availableBalance Available balance
     */
    function getAvailableBalance(address user, address token) 
        external 
        view 
        returns (uint256 availableBalance) 
    {
        return userBalances[user][token] - reservedFunds[user][token];
    }
    
    /**
     * @notice Get user total balance (including DeFi yield)
     * @param user User address
     * @param token Token address
     * @return totalBalance Total balance
     */
    function getTotalBalance(address user, address token) 
        external 
        view 
        returns (uint256 totalBalance) 
    {
        // Simplified implementation: return user recorded balance
        // Should actually include DeFi yield calculation
        return userBalances[user][token];
    }
    
    /**
     * @notice Get reserved funds
     * @param user User address
     * @param token Token address
     * @return reserved Reserved amount
     */
    function getReservedFunds(address user, address token) 
        external 
        view 
        returns (uint256 reserved) 
    {
        return reservedFunds[user][token];
    }

    // ========== Fund Reservation Functions ==========
    
    /**
     * @notice Reserve funds
     * @param user User address
     * @param token Token address
     * @param amount Amount to reserve
     * @param reason Reason for reservation
     */
    function reserveFunds(address user, address token, uint256 amount, string memory reason) 
        external 
        onlyAuthorized 
    {
        require(amount > 0, "Vault: Amount must be positive");
        
        uint256 userBalance = userBalances[user][token];
        uint256 currentReserved = reservedFunds[user][token];
        uint256 availableBalance = userBalance - currentReserved;
        
        require(availableBalance >= amount, "Vault: Insufficient balance for reservation");
        
        reservedFunds[user][token] += amount;
        
        emit FundsReserved(user, token, amount, reason);
    }
    
    /**
     * @notice Release reserved funds
     * @param user User address
     * @param token Token address
     * @param amount Amount to release
     * @param reason Reason for release
     */
    function releaseFunds(address user, address token, uint256 amount, string memory reason) 
        external 
        onlyAuthorized 
    {
        require(amount > 0, "Vault: Amount must be positive");
        require(reservedFunds[user][token] >= amount, "Vault: Insufficient reserved funds");
        
        reservedFunds[user][token] -= amount;
        
        emit FundsReleased(user, token, amount, reason);
    }

    // ========== Fee Deduction Functions ==========
    
    /**
     * @notice Deduct funds from user account (for fee payments)
     * @param user User address
     * @param token Token address
     * @param amount Amount to deduct
     * @param to Recipient address
     * @return actualAmount Actual deducted amount
     */
    function deductFunds(address user, address token, uint256 amount, address to) 
        external 
        onlyAuthorized 
        returns (uint256 actualAmount) 
    {
        require(amount > 0, "Vault: Amount must be positive");
        require(to != address(0), "Vault: Invalid recipient");
        
        uint256 userBalance = userBalances[user][token];
        if (userBalance >= amount) {
            userBalances[user][token] -= amount;
            actualAmount = amount;
            
            // Transfer to recipient address
            IERC20(token).safeTransfer(to, actualAmount);
            
            return actualAmount;
        }
        
        return 0;
    }

    // ========== Emergency Functions ==========
    
    /**
     * @notice Emergency withdraw all funds
     * @param token Token address
     */
    function emergencyWithdraw(address token) 
        external 
        onlyRole(Constants.EMERGENCY_ROLE) 
        whenPaused 
    {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).safeTransfer(owner(), balance);
        }
    }
} 