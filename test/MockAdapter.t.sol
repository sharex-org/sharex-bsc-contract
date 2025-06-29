// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {BaseAdapter} from "../src/adapters/BaseAdapter.sol";
import {Constants} from "../src/libraries/Constants.sol";

/**
 * @title MockAdapter
 * @dev Simple mock adapter for testing the new architecture
 */
contract MockAdapter is BaseAdapter {
    uint256 public mockTotalAssets;
    uint256 public mockAPY = 1200; // 12%
    uint256 public mockPendingRewards = 100e6;

    constructor(address _asset, address _admin) BaseAdapter(_asset, _admin) {}

    function totalAssets() public view override returns (uint256) {
        return mockTotalAssets;
    }

    function _deposit(uint256 amount) internal override returns (uint256 shares) {
        mockTotalAssets += amount;
        return amount; // 1:1 conversion for simplicity
    }

    function _withdraw(uint256 shares) internal override returns (uint256 amount) {
        amount = shares; // 1:1 conversion
        if (amount <= mockTotalAssets) {
            mockTotalAssets -= amount;
        } else {
            mockTotalAssets = 0;
        }
        return amount;
    }

    function _harvest() internal override returns (uint256 rewardAmount) {
        rewardAmount = mockPendingRewards;
        mockPendingRewards = 0;
        return rewardAmount;
    }

    function _emergencyExit() internal override returns (uint256 amount) {
        amount = ASSET_TOKEN.balanceOf(address(this));
        mockTotalAssets = 0;
        return amount;
    }

    function getAPY() external view override returns (uint256) {
        return mockAPY;
    }

    function getPendingRewards() external view override returns (uint256) {
        return mockPendingRewards;
    }

    function getAdapterInfo()
        external
        pure
        override
        returns (string memory protocolName, string memory strategyType, uint8 riskLevel)
    {
        return ("MockProtocol", "Testing", 1);
    }

    function setMockTotalAssets(uint256 _mockTotalAssets) external {
        mockTotalAssets = _mockTotalAssets;
    }

    function setMockAPY(uint256 _mockAPY) external {
        mockAPY = _mockAPY;
    }

    function setMockPendingRewards(uint256 _mockPendingRewards) external {
        mockPendingRewards = _mockPendingRewards;
    }
}

/**
 * @title MockAdapterTest
 * @dev Test suite for the new adapter architecture
 */
