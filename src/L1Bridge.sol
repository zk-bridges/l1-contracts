// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IScrollGatewayCallback.sol";

contract L1Bridge is IScrollGatewayCallback {
    uint256 public balance;

    struct BridgeInfo {
        uint64 chainId;
        address user;
    }

    mapping(address => bool) public authorizedContracts;

    mapping(uint64 => address) public gatewayContracts;

    uint64[] public listChains;
    mapping(uint64 => bool) public supportedChains;

    address private owner;

    event Bridged(
        address indexed receiver,
        uint256 amount,
        uint64 indexed chainId
    );

    error UnsupportedChain(uint64);

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

        BridgeInfo memory bridgeInfo = abi.decode(data, (BridgeInfo));
        if (bridgeInfo.chainId == 59140) {
            // linea
            _sendToLinea(bridgeInfo.user, dif);
        } else if (bridgeInfo.chainId == 534353) {
            _sendToScroll(bridgeInfo.user, dif);
        } else if (bridgeInfo.chainId == 1442) {
            _sendToPolygonZkEvm(bridgeInfo.user, dif);
        } else {
            revert UnsupportedChain(bridgeInfo.chainId);
        }

        balance = 0;
        emit Bridged(bridgeInfo.user, dif, bridgeInfo.chainId);
    }

    function _sendToPolygonZkEvm(address recipient, uint256 amount) private {
        address lylx = 0xF6BEEeBB578e214CA9E23B0e9683454Ff88Ed2A7;
    }

    function _sendToScroll(address recipient, uint256 amount) private {}

    function _sendToLinea(address recipient, uint256 amount) private {}
}
