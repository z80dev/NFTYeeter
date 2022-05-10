// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity >=0.8.7 <0.9.0;

import "ERC721X/ERC721X.sol";
import "ERC721X/ERC721XInitializable.sol";
import "openzeppelin-contracts/contracts/utils/Create2.sol";
import "openzeppelin-contracts/contracts/utils/Address.sol";
import {IExecutor} from "nxtp/interfaces/IExecutor.sol";
import "./interfaces/INFTCatcher.sol";
import "Default/Kernel.sol";
import "./ERC721TransferManager.sol";
import "./ERC721XManager.sol";
import "./ConnextBaseXApp.sol";

contract NFTCatcher is INFTCatcher, ConnextBaseXApp, Policy {
    uint32 public immutable localDomain;
    address public immutable connext;
    address private immutable transactingAssetId;
    address private registry;
    address public owner;
    ERC721TransferManager private mgr;
    ERC721XManager private xmgr;

    // we would want them all to have the same address. still, some may upgrade
    //

    function configureModules() external override onlyKernel {
        mgr = ERC721TransferManager(requireModule(bytes3("NMG")));
        xmgr = ERC721XManager(requireModule(bytes3("XMG")));
    }

    constructor(
        uint32 _localDomain,
        address _connext,
        address _transactingAssetId,
        Kernel kernel_
    ) ConnextBaseXApp(_connext) Policy(kernel_) {
        localDomain = _localDomain;
        transactingAssetId = _transactingAssetId;
    }

    // function called by remote contract
    // this signature maximizes future flexibility & backwards compatibility
    function receiveAsset(bytes memory _payload) external {
        // only connext can call this
        require(msg.sender == connext, "NOT_CONNEXT");
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
        address registry = requireModule(bytes3("REG"));
        if (details.originChainId == localDomain) {
            // we're bridging this NFT *back* home
            // remote copy has been burned
            // simply send local one from Registry to recipient
            mgr.safeTransferFrom(details.originAddress, registry, details.owner, details.tokenId, bytes(""));
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
