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

    function testScrollToLinea() public {
        address receiver = bob;
        uint256 amount = 0.5 ether;
        console.log("amount %s", amount);
        deal(deployer, amount);
        vm.startPrank(deployer);
        uint64 chainId = 59140;
        bytes memory data = bridge.formatData(receiver, chainId);
        address(bridge).call{value: amount}("");
        assertEq(address(bridge).balance, amount);
        assertEq(bridge.lastTransfer(), amount);
        bridge.onScrollGatewayCallback(data);
        assertEq(address(bridge).balance, 0);
        assertEq(bridge.lastTransfer(), 0);
        vm.stopPrank();
    }

    function testScrollToPolygon() public {
        address receiver = alice;
        uint256 amount = 0.1 ether;
        deal(deployer, amount);
        vm.startPrank(deployer);
        uint64 chainId = 1442;
        bytes memory data = bridge.formatData(receiver, chainId);
        address(bridge).call{value: amount}("");
        assertEq(address(bridge).balance, amount);
        assertEq(bridge.lastTransfer(), amount);
        bridge.onScrollGatewayCallback(data);
        assertEq(address(bridge).balance, 0);
        assertEq(bridge.lastTransfer(), 0);
        vm.stopPrank();
    }

    function testPolygonToLinea() public {
        address receiver = alice;
        uint256 amount = 0.1 ether;
        deal(deployer, amount);
        vm.startPrank(deployer);
        uint64 chainId = 59140;
        bytes memory data = bridge.formatData(receiver, chainId);
        bridge.onMessageReceived{value: amount}(address(0), 0, data);
        assertEq(address(bridge).balance, 0);
        assertEq(bridge.lastTransfer(), 0);
        vm.stopPrank();
    }

    function testPolygonToScroll() public {
        address receiver = charlie;
        uint256 amount = 0.15 ether;
        deal(deployer, amount);
        vm.startPrank(deployer);
        uint64 chainId = 59140;
        bytes memory data = bridge.formatData(receiver, chainId);
        bridge.onMessageReceived{value: amount}(address(0), 0, data);
        assertEq(address(bridge).balance, 0);
        assertEq(bridge.lastTransfer(), 0);
        vm.stopPrank();
    }

    error NoAmount();
    error UnsupportedChain(uint64);

    function testScrollNoAmount() public {
        address receiver = bob;
        uint64 chainId = 59140;
        bytes memory data = bridge.formatData(receiver, chainId);
        vm.expectRevert(NoAmount.selector);
        bridge.onScrollGatewayCallback(data);
    }

    function testScrollBadChain() public {
        address receiver = bob;
        uint256 amount = 0.1 ether;
        deal(deployer, amount);
        vm.startPrank(deployer);
        uint64 chainId = 333;
        bytes memory data = bridge.formatData(receiver, chainId);
        address(bridge).call{value: amount}("");
        bytes memory unsupported = abi.encodeWithSelector(
            UnsupportedChain.selector,
            chainId
        );
        vm.expectRevert(unsupported);
        bridge.onScrollGatewayCallback(data);
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
