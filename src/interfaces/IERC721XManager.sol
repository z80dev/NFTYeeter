// SPDX-License-Identifier: MIT

pragma solidity >=0.8.7 <0.9.0;

interface IERC721XManager {
    function mint(
        address collection,
        uint256 tokenId,
        string memory tokenURI,
        address recipient
    ) external;

    function burn(address collection, uint256 tokenId) external;

    function deployERC721X(
        uint32 originChainId,
        address originAddress,
        string memory name,
        string memory symbol,
        address feeRecipient,
        uint96 feeNumerator
    ) external returns (address);

    function getLocalAddress(uint32 originChainId, address originAddress)
        external
        view
        returns (address);
}
