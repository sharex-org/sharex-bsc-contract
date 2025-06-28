// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface
pragma solidity 0.8.24;

import {ShareXVault} from "../src/ShareXVault.sol";
import {CountryInfo} from "../src/libraries/DataTypes.sol";
import {
    EntityAlreadyExists,
    EntityNotFound,
    InvalidStringLength,
    MaintenanceModeActive
} from "../src/libraries/Errors.sol";
import {Test} from "forge-std/Test.sol";

contract ShareXVaultCountryTest is Test {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    ShareXVault public vault;

    address public admin = makeAddr("admin");
    address public operator = makeAddr("operator");
    address public user = makeAddr("user");

    event CountryRegistered(bytes2 indexed iso2, uint256 timestamp);

    function setUp() public {
        vault = new ShareXVault(admin);

        vm.startPrank(admin);
        vault.grantRole(OPERATOR_ROLE, operator);
        vm.stopPrank();
    }

    function testRegisterCountrySuccess() public {
        string memory iso2 = "US";

        vm.expectEmit(true, false, false, true);
        emit CountryRegistered(bytes2("US"), block.timestamp);

        vm.prank(operator);
        vault.registerCountry(iso2);

        // Verify country was registered
        CountryInfo memory country = vault.getCountry(bytes2("US"));
        assertEq(country.iso2, bytes2("US"));
        assertEq(country.timestamp, block.timestamp);

        // Verify country exists
        assertTrue(vault.countryExists(bytes2("US")));
    }

    function testRegisterCountryDuplicate() public {
        string memory iso2 = "US";

        // Register first country
        vm.prank(operator);
        vault.registerCountry(iso2);

        // Try to register duplicate
        vm.prank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(EntityAlreadyExists.selector, "country", bytes32("US"))
        );
        vault.registerCountry(iso2);
    }

    function testRegisterCountryUnauthorized() public {
        vm.prank(user);
        vm.expectRevert();
        vault.registerCountry("US");
    }

    function testRegisterCountryPaused() public {
        vm.prank(admin);
        vault.emergencyPause();

        vm.prank(operator);
        vm.expectRevert();
        vault.registerCountry("US");
    }

    function testRegisterCountryMaintenanceMode() public {
        vm.prank(admin);
        vault.setMaintenanceMode(true);

        vm.prank(operator);
        vm.expectRevert(MaintenanceModeActive.selector);
        vault.registerCountry("US");
    }

    function testRegisterCountryInvalidStringLengths() public {
        // Test empty ISO2
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(InvalidStringLength.selector, "iso2", 1, 256));
        vault.registerCountry("");

        // Test too long ISO2 (though this will fail at bytes2 conversion first)
        string memory longString = "TOOLONG";
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(InvalidStringLength.selector, "iso2", 2, 2));
        vault.registerCountry(longString);
    }

    function testRegisterCountryInvalidIso2Length() public {
        // Test single character
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(InvalidStringLength.selector, "iso2", 2, 2));
        vault.registerCountry("U");

        // Test three characters
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(InvalidStringLength.selector, "iso2", 2, 2));
        vault.registerCountry("USA");
    }

    function testRegisterCountryMultipleCountries() public {
        string[10] memory countries = ["US", "CA", "GB", "FR", "DE", "JP", "AU", "BR", "IN", "CN"];

        for (uint256 i = 0; i < countries.length; i++) {
            vm.prank(operator);
            vault.registerCountry(countries[i]);

            CountryInfo memory country = vault.getCountry(bytes2(abi.encodePacked(countries[i])));
            assertEq(country.iso2, bytes2(abi.encodePacked(countries[i])));
            assertTrue(vault.countryExists(bytes2(abi.encodePacked(countries[i]))));
        }
    }

    function testGetCountryNotFound() public {
        vm.expectRevert(abi.encodeWithSelector(EntityNotFound.selector, "country", bytes32("US")));
        vault.getCountry(bytes2("US"));
    }

    function testRegisterCountryCaseInsensitive() public {
        // Test lowercase
        vm.prank(operator);
        vault.registerCountry("us");

        // Test uppercase (should be different)
        vm.prank(operator);
        vault.registerCountry("US");

        // Both should exist as different entries
        assertTrue(vault.countryExists(bytes2("us")));
        assertTrue(vault.countryExists(bytes2("US")));

        CountryInfo memory countryLower = vault.getCountry(bytes2("us"));
        CountryInfo memory countryUpper = vault.getCountry(bytes2("US"));

        assertEq(countryLower.iso2, bytes2("us"));
        assertEq(countryUpper.iso2, bytes2("US"));
    }

    function testRegisterCountrySpecialCharacters() public {
        // These are not valid ISO codes but test the system's handling
        string[4] memory specialCodes = ["X1", "Z9", "00", "!@"];

        for (uint256 i = 0; i < specialCodes.length; i++) {
            vm.prank(operator);
            vault.registerCountry(specialCodes[i]);

            assertTrue(vault.countryExists(bytes2(abi.encodePacked(specialCodes[i]))));
        }
    }

    function testRegisterCountryRealIsoCodes() public {
        // Test with real ISO 3166-1 alpha-2 codes
        string[20] memory realCodes = [
            "AD",
            "AE",
            "AF",
            "AG",
            "AI",
            "AL",
            "AM",
            "AO",
            "AQ",
            "AR",
            "AS",
            "AT",
            "AU",
            "AW",
            "AX",
            "AZ",
            "BA",
            "BB",
            "BD",
            "BE"
        ];

        for (uint256 i = 0; i < realCodes.length; i++) {
            vm.prank(operator);
            vault.registerCountry(realCodes[i]);

            assertTrue(vault.countryExists(bytes2(abi.encodePacked(realCodes[i]))));
        }
    }

    function testCountryExistsFalse() public view {
        assertFalse(vault.countryExists(bytes2("US")));
        assertFalse(vault.countryExists(bytes2("XX")));
    }
}
