// SPDX-License-Identifier: MIT
// solhint-disable no-console,ordering,custom-errors
pragma solidity 0.8.24;

import {ShareXVault} from "../src/ShareXVault.sol";
import {DeployConfig} from "./DeployConfig.s.sol";
import {Deployer} from "./Deployer.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {console} from "forge-std/console.sol";

contract Deploy is Deployer {
    DeployConfig internal _cfg;

    /// @notice Modifier that wraps a function in broadcasting.
    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    /// @notice The name of the script, used to ensure the right deploy artifacts
    ///         are used.
    function name() public pure override returns (string memory name_) {
        name_ = "Deploy";
    }

    function setUp() public override {
        super.setUp();
        string memory path =
            string.concat(vm.projectRoot(), "/deploy-config/", deploymentContext, ".json");
        _cfg = new DeployConfig(path);

        console.log("Deploying from %s", deployScript);
        console.log("Deployment context: %s", deploymentContext);
    }

    /* solhint-disable comprehensive-interface */
    function run() external {
        deployImplementations();
        deployProxies();
        initializeContracts();
    }

    /// @notice Deploy all of the logic contracts
    function deployImplementations() public broadcast {
        deployShareXVault();
    }

    /// @notice Deploy all of the proxies
    function deployProxies() public broadcast {
        deployShareXVaultProxy();
    }

    /// @notice Initialize all contracts
    function initializeContracts() public broadcast {
        initializeShareXVault();
    }

    function deployShareXVault() public returns (address addr) {
        console.log("Deploying ShareXVault.sol");
        address admin = _cfg.vaultAdmin();
        ShareXVault vault = new ShareXVault(admin);

        save("ShareXVault", address(vault));
        console.log("ShareXVault deployed at %s", address(vault));
        addr = address(vault);
    }

    function deployShareXVaultProxy() public returns (address addr) {
        address logic = mustGetAddress("ShareXVault");

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy({
            _logic: logic,
            initialOwner: _cfg.proxyAdminOwner(),
            _data: ""
        });

        save("ShareXVaultProxy", address(proxy));
        console.log("ShareXVaultProxy deployed at %s", address(proxy));
        console.log("Proxy admin owner: %s", _cfg.proxyAdminOwner());
        addr = address(proxy);
    }

    function initializeShareXVault() public view {
        // No initialization needed - constructor handles setup
        console.log("ShareXVault deployment completed - no initialization needed");
    }
}
