// SPDX-License-Identifier: AGPL-3.0-only
//
// Dummy Bridge for testing

pragma solidity >=0.8.7 <0.9.0;

import "./NFTBridgeBase.sol";

contract SelfBridge is NFTBridgeBase {

    constructor(address _kernel, uint32 _domain) NFTBridgeBase(_kernel, _domain) {}

    function bridgeToken(
        address collection,
        uint256 tokenId,
        address recipient,
        uint32 dstChainId,
        uint256 relayerFee
    ) external {
        return this.bridgeToSelf(collection, tokenId, recipient, dstChainId, relayerFee);
    }

    function receiveAsset(bytes memory _payload) external {
        return _receive(_payload);
    }


    function bridgeToSelf(
        address collection,
        uint256 tokenId,
        address recipient,
        uint32 fakeChainId,
        uint256 relayerFee
                          ) external {
        ERC721XManager.BridgedTokenDetails memory details = _prepareTransfer(
            collection,
            tokenId,
            recipient
        );
        details.originChainId = uint32(fakeChainId);
        bytes memory _payload = abi.encode(details);
        _receive(_payload);
    }

}
