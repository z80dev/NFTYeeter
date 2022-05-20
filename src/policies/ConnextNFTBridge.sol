// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity >=0.8.7 <0.9.0;

import "ERC721X/ERC721X.sol";

import "solmate/tokens/ERC721.sol";

import "nxtp/interfaces/IConnextHandler.sol";
import "nxtp/interfaces/IExecutor.sol";

import "openzeppelin-contracts/contracts/utils/Address.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC165.sol";

import "../modules/ERC721XManager.sol";
import "../policies/NFTBridgeBasePolicy.sol";
import "../bridges/ConnextBaseXApp.sol";
import "../interfaces/INFTBridge.sol";

import "./NFTBridgeBase.sol";


contract ConnextNFTBridge is NFTBridgeBase, ConnextBaseXApp {
    // connext data
    address private immutable transactingAssetId; // this may change in the future

    constructor(
        uint32 _localDomain,
        address payable _connext,
        address _transactingAssetId,
        address kernel_
    )
        NFTBridgeBase(kernel_, _localDomain)
        ConnextBaseXApp(_connext, _localDomain)
    {
        transactingAssetId = _transactingAssetId;
    }

    function bridgeToken(
        address collection,
        uint256 tokenId,
        address recipient,
        uint32 dstChainId,
        uint256 relayerFee
    ) external payable {
        ERC721XManager.BridgedTokenDetails memory details = _prepareTransfer(
            collection,
            tokenId,
            recipient
        );
        _bridgeToken(details, dstChainId, relayerFee);
    }

    // function called by remote contract
    // this signature maximizes future flexibility & backwards compatibility
    function receiveAsset(bytes memory _payload) external onlyExecutor {
        // check remote contract is trusted remote NFTYeeter
        uint32 remoteChainId = IExecutor(msg.sender).origin();
        address remoteCaller = IExecutor(msg.sender).originSender();
        require(trustedRemote[remoteChainId] == remoteCaller, "UNAUTH");
        // decode payload
        ERC721XManager.BridgedTokenDetails memory details = abi.decode(
            _payload,
            (ERC721XManager.BridgedTokenDetails)
        );
        _receive(details);
    }

    function _bridgeToken(
        ERC721XManager.BridgedTokenDetails memory details,
        uint32 dstChainId,
        uint256 relayerFee
    ) internal {
        address dstCatcher = trustedRemote[dstChainId];
        require(dstCatcher != address(0), "Chain not supported");
        bytes4 selector = this.receiveAsset.selector;
        bytes memory payload = abi.encode(details);
        bytes memory callData = abi.encodeWithSelector(selector, payload);
        IConnextHandler.CallParams memory callParams = IConnextHandler
            .CallParams({
                to: dstCatcher,
                callData: callData,
                originDomain: localDomain,
                destinationDomain: dstChainId,
                forceSlow: false,
                receiveLocal: false
                // callback: address(0),
                // callbackFee: 0
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
