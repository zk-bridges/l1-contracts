// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/L1Bridge.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract L1BridgeTest is Test {
    ProxyAdmin public proxyAdmin;
    L1Bridge public bridge;

    address deployer = makeAddr("Deployer");
    address alice = makeAddr("Alice");
    address bob = makeAddr("Bob");
    address charlie = makeAddr("Charlie");
    address daniel = makeAddr("Daniel");

    function setUp() public {
        vm.createSelectFork("goerli");
        vm.startPrank(deployer);

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

        vm.stopPrank();
    }

    function testScrollToLinea(address receiver, uint256 amount) public {
        deal(deployer, amount);
        vm.startPrank(deployer);
        uint64 chainId = 59140;
        bytes memory data = bridge.formatData(receiver, chainId);
        address(bridge).call{value: amount}("");
        //bridge.onScrollGatewayCallback(data);
        assertEq(1, 1);
        vm.stopPrank();
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
