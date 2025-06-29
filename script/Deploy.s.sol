// SPDX-License-Identifier: MIT
// solhint-disable no-console,ordering,custom-errors
pragma solidity 0.8.24;

import {ShareXVault} from "../src/ShareXVault.sol";
import {YieldVault} from "../src/YieldVault.sol";
import {PancakeSwapV3Adapter} from "../src/adapters/PancakeSwapV3Adapter.sol";
import {Constants} from "../src/libraries/Constants.sol";
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
        deployYieldVault();
        deployPancakeSwapV3Adapter();
    }

    /// @notice Deploy all of the proxies
    function deployProxies() public broadcast {
        deployShareXVaultProxy();
        deployYieldVaultProxy();
    }

    /// @notice Initialize all contracts
    function initializeContracts() public broadcast {
        initializeShareXVault();
        initializePayFiEcosystem();
    }

    function deployShareXVault() public returns (address addr) {
        console.log("Deploying ShareXVault.sol");
        address admin = _cfg.vaultAdmin();
        ShareXVault vault = new ShareXVault(admin);

        save("ShareXVault", address(vault));
        console.log("ShareXVault deployed at %s", address(vault));
        addr = address(vault);
    }

    function deployYieldVault() public returns (address addr) {
        console.log("Deploying YieldVault.sol");
        address assetAddress = _cfg.usdtToken();
        address admin = _cfg.yieldVaultAdmin();
        YieldVault yieldVault = new YieldVault(assetAddress, admin);

        save("YieldVault", address(yieldVault));
        console.log("YieldVault deployed at %s", address(yieldVault));
        addr = address(yieldVault);
    }

    function deployPancakeSwapV3Adapter() public returns (address addr) {
        console.log("Deploying PancakeSwapV3Adapter.sol");
        address admin = _cfg.defiManager();
        uint24 poolFee = _cfg.poolFee();
        PancakeSwapV3Adapter adapter = new PancakeSwapV3Adapter(admin, poolFee);

        save("PancakeSwapV3Adapter", address(adapter));
        console.log("PancakeSwapV3Adapter deployed at %s", address(adapter));
        addr = address(adapter);
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

    function deployYieldVaultProxy() public returns (address addr) {
        address logic = mustGetAddress("YieldVault");

        // Prepare initialization data for YieldVault
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,address)", _cfg.usdtToken(), _cfg.yieldVaultAdmin()
        );

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy({
            _logic: logic,
            initialOwner: _cfg.proxyAdminOwner(),
            _data: initData
        });

        save("YieldVaultProxy", address(proxy));
        console.log("YieldVaultProxy deployed at %s", address(proxy));
        console.log("Proxy admin owner: %s", _cfg.proxyAdminOwner());
        addr = address(proxy);
    }

    function initializeShareXVault() public view {
        // No initialization needed - constructor handles setup
        console.log("ShareXVault deployment completed - no initialization needed");
    }

    function initializePayFiEcosystem() public {
        console.log("Initializing PayFi ecosystem...");

        // Get deployed contract addresses
        address yieldVaultProxy = mustGetAddress("YieldVaultProxy");
        address pancakeAdapter = mustGetAddress("PancakeSwapV3Adapter");

        // Initialize YieldVault with adapter
        YieldVault vault = YieldVault(yieldVaultProxy);

        // Grant DEFI_MANAGER_ROLE to deployer temporarily to add adapter
        console.log("Granting DEFI_MANAGER_ROLE to deployer...");
        vault.grantRole(Constants.DEFI_MANAGER_ROLE, msg.sender);

        // Add PancakeSwapV3Adapter to YieldVault with 100% weight (10000 basis points)
        console.log("Adding PancakeSwapV3Adapter to YieldVault...");
        vault.addAdapter(pancakeAdapter, 10000);

        console.log("PayFi ecosystem initialization completed");
        console.log("YieldVault: %s", yieldVaultProxy);
        console.log("PancakeSwapV3Adapter: %s", pancakeAdapter);
    }
}
