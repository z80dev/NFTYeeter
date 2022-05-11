// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.11;

import "solmate/tokens/ERC721.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC165.sol";
import {IConnextHandler} from "nxtp/interfaces/IConnextHandler.sol";
import {IExecutor} from "nxtp/interfaces/IExecutor.sol";
import "./interfaces/INFTCatcher.sol";
import "ERC721X/ERC721X.sol";
import "./interfaces/INFTYeeter.sol";
import "./NFTCatcher.sol";
import "./ERC721XManager.sol";
import "./NFTBridgeBasePolicy.sol";
import "openzeppelin-contracts/contracts/utils/Address.sol";

contract ConnextBridge is INFTYeeter, INFTCatcher, NFTBridgeBasePolicy {
    // connext data
    address private immutable transactingAssetId; // this may change in the future

    bytes4 constant IERC721XInterfaceID = 0xefd00bbc;

    constructor(
        uint32 _localDomain,
        address _connext,
        address _transactingAssetId,
        address kernel_
    ) NFTBridgeBasePolicy(_connext, localDomain, kernel_) {
        transactingAssetId = _transactingAssetId;
    }

    function bridgeToken(
        address collection,
        uint256 tokenId,
        address recipient,
        uint32 dstChainId,
        uint256 relayerFee
    ) external {
        // transfer NFT into registry via ERC721Manager
        mgr.safeTransferFrom(
            collection,
            msg.sender,
            address(registry),
            tokenId,
            bytes("")
        );

        // confirm NFT has been deposited
        require(
            ERC721(collection).ownerOf(tokenId) == address(registry),
            "NOT_IN_REGISTRY"
        );

        ERC721 nft = ERC721(collection);
        ERC721XManager.BridgedTokenDetails memory details = ERC721XManager
            .BridgedTokenDetails(
                localDomain,
                collection,
                tokenId,
                recipient,
                nft.name(),
                nft.symbol(),
                nft.tokenURI(tokenId)
            );

        // check if we're dealing with a bridged NFT
        if (IERC165(collection).supportsInterface(IERC721XInterfaceID)) {
            ERC721X nft = ERC721X(collection);
            details.originChainId = nft.originChainId();
            details.originAddress = nft.originAddress();
            address trustedLocalAddress = xmgr.getLocalAddress(
                details.originChainId,
                details.originAddress
            );

            require(collection == trustedLocalAddress, "NOT_AUTHENTIC");

            xmgr.burn(collection, tokenId); // burn local copy of tokenId now that its been re-bridged
        }

        _bridgeToken(details, dstChainId, relayerFee);
    }

    function _bridgeToken(
        ERC721XManager.BridgedTokenDetails memory details,
        uint32 dstChainId,
        uint256 relayerFee
    ) internal {
        address dstCatcher = trustedRemote[dstChainId];
        require(dstCatcher != address(0), "Chain not supported");
        bytes4 selector = NFTCatcher.receiveAsset.selector;
        bytes memory payload = abi.encodeWithSelector(selector, details);
        IConnextHandler.CallParams memory callParams = IConnextHandler
            .CallParams({
                to: dstCatcher,
                callData: payload,
                originDomain: localDomain,
                destinationDomain: dstChainId
            });
        IConnextHandler.XCallArgs memory xcallArgs = IConnextHandler.XCallArgs({
            params: callParams,
            transactingAssetId: transactingAssetId,
            amount: 0,
            relayerFee: relayerFee
        });
        connext.xcall(xcallArgs);
        // record that this NFT has been bridged
    }


    // function called by remote contract
    // this signature maximizes future flexibility & backwards compatibility
    function receiveAsset(bytes memory _payload) external onlyConnext {
        // check remote contract is trusted remote NFTYeeter
        uint32 remoteChainId = IExecutor(msg.sender).origin();
        address remoteCaller = IExecutor(msg.sender).originSender();
        require(trustedRemote[remoteChainId] == remoteCaller, "UNAUTH");

        // decode payload
        ERC721XManager.BridgedTokenDetails memory details = abi.decode(
            _payload,
            (ERC721XManager.BridgedTokenDetails)
        );

        // get DepositRegistry address
        if (details.originChainId == localDomain) {
            // we're bridging this NFT *back* home
            // remote copy has been burned
            // simply send local one from Registry to recipient
            mgr.safeTransferFrom(
                details.originAddress,
                address(registry),
                details.owner,
                details.tokenId,
                bytes("")
            );
        } else {
            // this is a remote NFT bridged to this chain

            // calculate local address for collection
            address localAddress = xmgr.getLocalAddress(
                details.originChainId,
                details.originAddress
            );

            if (!Address.isContract(localAddress)) {
                // contract doesn't exist; deploy
                xmgr.deployERC721X(
                    details.originChainId,
                    details.originAddress,
                    details.name,
                    details.symbol
                );
            }

            // mint ERC721X for user
            xmgr.mint(
                localAddress,
                details.tokenId,
                details.tokenURI,
                details.owner
            );
        }
    }

}
