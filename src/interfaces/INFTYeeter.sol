// SPDX-License-Identifier: MIT

pragma solidity >=0.8.7 <0.9.0;

interface INFTYeeter {
    function bridgeToken(address collection, uint256 tokenId, address recipient, uint32 dstChainId, uint256 relayerFee) external;
}
