// SPDX-License-Identifier: AGPL-3.0-only
//
// This contract handles deploying ERC721X contracts if needed
// Should have both explicit deploy functionality & deploy-if-needed

import "ERC721X/MinimalOwnable.sol";
import "ERC721X/ERC721XInitializable.sol";
import "./interfaces/IERC721XManager.sol";
import "openzeppelin-contracts/contracts/proxy/Clones.sol";
import "Default/Kernel.sol";

pragma solidity >=0.8.7 <0.9.0;

contract ERC721XManager is IERC721XManager, MinimalOwnable, Module {
    struct BridgedTokenDetails {
        uint32 originChainId;
        address originAddress;
        uint256 tokenId;
        address owner;
        string name;
        string symbol;
        string tokenURI;
    }

    address public erc721xImplementation;

    constructor(Kernel kernel_) MinimalOwnable() Module(kernel_) {
        erc721xImplementation = address(new ERC721XInitializable());
    }

    function KEYCODE() external pure override returns (bytes3) {
        return bytes3("XMG"); // XNFT Manager
    }

    function burn(address collection, uint256 tokenId) external onlyPolicy {
        ERC721XInitializable(collection).burn(tokenId);
    }

    function mint(
        address collection,
        uint256 tokenId,
        string memory tokenURI,
        address recipient
    ) external onlyPolicy {
        ERC721XInitializable(collection).mint(recipient, tokenId, tokenURI);
    }

    function _calculateCreate2Address(uint32 chainId, address originAddress)
        internal
        view
        returns (address)
    {
        bytes32 salt = keccak256(abi.encodePacked(chainId, originAddress));
        return Clones.predictDeterministicAddress(erc721xImplementation, salt);
    }

    function getLocalAddress(uint32 originChainId, address originAddress)
        external
        view
        returns (address)
    {
        return _calculateCreate2Address(originChainId, originAddress);
    }

    function deployERC721X(
        uint32 chainId,
        address originAddress,
        string memory name,
        string memory symbol
    ) external onlyPolicy returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(chainId, originAddress));
        ERC721XInitializable nft = ERC721XInitializable(
            Clones.cloneDeterministic(erc721xImplementation, salt)
        );
        nft.initialize(name, symbol, originAddress, chainId);
        return address(nft);
    }
}
