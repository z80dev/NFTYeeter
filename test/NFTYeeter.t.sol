// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.11;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/NFTYeeter.sol";
import "../src/NFTCatcher.sol";
import "../src/DepositRegistry.sol";
import "solmate/tokens/ERC721.sol";
import {IConnextHandler} from "nxtp/interfaces/IConnextHandler.sol";
import {IExecutor} from "nxtp/interfaces/IExecutor.sol";
import "ERC721X/ERC721X.sol";
import "ERC721X/ERC721XInitializable.sol";

contract DummyNFT is ERC721 {

    constructor() ERC721("Dummy NFT", "DUM") {

    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        return "testURI";
    }

    function mint(address recipient, uint256 tokenId) external {
        _safeMint(recipient, tokenId);
    }
}

contract NFTYeeterTest is Test {

    NFTYeeter yeeter;
    NFTCatcher remoteCatcher;
    DummyNFT dumbNFT;
    DepositRegistry reg;
    ERC721XInitializable localNFT;
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
        yeeter.setDeployer(remoteCatcher);
        remoteCatcher.setTrustedYeeter(localDomain, address(yeeter));
        reg.setOperatorAuth(address(yeeter), true);
        dumbNFT = new DummyNFT();
        dumbNFT.mint(alice, 0);
        localNFT = new ERC721XInitializable();
        localNFT.initialize("TestMonkeys", "TST", address(0), localDomain);
        localNFT.mint(alice, 0, "testURI");
    }

    function testYeeterWillBridge() public {
        vm.startPrank(alice);
        dumbNFT.safeTransferFrom(alice, address(reg), 0);
        assertTrue(!dumbNFT.supportsInterface(0xefd00bbc));
        vm.mockCall(connext, abi.encodePacked(IConnextHandler.xcall.selector), abi.encode(0));
        yeeter.bridgeToken(address(dumbNFT), 0, alice, remoteDomain, 0);
        (address depositor, bool bridged) = reg.deposits(address(dumbNFT), 0);
        assertEq(depositor, alice);
        assertTrue(bridged);


        // test that we can't bridge it again
        vm.expectRevert("ALREADY_BRIDGED");
        yeeter.bridgeToken(address(dumbNFT), 0, alice, remoteDomain, 0);

        vm.stopPrank();

        vm.startPrank(connext);
        vm.mockCall(connext, abi.encodePacked(IExecutor.origin.selector), abi.encode(localDomain));
        vm.mockCall(connext, abi.encodePacked(IExecutor.originSender.selector), abi.encode(address(yeeter)));

        bytes memory details = abi.encode(BridgedTokenDetails(
                                           localDomain,
                                           address(dumbNFT),
                                           0,
                                           alice,
                                           dumbNFT.name(),
                                           dumbNFT.symbol(),
                                           "testURI"
                                                ));
        remoteCatcher.receiveAsset(details);
        ERC721XInitializable remoteNFT = ERC721XInitializable(remoteCatcher.getLocalAddress(localDomain, address(dumbNFT)));

        assertEq(keccak256(abi.encodePacked(remoteNFT.name())), keccak256("Dummy NFT"));
        assertEq(keccak256(abi.encodePacked(remoteNFT.symbol())), keccak256("DUM"));
        assertEq(keccak256(abi.encodePacked(remoteNFT.tokenURI(0))), keccak256("testURI"));
        assertEq(remoteNFT.ownerOf(0), alice);
    }

}
