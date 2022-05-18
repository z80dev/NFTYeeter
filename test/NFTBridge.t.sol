// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.11;

// import "forge-std/Test.sol";
import "xapp-starter/contract-to-contract-interactions/test/utils/DSTestPlus.sol";
import {ConnextHandler} from "nxtp/nomad-xapps/contracts/connext/ConnextHandler.sol";
import "forge-std/console.sol";
import "../src/policies/ConnextNFTBridge.sol";
import "../src/modules/DepositRegistry.sol";
import "../src/modules/ERC721TransferManager.sol";
import "../src/modules/ERC721XManager.sol";
import "openzeppelin-contracts/contracts/proxy/Clones.sol";
import "solmate/tokens/ERC721.sol";
import {IConnextHandler} from "nxtp/interfaces/IConnextHandler.sol";
import {IExecutor} from "nxtp/interfaces/IExecutor.sol";
import "ERC721X/ERC721X.sol";
import "ERC721X/ERC721XInitializable.sol";
import "Default/Kernel.sol";
import "solidity-examples/mocks/LZEndpointMock.sol";

contract DummyNFT is ERC721 {

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {

    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        return "https://api.fantums.com/token/233";
    }

    function mint(address recipient, uint256 tokenId) external {
        _safeMint(recipient, tokenId);
    }
}

contract ConnextNFTBridgeTestFork is DSTestPlus {
    // Kernel & modules
    Kernel kernel;
    DepositRegistry reg;
    ERC721TransferManager nmg;
    ERC721XManager xmg;

    // Policies
    ConnextNFTBridge yeeter;
    ConnextNFTBridge remoteCatcher;

    address payable public connext = payable(0x71a52104739064bc35bED4Fc3ba8D9Fb2a84767f);
    address public constant testToken =
        0xB5AabB55385bfBe31D627E2A717a7B189ddA4F8F;

    // NFT contracts
    DummyNFT dumbNFT;
    address public erc721xImplementation;
    ERC721XInitializable localNFT;

    // simulated user addresses
    address public alice = address(0x51B746b9fa5484406aACc8E1Cc6D849e9cd2b5f8);
    // address public bob = address(0xbb);
    // address public charlie = address(0xcc);

    // resources
    // address public connext = address(0xce);
    LZEndpointMock public lzEndpoint;
    uint16 lzChainId = uint16(100);

    address remoteContract = address(0x1111);

    address transactingAssetId = address(0);

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

        // init lz endpoit
        lzEndpoint = new LZEndpointMock(lzChainId);

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
        yeeter = new ConnextNFTBridge(kovanDomainId, connext, testToken, address(kernel));

        // connext trusts
        yeeter.setTrustedRemote(rinkebyDomainId, address(yeeter));

        // init lz data
        lzEndpoint.setDestLzEndpoint(address(yeeter), address(lzEndpoint));

        // approve policies
        kernel.executeAction(Actions.ApprovePolicy, address(yeeter));

        dumbNFT = new DummyNFT("Dummy", "DUM");
        dumbNFT.mint(alice, 0);
    }

    function testReceive() public {
        address executor = address(ConnextHandler(connext).executor());
        vm.startPrank(executor);
        vm.mockCall(executor, abi.encodePacked(IExecutor.origin.selector), abi.encode(rinkebyDomainId));
        vm.mockCall(executor, abi.encodePacked(IExecutor.originSender.selector), abi.encode(address(yeeter)));

        bytes memory details = abi.encode(BridgedTokenDetails(
                                           rinkebyDomainId,
                                           address(dumbNFT),
                                           0,
                                           alice,
                                           dumbNFT.name(),
                                           dumbNFT.symbol(),
                                           "testURI"
                                                ));
        yeeter.receiveAsset(details);

        ERC721XInitializable remoteNFT = ERC721XInitializable(xmg.getLocalAddress(uint16(rinkebyDomainId), address(dumbNFT)));
        assertEq(remoteNFT.ownerOf(0), alice);
    }

    function testYeeterWillBridge() public {
        vm.startPrank(alice);
        // dumbNFT.safeTransferFrom(alice, address(reg), 0);
        // no longer moving, just approving
        dumbNFT.setApprovalForAll(address(nmg), true);
        assertTrue(!dumbNFT.supportsInterface(0xefd00bbc));
        vm.mockCall(connext, abi.encodeWithSelector(IConnextHandler.xcall.selector), abi.encode(0));
        yeeter.bridgeToken(address(dumbNFT), 0, alice, rinkebyDomainId, 0);


        // test that we can't bridge it again
        vm.expectRevert("WRONG_FROM");
        yeeter.bridgeToken(address(dumbNFT), 0, alice, rinkebyDomainId, 0);

        vm.stopPrank();

        address executor = address(ConnextHandler(connext).executor());
        vm.startPrank(executor);
        vm.mockCall(executor, abi.encodePacked(IExecutor.origin.selector), abi.encode(rinkebyDomainId));
        vm.mockCall(executor, abi.encodePacked(IExecutor.originSender.selector), abi.encode(address(yeeter)));
        bytes memory details = abi.encode(BridgedTokenDetails(
                                           kovanDomainId,
                                           address(dumbNFT),
                                           0,
                                           alice,
                                           dumbNFT.name(),
                                           dumbNFT.symbol(),
                                           "testURI"
                                                ));

        yeeter.receiveAsset(details);
        vm.stopPrank();
        assertEq(alice, dumbNFT.ownerOf(0));
        // remoteCatcher.receiveAsset(details);

        // assertEq(keccak256(abi.encodePacked(remoteNFT.symbol())), keccak256("DUM"));
        // assertEq(keccak256(abi.encodePacked(remoteNFT.tokenURI(0))), keccak256("testURI"));
        // assertEq(remoteNFT.ownerOf(0), alice);
    }

}

contract ConnextNFTBridgeTest is DSTestPlus {

    // Kernel & modules
    Kernel kernel;
    DepositRegistry reg;
    ERC721TransferManager nmg;
    ERC721XManager xmg;

    // Policies
    ConnextNFTBridge yeeter;
    ConnextNFTBridge remoteCatcher;

    // NFT contracts
    DummyNFT dumbNFT;
    address public erc721xImplementation;
    ERC721XInitializable localNFT;

    // simulated user addresses
    address public alice = address(0xaa);
    address public bob = address(0xbb);
    address public charlie = address(0xcc);

    // resources
    address payable public connext = payable(address(0xce));
    LZEndpointMock public lzEndpoint;

    address remoteContract = address(0x1111);

    address transactingAssetId = address(0);

    uint16 localDomain = uint16(1);
    uint16 remoteDomain = uint16(2);
    uint16 lzChainId = uint16(100);

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

        // init lz endpoit
        lzEndpoint = new LZEndpointMock(lzChainId);

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
        yeeter = new ConnextNFTBridge(localDomain, connext, transactingAssetId, address(kernel));
        remoteCatcher = new ConnextNFTBridge(remoteDomain, connext, transactingAssetId, address(kernel));

        // connext trusts
        yeeter.setTrustedRemote(remoteDomain, address(remoteCatcher));

        // lz trusts
        remoteCatcher.setTrustedRemote(localDomain, address(yeeter));

        // approve policies
        kernel.executeAction(Actions.ApprovePolicy, address(yeeter));
        kernel.executeAction(Actions.ApprovePolicy, address(remoteCatcher));

        dumbNFT = new DummyNFT("Dummy", "DUM");
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
