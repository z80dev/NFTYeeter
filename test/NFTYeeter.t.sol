// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.11;

import "forge-std/Test.sol";
import "../src/NFTYeeter.sol";
import "../src/NFTCatcher.sol";
import "../src/DepositRegistry.sol";
import {IConnextHandler} from "nxtp/interfaces/IConnextHandler.sol";
import {IExecutor} from "nxtp/interfaces/IExecutor.sol";
import "ERC721X/ERC721X.sol";
import "ERC721X/ERC721XInitializable.sol";

contract NFTYeeterTest is Test {

    NFTYeeter yeeter;
    NFTCatcher remoteCatcher;
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

    struct BridgedTokenDetails {
        uint32 originChainId;
        address originAddress;
        uint256 tokenId;
        address owner;
        string name;
        string symbol;
        string tokenURI;
    }


    function setUp() public {
        reg = new DepositRegistry();
        yeeter = new NFTYeeter(localDomain, connext, transactingAssetId, address(reg));
        remoteCatcher = new NFTCatcher(remoteDomain, connext, transactingAssetId, address(reg));
        yeeter.setTrustedCatcher(remoteDomain, address(remoteCatcher));
        remoteCatcher.setTrustedYeeter(localDomain, address(yeeter));
        reg.setOperatorAuth(address(yeeter), true);
        localNFT = new ERC721X("TestMonkeys", "TST", address(0), localDomain);
        localNFT.mint(alice, 0, "testURI");
    }

    function testYeeterWillBridge() public {
        vm.startPrank(alice);
        localNFT.safeTransferFrom(alice, address(reg), 0);
        vm.mockCall(connext, abi.encodePacked(IConnextHandler.xcall.selector), abi.encode(0));
        yeeter.bridgeToken(address(localNFT), 0, alice, remoteDomain, 0);
        (address depositor, bool bridged) = reg.deposits(address(localNFT), 0);
        assertEq(depositor, alice);
        assertTrue(bridged);


        // test that we can't bridge it again
        vm.expectRevert("ALREADY_BRIDGED");
        yeeter.bridgeToken(address(localNFT), 0, alice, remoteDomain, 0);

        vm.stopPrank();

        vm.prank(connext);
        vm.mockCall(connext, abi.encodePacked(IExecutor.origin.selector), abi.encode(localDomain));
        vm.mockCall(connext, abi.encodePacked(IExecutor.originSender.selector), abi.encode(address(yeeter)));

        bytes memory details = abi.encode(BridgedTokenDetails(
                                           localDomain,
                                           address(localNFT),
                                           0,
                                           alice,
                                           "TestMonkeys",
                                           "TST",
                                           "testURI"
                                                ));
        remoteCatcher.receiveAsset(details);
        ERC721XInitializable remoteNFT = ERC721XInitializable(remoteCatcher.getLocalAddress(localDomain, address(localNFT)));

        // remoteNFT.name();
        assertEq(keccak256(abi.encodePacked(remoteNFT.name())), keccak256("TestMonkeys"));
        assertEq(keccak256(abi.encodePacked(remoteNFT.symbol())), keccak256("TST"));
        assertEq(keccak256(abi.encodePacked(remoteNFT.tokenURI(0))), keccak256("testURI"));
        assertEq(remoteNFT.ownerOf(0), alice);
    }

}
