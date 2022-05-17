// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity >=0.8.7 <0.9.0;

import "solidity-examples/lzApp/NonblockingLzApp.sol";

import "./NFTBridgeBase.sol";

contract LZNFTBridge is NonblockingLzApp, NFTBridgeBase {

    constructor(address _lzEndpoint, address _kernel, uint32 _domain) NonblockingLzApp(_lzEndpoint) NFTBridgeBase(_kernel, _domain) {}

    function _nonblockingLzReceive(uint16 _srcChainId,
                                   bytes memory _srcAddress,
                                   uint64 _nonce,
                                   bytes memory _payload)
        internal override {
        // decode payload
        ERC721XManager.BridgedTokenDetails memory details = abi.decode(
            _payload,
            (ERC721XManager.BridgedTokenDetails)
        );
        _receive(details);
    }


    function bridgeToken(
        address collection,
        uint256 tokenId,
        address recipient,
        uint32 dstChainId,
        uint256 relayerFee
    ) external {
        ERC721XManager.BridgedTokenDetails memory details = _prepareTransfer(
            collection,
            tokenId,
            recipient
        );
        _bridgeToken(details, uint16(dstChainId), relayerFee);
    }

    function _bridgeToken(
        ERC721XManager.BridgedTokenDetails memory details,
        uint16 dstChainId,
        uint256 relayerFee
    ) internal {
        bytes memory payload = abi.encode(details);
        _lzSend(dstChainId, payload, payable(details.owner), address(0x0), bytes(""));
    }

}
