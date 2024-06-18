import { defineWorld } from "@latticexyz/world";

export default defineWorld({
  namespace: "TST",
  userTypes: {
    ResourceId: { filePath: '@latticexyz/store/src/ResourceId.sol', type: 'bytes32' },
  },
  tables: {
    TestConfig: {
      schema: {
        erc721: 'address',
        erc1155: 'address',
      },
      key: []
    },
    /************************************************************************
     *                                                                      *
     *    ERC1155 MODULE                                                    *
     *                                                                      *
     ************************************************************************/
    ERC1155MetadataURI: {
      schema: {
        uri: 'string',
      },
      key: [],
      codegen: {
        outputDirectory: 'tables',
        tableIdArgument: true,
      },
    },
    ERC1155URIStorage: {
      schema: {
        tokenId: 'uint256',
        uri: 'string',
      },
      key: ['tokenId'],
      codegen: {
        outputDirectory: 'tables',
        tableIdArgument: true,
      },
    },
    OperatorApproval: {
      schema: {
        owner: 'address',
        operator: 'address',
        approved: 'bool',
      },
      key: ['owner', 'operator'],
      codegen: {
        outputDirectory: 'tables',
        tableIdArgument: true,
      },
    },
    TotalSupply: {
      schema: {
        tokenId: 'uint256',
        currentSupply: 'uint256',
        totalSupply: 'uint256',
      },
      key: ['tokenId'],
      codegen: {
        outputDirectory: 'tables',
        tableIdArgument: true,
      },
    },
    Owners: {
      schema: {
        owner: 'address',
        tokenId: 'uint256',
        balance: 'uint256',
      },
      key: ['owner', 'tokenId'],
      codegen: {
        outputDirectory: 'tables',
        tableIdArgument: true,
      },
    },
    ERC1155Registry: {
      schema: {
        namespaceId: 'ResourceId',
        tokenAddress: 'address',
      },
      key: ['namespaceId'],
      codegen: {
        outputDirectory: 'tables',
        tableIdArgument: true,
      },
    },
  },
  excludeSystems: ['ERC1155Module','ERC1155URIStorage', 'ERC1155System', 'ERC1155URIStorageSystem'],
});
