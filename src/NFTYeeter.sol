// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.11;

import "solmate/tokens/ERC721.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC165.sol";
import {IConnext} from "nxtp/interfaces/IConnext.sol";
import {IExecutor} from "nxtp/interfaces/IExecutor.sol";
import "ERC721X/interfaces/IERC721X.sol";
import "ERC721X/ERC721X.sol";
import "./interfaces/INFTYeeter.sol";
import "./interfaces/INFTCatcher.sol";
import "./NFTCatcher.sol";
import "Default/Kernel.sol";
import "./ConnextBaseXApp.sol";
import "./ERC721TransferManager.sol";
import "./ERC721XManager.sol";

contract NFTYeeter is INFTYeeter, ConnextBaseXApp, Policy {
    uint32 public immutable localDomain;
    address private immutable transactingAssetId;
    address private registry;
    address public owner;
    ERC721TransferManager private mgr;
    ERC721XManager private xmgr;
    bytes4 constant IERC721XInterfaceID = 0xefd00bbc;

    constructor(
        uint32 _localDomain,
        address _connext,
        address _transactingAssetId,
        Kernel kernel_
    ) MinimalOwnable() ConnextBaseXApp(_connext) Policy(kernel_) {
        localDomain = _localDomain;
        transactingAssetId = _transactingAssetId;
    }

    function configureModules() external override onlyKernel {
        mgr = ERC721TransferManager(requireModule(bytes3("NMG")));
        xmgr = ERC721XManager(requireModule(bytes3("XMG")));
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
        address registry = requireModule(bytes3("REG"));
        mgr.safeTransferFrom(collection, msg.sender, registry, tokenId, bytes(""));
        require(
            ERC721(collection).ownerOf(tokenId) == registry,
            "NOT_IN_REGISTRY"
        ); // may not need to require this step for ERC721Xs, could be cool
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
            ERC721XManager.BridgedTokenDetails memory details = ERC721XManager.BridgedTokenDetails(
                nft.originChainId(),
                nft.originAddress(),
                tokenId,
                recipient,
                nft.name(),
                nft.symbol(),
                nft.tokenURI(tokenId)
            );
            _bridgeToken(details, dstChainId, relayerFee);

            xmgr.burn(collection, tokenId); // burn local copy of tokenId now that its been bridged
        } else {
            // we have already verified ownership via safeTransferFrom when
            // moving the NFT into the registry, then checking registry
            // ownership
            _bridgeNativeToken(
                collection,
                tokenId,
                recipient,
                dstChainId,
                relayerFee
            );
        }
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
        IConnext.CallParams memory callParams = IConnext.CallParams({
            to: dstCatcher,
            callData: payload,
            originDomain: localDomain,
            destinationDomain: dstChainId
        });
        IConnext.XCallArgs memory xcallArgs = IConnext.XCallArgs({
            params: callParams,
            transactingAssetId: transactingAssetId,
            amount: 0
            // relayerFee: relayerFee
        });
        IConnext(connext).xcall(xcallArgs);
        // record that this NFT has been bridged
    }

    function _bridgeNativeToken(
        address collection,
        uint256 tokenId,
        address recipient,
        uint32 dstChainId,
        uint256 relayerFee
    ) internal {
        ERC721 nft = ERC721(collection);
        ERC721XManager.BridgedTokenDetails memory details = ERC721XManager.BridgedTokenDetails(
            localDomain,
            collection,
            tokenId,
            recipient,
            nft.name(),
            nft.symbol(),
            nft.tokenURI(tokenId)
        );
        _bridgeToken(details, dstChainId, relayerFee);
    }
}
