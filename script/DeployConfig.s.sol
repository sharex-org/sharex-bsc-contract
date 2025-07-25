// SPDX-License-Identifier: MIT
// solhint-disable private-vars-leading-underscore,no-console
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

/// @title DeployConfig
/// @notice Represents the configuration required to deploy the ShareX system. It is expected
///         to read the file from JSON. A future improvement would be to have fallback
///         values if they are not defined in the JSON themselves.
contract DeployConfig is Script {
    string internal _json;

    address public proxyAdminOwner;
    address public vaultAdmin;

    // PayFi configuration
    address public yieldVaultAdmin;
    address public usdtToken;
    uint24 public poolFee;
    address public defiManager;

    constructor(string memory _path) {
        console.log("DeployConfig: reading file %s", _path);
        try vm.readFile(_path) returns (string memory data) {
            _json = data;
        } catch {
            console.log(
                "Warning: unable to read config. Do not deploy unless you are not using config."
            );
            return;
        }

        proxyAdminOwner = stdJson.readAddress(_json, "$.proxyAdminOwner");
        vaultAdmin = stdJson.readAddress(_json, "$.vaultAdmin");

        // PayFi configuration
        yieldVaultAdmin = stdJson.readAddress(_json, "$.yieldVaultAdmin");
        usdtToken = stdJson.readAddress(_json, "$.usdtToken");
        poolFee = uint24(stdJson.readUint(_json, "$.poolFee"));
        defiManager = stdJson.readAddress(_json, "$.defiManager");
    }
}
