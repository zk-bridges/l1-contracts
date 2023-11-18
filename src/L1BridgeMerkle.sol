// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IScrollGatewayCallback.sol";

contract L1BridgeMerkle is IScrollGatewayCallback {
    mapping(bytes32 => uint256) public amountSent;
    uint256 public balance;

    struct BridgeInfo {
        uint64 chainId;
        uint192 amount;
        bytes32 merkleRoot;
    }

    struct DataToBridge {
        uint192 amount;
        bytes32[] merkleRoots;
    }

    mapping(uint64 => DataToBridge) public dataToBridges;

    mapping(address => bool) public authorizedContracts;

    mapping(uint64 => address) public gatewayContracts;

    uint64[] public listChains;
    mapping(uint64 => bool) public supportedChains;

    address private owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    receive() external payable {
        require(authorizedContracts[msg.sender], "Unauthorized contracts");
    }

    function changeOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function setAuthorizedContracts(
        address contractAddress,
        bool authorized
    ) external onlyOwner {
        authorizedContracts[contractAddress] = authorized;
    }

    function setGatewayByChain(
        uint64 chainId,
        address contractAddress
    ) external onlyOwner {
        gatewayContracts[chainId] = contractAddress;
    }

    function addSupportedChain(
        uint64 chainId,
        bool supported
    ) external onlyOwner {
        supportedChains[chainId] = supported;
        if (supported) {
            listChains.push(chainId);
        } else {
            int256 index = -1;
            for (uint i = 0; i < listChains.length; i++) {
                if (listChains[i] == chainId) {
                    index = int256(i);
                    break;
                }
            }
            if (index > -1) {
                // delete element in array
                listChains[uint256(index)] = listChains[listChains.length - 1];
                listChains.pop();
            }
        }
    }

    function onScrollGatewayCallback(bytes memory data) external {
        require(authorizedContracts[msg.sender], "Unauthorized contracts");
        // we check we have send amount with this bridge
        uint256 oldBalance = balance;
        uint256 newBalance = address(this).balance;
        uint dif = newBalance - oldBalance;
        require(dif > 0, "No amount");

        BridgeInfo[] memory bridgeInfos = abi.decode(data, (BridgeInfo[]));
        uint256 totalAmount;
        for (uint i = 0; i < bridgeInfos.length; i++) {
            BridgeInfo memory info = bridgeInfos[i];
            require(supportedChains[info.chainId], "Unsupported chain");
            totalAmount += info.amount;
            // we regroup by chain id to send only one request by chain after
            DataToBridge storage dataToBridge = dataToBridges[info.chainId];
            dataToBridge.amount += info.amount;
            dataToBridge.merkleRoots.push(info.merkleRoot);
        }
        // the amount sent need to match with amount sent to user
        require(totalAmount == dif, "Invalid amount");
    }

    function proceed() external{
        for (uint i = 0; i < listChains.length; i++) {
            uint64 chainId = listChains[i];
            DataToBridge memory dataTB = dataToBridges[chainId];
            if(dataTB.amount > 0){
                // todo code to proceed by gateway

                delete dataToBridges[chainId];
            }
        }
    }
}
