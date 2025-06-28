// solhint-disable no-console,comprehensive-interface,quotes
pragma solidity 0.8.24;

import {ShareXVault} from "../src/ShareXVault.sol";
import {PartnerInfo, PartnerParams} from "../src/libraries/DataTypes.sol";
import {
    EntityAlreadyExists,
    EntityNotFound,
    InvalidStringLength,
    MaintenanceModeActive
} from "../src/libraries/Errors.sol";
import {PartnerRegistered} from "../src/libraries/Events.sol";
import {Test} from "forge-std/Test.sol";

contract ShareXVaultPartnerTest is Test {
    // ================================================================
    // Constants
    // ================================================================

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    address public constant admin = address(0x1111);
    address public constant operator = address(0x2222);
    address public constant user = address(0x3333);

    // ================================================================
    // State Variables
    // ================================================================

    ShareXVault public vault;

    function setUp() public {
        vault = new ShareXVault(admin);

        vm.startPrank(admin);
        vault.grantRole(OPERATOR_ROLE, operator);
        vm.stopPrank();
    }

    function testRegisterPartner() public {
        PartnerParams memory params = _createValidPartnerParams();
        bytes32 expectedPartnerCode = keccak256(abi.encodePacked(params.partnerCode));

        vm.expectEmit(true, true, false, true);
        emit PartnerRegistered(
            1, expectedPartnerCode, params.partnerName, bytes2("US"), block.timestamp
        );

        vm.prank(operator);
        vault.registerPartner(params);

        // Verify partner was registered
        PartnerInfo memory partner = vault.getPartner(1);
        vm.assertEq(partner.id, 1);
        vm.assertEq(partner.partnerCode, expectedPartnerCode);
        vm.assertEq(partner.partnerName, params.partnerName);
        vm.assertEq(partner.iso2, bytes2("US"));
        vm.assertEq(partner.verification, keccak256(abi.encodePacked(params.verification)));
        vm.assertEq(partner.description, params.description);
        vm.assertEq(partner.businessType, params.businessType);
        vm.assertEq(partner.timestamp, block.timestamp);

        // Verify partner exists
        vm.assertTrue(vault.partnerExists(expectedPartnerCode));

        // Verify partner can be retrieved by code
        PartnerInfo memory partnerByCode = vault.getPartnerByCode(expectedPartnerCode);
        vm.assertEq(partnerByCode.id, partner.id);
        vm.assertEq(partnerByCode.partnerCode, partner.partnerCode);
    }

    function testRegisterPartnerFail() public {
        PartnerParams memory params = _createValidPartnerParams();
        bytes32 partnerCode = keccak256(abi.encodePacked(params.partnerCode));

        // Test duplicate registration
        vm.prank(operator);
        vault.registerPartner(params);

        vm.prank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(EntityAlreadyExists.selector, "partner", partnerCode)
        );
        vault.registerPartner(params);

        // Test unauthorized
        vm.prank(user);
        vm.expectRevert();
        vault.registerPartner(params);

        // Test paused state
        vm.prank(admin);
        vault.emergencyPause();

        vm.prank(operator);
        vm.expectRevert();
        vault.registerPartner(params);

        // Unpause for maintenance mode test
        vm.prank(admin);
        vault.unpause();

        // Test maintenance mode
        vm.prank(admin);
        vault.setMaintenanceMode(true);

        vm.prank(operator);
        vm.expectRevert(MaintenanceModeActive.selector);
        vault.registerPartner(params);
    }

    function testRegisterPartnerInvalidStringLengths() public {
        PartnerParams memory params = _createValidPartnerParams();

        // Test empty partnerCode
        params.partnerCode = "";
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(InvalidStringLength.selector, "partnerCode", 1, 256));
        vault.registerPartner(params);

        // Test too long partnerCode
        params.partnerCode = _generateLongString(257);
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(InvalidStringLength.selector, "partnerCode", 1, 256));
        vault.registerPartner(params);

        // Reset and test other fields
        params = _createValidPartnerParams();

        // Test empty partnerName
        params.partnerName = "";
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(InvalidStringLength.selector, "partnerName", 1, 256));
        vault.registerPartner(params);

        // Test empty iso2
        params = _createValidPartnerParams();
        params.iso2 = "";
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(InvalidStringLength.selector, "iso2", 1, 256));
        vault.registerPartner(params);

        // Test empty verification
        params = _createValidPartnerParams();
        params.verification = "";
        vm.prank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(InvalidStringLength.selector, "verification", 1, 256)
        );
        vault.registerPartner(params);

        // Test empty description
        params = _createValidPartnerParams();
        params.description = "";
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(InvalidStringLength.selector, "description", 1, 256));
        vault.registerPartner(params);

        // Test empty businessType
        params = _createValidPartnerParams();
        params.businessType = "";
        vm.prank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(InvalidStringLength.selector, "businessType", 1, 256)
        );
        vault.registerPartner(params);
    }

    function testRegisterPartnerInvalidIso2Length() public {
        PartnerParams memory params = _createValidPartnerParams();

        // Test single character ISO2
        params.iso2 = "U";
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(InvalidStringLength.selector, "iso2", 2, 2));
        vault.registerPartner(params);

        // Test three character ISO2
        params.iso2 = "USA";
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(InvalidStringLength.selector, "iso2", 2, 2));
        vault.registerPartner(params);
    }

    function testRegisterPartnerMultiplePartners() public {
        // Register first partner
        PartnerParams memory params1 = _createValidPartnerParams();
        vm.prank(operator);
        vault.registerPartner(params1);

        // Register second partner
        PartnerParams memory params2 = PartnerParams({
            partnerCode: "PARTNER002",
            partnerName: "Second Partner",
            iso2: "CA",
            verification: "VER456",
            description: "Second Description",
            businessType: "Technology"
        });
        vm.prank(operator);
        vault.registerPartner(params2);

        // Verify both partners exist
        PartnerInfo memory partner1 = vault.getPartner(1);
        PartnerInfo memory partner2 = vault.getPartner(2);

        vm.assertEq(partner1.id, 1);
        vm.assertEq(partner2.id, 2);
        vm.assertTrue(vault.partnerExists(keccak256(abi.encodePacked(params1.partnerCode))));
        vm.assertTrue(vault.partnerExists(keccak256(abi.encodePacked(params2.partnerCode))));
    }

    function testGetPartnerNotFound() public {
        vm.expectRevert(
            abi.encodeWithSelector(EntityNotFound.selector, "partner", bytes32(uint256(1)))
        );
        vault.getPartner(1);

        bytes32 nonExistentCode = keccak256("NONEXISTENT");
        vm.expectRevert(abi.encodeWithSelector(EntityNotFound.selector, "partner", nonExistentCode));
        vault.getPartnerByCode(nonExistentCode);
    }

    function testPartnerExistsFalse() public view {
        vm.assertFalse(vault.partnerExists(keccak256("NONEXISTENT")));
    }

    function _createValidPartnerParams() internal pure returns (PartnerParams memory) {
        return PartnerParams({
            partnerCode: "PARTNER001",
            partnerName: "Test Partner",
            iso2: "US",
            verification: "VER123",
            description: "Test Description",
            businessType: "Retail"
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
