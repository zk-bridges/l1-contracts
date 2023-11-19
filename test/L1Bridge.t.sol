// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/L1Bridge.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts-upgradeable//transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin2/contracts-upgradeable/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract L1BridgeTest is Test {
    L1Bridge public bridge;

    function setUp() public {
         bridge = L1Bridge(
            _deployProxy(
                address(new L1Bridge()),
                ""
            )
        );

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
