// solhint-disable comprehensive-interface
pragma solidity 0.8.24;

import {ShareXVault} from "../src/ShareXVault.sol";
import {StatsInfo, SystemState, Version} from "../src/libraries/DataTypes.sol";
import {
    InsufficientBalance,
    InvalidAdminAddress,
    InvalidRecipientAddress
} from "../src/libraries/Errors.sol";
import {
    EmergencyActionTaken,
    EthDeposited,
    EthWithdrawn,
    MaintenanceModeToggled
} from "../src/libraries/Events.sol";
import {Test} from "forge-std/Test.sol";

contract ShareXVaultTest is Test {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    address public constant admin = address(0x1111);
    address public constant operator = address(0x2222);
    address public constant user = address(0x3333);
    address public constant recipient = address(0x4444);

    ShareXVault public vault;

    function setUp() public {
        vault = new ShareXVault(admin);

        // Grant operator role to operator address
        vm.startPrank(admin);
        vault.grantRole(OPERATOR_ROLE, operator);
        vm.stopPrank();
    }

    function testConstructor() public {
        ShareXVault newVault = new ShareXVault(admin);

        // Check admin role
        vm.assertTrue(newVault.hasRole(newVault.DEFAULT_ADMIN_ROLE(), admin));
        vm.assertTrue(newVault.hasRole(OPERATOR_ROLE, admin));

        // Check initial version
        Version memory version = newVault.getVersion();
        vm.assertEq(version.major, 1);
        vm.assertEq(version.minor, 0);
        vm.assertEq(version.patch, 0);

        // Check initial state
        SystemState memory state = newVault.getSystemState();
        vm.assertFalse(state.maintenanceMode);
    }

    function testConstructorFail() public {
        vm.expectRevert(InvalidAdminAddress.selector);
        new ShareXVault(address(0));
    }

    function testReceiveEther() public {
        uint256 amount = 1 ether;

        vm.expectEmit(true, false, false, true);
        emit EthDeposited(user, amount, block.timestamp);

        vm.deal(user, amount);
        vm.prank(user);
        (bool success,) = address(vault).call{value: amount}("");
        vm.assertTrue(success);

        vm.assertEq(address(vault).balance, amount);
    }

    function testSetMaintenanceMode() public {
        vm.expectEmit(false, false, false, true);
        emit MaintenanceModeToggled(true, block.timestamp);

        vm.prank(admin);
        vault.setMaintenanceMode(true);

        SystemState memory state = vault.getSystemState();
        vm.assertTrue(state.maintenanceMode);

        // Toggle back
        vm.prank(admin);
        vault.setMaintenanceMode(false);

        state = vault.getSystemState();
        vm.assertFalse(state.maintenanceMode);
    }

    function testSetMaintenanceModeFail() public {
        vm.prank(user);
        vm.expectRevert();
        vault.setMaintenanceMode(true);
    }

    function testEmergencyPause() public {
        vm.expectEmit(false, false, false, true);
        emit EmergencyActionTaken("emergency_pause", admin, block.timestamp);

        vm.prank(admin);
        vault.emergencyPause();

        vm.assertTrue(vault.paused());
    }

    function testEmergencyPauseFail() public {
        vm.prank(user);
        vm.expectRevert();
        vault.emergencyPause();
    }

    function testUnpause() public {
        // First pause
        vm.prank(admin);
        vault.emergencyPause();
        vm.assertTrue(vault.paused());

        // Then unpause
        vm.prank(admin);
        vault.unpause();
        vm.assertFalse(vault.paused());
    }

    function testUnpauseFail() public {
        vm.prank(admin);
        vault.emergencyPause();

        vm.prank(user);
        vm.expectRevert();
        vault.unpause();
    }

    function testWithdrawEth() public {
        uint256 amount = 1 ether;
        uint256 withdrawAmount = 0.5 ether;

        // Send ETH to contract
        vm.deal(address(vault), amount);

        uint256 recipientBalanceBefore = recipient.balance;

        vm.expectEmit(true, false, false, true);
        emit EthWithdrawn(recipient, withdrawAmount, block.timestamp);

        vm.prank(admin);
        vault.withdrawEth(payable(recipient), withdrawAmount);

        vm.assertEq(recipient.balance, recipientBalanceBefore + withdrawAmount);
        vm.assertEq(address(vault).balance, amount - withdrawAmount);
    }

    function testWithdrawEthFail() public {
        // Test invalid recipient
        vm.deal(address(vault), 1 ether);

        vm.prank(admin);
        vm.expectRevert(InvalidRecipientAddress.selector);
        vault.withdrawEth(payable(address(0)), 0.5 ether);

        // Test insufficient balance
        vm.deal(address(vault), 0.5 ether);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(InsufficientBalance.selector, 1 ether, 0.5 ether));
        vault.withdrawEth(payable(recipient), 1 ether);

        // Test unauthorized
        vm.deal(address(vault), 1 ether);

        vm.prank(user);
        vm.expectRevert();
        vault.withdrawEth(payable(recipient), 0.5 ether);
    }

    function testAccessControl() public view {
        // Test DEFAULT_ADMIN_ROLE
        vm.assertTrue(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), admin));
        vm.assertFalse(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), user));

        // Test OPERATOR_ROLE
        vm.assertTrue(vault.hasRole(OPERATOR_ROLE, admin));
        vm.assertTrue(vault.hasRole(OPERATOR_ROLE, operator));
        vm.assertFalse(vault.hasRole(OPERATOR_ROLE, user));
    }

    function testGetVersion() public view {
        Version memory version = vault.getVersion();
        vm.assertEq(version.major, 1);
        vm.assertEq(version.minor, 0);
        vm.assertEq(version.patch, 0);
    }

    function testGetSystemState() public view {
        SystemState memory state = vault.getSystemState();
        vm.assertEq(state.version.major, 1);
        vm.assertEq(state.version.minor, 0);
        vm.assertEq(state.version.patch, 0);
        vm.assertFalse(state.maintenanceMode);
    }

    function testGetStats() public view {
        StatsInfo memory stats = vault.getStats();
        vm.assertEq(stats.partnersCount, 0);
        vm.assertEq(stats.merchantsCount, 0);
        vm.assertEq(stats.devicesCount, 0);
        vm.assertEq(stats.transactionBatchesCount, 0);
        vm.assertEq(stats.countriesCount, 0);
        vm.assertEq(stats.contractBalance, 0);
    }
}
