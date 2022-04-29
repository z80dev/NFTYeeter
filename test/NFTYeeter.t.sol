// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.11;

import "forge-std/Test.sol";
import "../src/NFTYeeter.sol";
import "../src/DepositRegistry.sol";
import {IConnextHandler} from "nxtp/interfaces/IConnextHandler.sol";
import "solmate/tokens/ERC721.sol";
import "ERC721X/ERC721X.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";

contract NFTYeeterTest is Test {

    NFTYeeter yeeter;
    NFTYeeter remoteYeeter;
    DepositRegistry reg;
    ERC721X localNFT;
    address public alice = address(0xaa);
    address public bob = address(0xbb);
    address public charlie = address(0xcc);
    address public connext = address(0xce);
    address remoteContract = address(0x1111);
    address transactingAssetId = address(0);
    uint32 localDomain = uint32(1);
    uint32 remoteDomain = uint32(2);

    function setUp() public {
        reg = new DepositRegistry();
        yeeter = new NFTYeeter(localDomain, connext, transactingAssetId, address(reg));
        remoteYeeter = new NFTYeeter(remoteDomain, connext, transactingAssetId, address(reg));
        yeeter.setTrustedYeeter(remoteDomain, address(remoteYeeter));
        reg.setOperatorAuth(address(yeeter), true);
        localNFT = new ERC721X("TestMonkeys", "TST", address(0), localDomain);
        localNFT.mint(alice, 0, "testURI");
    }

    function testYeeterWillBridge() public {
        vm.startPrank(alice);
        localNFT.safeTransferFrom(alice, address(reg), 0);
        vm.mockCall(connext, abi.encodePacked(IConnextHandler.xcall.selector), abi.encode(0));
        yeeter.bridgeToken(address(localNFT), 0, alice, remoteDomain);
        (address depositor, bool bridged) = reg.deposits(address(localNFT), 0);
        assertEq(depositor, alice);
        assertTrue(bridged);

        // test that we can't bridge it again
        vm.expectRevert("ALREADY_BRIDGED");
        yeeter.bridgeToken(address(localNFT), 0, alice, remoteDomain);
    }

}
