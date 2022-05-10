// SPDX-License-Identifier: AGPL-3.0-only
//
// This contract acts as the universal NFT mover
// this way, users only have to approve one contract to move their NFTs through
// any of our other contracts

import "solmate/tokens/ERC721.sol";
import "./MinimalOwnable.sol";
import "Default/Kernel.sol";

pragma solidity >=0.8.7 <0.9.0;

contract ERC721TransferManager is MinimalOwnable, Module{

    constructor(Kernel kernel_) MinimalOwnable() Module(kernel_) {}

    function KEYCODE() external pure override returns (bytes3) {
        return bytes3("NMG"); // NFT Manager
    }

    function safeTransferFrom(
        address collection,
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) onlyPolicy external {
        ERC721(collection).safeTransferFrom(from, to, tokenId, data);
    }
}
