// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./DeShareDataProtocol.sol";

/**
 * @title DeShare DeFi Protocol Smart Contract
 * @dev A smart contract for managing DeFi-related records (deposits, rentals) in the DeShare ecosystem.
 * @author DeShare Team
 * @notice This is an upgradeable smart contract for DeFi record management.
 * @custom:security-contact security@deshare.com
 */
contract DeShareDeFiProtocol is 
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable 
{
    // ===== Roles =====
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant READER_ROLE = keccak256("READER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    // ===== Constants =====
    uint256 public constant MAX_BATCH_SIZE = 50;
    
    // ===== DeFi Record Structures =====
    
    /**
     * @dev Deposit record structure for tracking user DeFi operations.
     */
    struct DepositRecord {
        uint256 amount;         // Deposit/withdrawal amount
        uint256 timestamp;      // Operation timestamp
        bool isDeposit;         // true for deposit, false for withdrawal
    }
    
    /**
     * @dev Rental record structure for tracking device rental information.
     */
    struct RentalRecord {
        address user;           // User address
        uint256 deviceId;       // Device ID (converted to uint256)
        uint256 startTime;      // Rental start timestamp
        uint256 endTime;        // Rental end timestamp (0 if still active)
        uint256 deposit;        // Deposit amount required
        uint256 fee;            // Rental fee charged
        bool isActive;          // Whether rental is currently active
    }
    
    // ===== State Variables =====
    
    // Reference to data protocol contract
    DeShareDataProtocol public dataProtocol;
    
    // DeFi record mappings
    mapping(address => DepositRecord[]) internal _userDeposits;
    mapping(uint256 => RentalRecord) internal _rentalRecords;
    uint256 private _rentalIdCounter;
    
    // ===== Custom Errors =====
    
    error MaintenanceModeActive();
    error InvalidDataProtocol();
    
    // ===== Modifiers =====
    
    modifier notInMaintenance() {
        // Check maintenance mode from data protocol
        if (address(dataProtocol) != address(0)) {
            // Note: Would need to add a getter function in DeShareDataProtocol for maintenance mode
            // For now, we'll implement our own maintenance check
        }
        _;
    }
    
    // ===== Events =====
    
    event DepositRecorded(
        address indexed user,
        uint256 indexed amount,
        bool indexed isDeposit,
        uint256 timestamp
    );
    
    event RentalRecorded(
        uint256 indexed rentalId,
        address indexed user,
        uint256 indexed deviceId,
        uint256 startTime,
        uint256 deposit,
        uint256 fee
    );
    
    event RentalReturned(
        uint256 indexed rentalId,
        address indexed user,
        uint256 indexed deviceId,
        uint256 endTime,
        uint256 finalFee
    );

    event DataProtocolUpdated(
        address indexed oldProtocol,
        address indexed newProtocol
    );

    // ========== Constructor Disabled ==========
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ========== Initialization Function ==========
    
    /**
     * @dev Initialization function
     * @param _dataProtocol Address of the data protocol contract
     * @param _initialOwner Initial admin address
     */
    function initialize(
        address _dataProtocol,
        address _initialOwner
    ) public initializer {
        require(_dataProtocol != address(0), "DeShareDeFiProtocol: Invalid data protocol");
        require(_initialOwner != address(0), "DeShareDeFiProtocol: Invalid initial owner");
        
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        
        dataProtocol = DeShareDataProtocol(_dataProtocol);
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, _initialOwner);
        _grantRole(OPERATOR_ROLE, _initialOwner);
        _grantRole(READER_ROLE, _initialOwner);
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
        require(newImplementation != address(0), "DeShareDeFiProtocol: Invalid implementation");
        require(newImplementation.code.length > 0, "DeShareDeFiProtocol: Invalid implementation");
    }

    // ========== Admin Functions ==========
    
    /**
     * @notice Update data protocol contract address
     * @param _newDataProtocol New data protocol address
     */
    function setDataProtocol(address _newDataProtocol) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(_newDataProtocol != address(0), "DeShareDeFiProtocol: Invalid data protocol");
        
        address oldProtocol = address(dataProtocol);
        dataProtocol = DeShareDataProtocol(_newDataProtocol);
        
        emit DataProtocolUpdated(oldProtocol, _newDataProtocol);
    }

    // ===== DeFi Record Functions =====
    
    /**
     * @dev Records a user deposit or withdrawal operation.
     * @param user User address
     * @param amount Operation amount
     * @param isDeposit true for deposit, false for withdrawal
     */
    function recordDeposit(
        address user,
        uint256 amount,
        bool isDeposit
    ) 
        external 
        onlyRole(OPERATOR_ROLE) 
        notInMaintenance 
    {
        require(user != address(0), "DeShareDeFiProtocol: Invalid user address");
        require(amount > 0, "DeShareDeFiProtocol: Amount must be greater than 0");
        
        DepositRecord memory record = DepositRecord({
            amount: amount,
            timestamp: block.timestamp,
            isDeposit: isDeposit
        });
        
        _userDeposits[user].push(record);
        
        emit DepositRecorded(user, amount, isDeposit, block.timestamp);
    }
    
    /**
     * @dev Records a device rental operation.
     * @param user User address
     * @param deviceId Device ID (as string, will be converted)
     * @param deposit Deposit amount required
     * @param fee Rental fee
     * @return rentalId The ID of the created rental record
     */
    function recordRental(
        address user,
        string memory deviceId,
        uint256 deposit,
        uint256 fee
    ) 
        external 
        onlyRole(OPERATOR_ROLE) 
        notInMaintenance 
        returns (uint256 rentalId)
    {
        require(user != address(0), "DeShareDeFiProtocol: Invalid user address");
        require(bytes(deviceId).length > 0, "DeShareDeFiProtocol: Invalid device ID");
        require(deposit > 0, "DeShareDeFiProtocol: Deposit must be greater than 0");
        
        // Note: Device existence check would be done via dataProtocol if needed
        // For now, we'll skip this check to avoid tight coupling
        
        rentalId = ++_rentalIdCounter;
        
        RentalRecord memory record = RentalRecord({
            user: user,
            deviceId: rentalId, // Using rentalId as unique identifier
            startTime: block.timestamp,
            endTime: 0, // 0 indicates active rental
            deposit: deposit,
            fee: fee,
            isActive: true
        });
        
        _rentalRecords[rentalId] = record;
        
        emit RentalRecorded(rentalId, user, rentalId, block.timestamp, deposit, fee);
        
        return rentalId;
    }
    
    /**
     * @dev Records the return of a rented device.
     * @param rentalId Rental record ID
     * @param finalFee Final fee charged (may be different from initial fee)
     */
    function recordReturn(
        uint256 rentalId,
        uint256 finalFee
    ) 
        external 
        onlyRole(OPERATOR_ROLE) 
        notInMaintenance 
    {
        require(rentalId > 0 && rentalId <= _rentalIdCounter, "DeShareDeFiProtocol: Invalid rental ID");
        
        RentalRecord storage record = _rentalRecords[rentalId];
        require(record.isActive, "DeShareDeFiProtocol: Rental already returned");
        
        record.endTime = block.timestamp;
        record.fee = finalFee;
        record.isActive = false;
        
        emit RentalReturned(rentalId, record.user, record.deviceId, block.timestamp, finalFee);
    }
    
    /**
     * @dev Gets user's deposit history.
     * @param user User address
     * @return Array of deposit records
     */
    function getUserDepositHistory(address user) 
        external 
        view 
        onlyRole(READER_ROLE) 
        returns (DepositRecord[] memory) 
    {
        require(user != address(0), "DeShareDeFiProtocol: Invalid user address");
        return _userDeposits[user];
    }
    
    /**
     * @dev Gets user's deposit history with pagination.
     * @param user User address
     * @param offset Starting index
     * @param limit Maximum number of records to return
     * @return Array of deposit records
     */
    function getUserDepositHistoryPaginated(
        address user,
        uint256 offset,
        uint256 limit
    ) 
        external 
        view 
        onlyRole(READER_ROLE) 
        returns (DepositRecord[] memory) 
    {
        require(user != address(0), "DeShareDeFiProtocol: Invalid user address");
        require(limit > 0 && limit <= MAX_BATCH_SIZE, "DeShareDeFiProtocol: Invalid limit");
        
        DepositRecord[] storage userRecords = _userDeposits[user];
        uint256 length = userRecords.length;
        
        if (offset >= length) {
            return new DepositRecord[](0);
        }
        
        uint256 count = (offset + limit > length) ? (length - offset) : limit;
        DepositRecord[] memory result = new DepositRecord[](count);
        
        for (uint256 i = 0; i < count; i++) {
            result[i] = userRecords[offset + i];
        }
        
        return result;
    }
    
    /**
     * @dev Gets rental record by ID.
     * @param rentalId Rental record ID
     * @return Rental record
     */
    function getRentalRecord(uint256 rentalId) 
        external 
        view 
        onlyRole(READER_ROLE) 
        returns (RentalRecord memory) 
    {
        require(rentalId > 0 && rentalId <= _rentalIdCounter, "DeShareDeFiProtocol: Invalid rental ID");
        return _rentalRecords[rentalId];
    }
    
    /**
     * @dev Gets active rentals for a user.
     * @param user User address
     * @return Array of rental IDs for active rentals
     */
    function getUserActiveRentals(address user) 
        external 
        view 
        onlyRole(READER_ROLE) 
        returns (uint256[] memory) 
    {
        require(user != address(0), "DeShareDeFiProtocol: Invalid user address");
        
        // First pass: count active rentals
        uint256 activeCount = 0;
        for (uint256 i = 1; i <= _rentalIdCounter; i++) {
            if (_rentalRecords[i].user == user && _rentalRecords[i].isActive) {
                activeCount++;
            }
        }
        
        // Second pass: collect active rental IDs
        uint256[] memory activeRentals = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 1; i <= _rentalIdCounter; i++) {
            if (_rentalRecords[i].user == user && _rentalRecords[i].isActive) {
                activeRentals[index] = i;
                index++;
            }
        }
        
        return activeRentals;
    }
    
    /**
     * @dev Gets rental history for a user.
     * @param user User address
     * @param includeActive Whether to include active rentals
     * @return Array of rental IDs
     */
    function getUserRentalHistory(
        address user,
        bool includeActive
    ) 
        external 
        view 
        onlyRole(READER_ROLE) 
        returns (uint256[] memory) 
    {
        require(user != address(0), "DeShareDeFiProtocol: Invalid user address");
        
        // First pass: count matching rentals
        uint256 matchingCount = 0;
        for (uint256 i = 1; i <= _rentalIdCounter; i++) {
            if (_rentalRecords[i].user == user) {
                if (includeActive || !_rentalRecords[i].isActive) {
                    matchingCount++;
                }
            }
        }
        
        // Second pass: collect matching rental IDs
        uint256[] memory rentals = new uint256[](matchingCount);
        uint256 index = 0;
        for (uint256 i = 1; i <= _rentalIdCounter; i++) {
            if (_rentalRecords[i].user == user) {
                if (includeActive || !_rentalRecords[i].isActive) {
                    rentals[index] = i;
                    index++;
                }
            }
        }
        
        return rentals;
    }
    
    /**
     * @dev Gets the total number of rental records.
     * @return Total rental count
     */
    function getTotalRentalCount() 
        external 
        view 
        onlyRole(READER_ROLE) 
        returns (uint256) 
    {
        return _rentalIdCounter;
    }
    
    /**
     * @dev Gets user deposit statistics.
     * @param user User address
     * @return totalDeposits Total amount deposited
     * @return totalWithdrawals Total amount withdrawn
     * @return depositCount Number of deposit operations
     * @return withdrawalCount Number of withdrawal operations
     */
    function getUserDepositStats(address user) 
        external 
        view 
        onlyRole(READER_ROLE) 
        returns (
            uint256 totalDeposits,
            uint256 totalWithdrawals,
            uint256 depositCount,
            uint256 withdrawalCount
        ) 
    {
        require(user != address(0), "DeShareDeFiProtocol: Invalid user address");
        
        DepositRecord[] storage userRecords = _userDeposits[user];
        
        for (uint256 i = 0; i < userRecords.length; i++) {
            if (userRecords[i].isDeposit) {
                totalDeposits += userRecords[i].amount;
                depositCount++;
            } else {
                totalWithdrawals += userRecords[i].amount;
                withdrawalCount++;
            }
        }
    }
    
    // ===== Storage Gap =====
    
    /**
     * @dev Reserved storage slots for future upgrades to prevent storage collisions.
     */
    uint256[47] private __gap;
} 