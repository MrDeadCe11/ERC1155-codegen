// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ResourceId} from "@latticexyz/store/src/ResourceId.sol";
import {System} from "@latticexyz/world/src/System.sol";
import {WorldResourceIdInstance, WorldResourceIdLib} from "@latticexyz/world/src/WorldResourceId.sol";
import {SystemRegistry} from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import {IERC721Mintable} from "@latticexyz/world-modules/src/modules/erc721-puppet/IERC721Mintable.sol";
import {IWorld} from "../codegen/world/IWorld.sol";
import {RESOURCE_SYSTEM} from "@latticexyz/world/src/worldResourceTypes.sol";

contract TestERC721System is System {
    function mint() public {
        ResourceId erc721resourceId =
            WorldResourceIdLib.encode({typeId: RESOURCE_SYSTEM, namespace: "TEST721", name: "ERC721System"});
        IWorld(_world()).call(erc721resourceId, abi.encodeCall(IERC721Mintable.mint, (address(this), 1)));
    }
}
