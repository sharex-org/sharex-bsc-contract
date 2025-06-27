// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../interfaces/IDeFiAdapter.sol";
import "../../interfaces/IDeFiProtocol.sol";
import "../../utils/Constants.sol";

/**
 * @title DeFiAdapter
 * @dev Unified DeFi protocol management contract with share-based fund management
 * 
 * Core Features:
 * - Multi-protocol management: Dynamically add/remove DeFi protocol adapters
 * - Smart protocol selection: Auto-select healthy protocols with optimal APY
 * - Share-based accounting: ERC4626-like share system for yield distribution
 * - Fund reservation system: Reserve/release user funds for ShareX rental deposits
 * - Authorized caller system: Allow external contracts to manage user funds
 * - Protocol health monitoring: Automatic failover to healthy protocols
 * 
 * Architecture:
 * - DeFiAdapter (this contract) - Central management and user interface
 *   ├── Manages multiple IDeFiProtocol implementations
 *   ├── AaveAdapter - AAVE V3 protocol integration
 *   ├── (Future) CompoundAdapter - Compound protocol integration  
 *   └── (Future) Other protocol adapters
 * 
 * Integration:
 * - Used by Vault contract for user deposit/withdrawal operations
 * - Used by ShareX contract for fund reservation/release operations
 * - Supports single token (USDT) with multi-protocol yield optimization
 */
