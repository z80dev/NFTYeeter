# Deployment Instructions

This bridge requires the careful setup of various contracts for each chain that will be supported, and then some additional setup for enabling a connection between each chain. This document includes all necessary instructions for setting up the bridge on a new chain.

## Initial Chain Setup

This process should be repeated for each chain to be supported.

### Deploy Registry Contract

This is the first contract that should be deployed. It requires no arguments to its contstructor. It can be deployed with the following command: 

`forge create DepositRegistry --rpc-url=$RPC_URL --private-key=$PRIVATE_KEY`

### Deploy Sender Contract

This contract accepts 4 constructor arguments:

- localDomain/localChainId (identifies to remote receivers the chain this contract is sending NFTs *from*)
- connext (address of the connext router for this chain)
- transactingAssetId (not very relevant for initial use-cases. in testing, use TST token
- registry contract address

`forge create NFTYeeter --rpc-url=$RPC_URL --private-key=$PRIVATE_KEY --constructor-args 2212 0xconnextaddress 0xtransactingassetid 0xregistrycontract`

### Deploy Receiver Contract 

This contract accepts 4 constructor arguments:

- localDomain/localChainId (identifies to remote receivers the chain this contract is sending NFTs *from*)
- connext (address of the connext router for this chain)
- transactingAssetId (not very relevant for initial use-cases. in testing, use TST token
- registry contract address

`forge create NFTCatcher --rpc-url=$RPC_URL --private-key=$PRIVATE_KEY --constructor-args 2212 0xconnextaddress 0xtransactingassetid 0xregistrycontract`

### Grant Registry Auth to Sender/Receiver Contracts

This is necessary to enable the Sender and Receiver contracts to trigger the minting or burning of ERC721Xs.

`cast send --rpc-url=$RPC_URL <registryAddress>  "setOperatorAuth(address, bool)" <senderAddress> true --private-key=$PRIVATE_KEY`

`cast send --rpc-url=$RPC_URL <registryAddress>  "setOperatorAuth(address, bool)" <receiverAddress> true --private-key=$PRIVATE_KEY`


## Authorize Inter-Chain Communication

Contracts in the bridge will only accept messages from, and send messages to, trusted contracts. This prevents spoofing in the network or the minting of counterfeit ERC721X bridged NFTs.

After contracts are deployed, we must authorize them to call into and out of each other across chains.

**Note: These steps must be followed for each pair of chains to be connected**

For example, to link chains A and B, we must:

- Authorize the sender on chain A to send messages to the receiver on chain B
- Authorize the receiver on chain A to receive messages from the sender on chain B

- Authorize the sender on chain B to send messages to the receiver on chain A
- Authorize the receiver on chain B to receive messages from the sender on chain A

All contracts on both chains should already be deployed. We will need their addresses in order to carry out the approvals.

## Authorize Sender to send to Receiver

`cast send --rpc-url=$RPC_URL <senderAddress>  "setTrustedCatcher(uint32, address)" <remoteChainId> <receiverAddress> --private-key=$PRIVATE_KEY`

## Authorize the Receiver to receive from the Sender

`cast send --rpc-url=$RPC_URL <receiverAddress>  "setTrustedYeeter(uint32, address)" <remoteChainId> <senderAddress> --private-key=$PRIVATE_KEY`
