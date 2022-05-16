// SPDX-License-Identifier: MIT

pragma solidity >=0.8.7 <0.9.0;

interface INFTBridgeReceiver {
    function receiveAsset(bytes memory _payload) external;
}

interface INFTBridgeTestReceiver is INFTBridgeReceiver {
    function localMint(uint16 chainId, address originAddress, string memory name, string memory symbol, string memory uri) external;
}
