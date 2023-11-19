# L1 contracts

Contract deployed on L1 to receipt message from L2 and bridge ether to the correct L2 build with solidity

## Deployment

### To load the variables in the .env file
source .env

### To deploy and verify our contract
forge script script/DeployBridge.s.sol --rpc-url goerli --broadcast --verify -vvvv

[Goerli L1 Bridge] https://goerli.etherscan.io/address/0x932f80fc3d023e8dac12a3ae2a8611fdd3cf360f

## Links

[L2 contracts](https://github.com/zk-bridges/contract-evm)

[Frontend created with nextJS, implement web3Modal](https://github.com/zk-bridges/frontend-evm)

