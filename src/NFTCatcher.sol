// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity >=0.8.7 <0.9.0;

import "ERC721X/ERC721X.sol";
import "ERC721X/MinimalOwnable.sol";
import "ERC721X/ERC721XInitializable.sol";
import "openzeppelin-contracts/contracts/utils/Create2.sol";
import "openzeppelin-contracts/contracts/utils/Address.sol";
import {IConnextHandler} from "nxtp/interfaces/IConnextHandler.sol";
import {IExecutor} from "nxtp/interfaces/IExecutor.sol";
import "./interfaces/IDepositRegistry.sol";
import "./interfaces/INFTCatcher.sol";

contract NFTCatcher is INFTCatcher, MinimalOwnable {
    uint32 public immutable localDomain;
    address public immutable connext;
    address private immutable transactingAssetId;
    address public owner;
    address public registry;

    mapping(uint32 => address) public trustedYeeters; // remote addresses of other yeeters, though ideally

    // we would want them all to have the same address. still, some may upgrade

    constructor(
        uint32 _localDomain,
        address _connext,
        address _transactingAssetId,
        address _registry
    ) MinimalOwnable() {
        localDomain = _localDomain;
        connext = _connext;
        transactingAssetId = _transactingAssetId;
        registry = _registry;
    }

    function setRegistry(address newRegistry) external {
        require(msg.sender == _owner);
        registry = newRegistry;
    }

    function setTrustedYeeter(uint32 chainId, address yeeter) external {
        require(msg.sender == _owner);
        trustedYeeters[chainId] = yeeter;
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

    // function called by remote contract
    // this signature maximizes future flexibility & backwards compatibility
    function receiveAsset(bytes memory _payload) external {
        // only connext can call this
        require(msg.sender == connext, "NOT_CONNEXT");
        // check remote contract is trusted remote NFTYeeter
        uint32 remoteChainId = IExecutor(msg.sender).origin();
        address remoteCaller = IExecutor(msg.sender).originSender();
        require(trustedYeeters[remoteChainId] == remoteCaller, "UNAUTH");

        BridgedTokenDetails memory details = abi.decode(
            _payload,
            (BridgedTokenDetails)
        );

        if (details.originChainId == localDomain) {
            // we're bridging this NFT *back* home
            IDepositRegistry(registry).setDetails(
                details.originAddress,
                details.tokenId,
                details.owner,
                false
            );
        } else {
            address localAddress = IDepositRegistry(registry).getLocalAddress(
                details.originChainId,
                details.originAddress
            );
            if (Address.isContract(localAddress)) {
                // this check will change after create2
                // local XERC721 contract exists, we just need to mint
                IDepositRegistry(registry).mint(localAddress, details.tokenId, details.tokenURI, details.owner);
            } else {
                // deploy new ERC721 contract
                // this will also change w/ create2
                address nft = IDepositRegistry(registry).deployERC721X(
                    details.originChainId,
                    details.originAddress,
                    details.name,
                    details.symbol
                );
                IDepositRegistry(registry).mint(localAddress, details.tokenId, details.tokenURI, details.owner);
            }
        }
    }
}
