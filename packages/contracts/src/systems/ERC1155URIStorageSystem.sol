    // SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ResourceId} from "@latticexyz/store/src/ResourceId.sol";
import {System} from "@latticexyz/world/src/System.sol";
import {
    _metadataTableId,
    _erc1155URIStorageTableId,
    _totalSupplyTableId,
    _operatorApprovalTableId,
    _ownersTableId
} from "./utils.sol";
import {ERC1155MetadataURI} from "../codegen/tables/ERC1155MetadataURI.sol";
import {ERC1155URIStorage} from "../codegen/tables/ERC1155URIStorage.sol";
import {SystemRegistry} from "@latticexyz/world/src/codegen/tables/SystemRegistry.sol";
import {AccessControlLib} from "@latticexyz/world-modules/src/utils/AccessControlLib.sol";
import {PuppetMaster} from "@latticexyz/world-modules/src/modules/puppet/PuppetMaster.sol";
import {WorldResourceIdInstance} from "@latticexyz/world/src/WorldResourceId.sol";
import "forge-std/console2.sol";

contract ERC1155URIStorageSystem is System {
    using WorldResourceIdInstance for ResourceId;

    function setTokenURI(uint256 tokenId, string memory tokenURI) public {
        console2.log("SET TOKEN URI");
        // _requireOwner();
        console2.log("owner requires");
        ERC1155URIStorage.setUri(_erc1155URIStorageTableId(_namespace()), tokenId, tokenURI);
    }

    function setMetadataURI(uint256 tokenId, string memory tokenURI) public {
        _requireOwner();
        ERC1155MetadataURI.setUri(_metadataTableId(_namespace()), tokenURI);
    }

    function _namespace() internal view returns (bytes14 namespace) {
        ResourceId systemId = SystemRegistry.get(address(this));
        return systemId.getNamespace();
    }

    function _requireOwner() internal view {
        console2.log("_requireOwner");
        console2.log(SystemRegistry.get(address(this)).toString());
        AccessControlLib.requireOwner(SystemRegistry.get(address(this)), _msgSender());
    }
}