contract MockAdapterTest is Test {
    // Test Constants
    uint256 private constant INITIAL_BALANCE = 1000000e6; // 1M USDT (6 decimals)
    uint256 private constant MIN_DEPOSIT = Constants.MIN_INVESTMENT_AMOUNT;

    // Contracts
    MockAdapter private adapter;
    ERC20Mock private usdt;

    // Test Accounts
    address private admin;
    address private vault;
    address private user;

    // Setup

    function setUp() public {
        // Create test accounts
        admin = makeAddr("admin");
        vault = makeAddr("vault");
        user = makeAddr("user");

        // Deploy mock USDT
        usdt = new ERC20Mock();

        // Deploy mock adapter
        vm.prank(admin);
        adapter = new MockAdapter(address(usdt), admin);

        // Grant vault role
        vm.prank(admin);
        adapter.grantRole(Constants.DEFI_MANAGER_ROLE, vault);

        // Fund accounts
        usdt.mint(vault, INITIAL_BALANCE);
        usdt.mint(user, INITIAL_BALANCE);
        // Don't fund adapter initially to avoid interfering with calculations
    }

    // Initialization Tests

    function testAdapterInitialization() public view {
        assertEq(adapter.asset(), address(usdt));
        assertTrue(adapter.isActive());
        assertFalse(adapter.emergencyMode());
        assertEq(adapter.totalShares(), 0);
        assertEq(adapter.totalAssets(), 0); // No initial balance
    }

    function testAdapterInfo() public view {
        (string memory protocolName, string memory strategyType, uint8 riskLevel) =
            adapter.getAdapterInfo();
        assertEq(protocolName, "MockProtocol");
        assertEq(strategyType, "Testing");
        assertEq(riskLevel, 1);
    }

    function testRoleSetup() public view {
        assertTrue(adapter.hasRole(Constants.DEFAULT_ADMIN_ROLE, admin));
        assertTrue(adapter.hasRole(Constants.DEFI_MANAGER_ROLE, admin));
        assertTrue(adapter.hasRole(Constants.DEFI_MANAGER_ROLE, vault));
        assertTrue(adapter.hasRole(Constants.EMERGENCY_ROLE, admin));
    }

    // Deposit Tests

    function testDepositSuccess() public {
        uint256 depositAmount = 1000e6;

        vm.startPrank(vault);
        usdt.approve(address(adapter), depositAmount);
        uint256 shares = adapter.deposit(depositAmount);
        vm.stopPrank();

        assertEq(shares, depositAmount, "Should receive equal shares");
        assertEq(adapter.totalShares(), shares, "Total shares should match");
        assertEq(adapter.mockTotalAssets(), depositAmount, "Mock assets should be updated");
    }

    function testDepositFailsNonVault() public {
        uint256 depositAmount = 1000e6;

        vm.startPrank(user);
        usdt.approve(address(adapter), depositAmount);

        vm.expectRevert("BaseAdapter: Only vault can call");
        adapter.deposit(depositAmount);
        vm.stopPrank();
    }

    function testDepositFailsSmallAmount() public {
        uint256 smallAmount = MIN_DEPOSIT - 1;

        vm.startPrank(vault);
        usdt.approve(address(adapter), smallAmount);

        vm.expectRevert("BaseAdapter: Amount too small");
        adapter.deposit(smallAmount);
        vm.stopPrank();
    }

    function testDepositFailsWhenPaused() public {
        uint256 depositAmount = 1000e6;

        // Pause the adapter
        vm.prank(admin);
        adapter.pause();

        vm.startPrank(vault);
        usdt.approve(address(adapter), depositAmount);

        vm.expectRevert();
        adapter.deposit(depositAmount);
        vm.stopPrank();
    }

    function testDepositFailsInEmergency() public {
        uint256 depositAmount = 1000e6;

        // Trigger emergency mode
        vm.prank(admin);
        adapter.emergencyExit();

        vm.startPrank(vault);
        usdt.approve(address(adapter), depositAmount);

        vm.expectRevert("BaseAdapter: Emergency mode active");
        adapter.deposit(depositAmount);
        vm.stopPrank();
    }

    // Withdraw Tests

    function testWithdrawSuccess() public {
        uint256 depositAmount = 1000e6;

        // First deposit
        vm.startPrank(vault);
        usdt.approve(address(adapter), depositAmount);
        uint256 shares = adapter.deposit(depositAmount);

        // Then withdraw
        uint256 amount = adapter.withdraw(shares);
        vm.stopPrank();

        assertEq(amount, shares, "Should withdraw equal amount");
        assertEq(adapter.totalShares(), 0, "Total shares should be zero");
        assertEq(adapter.mockTotalAssets(), 0, "Mock assets should be zero");
    }

    function testWithdrawFailsInsufficientShares() public {
        uint256 excessiveShares = 1000e6;

        vm.prank(vault);
        vm.expectRevert("BaseAdapter: Insufficient shares");
        adapter.withdraw(excessiveShares);
    }

    function testPartialWithdraw() public {
        uint256 depositAmount = 1000e6;

        // Deposit
        vm.startPrank(vault);
        usdt.approve(address(adapter), depositAmount);
        uint256 shares = adapter.deposit(depositAmount);

        // Withdraw half
        uint256 withdrawShares = shares / 2;
        uint256 amount = adapter.withdraw(withdrawShares);
        vm.stopPrank();

        assertEq(amount, withdrawShares, "Should withdraw half");
        assertEq(adapter.totalShares(), shares - withdrawShares, "Remaining shares");
        assertEq(adapter.mockTotalAssets(), depositAmount - amount, "Remaining assets");
    }

    // Harvest Tests

    function testHarvestSuccess() public {
        uint256 expectedRewards = 100e6;

        vm.prank(vault);
        uint256 rewards = adapter.harvest();

        assertEq(rewards, expectedRewards, "Should harvest expected rewards");
        assertEq(adapter.mockPendingRewards(), 0, "Pending rewards should be zero");
    }

    function testHarvestMultipleTimes() public {
        // First harvest
        vm.prank(vault);
        uint256 rewards1 = adapter.harvest();
        assertEq(rewards1, 100e6);

        // Set new pending rewards
        adapter.setMockPendingRewards(50e6);

        // Second harvest
        vm.prank(vault);
        uint256 rewards2 = adapter.harvest();
        assertEq(rewards2, 50e6);
    }

    function testHarvestFailsNonVault() public {
        vm.prank(user);
        vm.expectRevert("BaseAdapter: Only vault can call");
        adapter.harvest();
    }

    // Emergency Functions Tests

    function testEmergencyExit() public {
        uint256 depositAmount = 1000e6;

        // Deposit some funds
        vm.startPrank(vault);
        usdt.approve(address(adapter), depositAmount);
        adapter.deposit(depositAmount);
        vm.stopPrank();

        uint256 initialBalance = usdt.balanceOf(admin);

        // Emergency exit
        vm.prank(admin);
        uint256 exitAmount = adapter.emergencyExit();

        assertTrue(adapter.emergencyMode(), "Should be in emergency mode");
        assertGt(exitAmount, 0, "Should withdraw some amount");
        assertGt(usdt.balanceOf(admin), initialBalance, "Admin should receive tokens");
    }

    function testEmergencyExitFailsNonAdmin() public {
        vm.prank(user);
        vm.expectRevert();
        adapter.emergencyExit();
    }

    function testPauseUnpause() public {
        // Test pause
        vm.prank(admin);
        adapter.pause();
        assertTrue(adapter.paused(), "Should be paused");
        assertFalse(adapter.isActive(), "Should not be active when paused");

        // Test unpause
        vm.prank(admin);
        adapter.unpause();
        assertFalse(adapter.paused(), "Should not be paused");
        assertTrue(adapter.isActive(), "Should be active when unpaused");
    }

    // View Functions Tests

    function testConvertToShares() public {
        uint256 assets = 1000e6;
        uint256 shares = adapter.convertToShares(assets);
        assertEq(shares, assets, "Should be 1:1 when no deposits");

        // After deposit, ratio should change
        vm.startPrank(vault);
        usdt.approve(address(adapter), assets);
        adapter.deposit(assets);
        vm.stopPrank();

        // Set mock assets to simulate growth
        adapter.setMockTotalAssets(assets * 2);

        uint256 newShares = adapter.convertToShares(assets);
        assertLt(newShares, assets, "Shares should be less due to growth");
    }

    function testConvertToAssets() public {
        // First check conversion when adapter is empty
        uint256 shares = 1000e6;
        uint256 assets = adapter.convertToAssets(shares);
        assertEq(assets, shares, "Should return 1:1 when no strategy shares exist");

        // Now test after deposit
        uint256 depositAmount = 1000e6;

        vm.startPrank(vault);
        usdt.approve(address(adapter), depositAmount);
        uint256 receivedShares = adapter.deposit(depositAmount);
        vm.stopPrank();

        uint256 convertedAssets = adapter.convertToAssets(receivedShares);
        // Should convert back to exactly the deposited amount (1:1 ratio)
        assertEq(convertedAssets, depositAmount, "Should convert back to original amount");
    }

    function testGetAPY() public view {
        uint256 apy = adapter.getAPY();
        assertEq(apy, 1200, "APY should be 12%");
    }

    function testGetPendingRewards() public view {
        uint256 pending = adapter.getPendingRewards();
        assertEq(pending, 100e6, "Should have 100 USDT pending");
    }

    function testMaxDeposit() public view {
        uint256 maxDep = adapter.maxDeposit();
        assertEq(maxDep, type(uint256).max, "Should allow max deposit when active");
    }

    function testMaxDepositWhenInactive() public {
        vm.prank(admin);
        adapter.pause();

        uint256 maxDep = adapter.maxDeposit();
        assertEq(maxDep, 0, "Should not allow deposits when paused");
    }

    function testMaxWithdraw() public {
        uint256 depositAmount = 1000e6;

        vm.startPrank(vault);
        usdt.approve(address(adapter), depositAmount);
        adapter.deposit(depositAmount);
        vm.stopPrank();

        uint256 maxWith = adapter.maxWithdraw();
        assertGe(maxWith, depositAmount, "Should allow withdrawing at least deposited amount");
    }
}
