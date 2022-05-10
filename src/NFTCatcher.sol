// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity >=0.8.7 <0.9.0;

import "ERC721X/ERC721X.sol";
import "ERC721X/ERC721XInitializable.sol";
import "openzeppelin-contracts/contracts/utils/Create2.sol";
import "openzeppelin-contracts/contracts/utils/Address.sol";
import {IExecutor} from "nxtp/interfaces/IExecutor.sol";
import "./interfaces/INFTCatcher.sol";
import "./ERC721TransferManager.sol";
import "./ERC721XManager.sol";
import "./NFTBridgeBasePolicy.sol";

contract NFTCatcher is INFTCatcher, NFTBridgeBasePolicy {

    address private immutable transactingAssetId;

    // we would want them all to have the same address. still, some may upgrade
    //

    constructor(
        uint32 _localDomain,
        address _connext,
        address _transactingAssetId,
        address kernel_
    ) NFTBridgeBasePolicy(_connext, _localDomain, kernel_) {
        transactingAssetId = _transactingAssetId;
    }

    // function called by remote contract
    // this signature maximizes future flexibility & backwards compatibility
    function receiveAsset(bytes memory _payload) onlyConnext external {
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
            mgr.safeTransferFrom(details.originAddress, address(registry), details.owner, details.tokenId, bytes(""));
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
