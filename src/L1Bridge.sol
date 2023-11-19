// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IScrollGatewayCallback.sol";
import "./interfaces/IPolygonZkEVMBridge.sol";
import "./interfaces/IBridgeMessageReceiver.sol";
import "./interfaces/IL1ETHGateway.sol";
import "./interfaces/IMessageService.sol";

contract L1Bridge is IScrollGatewayCallback, IBridgeMessageReceiver {
    struct BridgeInfo {
        uint64 chainId;
        address user;
    }

    uint256 public balance;
    address private owner;

    event Bridged(
        address indexed receiver,
        uint256 amount,
        uint64 indexed chainId
    );

    error UnsupportedChain(uint64);
    error FailedWithdraw();

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    receive() external payable {}

    function changeOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function onScrollGatewayCallback(bytes memory data) external {
        _bridgeData(data);
    }

    function onMessageReceived(
        address,
        uint32,
        bytes memory data
    ) external payable {
        _bridgeData(data);
    }

    function _bridgeData(bytes memory data) private {
        // we check we have send amount with this bridge
        uint256 oldBalance = balance;
        uint256 newBalance = address(this).balance;
        uint dif = newBalance - oldBalance;
        require(dif > 0, "No amount");

        balance -= dif;

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

        emit Bridged(bridgeInfo.user, dif, bridgeInfo.chainId);
    }

    function _sendToPolygonZkEvm(address recipient, uint256 amount) private {
        address lylx = 0xF6BEEeBB578e214CA9E23B0e9683454Ff88Ed2A7;
        // 1 for zkevm testnet
        uint32 networkId = 1;

        IPolygonZkEVMBridge zkEvmBridge = IPolygonZkEVMBridge(lylx);
        zkEvmBridge.bridgeMessage{value: amount}(
            networkId,
            recipient,
            false,
            ""
        );
    }

    function _sendToScroll(address recipient, uint256 amount) private {
        address gateway = 0x429b73A21cF3BF1f3E696a21A95408161daF311f;
        IL1ETHGateway l1Gateway = IL1ETHGateway(gateway);
        uint256 maxGas = 1e6;
        l1Gateway.depositETH{value: amount}(recipient, amount, maxGas);
    }

    function _sendToLinea(address recipient, uint256 amount) private {
        address bridge = 0x70BaD09280FD342D02fe64119779BC1f0791BAC2;
        uint256 maxGas = 1e6;
        IMessageService messageService = IMessageService(bridge);
        messageService.sendMessage{value: amount}(recipient, maxGas, "");
    }

    function withdraw() external onlyOwner {
        // remove stuck funds
        (bool sent, ) = payable(owner).call{value: address(this).balance}("");
        if (!sent) {
            revert FailedWithdraw();
        }
        balance = 0;
    }
}
