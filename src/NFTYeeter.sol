// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.11;

import "solmate/tokens/ERC721.sol";
import {IConnextHandler} from "nxtp/interfaces/IConnextHandler.sol";
import {IExecutor} from "nxtp/interfaces/IExecutor.sol";
import "openzeppelin-contracts/contracts/utils/Create2.sol";
import "openzeppelin-contracts/contracts/utils/Address.sol";
import "ERC721X/interfaces/IERC721X.sol";
import "ERC721X/ERC721X.sol";
import "./interfaces/IDepositRegistry.sol";

contract NFTYeeter is ERC721TokenReceiver {

    uint32 public immutable localDomain;
    address public immutable connext;
    address public owner;
    address public registry;
    address private immutable transactingAssetId;

    mapping(uint32 => address) public trustedYeeters; // remote addresses of other yeeters, though ideally
                                               // we would want them all to have the same address. still, some may upgrade

    constructor(uint32 _localDomain, address _connext, address _transactingAssetId, address _registry) {
        localDomain = _localDomain;
        connext = _connext;
        transactingAssetId = _transactingAssetId;
        owner = msg.sender;
        registry = _registry;
    }

    function setOwner(address newOwner) external {
        require(msg.sender == owner);
        owner = newOwner;
    }

    function setTrustedYeeter(uint32 chainId, address yeeter) external {
        require(msg.sender == owner);
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

    function _calculateCreate2Address(uint32 chainId, address originAddress) internal view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(chainId, originAddress));
        bytes memory creationCode = type(ERC721X).creationCode;
        return Create2.computeAddress(salt, keccak256(creationCode));
    }

    function getLocalAddress(uint32 originChainId, address originAddress) external view returns (address) {
        return _calculateCreate2Address(originChainId, originAddress);
    }

    function _deployERC721X(uint32 chainId, address originAddress) internal returns (ERC721X) {
        bytes32 salt = keccak256(abi.encodePacked(chainId, originAddress));
        bytes memory creationCode = type(ERC721X).creationCode;
        return ERC721X(Create2.deploy(0, salt, creationCode));
    }

    // function called by remote contract
    // this signature maximizes future flexibility & backwards compatibility
    function receiveAsset(bytes memory _payload) public {
        // only connext can call this
        require(msg.sender == connext, "NOT_CONNEXT");
        // check remote contract is trusted remote NFTYeeter
        uint32 remoteChainId = IExecutor(msg.sender).origin();
        address remoteCaller = IExecutor(msg.sender).originSender();
        require(trustedYeeters[remoteChainId] == remoteCaller, "UNAUTH");

        (BridgedTokenDetails memory details) = abi.decode(_payload, (BridgedTokenDetails));

        if (details.originChainId == localDomain) {
            // we're bridging this NFT *back* home
            IDepositRegistry(registry).setDetails(details.originAddress, details.tokenId, details.owner, false);

        } else {
            address localAddress = _calculateCreate2Address(details.originChainId, details.originAddress);
            if (!Address.isContract(localAddress)) { // this check will change after create2
                // local XERC721 contract exists, we just need to mint
                ERC721X nft = ERC721X(localAddress);
                nft.mint(details.owner, details.tokenId, details.tokenURI);
            } else {
                // deploy new ERC721 contract
                // this will also change w/ create2
                ERC721X nft = _deployERC721X(details.originChainId, details.originAddress);
                nft.mint(details.owner, details.tokenId, details.tokenURI);
            }
        }


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
        address dstYeeter = trustedYeeters[dstChainId];
        require(dstYeeter != address(0), "Chain not supported");
        ERC721 nft = ERC721(collection);
        bytes4 selector = this.receiveAsset.selector;
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
                to: dstYeeter,
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
