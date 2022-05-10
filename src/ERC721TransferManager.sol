// SPDX-License-Identifier: AGPL-3.0-only
//
// This contract acts as the universal NFT mover
// this way, users only have to approve one contract to move their NFTs through
// any of our other contracts

import "solmate/tokens/ERC721.sol";
import "./MinimalOwnable.sol";

pragma solidity >=0.8.7 <0.9.0;

contract ERC721TransferManager is MinimalOwnable {
    mapping(address => bool) callerAuth;

    constructor() MinimalOwnable() {}

    function setCallerAuth(address caller, bool auth) external {
        require(msg.sender == _owner);
        callerAuth[caller] = auth;
    }

    function safeTransferFrom(
        address collection,
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external {
        require(callerAuth[msg.sender], "UNAUTH");
        ERC721(collection).safeTransferFrom(from, to, tokenId, data);
    }
}
