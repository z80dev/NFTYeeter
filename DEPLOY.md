# Deployment Instructions

This bridge requires the careful setup of various contracts for each chain that will be supported, and then some additional setup for enabling a connection between each chain. This document includes all necessary instructions for setting up the bridge on a new chain.

## Initial Chain Setup

This process should be repeated for each chain to be supported.

### Deploy Kernel

No arguments needed

`forge create Kernel --rpc-url=$RPC_URL --private-key=$PRIVATE_KEY`

### Deploy Registry Module

This is the first contract that should be deployed. It requires no arguments to its contstructor. It can be deployed with the following command: 

`forge create DepositRegistry --rpc-url=$RPC_URL --private-key=$PRIVATE_KEY --constructor-args 0xkerneladdress`

### Deploy ERC721TransferManager Module

`forge create ERC721TransferManager --rpc-url=$RPC_URL --private-key=$PRIVATE_KEY --constructor-args 0xkerneladdress`

### Deploy ERC721XManager Module 

`forge create ERC721XManager --rpc-url=$RPC_URL --private-key=$PRIVATE_KEY --constructor-args 0xkerneladdress`

### Install Modules

`cast send --rpc-url=$RPC_URL <kernelAddress>  "executeAction(uint8, address)" 0 <registryModule> --private-key=$PRIVATE_KEY`
`cast send --rpc-url=$RPC_URL <kernelAddress>  "executeAction(uint8, address)" 0 <NMGModule> --private-key=$PRIVATE_KEY`
`cast send --rpc-url=$RPC_URL <kernelAddress>  "executeAction(uint8, address)" 0 <XMGModule> --private-key=$PRIVATE_KEY`

### Deploy Bridge Policy

This contract accepts 4 constructor arguments:

- localDomain/localChainId (identifies to remote receivers the chain this contract is sending NFTs *from*)
- connext (address of the connext router for this chain)
- transactingAssetId (not very relevant for initial use-cases. in testing, use TST token
- registry contract address

`forge create NFTBridge --rpc-url=$RPC_URL --private-key=$PRIVATE_KEY --constructor-args 2212 0xconnextaddress 0xtransactingassetid 0xregistrycontract 0xlzEndpoint`

### Approve Policy

`cast send --rpc-url=$RPC_URL <kernelAddress>  "executeAction(uint8, address)" 2 <Bridge> --private-key=$PRIVATE_KEY`

## Authorize Inter-Chain Communication

Contracts in the bridge will only accept messages from, and send messages to, trusted contracts. This prevents spoofing in the network or the minting of counterfeit ERC721X bridged NFTs.

After contracts are deployed, we must authorize them to call into and out of each other across chains.

**Note: These steps must be followed for each pair of chains to be connected**

For example, to link chains A and B, we must:

- Authorize the bridge on chain A to send messages to the bridge on chain B

- Authorize the bridge on chain B to send messages to the bridge on chain A

All contracts on both chains should already be deployed. We will need their addresses in order to carry out the approvals.

### Connext Authorization
`cast send --rpc-url=$RPC_URL <senderAddress>  "setTrustedRemote(uint32, address)" <remoteChainId> <receiverAddress> --private-key=$PRIVATE_KEY`

### Layer Zero Authorization

`cast send --rpc-url=$RPC_URL <senderAddress>  "setTrustedRemote(uint16, bytes calldata)" <lzRemoteChainId> <receiverAddressBytes> --private-key=$PRIVATE_KEY`
