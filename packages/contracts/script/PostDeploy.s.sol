// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {StoreSwitch} from "@latticexyz/store/src/StoreSwitch.sol";
import {StoreCore, EncodedLengths} from "@latticexyz/store/src/StoreCore.sol";
import {PuppetModule} from "@latticexyz/world-modules/src/modules/puppet/PuppetModule.sol";
import {Systems} from "@latticexyz/world/src/codegen/tables/Systems.sol";
import {ResourceIdLib} from "@latticexyz/store/src/ResourceId.sol";
import {ResourceId, WorldResourceIdLib, WorldResourceIdInstance} from "@latticexyz/world/src/WorldResourceId.sol";
import {RESOURCE_SYSTEM} from "@latticexyz/world/src/worldResourceTypes.sol";
import {IERC721Mintable} from "@latticexyz/world-modules/src/modules/erc721-puppet/IERC721Mintable.sol";
import {registerERC721} from "@latticexyz/world-modules/src/modules/erc721-puppet/registerERC721.sol";
import {ERC721System} from "@latticexyz/world-modules/src/modules/erc721-puppet/ERC721System.sol";
import {ERC721MetadataData} from "@latticexyz/world-modules/src/modules/erc721-puppet/tables/ERC721Metadata.sol";
import {BEFORE_CALL_SYSTEM} from "@latticexyz/world/src/systemHookTypes.sol";
import {TestConfig} from "../src/codegen/tables/TestConfig.sol";
import {IWorld} from "../src/codegen/world/IWorld.sol";
////

import {IERC20Mintable} from "@latticexyz/world-modules/src/modules/erc20-puppet/IERC20Mintable.sol";
import {ERC20MetadataData} from "@latticexyz/world-modules/src/modules/erc20-puppet/tables/ERC20Metadata.sol";
import {ERC20System} from "@latticexyz/world-modules/src/modules/erc20-puppet/ERC20System.sol";
import {registerERC20} from "@latticexyz/world-modules/src/modules/erc20-puppet/registerERC20.sol";
import {System} from "@latticexyz/world/src/System.sol";

import {ERC1155Module} from "../src/systems/ERC1155Module.sol";
import {ERC1155System} from "../src/systems/ERC1155System.sol";
import {IERC1155} from "../src/systems/IERC1155.sol";
import {registerERC1155} from "../src/systems/registerERC1155.sol";
import {_erc1155SystemId} from "../src/systems/utils.sol";
import "forge-std/console2.sol";

struct ResourceIds {
    ResourceId erc721SystemId;
    ResourceId erc721NamespaceId;
    ResourceId characterSystemId;
    ResourceId erc20SystemId;
    ResourceId erc20NamespaceId;
    ResourceId rngSystemId;
    ResourceId erc1155SystemId;
    ResourceId erc1155NamespaceId;
    ResourceId itemsSystemId;
}

contract PostDeploy is Script {
    IWorld public world;
    ResourceIds public resourceIds;
    address public worldAddress;

    function run(address _worldAddress) external {
        worldAddress = _worldAddress;
        world = IWorld(worldAddress);
        // Specify a store so that you can use tables directly in PostDeploy
        StoreSwitch.setStoreAddress(worldAddress);

        // Load the private key from the `PRIVATE_KEY` environment variable (in .env)
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY"); // 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

        // Start broadcasting transactions from the deployer account
        vm.startBroadcast(deployerPrivateKey);

        //install puppet
        world.installModule(new PuppetModule(), new bytes(0));
        // install gold module
        IERC20Mintable goldToken =
            registerERC20(world, "TEST20", ERC20MetadataData({decimals: 18, name: "GoldToken", symbol: unicode"🜚"}));

        // characters
        IERC721Mintable characters = registerERC721(
            world, "TEST721", ERC721MetadataData({name: "test721", symbol: "SYM", baseURI: "ERC721_test_uri"})
        );

        TestConfig.setErc721(address(characters));

        ResourceId erc20SystemId =
            WorldResourceIdLib.encode({typeId: RESOURCE_SYSTEM, namespace: "TEST20", name: "GoldToken"});

        System goldSystemContract = new ERC20System();

        world.registerSystem(erc20SystemId, goldSystemContract, true);

        ResourceId testerc721SystemId =
            WorldResourceIdLib.encode({typeId: RESOURCE_SYSTEM, namespace: "TST", name: "TestERC721System"});

        address itemsSystemAddress = Systems.getSystem(testerc721SystemId);

        world.transferOwnership(WorldResourceIdLib.encodeNamespace("TEST721"), itemsSystemAddress);
    }
}
