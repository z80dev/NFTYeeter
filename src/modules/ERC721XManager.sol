// SPDX-License-Identifier: AGPL-3.0-only
//
// This contract handles deploying ERC721X contracts if needed
// Should have both explicit deploy functionality & deploy-if-needed

import "ERC721X/MinimalOwnable.sol";
import "ERC721X/MinimalOwnableInitializable.sol";
import "ERC721X/ERC721XInitializable.sol";
import "../interfaces/IERC721XManager.sol";
import "openzeppelin-contracts/contracts/proxy/Clones.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import "Default/Kernel.sol";

pragma solidity >=0.8.7 <0.9.0;

contract RoyaltyReceiver is Initializable, MinimalOwnableInitializable {

    address public originCollectionAddress;
    address public originFeeRecipient;
    uint32 public originChainId;

    constructor() {
        _disableInitializers();
    }

    function initialize(address _originCollectionAddress, address _originFeeRecipient, uint32 _originChainId) public {
        originCollectionAddress = _originCollectionAddress;
        originFeeRecipient = _originFeeRecipient;
        originChainId = _originChainId;
        initialize();
    }

    function withdraw(address token, address payable recipient) external {
        require(msg.sender == _owner || msg.sender == originFeeRecipient, "UNAUTH");
        if (token == address(0x0)) {
            recipient.send(address(this).balance);
        }
        IERC20(token).transfer(recipient, IERC20(token).balanceOf(address(this)));
    }

}

contract ERC721XManager is IERC721XManager, MinimalOwnable, Module {
    struct BridgedTokenDetails {
        uint32 originChainId;
        address originAddress;
        uint256 tokenId;
        address owner;
        string name;
        string symbol;
        string tokenURI;
        address feeRecipient;
        uint96 feeNumerator;
    }

    address public erc721xImplementation;
    address public royaltyReceiverImplementation;

    event MintedCollection(
        uint32 originChainId,
        address originAddress,
        string name
    );
    event MintedItem(address collection, uint256 tokenId, address recipient);

    constructor(Kernel kernel_) MinimalOwnable() Module(kernel_) {
        erc721xImplementation = address(new ERC721XInitializable());
        royaltyReceiverImplementation = address(new RoyaltyReceiver());
    }

    function KEYCODE() public pure override returns (bytes5) {
        return bytes5("XFTMG"); // XNFT Manager
    }

    function burn(address collection, uint256 tokenId) external onlyPermitted {
        ERC721XInitializable(collection).burn(tokenId);
    }

    function mint(
        address collection,
        uint256 tokenId,
        string memory tokenURI,
        address recipient
    ) external {
        ERC721XInitializable(collection).mint(recipient, tokenId, tokenURI);
        emit MintedItem(collection, tokenId, recipient);
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
        string memory symbol,
        address feeRecipient,
        uint96 feeNumerator
    ) external onlyPermitted returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(chainId, originAddress));
        ERC721XInitializable nft = ERC721XInitializable(
            Clones.cloneDeterministic(erc721xImplementation, salt)
        );
        RoyaltyReceiver receiver = RoyaltyReceiver(
            Clones.cloneDeterministic(royaltyReceiverImplementation, salt)
        );
        receiver.initialize(originAddress, feeRecipient, chainId);
        receiver.setOwner(_owner);
        nft.initialize(name, symbol, originAddress, chainId, feeNumerator, address(receiver));
        emit MintedCollection(chainId, originAddress, name);
        return address(nft);
    }
}
