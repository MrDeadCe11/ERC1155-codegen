// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import "forge-std/StdJson.sol";
import {MudTest} from "@latticexyz/world/test/MudTest.t.sol";
import {ResourceId} from "@latticexyz/store/src/ResourceId.sol";
import {StoreSwitch} from "@latticexyz/store/src/StoreSwitch.sol";
import {World} from "@latticexyz/world/src/World.sol";
import {WorldResourceIdLib, WorldResourceIdInstance} from "@latticexyz/world/src/WorldResourceId.sol";
import {IWorld} from "../src/codegen/world/IWorld.sol";
import {SystemRegistry} from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import {NamespaceOwner} from "@latticexyz/world/src/codegen/tables/NamespaceOwner.sol";
import {IWorldErrors} from "@latticexyz/world/src/IWorldErrors.sol";
import {RESOURCE_SYSTEM, RESOURCE_NAMESPACE} from "@latticexyz/world/src/worldResourceTypes.sol";
import {Systems} from "@latticexyz/world/src/codegen/tables/Systems.sol";
import {PuppetModule} from "@latticexyz/world-modules/src/modules/puppet/PuppetModule.sol";
import {ERC1155Module} from "../src/systems/ERC1155Module.sol";
import {IERC1155} from "../src/systems/IERC1155.sol";
import {ERC1155MetadataURI} from "../src/codegen/tables/ERC1155MetadataURI.sol";
import {ERC1155System} from "../src/systems/ERC1155System.sol";
import {ERC1155URIStorageSystem} from "../src/systems/ERC1155URIStorageSystem.sol";
import {IERC1155MetadataURI} from "../src/systems/IERC1155MetadataURI.sol";
import {IERC1155Receiver} from "../src/systems/IERC1155Receiver.sol";
import {registerERC1155} from "../src/systems/registerERC1155.sol";
import {IERC1155Errors} from "../src/systems/IERC1155Errors.sol";
import {IERC1155Events} from "../src/systems/IERC1155Events.sol";
import {_erc1155SystemId, _erc1155URIStorageSystemId} from "../src/systems/utils.sol";
import {MODULE_NAMESPACE} from "../src/systems/constants.sol";
import {TestConfig} from "../src/codegen/tables/TestConfig.sol";
import {ERC721System} from "@latticexyz/world-modules/src/modules/erc721-puppet/ERC721System.sol";

abstract contract ERC1155TokenReceiver {
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }
}

contract ERC1155Recipient is ERC1155TokenReceiver {
    address public operator;
    address public from;
    uint256 public id;
    bytes public data;

    function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes calldata _data)
        public
        virtual
        override
        returns (bytes4)
    {
        operator = _operator;
        from = _from;
        id = _id;
        data = _data;

        return ERC1155TokenReceiver.onERC1155Received.selector;
    }
}

contract RevertingERC1155Recipient is ERC1155TokenReceiver {
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external override returns (bytes4) {
        revert(string(abi.encodeWithSelector(ERC1155TokenReceiver.onERC1155Received.selector)));
    }
}

contract WrongReturnDataERC1155Recipient is ERC1155TokenReceiver {
    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        public
        virtual
        override
        returns (bytes4)
    {
        return 0xCAFEBEEF;
    }
}

contract NonERC1155Recipient {}

