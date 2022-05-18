# NFTYeeter

Yeets NFTs across chains

Makes use of:
- [ERC721X](https://github.com/OphiuchusDAO/ERC721X)
- Connext's upcoming Amarok update

# Current Architecture (Default Framework)

We are following the [Default Framework](https://github.com/fullyallocated/Default) approach for structuring this codebase. Although the architecture is only starting to grow, the potential for future growth of complexity is unbounded, and this framework provides us with the toolset to manage this complexity effectively, easily updating and upgrading the system in parts.

## Policies

Policies contain the logic at the edges of our system, and fire off the approprate actions within the system. They are managed and authorized via the Kernel.

Different policies can interact with the same Modules. This allows the system to grow easily and naturally. In context of Zipline, different Policies may handle different bridge technologies, all made compatible via their ability to interact with the same modules.

### NFTBridgeBasePolicy

Base Policy class which handles registering with the Kernel and setting up the modules all NFT bridge contracts will depend on, namely:

- ERC721TransferManager
- ERC721XManager
- DepositRegistry

### NFTBridgeBase

Base NFT bridge class which inherits from NFTBridgeBasePolicy, therefore already has access to the modules it needs.

This contract provides the base functionality for creating or parsing a struct containing necessary data for bridging an NFT. 

- `_prepareTransfer(address collection, uint256 tokenId, address recipient)`: internal function. It takes posession of the NFT to be bridged and returns the proper payload for bridging.
- `_receive(ERC721XManager.BridgedTokenDetails memory details)`: Handles a received transfer, mints the required NFT, etc.

### ConnextNFTBridge

This policy implements NFTBridgeBase and wires up the necessary logic between Connext and the methods exposed by NFTBridgeBase

To bridge, it calls `_prepareTransfer` in order to prepare the bridging data struct and take posession of the NFT. Then, it passes that bridging data struct to itself on another chain, via connext.

To receive a bridge, it parses the payload delivered by connext, and then passes it to `_receive`


### LZNFTBridge

This policy implements NFTBridgeBase and wires up the necessary logic between LayerZero and the methods exposed by NFTBridgeBase

To bridge, it calls `_prepareTransfer` in order to prepare the bridging data struct and take posession of the NFT. Then, it passes that bridging data struct to itself on another chain, via connext.

To receive a bridge, it parses the payload delivered by LayerZero, and then passes it to `_receive`

## Modules

From the [Default docs]()

> Modules can only be accessed through whitelisted Policy contracts, and have no dependencies of their own. Modules can only modify their own internal state.

### 

# Previous architecture, but still a good explanation of what existing parts do

## Deposits Registry

The Deposits Registry will be the custodian of locked NFTs while they are bridged. If the Registry has posession of an NFT, then that NFT is currently bridged to another chain.

It will be invoked upon receiving an ERC721 via safeTransferFrom, at which point it will record that it has locked this NFT, as well as by the Receiver contract in the cases where a bridged NFT is bridged back home in order to unlock the native NFT.

Tracking deposits may be unecessary. We can rely on the functionality that a Receiver will only be able to send NFTs it actually has in its posession (i.e. have been sent to it by the Sender contract in order to lock them), and that the contract triggering a withdrawal is a trusted contract, which would only do so upon conditions we have set up.

In other words, the Registry will take posession of NFTs, and only give up posession of them if triggered to do so by a trusted caller.

Keeping the responsibility for validating withdrawals outside of this contract and requiring a trusted/whitelisted caller lets us modularize the logic for validating withdrawals, allowing our system to be uprgadeable and extendable as it gains or adapts in functionality.


``` solidity
interface IDepositRegistry {
    struct DepositDetails {
        address depositor;
        bool bridged;
    }

    function withdraw(address collection, uint256 tokenId) external;
    function deposits(address, uint256) external returns (address, bool);
    function setDetails(address collection, uint256 tokenId, address _owner, bool bridged) external;
}
```


Handles recording records of user deposits. Will track whether a currently deposited NFT is bridged to another chain. Updated on each deposit (`depositor` set to sender), each time an NFT is bridged out of its home chain (`bridged` set to true), and each time an NFT is bridged back to its home chain (`bridged` set to false). It is checked in `withdraw` to prevent withdrawal of currently bridged NFT.

Both the Sender and Receiver contracts will interact with this contract in order to handle NFT deposits and withdrawals. Before bridging, users would interact with this contract by sending them their NFT via `safeTransferFrom`. They would then interact with it again to withdraw their NFT, if it is not currently bridged.

## NFTYeeter - Sender Contract

``` solidity
interface INFTYeeter {
    function bridgeToken(address collection, uint256 tokenId, address recipient, uint32 dstChainId) external;
}
```


This contract is entrusted with firing off transactions to bridge a users' NFTs across chains, and recording in the DepositRegistry that the NFT has been bridged.

### Bridging a Native NFT 

This describes how a typical ERC721 NFT is bridged across chains.

The sender contract checks with the Deposits Registry that the user firing off the transaction is the depositor, and that the NFT is not currently bridged. If these checks pass, it will notify the Deposits Registry that the NFT is being bridged, and then sends a cross-chain transaction via Connext's `xcall` to initiate bridging of the NFT.

### Bridging an ERC721X

In this case, the Sender Contract has no need to check with the Deposit Registry whether the NFT can be bridged or who the depositor is. That information is only relevant in the case of bridging a Native NFT.     

To bridge an ERC721X, the Sender Contract constructs a payload identically to when bridging a native NFT, but using the data from the ERC721X. For example, rather than using the Sender Contract's `localChainId`, it passes along the `originChainId` from the ERC721X contract.

For this, we should implement ERC165 for ERC721X to be able to differentiate between ERC721X's and regular ERC721X contracts without maintaining a registry of ERC721X's.

## NFTCatcher - Receiver Contract

``` solidity
interface INFTCatcher {
    function getLocalAddress(uint32 originChainId, address originAddress) external view returns (address);
    function receiveAsset(bytes memory _payload) external;
}
```


This contract is entrusted with deploying ERC721X contracts on the receiving chain and minting specific tokens when they are bridged. It does not need to interact with the Deposits Registry. It must simply mint, via `Create2`, an ERC721X with the data it receives, including the necessary `tokenURI`, `originChainId`, and `originAddress`

## ERC721TransferManager

This contract acts as a single universal NFT mover for the whole project. It will maintain a whitelist of allowed callers and allowed destinations. Its desinations may be managed via Default Framework's kernel.sol (Implementation TBD). For now, callers are whitelisted and they will specify where they're moving into by address.

## ERC721XManager

This contract is responsible for deployment of ERC721X contracts and minting of specific tokenIds when needed. Any time an ERC721X contract must be deployed, or a specific tokenId needs to be minted or burned, it should be done through the ERC721X manager. No other contract has the authority to perform these mints and burns.


# Deployment instructions

Find deployment instructions [here](DEPLOY.md)
