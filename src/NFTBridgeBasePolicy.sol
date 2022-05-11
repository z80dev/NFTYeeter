// SPDX-License-Identifier: AGPL-3.0-only
//

import "Default/Kernel.sol";
import "./ConnextBaseXApp.sol";
import "./ERC721TransferManager.sol";
import "./ERC721XManager.sol";
import "./DepositRegistry.sol";

pragma solidity >=0.8.7 <0.9.0;

abstract contract NFTBridgeBasePolicy is ConnextBaseXApp, Policy {
    // Modules this Policy communicates with
    ERC721TransferManager public mgr;
    ERC721XManager public xmgr;
    DepositRegistry public registry;

    constructor(
        address _connext,
        uint32 _domain,
        address _kernel
    ) ConnextBaseXApp(_connext, _domain) Policy(Kernel(_kernel)) {}

    function configureModules() external override onlyKernel {
        mgr = ERC721TransferManager(requireModule(bytes3("NMG")));
        xmgr = ERC721XManager(requireModule(bytes3("XMG")));
        registry = DepositRegistry(requireModule(bytes3("REG")));
    }
}