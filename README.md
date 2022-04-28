# NFTYeeter

Yeets NFTs across chains

Makes use of:
- [ERC721X](https://github.com/OphiuchusDAO/ERC721X)
- Connext's upcoming Amarok update

# Current architecture

Right now there's a single contract tracking all state and handling all of the functionality described below, but this will be split up into single contracts that handle a specific responsibility.

# Planned Architecture

## Deposits Registry

Handles recording records of user deposits. Will track whether a currently deposited NFT is bridged to another chain. Updated on each deposit (`depositor` set to sender), each time an NFT is bridged out of its home chain (`bridged` set to true), and each time an NFT is bridged back to its home chain (`bridged` set to false). It is checked in `withdraw` to prevent withdrawal of currently bridged NFT.

Both the Sender and Receiver contracts will interact with this contract in order to handle NFT deposits and withdrawals. Before bridging, users would interact with this contract by sending them their NFT via `safeTransferFrom`. They would then interact with it again to withdraw their NFT, if it is not currently bridged.

## Sender Contract

This contract is entrusted with firing off transactions to bridge a users' NFTs across chains. 

### Bridging a Native NFT 

This describes how a typical ERC721 NFT is bridged across chains.

The sender contract checks with the Deposits Registry that the user firing off the transaction is the depositor, and that the NFT is not currently bridged. If these checks pass, it will notify the Deposits Registry that the NFT is being bridged, and then sends a cross-chain transaction via Connext's `xcall` to initiate bridging of the NFT.

### Bridging an ERC721X

In this case, the Sender Contract has no need to check with the Deposit Registry whether the NFT can be bridged or who the depositor is. That information is only relevant in the case of bridging a Native NFT. 

To bridge an ERC721X, the Sender Contract constructs a payload identically to when bridging a native NFT, but using the data from the ERC721X. For example, rather than using the Sender Contract's `localChainId`, it passes along the `originChainId` from the ERC721X contract.

For this, we should implement ERC165 for ERC721X to be able to differentiate between ERC721X's and regular ERC721X contracts without maintaining a registry of ERC721X's.

## Receiver Contract

This contract is entrusted with deploying ERC721X contracts on the receiving chain and minting specific tokens when they are bridged. It does not need to interact with the Deposits Registry. It must simply mint, via `Create2`, an ERC721X with the data it receives, including the necessary `tokenURI`, `originChainId`, and `originAddress`
