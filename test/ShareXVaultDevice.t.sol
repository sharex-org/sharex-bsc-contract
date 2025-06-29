// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,function-max-lines
pragma solidity 0.8.24;

import {ShareXVault} from "../src/ShareXVault.sol";
import {
    DeviceInfo, DeviceParams, MerchantParams, PartnerParams
} from "../src/libraries/DataTypes.sol";
import {
    EntityAlreadyExists,
    EntityNotFound,
    InvalidStringLength,
    MaintenanceModeActive
} from "../src/libraries/Errors.sol";
import {Test} from "forge-std/Test.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

contract ShareXVaultDeviceTest is Test {
    // ================================================================
    // Constants
    // ================================================================

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // ================================================================
    // State Variables
    // ================================================================

    ShareXVault public vault;

    address public admin = makeAddr("admin");
    address public operator = makeAddr("operator");
    address public user = makeAddr("user");

    event DeviceRegistered(
        uint256 indexed id,
        bytes32 indexed deviceId,
        bytes32 deviceType,
        bytes32 partnerCode,
        bytes32 merchantId,
        uint256 timestamp
    );

    function setUp() public {
        vault = new ShareXVault(admin);

        vm.startPrank(admin);
        vault.grantRole(OPERATOR_ROLE, operator);
        vm.stopPrank();

        // Register a partner and merchant for dependency tests
        _registerTestPartner();
        _registerTestMerchant();
    }

    function testRegisterDeviceSuccess() public {
        DeviceParams memory params = _createValidDeviceParams();
        bytes32 expectedDeviceId = keccak256(abi.encodePacked(params.deviceId));
        bytes32 expectedDeviceType = keccak256(abi.encodePacked(params.deviceType));
        bytes32 expectedPartnerCode = keccak256(abi.encodePacked(params.partnerCode));
        bytes32 expectedMerchantId = keccak256(abi.encodePacked(params.merchantId));

        vm.expectEmit(true, true, true, true);
        emit DeviceRegistered(
            1,
            expectedDeviceId,
            expectedDeviceType,
            expectedPartnerCode,
            expectedMerchantId,
            block.timestamp
        );

        vm.prank(operator);
        vault.registerDevice(params);

        // Verify device was registered
        DeviceInfo memory device = vault.getDevice(1);
        assertEq(device.id, 1);
        assertEq(device.deviceId, expectedDeviceId);
        assertEq(device.deviceType, expectedDeviceType);
        assertEq(device.partnerCode, expectedPartnerCode);
        assertEq(device.merchantId, expectedMerchantId);
        assertEq(device.timestamp, block.timestamp);

        // Verify device exists
        assertTrue(vault.deviceExists(expectedDeviceId));

        // Verify device can be retrieved by ID
        DeviceInfo memory deviceById = vault.getDeviceById(expectedDeviceId);
        assertEq(deviceById.id, device.id);
        assertEq(deviceById.deviceId, device.deviceId);
    }

    function testRegisterDeviceDuplicate() public {
        DeviceParams memory params = _createValidDeviceParams();
        bytes32 deviceId = keccak256(abi.encodePacked(params.deviceId));

        // Register first device
        vm.prank(operator);
        vault.registerDevice(params);

        // Try to register duplicate
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(EntityAlreadyExists.selector, "device", deviceId));
        vault.registerDevice(params);
    }

    function testRegisterDevicePartnerNotFound() public {
        DeviceParams memory params = DeviceParams({
            deviceId: "DEVICE001",
            deviceType: "POS_TERMINAL",
            partnerCode: "NONEXISTENT_PARTNER",
            merchantId: "MERCHANT001"
        });

        bytes32 partnerCode = keccak256(abi.encodePacked(params.partnerCode));

        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(EntityNotFound.selector, "partner", partnerCode));
        vault.registerDevice(params);
    }

    function testRegisterDeviceMerchantNotFound() public {
        DeviceParams memory params = DeviceParams({
            deviceId: "DEVICE001",
            deviceType: "POS_TERMINAL",
            partnerCode: "PARTNER001",
            merchantId: "NONEXISTENT_MERCHANT"
        });

        bytes32 merchantId = keccak256(abi.encodePacked(params.merchantId));

        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(EntityNotFound.selector, "merchant", merchantId));
        vault.registerDevice(params);
    }

    function testRegisterDeviceUnauthorized() public {
        DeviceParams memory params = _createValidDeviceParams();

        vm.prank(user);
        vm.expectRevert();
        vault.registerDevice(params);
    }

    function testRegisterDevicePaused() public {
        DeviceParams memory params = _createValidDeviceParams();

        vm.prank(admin);
        vault.emergencyPause();

        vm.prank(operator);
        vm.expectRevert();
        vault.registerDevice(params);
    }

    function testRegisterDeviceMaintenanceMode() public {
        DeviceParams memory params = _createValidDeviceParams();

        vm.prank(admin);
        vault.setMaintenanceMode(true);

        vm.prank(operator);
        vm.expectRevert(MaintenanceModeActive.selector);
        vault.registerDevice(params);
    }

    function testRegisterDeviceInvalidStringLengths() public {
        DeviceParams memory params = _createValidDeviceParams();

        // Test empty deviceId
        params.deviceId = "";
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(InvalidStringLength.selector, "deviceId", 1, 256));
        vault.registerDevice(params);

        // Test too long deviceId
        params.deviceId = _generateLongString(257);
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(InvalidStringLength.selector, "deviceId", 1, 256));
        vault.registerDevice(params);

        // Reset and test other fields
        params = _createValidDeviceParams();

        // Test empty deviceType
        params.deviceType = "";
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(InvalidStringLength.selector, "deviceType", 1, 256));
        vault.registerDevice(params);

        // Test empty partnerCode
        params = _createValidDeviceParams();
        params.partnerCode = "";
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(InvalidStringLength.selector, "partnerCode", 1, 256));
        vault.registerDevice(params);

        // Test empty merchantId
        params = _createValidDeviceParams();
        params.merchantId = "";
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(InvalidStringLength.selector, "merchantId", 1, 256));
        vault.registerDevice(params);
    }

    function testRegisterDeviceMultipleDevices() public {
        // Register multiple devices
        for (uint256 i = 1; i <= 5; i++) {
            DeviceParams memory params = DeviceParams({
                deviceId: string(abi.encodePacked("DEVICE", Strings.toString(i))),
                deviceType: "POS_TERMINAL",
                partnerCode: "PARTNER001",
                merchantId: "MERCHANT001"
            });

            vm.prank(operator);
            vault.registerDevice(params);

            // Verify device exists
            assertTrue(vault.deviceExists(keccak256(abi.encodePacked(params.deviceId))));
        }
    }

    function testGetDeviceNotFound() public {
        vm.expectRevert(
            abi.encodeWithSelector(EntityNotFound.selector, "device", bytes32(uint256(1)))
        );
        vault.getDevice(1);

        bytes32 nonExistentId = keccak256("NONEXISTENT");
        vm.expectRevert(abi.encodeWithSelector(EntityNotFound.selector, "device", nonExistentId));
        vault.getDeviceById(nonExistentId);
    }

    function testDeviceExistsFalse() public view {
        assertFalse(vault.deviceExists(keccak256("NONEXISTENT")));
    }

    function _registerTestPartner() internal {
        PartnerParams memory partnerParams = PartnerParams({
            partnerCode: "PARTNER001",
            partnerName: "Test Partner",
            iso2: "US",
            verification: "VER123",
            description: "Test Description",
            businessType: "Retail"
        });

        vm.prank(operator);
        vault.registerPartner(partnerParams);
    }

    function _registerTestMerchant() internal {
        MerchantParams memory merchantParams = MerchantParams({
            merchantName: "Test Merchant",
            merchantId: "MERCHANT001",
            description: abi.encodePacked("Test merchant description"),
            iso2: "US",
            locationId: "NYC001",
            location: "New York City",
            merchantType: "Retail",
            verification: "VER123"
        });

        vm.prank(operator);
        vault.registerMerchant(merchantParams);
    }

    function _createValidDeviceParams() internal pure returns (DeviceParams memory) {
        return DeviceParams({
            deviceId: "DEVICE001",
            deviceType: "POS_TERMINAL",
            partnerCode: "PARTNER001",
            merchantId: "MERCHANT001"
        });
    }

    function _generateLongString(uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            buffer[i] = bytes1(uint8(65 + (i % 26))); // A-Z repeating
        }
        return string(buffer);
    }
}
