// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity >=0.8.7 <0.9.0;

import {IConnextHandler} from "nxtp/interfaces/IConnextHandler.sol";
import "ERC721X/MinimalOwnable.sol";

abstract contract ConnextBaseXApp is MinimalOwnable {

    uint32 public immutable localDomain; // identifies our chain to other chains

    IConnextHandler public immutable connext;
    mapping(uint32 => address) public trustedRemote;

    constructor(address _connext, uint32 _domain) MinimalOwnable() {
        connext = IConnextHandler(_connext);
        localDomain = _domain;
    }

    modifier onlyConnext() {
        require(msg.sender == address(connext), "NOT_CONNEXT");
        _;
    }

    function setTrustedRemote(uint32 chainId, address remote) external {
        require(msg.sender == _owner);
        trustedRemote[chainId] = remote;
    }
}
