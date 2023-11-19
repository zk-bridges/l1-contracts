// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./interfaces/IScrollGatewayCallback.sol";
import "./interfaces/IPolygonZkEVMBridge.sol";
import "./interfaces/IBridgeMessageReceiver.sol";
import "./interfaces/IL1ETHGateway.sol";
import "./interfaces/IMessageService.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract L1Bridge is
    Initializable,
    OwnableUpgradeable,
    IScrollGatewayCallback,
    IBridgeMessageReceiver
{
    struct BridgeInfo {
        uint64 chainId;
        address user;
    }

    uint256 public balance;

    event Bridged(
        address indexed receiver,
        uint256 amount,
        uint64 indexed chainId
    );

    event Withdraw(address indexed receiver, uint256 amount);

    error UnsupportedChain(uint64);
    error FailedWithdraw();

    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
    }

    receive() external payable {}

    fallback() external payable {
        // receive after claim message on linea bridge
        _bridgeData(msg.data);
    }

    function claimFromLinea(
        address _from,
        address _to,
        uint256 _fee,
        uint256 _value,
        address payable _feeRecipient,
        bytes calldata _calldata,
        uint256 _nonce
    ) external {
        // for linea we need to claim manually the message to bridge
        address bridge = 0x70BaD09280FD342D02fe64119779BC1f0791BAC2;
        IMessageService messageService = IMessageService(bridge);
        messageService.claimMessage(
            _from,
            _to,
            _fee,
            _value,
            _feeRecipient,
            _calldata,
            _nonce
        );
    }

    function onScrollGatewayCallback(bytes memory data) external {
        // receive message from scroll l2
        _bridgeData(data);
    }

    function onMessageReceived(
        address,
        uint32,
        bytes memory data
    ) external payable {
        // receive message from polygon zkevm l2
        _bridgeData(data);
    }

    function withdraw() external onlyOwner {
        // remove stuck funds
        uint256 amount = address(this).balance;
        (bool sent, ) = payable(owner()).call{value: amount}("");
        if (!sent) {
            revert FailedWithdraw();
        }
        balance = 0;

        emit Withdraw(owner(), amount);
    }

    function formatData(
        address receiver,
        uint64 chainId
    ) external pure returns (bytes memory) {
        BridgeInfo memory info = BridgeInfo(chainId, receiver);
        return abi.encode(info);
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
            // scroll
            _sendToScroll(bridgeInfo.user, dif);
        } else if (bridgeInfo.chainId == 1442) {
            // polygon zkevm
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
        uint256 fees = 127200001484000; // copy from real tx
        IMessageService messageService = IMessageService(bridge);
        messageService.sendMessage{value: amount}(recipient, fees, "");
    }
}
