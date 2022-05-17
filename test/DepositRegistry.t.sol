// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.11;

import "forge-std/Test.sol";
import "../src/modules/DepositRegistry.sol";
import "ERC721X/ERC721X.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";
import "Default/Kernel.sol";

contract DepositRegistryTest is Test {

    ERC721X localNFT;
    Kernel kernel;
    DepositRegistry reg;
    address public alice = address(0xaa);
    address public bob = address(0xbb);
    address public charlie = address(0xcc);

    function setUp() public {
        kernel = new Kernel();
        reg = new DepositRegistry(kernel);
        localNFT = new ERC721X("TestMonkeys", "TST", address(0), uint16(0));
        localNFT.mint(alice, 0, "testURI");
    }

    function testYeeterAcceptsDeposits() public {
        vm.prank(alice);
        localNFT.safeTransferFrom(alice, address(reg), 0);
        assertEq(localNFT.ownerOf(0), address(reg));
    }

    /*
    function testYeeterWillBridge() public {
        vm.startPrank(alice);
        localNFT.safeTransferFrom(alice, address(yeeter), 0);
        vm.mockCall(connext, abi.encodePacked(IConnextHandler.xcall.selector), abi.encode(0));
        yeeter.bridgeToken(address(localNFT), 0, alice, remoteDomain);
        (address depositor, bool bridged) = yeeter.deposits(address(localNFT), 0);
        assertEq(depositor, alice);
        assertTrue(bridged);
    }
    */

}
