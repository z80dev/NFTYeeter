// SPDX-License-Identifier: MIT

pragma solidity >=0.8.7 <0.9.0;

interface IDepositRegistry {
    // this is maintained on each "Home" chain where an NFT is originally locked
    // we don't need it on remote chains because:
    // - the ERC721X on the remote chain will have all the info we need to re-bridge the NFT to another chain
    // - you can't "unwrap" an NFT on a remote chain and that's what this is for
    struct DepositDetails {
        address depositor;
        bool bridged;
    }

    function withdraw(address collection, uint256 tokenId) external;

    function deposits(address, uint256) external returns (address, bool);

    function mint(address collection, uint256 tokenId, string memory tokenURI, address recipient) external;

    function burn(address collection, uint256 tokenId) external;

    function deployERC721X(uint32 originChainId, address originAddress, string memory name, string memory symbol) external returns (address);

    function getLocalAddress(uint32 originChainId, address originAddress)
        external
        view
        returns (address);

    function setDetails(
        address collection,
        uint256 tokenId,
        address _owner,
        bool bridged
    ) external;
}
