// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ResourceId } from '@latticexyz/store/src/ResourceId.sol';
import { System } from '@latticexyz/world/src/System.sol';
import { WorldResourceIdInstance, WorldResourceIdLib } from '@latticexyz/world/src/WorldResourceId.sol';
import { SystemRegistry } from '@latticexyz/world/src/codegen/tables/SystemRegistry.sol';
import {IERC1155System} from './IERC1155System.sol';
import { IWorld } from '../codegen/world/IWorld.sol';
import { RESOURCE_SYSTEM } from '@latticexyz/world/src/worldResourceTypes.sol';

contract Test1155System is System {
    function mint1155() public {
       ResourceId erc1155resourceId =  WorldResourceIdLib.encode({ typeId: RESOURCE_SYSTEM, namespace: 'ERC1155', name: 'ERC1155System' });
            IWorld(_world()).call(
      erc1155resourceId,
      abi.encodeCall(IERC1155System.mint, (address(this), 1, 1, ''))
    );

    }
}