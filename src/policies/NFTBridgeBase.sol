// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity >=0.8.7 <0.9.0;

import "ERC721X/ERC721X.sol";

import "solmate/tokens/ERC721.sol";

import "openzeppelin-contracts/contracts/utils/Address.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC165.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC2981.sol";

import "../modules/ERC721XManager.sol";
import "./NFTBridgeBasePolicy.sol";
import "../interfaces/INFTBridge.sol";


abstract contract NFTBridgeBase is INFTBridge, NFTBridgeBasePolicy {
    uint32 localDomain;
    bytes4 constant IERC721XInterfaceID = 0xefd00bbc;
    bytes4 constant IERC2981InterfaceID = 0x2a55205a;

    constructor(address kernel_, uint32 _domain) NFTBridgeBasePolicy(kernel_) {
        localDomain = _domain;
    }

    function _prepareTransfer(
        address collection,
        uint256 tokenId,
        address recipient
    ) internal returns (ERC721XManager.BridgedTokenDetails memory) {
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
        address feeRecipient = address(0x0);
        uint256 feeNumerator = 0;

        if (IERC165(collection).supportsInterface(IERC2981InterfaceID)) {
            (feeRecipient, feeNumerator) = IERC2981(collection).royaltyInfo(0, 10000);
        }

        ERC721XManager.BridgedTokenDetails memory details = ERC721XManager
            .BridgedTokenDetails(
                localDomain,
                collection,
                tokenId,
                recipient,
                nft.name(),
                nft.symbol(),
                nft.tokenURI(tokenId),
                feeRecipient,
                uint96(feeNumerator)
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

        return details;
    }

    event ReceivedToken(address originAddress, uint256 tokenId, address owner);

    function _receive(ERC721XManager.BridgedTokenDetails memory details)
        internal
    {
        emit ReceivedToken(
            details.originAddress,
            details.tokenId,
            details.owner
        );

        // get DepositRegistry address
        if (details.originChainId == localDomain) {
            // we're bridging this NFT *back* home
            // remote copy has been burned
            // simply send local one from Registry to recipient
            registry.withdraw(details.originAddress, details.owner, details.tokenId);
            // mgr.safeTransferFrom(
            //     details.originAddress,
            //     address(registry),
            //     details.owner,
            //     details.tokenId,
            //     bytes("")
            // );
        } else {
            // this is a remote NFT bridged to this chain

            // calculate local address for collection
            address localAddress = xmgr.getLocalAddress(
                details.originChainId,
                details.originAddress
            );

            if (!Address.isContract(localAddress)) {
                // contract doesn't exist; deploy
                address feeRecipient = details.feeRecipient;
                if (feeRecipient == address(0x0)) {
                    feeRecipient = address(this);
                }
                xmgr.deployERC721X(
                    details.originChainId,
                    details.originAddress,
                    details.name,
                    details.symbol,
                    feeRecipient,
                    details.feeNumerator
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
