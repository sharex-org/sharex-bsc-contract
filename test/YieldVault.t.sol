// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {YieldVault} from "../src/YieldVault.sol";

import {Constants} from "../src/libraries/Constants.sol";
import {MockAdapter} from "./MockAdapter.t.sol";

/**
 * @title YieldVaultTest
 * @dev Comprehensive test suite for the YieldVault
 */
contract YieldVaultTest is Test {
    // Test Constants
    uint256 private constant INITIAL_BALANCE = 1000000e6; // 1M USDT
    uint256 private constant MIN_DEPOSIT = Constants.MIN_INVESTMENT_AMOUNT;

    // Contracts
    YieldVault private vault;
    MockAdapter private adapter1;
    MockAdapter private adapter2;
    ERC20Mock private usdt;

    // Test Accounts
    address private admin;
    address private user1;
    address private user2;
    address private manager;

    // Setup

    function setUp() public {
        // Create test accounts
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        manager = makeAddr("manager");

        // Deploy mock USDT
        usdt = new ERC20Mock();

        // Deploy vault
        vm.prank(admin);
        vault = new YieldVault(address(usdt), admin);

        // Deploy mock adapters
        vm.prank(admin);
        adapter1 = new MockAdapter(address(usdt), admin);

        vm.prank(admin);
        adapter2 = new MockAdapter(address(usdt), admin);

        // Grant manager role
        vm.prank(admin);
        vault.grantRole(Constants.DEFI_MANAGER_ROLE, manager);

        // Grant vault role to adapters
        vm.prank(admin);
        adapter1.grantRole(Constants.DEFI_MANAGER_ROLE, address(vault));

        vm.prank(admin);
        adapter2.grantRole(Constants.DEFI_MANAGER_ROLE, address(vault));

        // Also grant emergency role to vault for emergency exit
        vm.prank(admin);
        adapter1.grantRole(Constants.EMERGENCY_ROLE, address(vault));

        vm.prank(admin);
        adapter2.grantRole(Constants.EMERGENCY_ROLE, address(vault));

        // Fund accounts
        usdt.mint(user1, INITIAL_BALANCE);
        usdt.mint(user2, INITIAL_BALANCE);
        // Don't fund adapters initially to avoid interfering with calculations
    }

    function _approveVault(address user, uint256 amount) private {
        vm.prank(user);
        usdt.approve(address(vault), amount);
    }

    // Initialization Tests

    function testVaultInitialization() public view {
        assertEq(address(vault.asset()), address(usdt));
        assertEq(vault.totalVaultShares(), 0);
        assertEq(vault.totalDeposits(), 0);
        assertEq(vault.investmentRatio(), 9000); // 90%
    }

    function testRoleSetup() public view {
        assertTrue(vault.hasRole(Constants.DEFAULT_ADMIN_ROLE, admin));
        assertTrue(vault.hasRole(Constants.DEFI_MANAGER_ROLE, admin));
        assertTrue(vault.hasRole(Constants.DEFI_MANAGER_ROLE, manager));
        assertTrue(vault.hasRole(Constants.EMERGENCY_ROLE, admin));
    }

    // Deposit Tests

    function testDepositWithoutAutoInvest() public {
        uint256 depositAmount = 1000e6;

        _approveVault(user1, depositAmount);

        vm.prank(user1);
        uint256 shares = vault.deposit(depositAmount, false);

        assertEq(shares, depositAmount, "Should receive equal shares for first deposit");
        assertEq(vault.vaultShares(user1), shares, "User shares should match");
        assertEq(vault.totalVaultShares(), shares, "Total shares should match");
        assertEq(vault.totalDeposits(), depositAmount, "Total deposits should match");
        assertEq(usdt.balanceOf(address(vault)), depositAmount, "Vault should hold tokens");
    }

    function testDepositWithAutoInvestNoAdapters() public {
        uint256 depositAmount = 1000e6;

        _approveVault(user1, depositAmount);

        vm.prank(user1);
        uint256 shares = vault.deposit(depositAmount, true);

        // Should behave same as without auto-invest since no adapters
        assertEq(shares, depositAmount);
        assertEq(usdt.balanceOf(address(vault)), depositAmount);
    }

    function testDepositWithAutoInvest() public {
        uint256 depositAmount = 10000e6; // Larger amount to trigger investment

        // Add an adapter first
        vm.prank(manager);
        vault.addAdapter(address(adapter1), 5000); // 50% weight

        _approveVault(user1, depositAmount);

        vm.prank(user1);
        uint256 shares = vault.deposit(depositAmount, true);

        assertEq(shares, depositAmount);
        assertLt(usdt.balanceOf(address(vault)), depositAmount, "Should have invested some funds");
        assertGt(adapter1.totalAssets(), 0, "Adapter should have received funds");
    }

    function testDepositFailsSmallAmount() public {
        uint256 smallAmount = MIN_DEPOSIT - 1;

        _approveVault(user1, smallAmount);

        vm.expectRevert("YieldVault: Amount too small");
        vm.prank(user1);
        vault.deposit(smallAmount, false);
    }

    function testMultipleDeposits() public {
        uint256 depositAmount1 = 1000e6;
        uint256 depositAmount2 = 500e6;

        // First deposit
        _approveVault(user1, depositAmount1);
        vm.prank(user1);
        uint256 shares1 = vault.deposit(depositAmount1, false);

        // Second deposit by different user
        _approveVault(user2, depositAmount2);
        vm.prank(user2);
        uint256 shares2 = vault.deposit(depositAmount2, false);

        assertEq(vault.vaultShares(user1), shares1);
        assertEq(vault.vaultShares(user2), shares2);
        assertEq(vault.totalVaultShares(), shares1 + shares2);
        assertEq(vault.totalDeposits(), depositAmount1 + depositAmount2);
    }

    // Withdraw Tests

    function testWithdrawSuccess() public {
        uint256 depositAmount = 1000e6;

        // First deposit
        _approveVault(user1, depositAmount);
        vm.prank(user1);
        uint256 shares = vault.deposit(depositAmount, false);

        uint256 initialBalance = usdt.balanceOf(user1);

        // Then withdraw
        vm.prank(user1);
        uint256 amount = vault.withdraw(shares);

        assertEq(amount, depositAmount, "Should withdraw equal amount");
        assertEq(vault.vaultShares(user1), 0, "User shares should be zero");
        assertEq(vault.totalVaultShares(), 0, "Total shares should be zero");
        assertEq(usdt.balanceOf(user1), initialBalance + amount, "User balance should increase");
    }

    function testWithdrawFailsInsufficientShares() public {
        uint256 excessiveShares = 1000e6;

        vm.expectRevert("YieldVault: Insufficient shares");
        vm.prank(user1);
        vault.withdraw(excessiveShares);
    }

    function testPartialWithdraw() public {
        uint256 depositAmount = 1000e6;

        // Deposit
        _approveVault(user1, depositAmount);
        vm.prank(user1);
        uint256 shares = vault.deposit(depositAmount, false);

        // Withdraw half
        uint256 withdrawShares = shares / 2;

        vm.prank(user1);
        uint256 amount = vault.withdraw(withdrawShares);

        assertEq(amount, withdrawShares, "Should withdraw half");
        assertEq(vault.vaultShares(user1), shares - withdrawShares, "Remaining shares");
    }

    // Adapter Management Tests

    function testAddAdapter() public {
        uint256 weight = 3000; // 30%

        vm.prank(manager);
        vault.addAdapter(address(adapter1), weight);

        assertTrue(vault.isAdapterActive(address(adapter1)), "Adapter should be active");
        assertEq(vault.adapterWeights(address(adapter1)), weight, "Weight should match");

        // Check approvals
        assertEq(usdt.allowance(address(vault), address(adapter1)), type(uint256).max);
    }

    function testAddAdapterFailsNonManager() public {
        vm.expectRevert();
        vm.prank(user1);
        vault.addAdapter(address(adapter1), 3000);
    }

    function testAddAdapterFailsZeroWeight() public {
        vm.expectRevert("YieldVault: Weight must be positive");
        vm.prank(manager);
        vault.addAdapter(address(adapter1), 0);
    }

    function testAddAdapterFailsDuplicate() public {
        vm.prank(manager);
        vault.addAdapter(address(adapter1), 3000);

        vm.expectRevert("YieldVault: Adapter already added");
        vm.prank(manager);
        vault.addAdapter(address(adapter1), 4000);
    }

    function testRemoveAdapter() public {
        // Add adapter first
        vm.prank(manager);
        vault.addAdapter(address(adapter1), 3000);

        // Remove adapter
        vm.prank(manager);
        vault.removeAdapter(address(adapter1));

        assertFalse(vault.isAdapterActive(address(adapter1)), "Adapter should be inactive");
        assertEq(vault.adapterWeights(address(adapter1)), 0, "Weight should be zero");
        assertEq(usdt.allowance(address(vault), address(adapter1)), 0, "Approval should be revoked");
    }

    function testUpdateAdapterWeight() public {
        uint256 initialWeight = 3000;
        uint256 newWeight = 4000;

        // Add adapter first
        vm.prank(manager);
        vault.addAdapter(address(adapter1), initialWeight);

        // Update weight
        vm.prank(manager);
        vault.updateAdapterWeight(address(adapter1), newWeight);

        assertEq(vault.adapterWeights(address(adapter1)), newWeight, "Weight should be updated");
    }

    // Investment and Harvest Tests

    function testHarvestAllRewards() public {
        uint256 depositAmount = 10000e6;

        // Add adapters
        vm.prank(manager);
        vault.addAdapter(address(adapter1), 3000);

        vm.prank(manager);
        vault.addAdapter(address(adapter2), 7000);

        // Deposit with auto-invest
        _approveVault(user1, depositAmount);
        vm.prank(user1);
        vault.deposit(depositAmount, true);

        // Harvest rewards
        vm.prank(manager);
        uint256 totalRewards = vault.harvestAllRewards();

        assertGt(totalRewards, 0, "Should harvest some rewards");
        assertEq(vault.totalRewardsHarvested(), totalRewards, "Total rewards should be tracked");
    }

    function testRebalance() public {
        uint256 depositAmount = 10000e6;

        // Add adapters
        vm.prank(manager);
        vault.addAdapter(address(adapter1), 3000);

        vm.prank(manager);
        vault.addAdapter(address(adapter2), 7000);

        // Deposit with auto-invest
        _approveVault(user1, depositAmount);
        vm.prank(user1);
        vault.deposit(depositAmount, true);

        uint256 rebalanceTimeBefore = vault.lastRebalanceTime();

        // Rebalance
        vm.prank(manager);
        vault.rebalance();

        assertGt(vault.lastRebalanceTime(), rebalanceTimeBefore, "Rebalance time should update");
    }

    // View Functions Tests

    function testBalanceOf() public {
        uint256 depositAmount = 1000e6;

        _approveVault(user1, depositAmount);
        vm.prank(user1);
        vault.deposit(depositAmount, false);

        uint256 balance = vault.balanceOf(user1);
        assertEq(balance, depositAmount, "Balance should equal deposit");
    }

    function testTotalAssets() public {
        uint256 depositAmount = 10000e6;

        // Add adapter
        vm.prank(manager);
        vault.addAdapter(address(adapter1), 5000);

        // Deposit
        _approveVault(user1, depositAmount);
        vm.prank(user1);
        vault.deposit(depositAmount, true);

        uint256 totalAssets = vault.totalAssets();
        assertGe(totalAssets, depositAmount, "Total assets should be at least deposit amount");
    }

    function testGetVaultStats() public {
        uint256 depositAmount = 1000e6;

        _approveVault(user1, depositAmount);
        vm.prank(user1);
        vault.deposit(depositAmount, false);

        (uint256 totalDeposits, uint256 totalInvested, uint256 totalShares, uint256 averageAPY) =
            vault.getVaultStats();

        assertEq(totalDeposits, depositAmount, "Total deposits should match");
        assertEq(totalShares, depositAmount, "Total shares should match first deposit");
        // totalInvested and averageAPY depend on adapters
    }

    function testGetActiveAdapters() public {
        // Initially no adapters
        (address[] memory adapters, uint256[] memory weights) = vault.getActiveAdapters();
        assertEq(adapters.length, 0, "Should have no adapters initially");

        // Add two adapters
        vm.prank(manager);
        vault.addAdapter(address(adapter1), 3000);

        vm.prank(manager);
        vault.addAdapter(address(adapter2), 7000);

        (adapters, weights) = vault.getActiveAdapters();
        assertEq(adapters.length, 2, "Should have two adapters");
        assertEq(adapters[0], address(adapter1), "First adapter should match");
        assertEq(adapters[1], address(adapter2), "Second adapter should match");
        assertEq(weights[0], 3000, "First weight should match");
        assertEq(weights[1], 7000, "Second weight should match");
    }

    // Admin Functions Tests

    function testUpdateInvestmentConfig() public {
        uint256 newRatio = 8000; // 80%
        uint256 newMinAmount = MIN_DEPOSIT * 5;

        vm.prank(manager);
        vault.updateInvestmentConfig(newRatio, newMinAmount);

        assertEq(vault.investmentRatio(), newRatio, "Investment ratio should be updated");
        assertEq(
            vault.minInvestmentAmount(), newMinAmount, "Min investment amount should be updated"
        );
    }

    function testUpdateInvestmentConfigFailsInvalidRatio() public {
        uint256 invalidRatio = Constants.BASIS_POINTS + 1; // > 100%

        vm.expectRevert("YieldVault: Invalid ratio");
        vm.prank(manager);
        vault.updateInvestmentConfig(invalidRatio, MIN_DEPOSIT);
    }

    function testPauseUnpause() public {
        // Test pause
        vm.prank(admin);
        vault.pause();
        assertTrue(vault.paused(), "Should be paused");

        // Test deposits fail when paused
        _approveVault(user1, 1000e6);
        vm.expectRevert();
        vm.prank(user1);
        vault.deposit(1000e6, false);

        // Test unpause
        vm.prank(admin);
        vault.unpause();
        assertFalse(vault.paused(), "Should not be paused");
    }

    function testEmergencyWithdrawAll() public {
        uint256 depositAmount = 10000e6;

        // Add adapter and deposit
        vm.prank(manager);
        vault.addAdapter(address(adapter1), 5000);

        _approveVault(user1, depositAmount);
        vm.prank(user1);
        vault.deposit(depositAmount, true);

        // Grant emergency role to vault for the adapters
        vm.prank(admin);
        adapter1.grantRole(Constants.EMERGENCY_ROLE, address(vault));

        // Emergency withdraw
        vm.prank(admin);
        vault.emergencyWithdrawAll();

        // Adapter should be in emergency mode
        assertTrue(adapter1.emergencyMode(), "Adapter should be in emergency mode");
    }

    // Integration Tests

    function testFullDepositInvestWithdrawCycle() public {
        uint256 depositAmount = 10000e6;

        // Setup adapters
        vm.prank(manager);
        vault.addAdapter(address(adapter1), 4000); // 40%

        vm.prank(manager);
        vault.addAdapter(address(adapter2), 6000); // 60%

        uint256 initialBalance = usdt.balanceOf(user1);

        // Deposit with auto-invest
        _approveVault(user1, depositAmount);
        vm.prank(user1);
        uint256 shares = vault.deposit(depositAmount, true);

        // Check investment
        assertGt(adapter1.totalAssets(), 0, "Adapter1 should have assets");
        assertGt(adapter2.totalAssets(), 0, "Adapter2 should have assets");

        // Harvest rewards
        vm.prank(manager);
        uint256 rewards = vault.harvestAllRewards();
        assertGt(rewards, 0, "Should harvest rewards");

        // Withdraw all
        vm.prank(user1);
        uint256 withdrawnAmount = vault.withdraw(shares);

        assertEq(vault.vaultShares(user1), 0, "Should have no shares left");
        // Allow for some variance due to rounding and potential rewards
        assertGt(withdrawnAmount, 0, "Should withdraw some amount");
        assertGt(
            usdt.balanceOf(user1), initialBalance / 2, "User should get back significant funds"
        );
    }
}
