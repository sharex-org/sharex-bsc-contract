// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,function-max-lines
pragma solidity 0.8.24;

import {ShareXVault} from "../src/ShareXVault.sol";
import {MerchantInfo, MerchantParams} from "../src/libraries/DataTypes.sol";
import {
    EntityAlreadyExists,
    EntityNotFound,
    InvalidStringLength,
    MaintenanceModeActive
} from "../src/libraries/Errors.sol";
import {Test} from "forge-std/Test.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

contract ShareXVaultMerchantTest is Test {
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

    event MerchantRegistered(
        uint256 indexed merchantId,
        bytes32 indexed merchantName,
        bytes32 indexed merchantIdHash,
        bytes2 iso2,
        uint256 timestamp
    );

    function setUp() public {
        vault = new ShareXVault(admin);

        vm.startPrank(admin);
        vault.grantRole(OPERATOR_ROLE, operator);
        vm.stopPrank();
    }

    function testRegisterMerchantSuccess() public {
        MerchantParams memory params = _createValidMerchantParams();
        bytes32 expectedMerchantName = keccak256(abi.encodePacked(params.merchantName));
        bytes32 expectedMerchantId = keccak256(abi.encodePacked(params.merchantId));

        vm.expectEmit(true, true, true, true);
        emit MerchantRegistered(
            1, expectedMerchantName, expectedMerchantId, bytes2("US"), block.timestamp
        );

        vm.prank(operator);
        vault.registerMerchant(params);

        // Verify merchant was registered
        MerchantInfo memory merchant = vault.getMerchant(1);
        assertEq(merchant.id, 1);
        assertEq(merchant.merchantName, expectedMerchantName);
        assertEq(merchant.merchantId, expectedMerchantId);
        assertEq(merchant.description, params.description);
        assertEq(merchant.iso2, bytes2("US"));
        assertEq(merchant.locationId, keccak256(abi.encodePacked(params.locationId)));
        assertEq(merchant.location, keccak256(abi.encodePacked(params.location)));
        assertEq(merchant.merchantType, keccak256(abi.encodePacked(params.merchantType)));
        assertEq(merchant.verification, keccak256(abi.encodePacked(params.verification)));
        assertEq(merchant.timestamp, block.timestamp);

        // Verify merchant exists
        assertTrue(vault.merchantExists(expectedMerchantId));

        // Verify merchant can be retrieved by ID
        MerchantInfo memory merchantById = vault.getMerchantById(expectedMerchantId);
        assertEq(merchantById.id, merchant.id);
        assertEq(merchantById.merchantId, merchant.merchantId);
    }

    function testRegisterMerchantDuplicate() public {
        MerchantParams memory params = _createValidMerchantParams();
        bytes32 merchantId = keccak256(abi.encodePacked(params.merchantId));

        // Register first merchant
        vm.prank(operator);
        vault.registerMerchant(params);

        // Try to register duplicate
        vm.prank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(EntityAlreadyExists.selector, "merchant", merchantId)
        );
        vault.registerMerchant(params);
    }

    function testRegisterMerchantUnauthorized() public {
        MerchantParams memory params = _createValidMerchantParams();

        vm.prank(user);
        vm.expectRevert();
        vault.registerMerchant(params);
    }

    function testRegisterMerchantPaused() public {
        MerchantParams memory params = _createValidMerchantParams();

        vm.prank(admin);
        vault.emergencyPause();

        vm.prank(operator);
        vm.expectRevert();
        vault.registerMerchant(params);
    }

    function testRegisterMerchantMaintenanceMode() public {
        MerchantParams memory params = _createValidMerchantParams();

        vm.prank(admin);
        vault.setMaintenanceMode(true);

        vm.prank(operator);
        vm.expectRevert(MaintenanceModeActive.selector);
        vault.registerMerchant(params);
    }

    function testRegisterMerchantInvalidStringLengths() public {
        MerchantParams memory params = _createValidMerchantParams();

        // Test empty merchantName
        params.merchantName = "";
        vm.prank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(InvalidStringLength.selector, "merchantName", 1, 256)
        );
        vault.registerMerchant(params);

        // Test too long merchantName
        params.merchantName = _generateLongString(257);
        vm.prank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(InvalidStringLength.selector, "merchantName", 1, 256)
        );
        vault.registerMerchant(params);

        // Reset and test other fields
        params = _createValidMerchantParams();

        // Test empty merchantId
        params.merchantId = "";
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(InvalidStringLength.selector, "merchantId", 1, 256));
        vault.registerMerchant(params);

        // Test empty iso2
        params = _createValidMerchantParams();
        params.iso2 = "";
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(InvalidStringLength.selector, "iso2", 1, 256));
        vault.registerMerchant(params);

        // Test empty locationId
        params = _createValidMerchantParams();
        params.locationId = "";
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(InvalidStringLength.selector, "locationId", 1, 256));
        vault.registerMerchant(params);

        // Test empty location
        params = _createValidMerchantParams();
        params.location = "";
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(InvalidStringLength.selector, "location", 1, 256));
        vault.registerMerchant(params);

        // Test empty merchantType
        params = _createValidMerchantParams();
        params.merchantType = "";
        vm.prank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(InvalidStringLength.selector, "merchantType", 1, 256)
        );
        vault.registerMerchant(params);

        // Test empty verification
        params = _createValidMerchantParams();
        params.verification = "";
        vm.prank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(InvalidStringLength.selector, "verification", 1, 256)
        );
        vault.registerMerchant(params);
    }

    function testRegisterMerchantInvalidIso2Length() public {
        MerchantParams memory params = _createValidMerchantParams();

        // Test single character ISO2
        params.iso2 = "U";
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(InvalidStringLength.selector, "iso2", 2, 2));
        vault.registerMerchant(params);

        // Test three character ISO2
        params.iso2 = "USA";
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(InvalidStringLength.selector, "iso2", 2, 2));
        vault.registerMerchant(params);
    }

    function testRegisterMerchantMultipleMerchants() public {
        // Register multiple merchants
        for (uint256 i = 1; i <= 5; i++) {
            MerchantParams memory params = MerchantParams({
                merchantName: string(abi.encodePacked("Merchant ", Strings.toString(i))),
                merchantId: string(abi.encodePacked("MERCHANT00", Strings.toString(i))),
                description: abi.encodePacked("Description for merchant ", Strings.toString(i)),
                iso2: "US",
                locationId: string(abi.encodePacked("LOC00", Strings.toString(i))),
                location: string(abi.encodePacked("Location ", Strings.toString(i))),
                merchantType: "Retail",
                verification: string(abi.encodePacked("VER", Strings.toString(i)))
            });

            vm.prank(operator);
            vault.registerMerchant(params);

            // Verify merchant exists
            assertTrue(vault.merchantExists(keccak256(abi.encodePacked(params.merchantId))));
        }
    }

    function testGetMerchantNotFound() public {
        vm.expectRevert(
            abi.encodeWithSelector(EntityNotFound.selector, "merchant", bytes32(uint256(1)))
        );
        vault.getMerchant(1);

        bytes32 nonExistentId = keccak256("NONEXISTENT");
        vm.expectRevert(abi.encodeWithSelector(EntityNotFound.selector, "merchant", nonExistentId));
        vault.getMerchantById(nonExistentId);
    }

    function testMerchantExistsFalse() public view {
        assertFalse(vault.merchantExists(keccak256("NONEXISTENT")));
    }

    function _createValidMerchantParams() internal pure returns (MerchantParams memory) {
        return MerchantParams({
            merchantName: "Test Merchant",
            merchantId: "MERCHANT001",
            description: abi.encodePacked("Test merchant description"),
            iso2: "US",
            locationId: "NYC001",
            location: "New York City",
            merchantType: "Retail",
            verification: "VER123"
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
