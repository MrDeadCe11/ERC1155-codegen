// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ResourceId} from "@latticexyz/store/src/ResourceId.sol";
import {System} from "@latticexyz/world/src/System.sol";
import {WorldResourceIdInstance, WorldResourceIdLib} from "@latticexyz/world/src/WorldResourceId.sol";
import {SystemRegistry} from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import {IERC1155System} from "./IERC1155System.sol";
import {IWorld} from "../codegen/world/IWorld.sol";
import {RESOURCE_SYSTEM} from "@latticexyz/world/src/worldResourceTypes.sol";
import {_erc1155SystemId, _erc1155URIStorageSystemId} from "./utils.sol";

contract Test1155System is System {
    function mint1155(address owner, uint256 tokenId, uint256 _value) public {
        ResourceId erc1155resourceId = _erc1155SystemId("ERC1155");
        IWorld(_world()).call(erc1155resourceId, abi.encodeCall(IERC1155System.mint, (owner, tokenId, _value, "")));
    }
}
