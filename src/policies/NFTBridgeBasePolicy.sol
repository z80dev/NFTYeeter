// SPDX-License-Identifier: AGPL-3.0-only
//

pragma solidity >=0.8.7 <0.9.0;

import "Default/Kernel.sol";
import "../modules/ERC721TransferManager.sol";
import "../modules/ERC721XManager.sol";
import "../modules/DepositRegistry.sol";


abstract contract NFTBridgeBasePolicy is Policy {
    // Modules this Policy communicates with
    ERC721TransferManager public mgr;
    ERC721XManager public xmgr;
    DepositRegistry public registry;

    constructor(address _kernel) Policy(Kernel(_kernel)) {}

    function configureReads() external override onlyKernel {
        registry = DepositRegistry(getModuleAddress(bytes5("DPREG")));
        mgr = ERC721TransferManager(getModuleAddress(bytes5("NFTMG")));
        xmgr = ERC721XManager(getModuleAddress(bytes5("XFTMG")));
    }

    function requestWrites()
        external
        view
        override
        onlyKernel
        returns (bytes5[] memory permissions)
    {
        bytes5[] memory reqs = new bytes5[](3);
        reqs[0] = bytes5("NFTMG");
        reqs[1] = bytes5("XFTMG");
        reqs[2] = bytes5("DPREG");
        return reqs;
    }
}
