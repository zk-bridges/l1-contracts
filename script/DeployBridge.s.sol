// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/L1Bridge.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract DeployBridgeScript is Script {
    ProxyAdmin public proxyAdmin;
    L1Bridge public bridge;
    uint256 private deployerPrivateKey;

    function setUp() public {}

    function run() public {
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        address deployer = vm.addr(deployerPrivateKey);
        proxyAdmin = new ProxyAdmin(deployer);

        bridge = L1Bridge(
            payable(
                _deployProxy(
                    address(new L1Bridge()),
                    abi.encodeWithSelector(
                        L1Bridge.initialize.selector,
                        deployer
                    )
                )
            )
        );

        vm.stopBroadcast();
    }

    function _deployProxy(
        address implementation_,
        bytes memory initializer_
    ) internal returns (address) {
        return
            address(
                new TransparentUpgradeableProxy(
                    implementation_,
                    address(proxyAdmin),
                    initializer_
                )
            );
    }
}
