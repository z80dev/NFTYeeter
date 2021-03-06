// SPDX-License-Identifier: AGPL-3.0-only
//

pragma solidity >=0.8.7 <0.9.0;

import "solmate/tokens/ERC721.sol";
import "../interfaces/IDepositRegistry.sol";
import "ERC721X/ERC721XInitializable.sol";
import "Default/Kernel.sol";


contract DepositRegistry is
    IDepositRegistry,
    ERC721TokenReceiver,
    Module
{
    function KEYCODE() public pure override returns (bytes5) {
        return bytes5("DPREG");
    }

    constructor(Kernel kernel_) Module(kernel_) {}

    function withdraw(
        address collection,
        address recipient,
        uint256 tokenId
    ) external onlyPermitted {
        ERC721(collection).safeTransferFrom(address(this), recipient, tokenId);
    }
}
