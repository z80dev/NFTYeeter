// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.11;

import "solmate/tokens/ERC721.sol";
import {IConnextHandler} from "nxtp/interfaces/IConnextHandler.sol";
import {IExecutor} from "nxtp/interfaces/IExecutor.sol";
import "ERC721X/interfaces/IERC721X.sol";
import "ERC721X/ERC721X.sol";
import "./interfaces/IDepositRegistry.sol";
import "./interfaces/INFTYeeter.sol";
import "./NFTCatcher.sol";
import "./MinimalOwnable.sol";

contract NFTYeeter is INFTYeeter, MinimalOwnable {

    uint32 public immutable localDomain;
    address public immutable connext;
    address private immutable transactingAssetId;
    address public owner;
    address public registry;

    mapping(uint32 => address) public trustedCatcher; // remote addresses of other yeeters, though ideally
                                               // we would want them all to have the same address. still, some may upgrade

    constructor(uint32 _localDomain, address _connext, address _transactingAssetId, address _registry) MinimalOwnable() {
        localDomain = _localDomain;
        connext = _connext;
        transactingAssetId = _transactingAssetId;
        registry = _registry;
    }

    function setRegistry(address newRegistry) external {
        require(msg.sender == _owner);
        registry = newRegistry;
    }

    function setTrustedCatcher(uint32 chainId, address catcher) external {
        require(msg.sender == _owner);
        trustedCatcher[chainId] = catcher;
    }

    // this is used to mint new NFTs upon receipt on a "remote" chain
    // if this big payload makes bridging expensive, we should separate
    // the process of bridging a collection (name, symbol) from bridging
    // of tokens (tokenId, tokenUri)
    // specially once we add royalties
    //
    // buuuut... this would add a requirement that a collection *must* be bridged before any single items
    // can be bridged, which was a big value add
    //
    // it will all come down to how expensive bridging a single item + all the data for the collection is
    struct BridgedTokenDetails {
        uint32 originChainId;
        address originAddress;
        uint256 tokenId;
        address owner;
        string name;
        string symbol;
        string tokenURI;
    }

    function bridgeToken(address collection, uint256 tokenId, address recipient, uint32 dstChainId) external {
        // need to check here and differentiate between native NFTs and ERC721X
        require(ERC721(collection).ownerOf(tokenId) == registry, "NOT_IN_REGISTRY");
        (address depositor, bool bridged) = IDepositRegistry(registry).deposits(collection, tokenId);
        require(depositor == msg.sender, "NOT_DEPOSITOR");
        require(bridged == false, "ALREADY_BRIDGED");
        _bridgeToken(collection, tokenId, recipient, dstChainId);
    }

    function _bridgeToken(address collection, uint256 tokenId, address recipient, uint32 dstChainId) internal {
        address dstCatcher = trustedCatcher[dstChainId];
        require(dstCatcher != address(0), "Chain not supported");
        ERC721 nft = ERC721(collection);
        bytes4 selector = NFTCatcher.receiveAsset.selector;
        BridgedTokenDetails memory details = BridgedTokenDetails(
                                                                 localDomain,
                                                                 collection,
                                                                 tokenId,
                                                                 recipient,
                                                                 nft.name(),
                                                                 nft.symbol(),
                                                                 nft.tokenURI(tokenId)
        );
        bytes memory payload = abi.encodeWithSelector(selector, details);
        IConnextHandler.CallParams memory callParams = IConnextHandler.CallParams({
                to: dstCatcher,
                callData: payload,
                originDomain: localDomain,
                destinationDomain: dstChainId
            });
        IConnextHandler.XCallArgs memory xcallArgs = IConnextHandler.XCallArgs({
                params: callParams,
                transactingAssetId: transactingAssetId,
                amount: 0,
                relayerFee: 0
            });
        IConnextHandler(connext).xcall(xcallArgs);
        // record that this NFT has been bridged
        IDepositRegistry(registry).setDetails(collection, tokenId, recipient, true);
    }

}
