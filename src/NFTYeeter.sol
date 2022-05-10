// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.11;

import "solmate/tokens/ERC721.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC165.sol";
import {IConnextHandler} from "nxtp/interfaces/IConnextHandler.sol";
import {IExecutor} from "nxtp/interfaces/IExecutor.sol";
import "ERC721X/interfaces/IERC721X.sol";
import "ERC721X/ERC721X.sol";
import "./interfaces/INFTYeeter.sol";
import "./interfaces/INFTCatcher.sol";
import "./NFTCatcher.sol";
import "./ConnextBaseXApp.sol";
import "./ERC721TransferManager.sol";
import "./ERC721XManager.sol";
import "./NFTBridgeBasePolicy.sol";

contract NFTYeeter is INFTYeeter, NFTBridgeBasePolicy {
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
        //
        // get address from kernel
        //
        // then call the function we need from it
        mgr.safeTransferFrom(
            collection,
            msg.sender,
            address(registry),
            tokenId,
            bytes("")
        );
        require(
            ERC721(collection).ownerOf(tokenId) == address(registry),
            "NOT_IN_REGISTRY"
        ); // may not need to require this step for ERC721Xs, could be cool
        ERC721XManager.BridgedTokenDetails memory details;
        if (IERC165(collection).supportsInterface(IERC721XInterfaceID)) {
            ERC721X nft = ERC721X(collection);
            require(
                collection ==
                    xmgr.getLocalAddress(
                        nft.originChainId(),
                        nft.originAddress()
                    ),
                "NOT_AUTHENTIC"
            );

            // _bridgeXToken(...); // similar to bridgeNativeToken but use originAddress, originChainId, etc.
            //
            details = ERC721XManager.BridgedTokenDetails(
                nft.originChainId(),
                nft.originAddress(),
                tokenId,
                recipient,
                nft.name(),
                nft.symbol(),
                nft.tokenURI(tokenId)
            );

            xmgr.burn(collection, tokenId); // burn local copy of tokenId now that its been bridged
        } else {
            ERC721 nft = ERC721(collection);

            details = ERC721XManager.BridgedTokenDetails(
                localDomain,
                collection,
                tokenId,
                recipient,
                nft.name(),
                nft.symbol(),
                nft.tokenURI(tokenId)
            );
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
}
