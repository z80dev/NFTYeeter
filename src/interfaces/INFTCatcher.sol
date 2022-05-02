// SPDX-License-Identifier: MIT

pragma solidity >=0.8.7 <0.9.0;

interface INFTCatcher {

    function receiveAsset(bytes memory _payload) external;
}
