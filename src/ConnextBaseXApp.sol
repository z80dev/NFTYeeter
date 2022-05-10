// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity >=0.8.7 <0.9.0;

import {IConnextHandler} from "nxtp/interfaces/IConnextHandler.sol";
import "ERC721X/MinimalOwnable.sol";

abstract contract ConnextBaseXApp is MinimalOwnable {

    IConnextHandler public immutable connext;
    mapping(uint32 => address) public trustedRemote;

    constructor(IConnextHandler _connext) MinimalOwnable() {
        connext = _connext;
    }

    function setTrustedRemote(uint32 chainId, address remote) external {
        require(msg.sender == _owner);
        trustedRemote[chainId] = remote;
    }
}
