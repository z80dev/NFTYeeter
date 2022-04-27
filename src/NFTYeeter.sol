// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/tokens/ERC721.sol";
import "ERC721X/interfaces/IERC721X.sol";

contract NFTYeeter is ERC721TokenReceiver {

    uint32 public immutable localDomain;
    address public immutable connext;

    mapping(address => mapping(uint256 => DepositDetails)) deposits; // deposits[collection][tokenId] = depositor
    mapping(uint16 => mapping(address => address)) localAddress; // localAddress[originChainId][collectionAddress]

    constructor(uint32 _localDomain, address _connext) {
        localDomain = _localDomain;
        connext = _connext;
    }

    // this is maintained on each "Home" chain where an NFT is originally locked
    struct DepositDetails {
        address depositor;
        bool bridged;
    }

    // this is used to mint new NFTs upon receipt
    // if this big payload makes bridging expensive, we should separate
    // the process of bridging a collection (name, symbol) from bridging
    // of tokens (tokenId, tokenUri)
    struct BridgedTokenDetails {
        uint16 originChainId;
        address originAddress;
        uint256 tokenId;
        address owner;
        string name;
        string symbol;
        string tokenURI;
    }

    function getLocalAddress(uint16 originChainId, address originAddress) external view returns (address) {
        return localAddress[originChainId][originAddress];
    }

    function withdraw(address collection, uint256 tokenId) external {
        require(ERC721(collection).ownerOf(tokenId) == address(this), "NFT Not Deposited");
        DepositDetails memory details = deposits[collection][tokenId];
        require(details.bridged == false, "NFT Currently Bridged");
        require(details.depositor == msg.sender, "Unauth");
        ERC721(collection).safeTransferFrom(address(this), msg.sender, tokenId);
    }

    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        deposits[msg.sender][tokenId] = DepositDetails({depositor: from, bridged: false });
        return ERC721TokenReceiver.onERC721Received.selector;
    }
}