contract ERC1155Test is MudTest, IERC1155Events, IERC1155Errors {
    using WorldResourceIdInstance for ResourceId;
    using stdJson for string;

    address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
    IWorld world;
    ERC1155Module erc1155Module;
    IERC1155 base;
    ERC1155System public token;
    ERC1155URIStorageSystem uriStorage;
    bytes14 public erc1155Namespace = "ERC1155";
    ERC721System public erc721Token;
    address test721System;
    address test1155System;

    function setUp() public override {
        super.setUp();
        world = IWorld(worldAddress);
        StoreSwitch.setStoreAddress(address(world));
        vm.startPrank(deployer);
        IERC1155 base = registerERC1155(world, erc1155Namespace, "test_IERC1155_uri/");

        world.grantAccess(_erc1155SystemId(erc1155Namespace), address(this));
        ResourceId test1155resourceId =
            WorldResourceIdLib.encode({typeId: RESOURCE_SYSTEM, namespace: "TST", name: bytes16("Test1155System")});
        test1155System = Systems.getSystem(test1155resourceId);
        world.transferOwnership(WorldResourceIdLib.encodeNamespace(erc1155Namespace), address(this));
        token = ERC1155System(address(base));

        ResourceId test721SystemId =
            WorldResourceIdLib.encode({typeId: RESOURCE_SYSTEM, namespace: "TST", name: bytes16("TestERC721System")});
        test721System = Systems.getSystem(test721SystemId);
        address test721 = TestConfig.getErc721();
        erc721Token = ERC721System(test721);
        // address uriStorageAddress = Systems.getSystem(_erc1155URIStorageSystemId('myERC1155'));
        // uriStorage = ERC1155URIStorageSystem(uriStorageAddress);
        // world.grantAccess(_erc1155URIStorageSystemId('myERC1155'), address(this));
        vm.label(worldAddress, "world");
        vm.label(address(token), "ERC1155System");
        vm.label(test1155System, "test 1155 system");
        vm.stopPrank();
    }

    function _expectAccessDenied(address caller) internal {
        ResourceId tokenSystemId = _erc1155SystemId("ERC1155");
        vm.expectRevert(
            abi.encodeWithSelector(IWorldErrors.World_AccessDenied.selector, tokenSystemId.toString(), caller)
        );
    }

    function _expectMintEvent(address to, uint256 id, uint256 value) internal {
        _expectTransferEvent(address(0), address(0), to, id, value);
    }

    function _expectBurnEvent(address from, uint256 id, uint256 value) internal {
        _expectTransferEvent(from, from, address(0), id, value);
    }

    function _expectTransferEvent(address operator, address from, address to, uint256 id, uint256 value) internal {
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(operator, from, to, id, value);
    }

    function _expectApprovalForAllEvent(address owner, address operator, bool approved) internal {
        vm.expectEmit(true, true, true, true);
        emit ApprovalForAll(owner, operator, approved);
    }

    function _assumeDifferentNonZero(address address1, address address2) internal pure {
        vm.assume(address1 != address(0));
        vm.assume(address2 != address(0));
        vm.assume(address1 != address2);
    }

    function _assumeEOA(address address1) internal view {
        uint256 toCodeSize;
        assembly {
            toCodeSize := extcodesize(address1)
        }
        vm.assume(toCodeSize == 0);
    }

    function _assumeDifferentNonZero(address address1, address address2, address address3) internal pure {
        vm.assume(address1 != address(0));
        vm.assume(address2 != address(0));
        vm.assume(address3 != address(0));
        vm.assume(address1 != address2);
        vm.assume(address2 != address3);
        vm.assume(address3 != address1);
    }

    function testSetUp() public {
        assertTrue(address(token) != address(0));
        assertEq(NamespaceOwner.get(WorldResourceIdLib.encodeNamespace("ERC1155")), address(this));
    }

    function testInstallTwice() public {
        // Install the ERC721 module again
        IERC1155 anotherTokenBase = registerERC1155(world, "anotherERC1155", "test2tokenuri");
        ERC1155System anotherToken = new ERC1155System();
        world.grantAccess(_erc1155SystemId("anotherERC1155"), address(this));
        world.transferOwnership(WorldResourceIdLib.encodeNamespace("anotherERC1155"), address(this));
        assertTrue(address(anotherToken) != address(0));
        assertTrue(address(anotherToken) != address(token));
    }

    function test_erc721Module() public {
        world.TST__mint();
        assertEq(erc721Token.balanceOf(test721System), 1);
    }

    /////////////////////////////////////////////////
    // SOLADY ERC1155 TEST CASES
    // (https://github.com/Vectorized/solady/blob/main/test/ERC1155.t.sol)
    /////////////////////////////////////////////////

    function testMint(uint256 id, address owner, uint256 value) public {
        vm.assume(value != 0 && value < uint256(type(int256).max));
        vm.assume(owner != address(0));

        token.mint(owner, id, value, "");
        // world.TST__mint1155(owner, id, value);
        // token.isApprovedForAll(owner, address(this));
        assertEq(token.balanceOf(owner, id), value);
    }

    function testTokenURI(address owner) public {
        vm.assume(owner != address(0));

        token.mint(owner, 1, 1, "");
        uriStorage.setTokenURI(1, "1");
        IERC1155MetadataURI tokenMetadata = IERC1155MetadataURI(address(token));
        assertEq(token.uri(1), "testTokenURI/1");
    }

    function testMintRevertAccessDenied(uint256 id, address owner, uint256 value, address operator) public {
        _assumeDifferentNonZero(owner, operator, address(this));

        _expectAccessDenied(operator);
        vm.prank(operator);
        token.mint(owner, id, value, "");
    }

    function testBurn(uint256 id, address owner, uint256 value) public {
        vm.assume(owner != address(0));
        vm.assume(value != 0 && value < uint256(type(int256).max));
        assertEq(token.balanceOf(owner, id), 0, "before");

        token.mint(owner, id, value, "");

        assertEq(token.balanceOf(owner, id), value, "after mint");

        vm.prank(owner);
        token.burn(id, value);

        assertEq(token.balanceOf(owner, id), 0, "after burn");
    }

    function testBurnRevertAccessDenied(uint256 id, address owner, uint256 value, address operator) public {
        _assumeDifferentNonZero(owner, operator, address(this));
        vm.assume(value != 0 && value < uint256(type(int256).max));
        token.mint(owner, id, value, "");

        vm.expectRevert();
        vm.prank(operator);
        token.burn(id, value);
    }

    function testTransferFrom(address owner, address to, uint256 tokenId, uint256 value) public {
        _assumeDifferentNonZero(owner, to);
        vm.assume(value != 0 && value < uint256(type(int256).max));
        token.mint(owner, tokenId, value, "");

        vm.prank(owner);
        token.transferFrom(owner, to, tokenId, value);

        assertEq(token.balanceOf(owner, tokenId), 0);
        assertEq(token.balanceOf(to, tokenId), value);
    }

    function testApproveAll(address owner, address operator, bool approved) public {
        _assumeDifferentNonZero(owner, operator);

        vm.prank(owner);
        _expectApprovalForAllEvent(owner, operator, approved);

        token.setApprovalForAll(operator, approved);

        assertEq(token.isApprovedForAll(owner, operator), approved);
    }

    function testTransferFromSelf(uint256 id, address from, address to, uint256 value) public {
        _assumeDifferentNonZero(from, to);
        vm.assume(value != 0 && value < uint256(type(int256).max));
        token.mint(from, id, value, "");

        vm.prank(from);
        token.transferFrom(from, to, id, value);

        // assertEq(world.getApproved(id), address(0));
        assertEq(token.balanceOf(to, id), value);
        assertEq(token.balanceOf(from, id), 0);
    }

    function testTransferFromApproveAll(uint256 id, address from, address to, uint256 value, address operator) public {
        _assumeDifferentNonZero(from, to, operator);
        vm.assume(value != 0 && value < uint256(type(int256).max));
        token.mint(from, id, value, "");

        vm.prank(from);
        token.setApprovalForAll(operator, true);

        vm.prank(operator);
        token.transferFrom(from, to, id, value);

        assertEq(token.balanceOf(to, id), value);
        assertEq(token.balanceOf(from, id), 0);
    }

    function testSafeTransferFromToEOA(uint256 id, address from, address to, uint256 value, address operator) public {
        _assumeEOA(from);
        _assumeEOA(to);
        _assumeDifferentNonZero(from, to, operator);
        vm.assume(value != 0 && value < uint256(type(int256).max));

        token.mint(from, id, value, "");

        vm.prank(from);
        token.setApprovalForAll(operator, true);

        vm.prank(operator);
        token.safeTransferFrom(from, to, id, value, "");

        assertFalse(token.isApprovedForAll(from, to));
        assertEq(token.balanceOf(to, id), value);
        assertEq(token.balanceOf(from, id), 0);
    }

    function testSafeTransferFromToERC1155Recipient(uint256 id, address from, uint256 value, address operator) public {
        ERC1155Recipient recipient = new ERC1155Recipient();
        _assumeDifferentNonZero(from, operator, address(recipient));
        vm.assume(value != 0 && value < uint256(type(int256).max));
        token.mint(from, id, value, "");

        vm.prank(from);
        token.setApprovalForAll(operator, true);

        vm.prank(operator);
        token.safeTransferFrom(from, address(recipient), id, value, "");

        assertEq(token.balanceOf(address(recipient), id), value);
        assertEq(token.balanceOf(from, id), 0);

        assertEq(recipient.operator(), operator);
        assertEq(recipient.from(), from);
        assertEq(recipient.id(), id);
        assertEq(recipient.data(), "");
    }

    function testSafeMintToEOA(uint256 id, address to, uint256 value) public {
        _assumeEOA(to);
        vm.assume(to != address(0));
        vm.assume(value != 0 && value < uint256(type(int256).max));

        token.safeMint(to, id, value, "");

        assertEq(token.balanceOf(to, id), value);
    }

    function testSafeMintToERC1155Recipient(uint256 id, uint256 value) public {
        ERC1155Recipient to = new ERC1155Recipient();
        vm.assume(value != 0 && value < uint256(type(int256).max));
        token.safeMint(address(to), id, value, "");

        assertEq(token.balanceOf(address(to), id), value);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), id);
        assertEq(to.data(), "");
    }

    function testMintToZeroReverts(uint256 id, uint256 value) public {
        vm.expectRevert(abi.encodeWithSelector(ERC1155InvalidReceiver.selector, address(0)));
        token.mint(address(0), id, value, "");
    }

    // function testDoubleMintIncreasesTotalSupply(uint256 id, address to, uint256 value) public {
    //     vm.assume(to != address(0));
    //     vm.assume(value != 0 && value < (uint256(type(int256).max) / 2));
    //     token.mint(to, id, value);

    //     token.mint(to, id, value);
    //     uint256 totalSupply = world.totalSupply(id);
    //     assertEq(totalSupply, value + value);
    // }

    function testBurnNonExistentReverts(uint256 id, uint256 value) public {
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155NonexistentToken.selector, id));
        token.burn(id, value);
    }

    function testDoubleBurnReverts(uint256 id, uint256 value) public {
        vm.assume(value != 0 && value < uint256(type(int256).max));

        token.mint(address(this), id, value, "");
        token.burn(id, value);

        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155NonexistentToken.selector, id));
        token.burn(id, value);
    }

    function testTransferFromNotExistentReverts(address from, address to, uint256 id, uint256 value) public {
        _assumeDifferentNonZero(from, to);

        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155NonexistentToken.selector, id));
        token.transferFrom(address(this), to, id, value);
    }

    function testTransferFromWrongFromReverts(address to, uint256 id, address owner, address from, uint256 value)
        public
    {
        _assumeDifferentNonZero(owner, from, to);
        vm.assume(value != 0 && value < uint256(type(int256).max));
        token.mint(owner, id, value, "");

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155MissingApprovalForAll.selector, owner, from));
        token.transferFrom(from, to, id, value);
    }

    function testTransferFromToZeroReverts(uint256 id, uint256 value) public {
        vm.assume(value != 0 && value < uint256(type(int256).max));
        token.mint(address(this), id, value, "");

        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(0)));
        token.transferFrom(address(this), address(0), id, value);
    }

    function testTransferFromNotOwner(uint256 id, address from, address to, uint256 value, address operator) public {
        _assumeDifferentNonZero(from, to, operator);
        vm.assume(value != 0 && value < uint256(type(int256).max));
        token.mint(from, id, value, "");

        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155MissingApprovalForAll.selector, operator, from));
        token.transferFrom(from, to, id, value);
    }

    function testSafeTransferFromToNonERC1155RecipientReverts(uint256 id, address from, uint256 value) public {
        vm.assume(from != address(0));
        vm.assume(value != 0 && value < uint256(type(int256).max));

        token.mint(from, id, value, "");

        address to = address(new NonERC1155Recipient());

        vm.prank(from);
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, to));
        token.safeTransferFrom(from, to, id, value, "");
    }

    function testSafeTransferFromToNonERC1155RecipientWithDataReverts(
        uint256 id,
        address from,
        uint256 value,
        bytes memory data
    ) public {
        vm.assume(from != address(0));
        vm.assume(value != 0 && value < uint256(type(int256).max));
        token.mint(from, id, value, "");

        address to = address(new NonERC1155Recipient());

        vm.prank(from);
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, to));
        token.safeTransferFrom(from, to, id, value, data);
    }

    function testSafeTransferFromToRevertingERC1155RecipientReverts(uint256 id, address from, uint256 value) public {
        vm.assume(from != address(0));
        vm.assume(value != 0 && value < uint256(type(int256).max));
        token.mint(from, id, value, "");

        address to = address(new RevertingERC1155Recipient());

        vm.prank(from);
        vm.expectRevert(abi.encodeWithSelector(IERC1155Receiver.onERC1155Received.selector));
        token.safeTransferFrom(from, to, id, value, "");
    }

    function testSafeTransferFromToRevertingERC1155RecipientWithDataReverts(
        uint256 id,
        address from,
        uint256 value,
        bytes memory data
    ) public {
        vm.assume(from != address(0));
        vm.assume(value != 0 && value < uint256(type(int256).max));
        token.mint(from, id, value, "");

        address to = address(new RevertingERC1155Recipient());

        vm.prank(from);
        vm.expectRevert(abi.encodeWithSelector(IERC1155Receiver.onERC1155Received.selector));
        token.safeTransferFrom(from, to, id, value, data);
    }

    function testSafeTransferFromToERC1155RecipientWithWrongReturnDataReverts(uint256 id, address from, uint256 value)
        public
    {
        vm.assume(from != address(0));
        vm.assume(value != 0 && value < uint256(type(int256).max));
        token.mint(from, id, value, "");

        address to = address(new WrongReturnDataERC1155Recipient());

        vm.prank(from);
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, to));
        token.safeTransferFrom(from, to, id, value, "");
    }

    function testSafeTransferFromToERC1155RecipientWithWrongReturnDataWithDataReverts(
        uint256 id,
        address from,
        uint256 value,
        bytes memory data
    ) public {
        vm.assume(from != address(0));
        vm.assume(value != 0 && value < uint256(type(int256).max));
        token.mint(from, id, value, "");

        address to = address(new WrongReturnDataERC1155Recipient());

        vm.prank(from);
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, to));
        token.safeTransferFrom(from, to, id, value, data);
    }

    function testSafeMintToNonERC1155RecipientReverts(uint256 id, uint256 value) public {
        address to = address(new NonERC1155Recipient());
        vm.assume(value != 0 && value < uint256(type(int256).max));
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, to));
        token.safeMint(to, id, value, "");
    }

    function testSafeMintToNonERC1155RecipientWithDataReverts(uint256 id, uint256 value, bytes memory data) public {
        address to = address(new NonERC1155Recipient());
        vm.assume(value != 0 && value < uint256(type(int256).max));
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, to));
        token.safeMint(to, id, value, data);
    }

    function testSafeMintToRevertingERC1155RecipientReverts(uint256 id, uint256 value) public {
        address to = address(new RevertingERC1155Recipient());
        vm.assume(value != 0 && value < uint256(type(int256).max));
        vm.expectRevert(abi.encodeWithSelector(IERC1155Receiver.onERC1155Received.selector));
        token.safeMint(to, id, value, "");
    }

    function testSafeMintToRevertingERC1155RecipientWithDataReverts(uint256 id, uint256 value, bytes memory data)
        public
    {
        address to = address(new RevertingERC1155Recipient());
        vm.assume(value != 0 && value < uint256(type(int256).max));
        vm.expectRevert(abi.encodeWithSelector(IERC1155Receiver.onERC1155Received.selector));
        token.safeMint(to, id, value, data);
    }

    function testSafeMintToERC1155RecipientWithWrongReturnData(uint256 id, uint256 value) public {
        address to = address(new WrongReturnDataERC1155Recipient());
        vm.assume(value != 0 && value < uint256(type(int256).max));
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, to));
        token.safeMint(to, id, value, "");
    }

    function testSafeMintToERC1155RecipientWithWrongReturnDataWithData(uint256 id, uint256 value, bytes memory data)
        public
    {
        address to = address(new WrongReturnDataERC1155Recipient());
        vm.assume(value != 0 && value < uint256(type(int256).max));
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, to));
        token.safeMint(to, id, value, data);
    }
}
