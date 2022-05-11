// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.11;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/ConnextBridge.sol";
import "../src/DepositRegistry.sol";
import "../src/ERC721TransferManager.sol";
import "../src/ERC721XManager.sol";
import "openzeppelin-contracts/contracts/proxy/Clones.sol";
import "solmate/tokens/ERC721.sol";
import {IConnextHandler} from "nxtp/interfaces/IConnextHandler.sol";
import {IExecutor} from "nxtp/interfaces/IExecutor.sol";
import "ERC721X/ERC721X.sol";
import "ERC721X/ERC721XInitializable.sol";
import "Default/Kernel.sol";

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

    // Kernel & modules
    Kernel kernel;
    DepositRegistry reg;
    ERC721TransferManager nmg;
    ERC721XManager xmg;

    // Policies
    ConnextBridge yeeter;
    ConnextBridge remoteCatcher;

    // NFT contracts
    DummyNFT dumbNFT;
    address public erc721xImplementation;
    ERC721XInitializable localNFT;

    // simulated user addresses
    address public alice = address(0xaa);
    address public bob = address(0xbb);
    address public charlie = address(0xcc);

    // resources
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
        // init kernel
        kernel = new Kernel();

        // init modules
        reg = new DepositRegistry(kernel);
        nmg = new ERC721TransferManager(kernel);
        xmg = new ERC721XManager(kernel);

        // install modules
        kernel.executeAction(Actions.InstallModule, address(reg));
        kernel.executeAction(Actions.InstallModule, address(nmg));
        kernel.executeAction(Actions.InstallModule, address(xmg));

        // init policies
        yeeter = new ConnextBridge(localDomain, connext, transactingAssetId, address(kernel));
        remoteCatcher = new ConnextBridge(remoteDomain, connext, transactingAssetId, address(kernel));
        yeeter.setTrustedRemote(remoteDomain, address(remoteCatcher));
        remoteCatcher.setTrustedRemote(localDomain, address(yeeter));

        // approve policies
        kernel.executeAction(Actions.ApprovePolicy, address(yeeter));
        kernel.executeAction(Actions.ApprovePolicy, address(remoteCatcher));

        dumbNFT = new DummyNFT();
        dumbNFT.mint(alice, 0);
        erc721xImplementation = address(new ERC721XInitializable());
        bytes32 salt = keccak256(abi.encodePacked(uint32(1), address(0x0a0a)));
        localNFT = ERC721XInitializable(
            Clones.cloneDeterministic(erc721xImplementation, salt)
        );
        localNFT.initialize("TestMonkeys", "TST", address(0), localDomain);
        localNFT.mint(alice, 0, "testURI");
    }

    function testYeeterRejectsCounterfeits() public {
        // check we can't bridge an ERC721X not deployed by us
        vm.startPrank(alice);
        localNFT.setApprovalForAll(address(nmg), true);
        assertTrue(localNFT.supportsInterface(0xefd00bbc));
        vm.mockCall(connext, abi.encodePacked(IConnextHandler.xcall.selector), abi.encode(0));
        vm.expectRevert("NOT_AUTHENTIC");
        yeeter.bridgeToken(address(localNFT), 0, alice, remoteDomain, 0);
    }

    function testYeeterWillBridge() public {
        vm.startPrank(alice);
        // dumbNFT.safeTransferFrom(alice, address(reg), 0);
        // no longer moving, just approving
        dumbNFT.setApprovalForAll(address(nmg), true);
        assertTrue(!dumbNFT.supportsInterface(0xefd00bbc));
        vm.mockCall(connext, abi.encodeWithSelector(IConnextHandler.xcall.selector), abi.encode(0));
        yeeter.bridgeToken(address(dumbNFT), 0, alice, remoteDomain, 0);


        // test that we can't bridge it again
        vm.expectRevert("WRONG_FROM");
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
        ERC721XInitializable remoteNFT = ERC721XInitializable(xmg.getLocalAddress(localDomain, address(dumbNFT)));

        assertEq(keccak256(abi.encodePacked(remoteNFT.name())), keccak256("Dummy NFT"));
        assertEq(keccak256(abi.encodePacked(remoteNFT.symbol())), keccak256("DUM"));
        assertEq(keccak256(abi.encodePacked(remoteNFT.tokenURI(0))), keccak256("testURI"));
        assertEq(remoteNFT.ownerOf(0), alice);
    }

}