contract DeFiAdapter is 
    IDeFiAdapter,
    Ownable,
    AccessControl,
    ReentrancyGuard,
    Pausable
{
    using SafeERC20 for IERC20;

    // ========== Storage Variables ==========
    
    /// @notice Supported token (currently only supports USDT)
    IERC20 public immutable token;
    
    /// @notice Protocol list
    mapping(string => address) public protocols;
    
    /// @notice Protocol names list
    string[] public protocolNames;
    
    /// @notice Default protocol (priority usage)
    string public defaultProtocol;
    
    /// @notice Total deposit amount
    uint256 public totalDeposits;
    
    /// @notice Total shares
    uint256 public totalShares;
    
    /// @notice User deposit records
    mapping(address => UserDeposit) public userDeposits;
    
    /// @notice Reserved funds records
    mapping(address => uint256) public reservedFunds;
    
    /// @notice Authorized contracts can call reserve/release funds
    mapping(address => bool) public authorizedCallers;
    
    /// @notice Protocol allocation weights (base 10000)
    mapping(string => uint256) public protocolWeights;

    // ========== Data Structures ==========
    
    struct UserDeposit {
        uint256 amount;      // User deposit amount
        uint256 shares;      // User shares
        uint256 timestamp;   // Deposit time
    }

    // ========== Event Definitions ==========
    
    event AuthorizedCallerUpdated(address indexed caller, bool authorized);
    event ProtocolAdded(string indexed protocolName, address protocolAddress);
    event ProtocolRemoved(string indexed protocolName);
    event DefaultProtocolChanged(string indexed oldDefault, string indexed newDefault);
    event ProtocolWeightUpdated(string indexed protocolName, uint256 weight);

    // ========== Modifiers ==========
    
    modifier onlyAuthorized() {
        require(
            authorizedCallers[msg.sender] || hasRole(Constants.DEFI_MANAGER_ROLE, msg.sender),
            "DeFiAdapter: Not authorized"
        );
        _;
    }

    // ========== Constructor ==========
    
    /**
     * @notice Constructor
     * @param _token Supported token address (USDT)
     * @param _initialOwner Initial owner address
     */
    constructor(
        address _token,
        address _initialOwner
    ) Ownable(_initialOwner) {
        require(_token != address(0), "DeFiAdapter: Invalid token address");
        require(_initialOwner != address(0), "DeFiAdapter: Invalid initial owner");
        
        token = IERC20(_token);
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, _initialOwner);
        _grantRole(Constants.DEFI_MANAGER_ROLE, _initialOwner);
        _grantRole(Constants.EMERGENCY_ROLE, _initialOwner);
    }

    // ========== Protocol Management Functions ==========
    
    /**
     * @notice Add DeFi protocol adapter
     * @param protocolName Protocol name (e.g.: "AAVE", "Compound")
     * @param protocolAddress Protocol adapter contract address
     * @param weight Protocol weight (base 10000)
     */
    function addProtocol(
        string memory protocolName, 
        address protocolAddress,
        uint256 weight
    ) external onlyRole(Constants.DEFI_MANAGER_ROLE) {
        require(bytes(protocolName).length > 0, "DeFiAdapter: Empty protocol name");
        require(protocolAddress != address(0), "DeFiAdapter: Invalid protocol address");
        require(protocols[protocolName] == address(0), "DeFiAdapter: Protocol already exists");
        require(weight <= 10000, "DeFiAdapter: Weight too high");
        
        // Verify that the protocol contract implements IDeFiProtocol interface
        try IDeFiProtocol(protocolAddress).protocolName() returns (string memory) {
            // Interface verification passed
        } catch {
            revert("DeFiAdapter: Invalid protocol contract");
        }
        
        protocols[protocolName] = protocolAddress;
        protocolNames.push(protocolName);
        protocolWeights[protocolName] = weight;
        
        // If it's the first protocol, set as default protocol
        if (protocolNames.length == 1) {
            defaultProtocol = protocolName;
        }
        
        emit ProtocolAdded(protocolName, protocolAddress);
        emit ProtocolWeightUpdated(protocolName, weight);
    }
    
    /**
     * @notice Remove DeFi protocol adapter
     * @param protocolName Protocol name
     */
    function removeProtocol(string memory protocolName) external onlyRole(Constants.DEFI_MANAGER_ROLE) {
        require(protocols[protocolName] != address(0), "DeFiAdapter: Protocol not found");
        
        // Remove protocol
        delete protocols[protocolName];
        delete protocolWeights[protocolName];
        
        // Remove from array
        for (uint256 i = 0; i < protocolNames.length; i++) {
            if (keccak256(bytes(protocolNames[i])) == keccak256(bytes(protocolName))) {
                protocolNames[i] = protocolNames[protocolNames.length - 1];
                protocolNames.pop();
                break;
            }
        }
        
        // If the deleted one is the default protocol, reset default protocol
        if (keccak256(bytes(defaultProtocol)) == keccak256(bytes(protocolName))) {
            if (protocolNames.length > 0) {
                defaultProtocol = protocolNames[0];
            } else {
                defaultProtocol = "";
            }
        }
        
        emit ProtocolRemoved(protocolName);
    }
    
    /**
     * @notice Set default protocol
     * @param protocolName Protocol name
     */
    function setDefaultProtocol(string memory protocolName) external onlyRole(Constants.DEFI_MANAGER_ROLE) {
        require(protocols[protocolName] != address(0), "DeFiAdapter: Protocol not found");
        
        string memory oldDefault = defaultProtocol;
        defaultProtocol = protocolName;
        
        emit DefaultProtocolChanged(oldDefault, protocolName);
    }
    
    /**
     * @notice Update protocol weight
     * @param protocolName Protocol name
     * @param weight New weight (base 10000)
     */
    function updateProtocolWeight(string memory protocolName, uint256 weight) external onlyRole(Constants.DEFI_MANAGER_ROLE) {
        require(protocols[protocolName] != address(0), "DeFiAdapter: Protocol not found");
        require(weight <= 10000, "DeFiAdapter: Weight too high");
        
        protocolWeights[protocolName] = weight;
        emit ProtocolWeightUpdated(protocolName, weight);
    }
    
    /**
     * @notice Set authorized caller
     * @param caller Caller address
     * @param authorized Whether to authorize
     */
    function setAuthorizedCaller(address caller, bool authorized) 
        external 
        onlyRole(Constants.DEFI_MANAGER_ROLE) 
    {
        require(caller != address(0), "DeFiAdapter: Invalid caller");
        authorizedCallers[caller] = authorized;
        emit AuthorizedCallerUpdated(caller, authorized);
    }

    /**
     * @notice Emergency pause contract
     */
    function pause() external onlyRole(Constants.EMERGENCY_ROLE) {
        _pause();
    }

    /**
     * @notice Resume contract operation
     */
    function unpause() external onlyRole(Constants.EMERGENCY_ROLE) {
        _unpause();
    }

    // ========== DeFi operation functions ==========
    
    /**
     * @notice Deposit to the optimal DeFi protocol
     * @param amount Deposit amount
     * @return shares Obtained shares
     */
    function deposit(uint256 amount) 
        external 
        override
        nonReentrant 
        whenNotPaused 
        returns (uint256 shares) 
    {
        require(amount > 0, "DeFiAdapter: Amount must be positive");
        require(protocolNames.length > 0, "DeFiAdapter: No protocols available");
        
        // Transfer in token
        token.safeTransferFrom(msg.sender, address(this), amount);
        
        // Calculate shares
        shares = convertToShares(amount);
        
        // Update user record
        UserDeposit storage userDeposit = userDeposits[msg.sender];
        userDeposit.amount += amount;
        userDeposit.shares += shares;
        userDeposit.timestamp = block.timestamp;
        
        // Update total
        totalDeposits += amount;
        totalShares += shares;
        
        // Select optimal protocol and deposit
        string memory selectedProtocol = _selectBestProtocol();
        _depositToProtocol(selectedProtocol, amount);
        
        emit DepositToAave(msg.sender, amount, shares);
        return shares;
    }
    
    // ========== Protocol selection and call ==========
    
    /**
     * @notice Select optimal protocol
     * @return protocolName Selected protocol name
     */
    function _selectBestProtocol() internal view returns (string memory protocolName) {
        if (protocolNames.length == 0) {
            revert("DeFiAdapter: No protocols available");
        }
        
        // Simple strategy: Prioritize default protocol, if default protocol is not healthy, select the first healthy protocol
        if (bytes(defaultProtocol).length > 0 && protocols[defaultProtocol] != address(0)) {
            if (_isProtocolHealthy(defaultProtocol)) {
                return defaultProtocol;
            }
        }
        
        // Iterate to find the first healthy protocol
        for (uint256 i = 0; i < protocolNames.length; i++) {
            if (_isProtocolHealthy(protocolNames[i])) {
                return protocolNames[i];
            }
        }
        
        // If there are no healthy protocols, return default protocol (let the call fail for error information)
        return defaultProtocol;
    }
    
    /**
     * @notice Check if protocol is healthy
     * @param protocolName Protocol name
     * @return healthy Whether healthy
     */
    function _isProtocolHealthy(string memory protocolName) internal view returns (bool healthy) {
        address protocolAddress = protocols[protocolName];
        if (protocolAddress == address(0)) {
            return false;
        }
        
        try IDeFiProtocol(protocolAddress).isHealthy() returns (bool isHealthy) {
            return isHealthy;
        } catch {
            return false;
        }
    }
    
    /**
     * @notice Deposit to specified protocol
     * @param protocolName Protocol name
     * @param amount Deposit amount
     */
    function _depositToProtocol(string memory protocolName, uint256 amount) internal {
        address protocolAddress = protocols[protocolName];
        require(protocolAddress != address(0), "DeFiAdapter: Protocol not found");
        
        // Authorize protocol contract to use token
        token.forceApprove(protocolAddress, amount);
        
        // Call protocol's deposit function
        bool success = IDeFiProtocol(protocolAddress).protocolDeposit(amount);
        require(success, "DeFiAdapter: Protocol deposit failed");
    }
    
    /**
     * @notice Withdraw from specified protocol
     * @param protocolName Protocol name
     * @param amount Withdraw amount
     * @return actualAmount Actual withdraw amount
     */
    function _withdrawFromProtocol(string memory protocolName, uint256 amount) internal returns (uint256 actualAmount) {
        address protocolAddress = protocols[protocolName];
        require(protocolAddress != address(0), "DeFiAdapter: Protocol not found");
        
        // Call protocol's withdraw function
        actualAmount = IDeFiProtocol(protocolAddress).protocolWithdraw(amount);
        require(actualAmount > 0, "DeFiAdapter: Protocol withdraw failed");
        
        return actualAmount;
    }

    /**
     * @notice Withdraw from DeFi protocol
     * @param shares Shares to withdraw
     * @return amount Actual withdraw amount
     */
    function withdraw(uint256 shares) 
        external 
        override
        nonReentrant 
        whenNotPaused 
        returns (uint256 amount) 
    {
        require(shares > 0, "DeFiAdapter: Shares must be positive");
        
        UserDeposit storage userDeposit = userDeposits[msg.sender];
        require(userDeposit.shares >= shares, "DeFiAdapter: Insufficient shares");
        
        // Calculate withdraw amount
        amount = convertToAssets(shares);
        require(amount > 0, "DeFiAdapter: Invalid withdrawal amount");
        
        // Update user record
        userDeposit.amount -= amount;
        userDeposit.shares -= shares;
        
        // Update total
        totalDeposits -= amount;
        totalShares -= shares;
        
        // Withdraw from optimal protocol
        string memory selectedProtocol = _selectBestProtocol();
        uint256 actualAmount = _withdrawFromProtocol(selectedProtocol, amount);
        
        // Transfer funds to user
        token.safeTransfer(msg.sender, actualAmount);
        
        emit WithdrawFromAave(msg.sender, actualAmount, shares);
        return actualAmount;
    }

    /**
     * @notice Reserve user funds
     * @param user User address
     * @param amount Reserved amount
     */
    function reserveFunds(address user, uint256 amount) 
        external 
        override
        onlyAuthorized 
        nonReentrant 
        whenNotPaused 
    {
        require(user != address(0), "DeFiAdapter: Invalid user");
        require(amount > 0, "DeFiAdapter: Amount must be positive");
        
        // Check user balance
        uint256 userBalance = getBalance(user);
        require(userBalance >= amount, "DeFiAdapter: Insufficient balance");
        
        // Update reserved record
        reservedFunds[user] += amount;
    }

    /**
     * @notice Release reserved funds
     * @param user User address
     * @param amount Released amount
     */
    function releaseFunds(address user, uint256 amount) 
        external 
        override
        onlyAuthorized 
        nonReentrant 
        whenNotPaused 
    {
        require(user != address(0), "DeFiAdapter: Invalid user");
        require(amount > 0, "DeFiAdapter: Amount must be positive");
        require(reservedFunds[user] >= amount, "DeFiAdapter: Insufficient reserved funds");
        
        // Update reserved record
        reservedFunds[user] -= amount;
    }

    /**
     * @notice Deduct from user balance
     * @param user User address
     * @param amount Deduct amount
     * @return success Whether successful
     */
    function deductFromBalance(address user, uint256 amount) 
        external 
        override
        onlyAuthorized 
        nonReentrant 
        whenNotPaused 
        returns (bool success) 
    {
        require(user != address(0), "DeFiAdapter: Invalid user");
        require(amount > 0, "DeFiAdapter: Amount must be positive");
        
        UserDeposit storage userDeposit = userDeposits[user];
        uint256 userBalance = getBalance(user);
        
        if (userBalance < amount) {
            return false;
        }
        
        // Calculate shares to reduce
        uint256 sharesToReduce = convertToShares(amount);
        
        // Update user record
        userDeposit.amount -= amount;
        userDeposit.shares -= sharesToReduce;
        
        // Update total
        totalDeposits -= amount;
        totalShares -= sharesToReduce;
        
        // Withdraw from optimal protocol to calling contract
        string memory selectedProtocol = _selectBestProtocol();
        uint256 actualAmount = _withdrawFromProtocol(selectedProtocol, amount);
        
        // Transfer funds to calling contract
        token.safeTransfer(msg.sender, actualAmount);
        
        return true;
    }

    // ========== Query functions ==========
    
    /**
     * @notice Get user balance (including yield)
     * @param user User address
     * @return balance User balance
     */
    function getBalance(address user) public view override returns (uint256 balance) {
        UserDeposit memory userDeposit = userDeposits[user];
        if (userDeposit.shares == 0) {
            return 0;
        }
        
        return convertToAssets(userDeposit.shares) - reservedFunds[user];
    }

    /**
     * @notice Get user shares
     * @param user User address
     * @return shares User shares
     */
    function getUserShares(address user) external view returns (uint256 shares) {
        return userDeposits[user].shares;
    }

    /**
     * @notice Get user reserved funds
     * @param user User address
     * @return reserved Reserved amount
     */
    function getReservedFunds(address user) external view override returns (uint256 reserved) {
        return reservedFunds[user];
    }

    /**
     * @notice Convert asset amount to shares
     * @param assets Asset amount
     * @return shares Shares
     */
    function convertToShares(uint256 assets) public view override returns (uint256 shares) {
        if (totalShares == 0 || totalDeposits == 0) {
            return assets;
        }
        
        // Get current AAVE V3 total assets
        uint256 totalAssets = getTotalAssets();
        return (assets * totalShares) / totalAssets;
    }

    /**
     * @notice Convert shares to asset amount
     * @param shares Shares
     * @return assets Asset amount
     */
    function convertToAssets(uint256 shares) public view override returns (uint256 assets) {
        if (totalShares == 0) {
            return shares;
        }
        
        uint256 totalAssets = getTotalAssets();
        return (shares * totalAssets) / totalShares;
    }

    /**
     * @notice Get total assets in all protocols (including yield)
     * @return totalAssets Total assets
     */
    function getTotalAssets() public view returns (uint256 totalAssets) {
        uint256 total = 0;
        
        // Iterate through all protocols to calculate total assets
        for (uint256 i = 0; i < protocolNames.length; i++) {
            address protocolAddress = protocols[protocolNames[i]];
            if (protocolAddress != address(0)) {
                try IDeFiProtocol(protocolAddress).getProtocolTotalAssets() returns (uint256 assets) {
                    total += assets;
                } catch {
                    // If a protocol query fails, skip
                    continue;
                }
            }
        }
        
        // If there are no protocols or all queries fail, return deposit total
        return total > 0 ? total : totalDeposits;
    }
    
    // ========== Protocol query functions ==========
    
    /**
     * @notice Get all supported protocol list
     * @return names Protocol name list
     */
    function getSupportedProtocols() external view returns (string[] memory names) {
        return protocolNames;
    }
    
    /**
     * @notice Get protocol information
     * @param protocolName Protocol name
     * @return name Protocol name
     * @return version Protocol version
     * @return isHealthy Protocol health status
     * @return apy Protocol APY
     * @return totalAssets Protocol total assets
     * @return weight Protocol weight
     * @return protocolAddress Protocol contract address
     */
    function getProtocolInfo(string memory protocolName) external view returns (
        string memory name,
        string memory version,
        bool isHealthy,
        uint256 apy,
        uint256 totalAssets,
        uint256 weight,
        address protocolAddress
    ) {
        protocolAddress = protocols[protocolName];
        require(protocolAddress != address(0), "DeFiAdapter: Protocol not found");
        
        IDeFiProtocol protocol = IDeFiProtocol(protocolAddress);
        
        try protocol.protocolName() returns (string memory _name) {
            name = _name;
        } catch {
            name = protocolName;
        }
        
        try protocol.protocolVersion() returns (string memory _version) {
            version = _version;
        } catch {
            version = "Unknown";
        }
        
        try protocol.isHealthy() returns (bool _isHealthy) {
            isHealthy = _isHealthy;
        } catch {
            isHealthy = false;
        }
        
        try protocol.getCurrentAPY() returns (uint256 _apy) {
            apy = _apy;
        } catch {
            apy = 0;
        }
        
        try protocol.getProtocolTotalAssets() returns (uint256 _totalAssets) {
            totalAssets = _totalAssets;
        } catch {
            totalAssets = 0;
        }
        
        weight = protocolWeights[protocolName];
    }
    
    /**
     * @notice Get optimal protocol (protocol with the highest APY among healthy protocols)
     * @return bestProtocol Optimal protocol name
     * @return bestAPY Optimal APY
     */
    function getBestProtocol() external view returns (string memory bestProtocol, uint256 bestAPY) {
        bestAPY = 0;
        bestProtocol = "";
        
        for (uint256 i = 0; i < protocolNames.length; i++) {
            string memory protocolName = protocolNames[i];
            address protocolAddress = protocols[protocolName];
            
            if (protocolAddress != address(0)) {
                try IDeFiProtocol(protocolAddress).isHealthy() returns (bool isHealthy) {
                    if (isHealthy) {
                        try IDeFiProtocol(protocolAddress).getCurrentAPY() returns (uint256 apy) {
                            if (apy > bestAPY) {
                                bestAPY = apy;
                                bestProtocol = protocolName;
                            }
                        } catch {
                            // Skip protocols with APY query failure
                        }
                    }
                } catch {
                    // Skip protocols with health check failure
                }
            }
        }
    }

    // ========== Internal functions ==========
    
    /**
     * @notice Check interface support
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl)
        returns (bool)
    {
        return
            interfaceId == type(IDeFiAdapter).interfaceId ||
            super.supportsInterface(interfaceId);
    }
} 