// SPDX-License-Identifier: AGPL-3.0-only
//
// This contract acts as the universal NFT mover
// this way, users only have to approve one contract to move their NFTs through
// any of our other contracts

pragma solidity >=0.8.7 <0.9.0;

import "solmate/tokens/ERC721.sol";
import "Default/Kernel.sol";


contract ERC721TransferManager is Module {
    constructor(Kernel kernel_) Module(kernel_) {}

    function KEYCODE() public pure override returns (bytes5) {
        return bytes5("NFTMG"); // NFT Manager
    }

    function safeTransferFrom(
        address collection,
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external onlyPermitted {
        ERC721(collection).safeTransferFrom(from, to, tokenId, data);
    }
}
