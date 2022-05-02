// SPDX-License-Identifier: AGPL-3.0-only
import "solmate/tokens/ERC721.sol";
import "openzeppelin-contracts/contracts/proxy/Clones.sol";
import "./interfaces/IDepositRegistry.sol";
import "ERC721X/ERC721XInitializable.sol";
import "ERC721X/MinimalOwnable.sol";

pragma solidity >=0.8.7 <0.9.0;

contract DepositRegistry is
    IDepositRegistry,
    ERC721TokenReceiver,
    MinimalOwnable
{
    mapping(address => bool) operatorAuth;
    address public erc721xImplementation;
    mapping(address => mapping(uint256 => DepositDetails)) public deposits; // deposits[collection][tokenId] = depositor

    constructor() MinimalOwnable() {
        erc721xImplementation = address(new ERC721XInitializable());
    }

    function setOperatorAuth(address operator, bool auth) external {
        require(msg.sender == _owner);
        operatorAuth[operator] = auth;
    }

    function setDetails(
        address collection,
        uint256 tokenId,
        address _owner,
        bool bridged
    ) external {
        require(msg.sender == _owner || operatorAuth[msg.sender]);
        DepositDetails storage details = deposits[collection][tokenId];
        if (_owner != address(0x0)) {
            details.depositor = _owner;
        }
        details.bridged = bridged;
    }

    function mint(address collection, uint256 tokenId, string memory tokenURI, address recipient) external {
        require(operatorAuth[msg.sender], "UNAUTH");
        ERC721XInitializable(collection).mint(recipient, tokenId, tokenURI);
    }

    function burn(address collection, uint256 tokenId) external {
        require(operatorAuth[msg.sender], "UNAUTH");
        ERC721XInitializable(collection).burn(tokenId);
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

    function deployERC721X(uint32 chainId, address originAddress, string memory name, string memory symbol) external returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(chainId, originAddress));
        ERC721XInitializable nft = ERC721XInitializable(
            Clones.cloneDeterministic(erc721xImplementation, salt)
        );
        nft.initialize(name, symbol, originAddress, chainId);
        return address(nft);
    }

    function withdraw(address collection, uint256 tokenId) external {
        // don't need to do much here other than send NFT back
        // could clear deposits, but why waste gas
        // a deposit is only usable if the NFT is in posession of the contract anyway
        // and anytime the contract receives an NFT via safeTransferFrom, deposits is
        // updated anyway.
        require(
            ERC721(collection).ownerOf(tokenId) == address(this),
            "NFT Not Deposited"
        );
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
        deposits[msg.sender][tokenId] = DepositDetails({
            depositor: from,
            bridged: false
        });
        return ERC721TokenReceiver.onERC721Received.selector;
    }
}
