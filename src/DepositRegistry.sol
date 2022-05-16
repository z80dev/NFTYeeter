// SPDX-License-Identifier: AGPL-3.0-only
//
import "solmate/tokens/ERC721.sol";
import "openzeppelin-contracts/contracts/proxy/Clones.sol";
import "./interfaces/IDepositRegistry.sol";
import "ERC721X/ERC721XInitializable.sol";
import "ERC721X/MinimalOwnable.sol";
import "Default/Kernel.sol";

pragma solidity >=0.8.7 <0.9.0;

contract DepositRegistry is
    IDepositRegistry,
    ERC721TokenReceiver,
    MinimalOwnable,
    Module
{
    function KEYCODE() public pure override returns (bytes5) {
        return bytes5("DPREG");
    }

    constructor(Kernel kernel_) MinimalOwnable() Module(kernel_) {}

    function withdraw(
        address collection,
        address recipient,
        uint256 tokenId
    ) external onlyPermitted {
        ERC721(collection).safeTransferFrom(address(this), recipient, tokenId);
    }
}
