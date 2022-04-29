// SPDX-License-Identifier: MIT

pragma solidity >=0.8.7 <0.9.0;

interface INFTCatcher {
    function getLocalAddress(uint32 originChainId, address originAddress) external view returns (address);
    function receiveAsset(bytes memory _payload) external;
}
