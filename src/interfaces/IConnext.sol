// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.7 <0.9.0;

interface IConnext{
    struct CallParams {
        address to;
        bytes callData;
        uint32 originDomain;
        uint32 destinationDomain;
    }

    struct XCallArgs {
        CallParams params;
        address transactingAssetId;
        uint256 amount;
    }

    struct ExecuteArgs {
        CallParams params;
        address local;
        address[] routers;
        uint32 feePercentage;
        uint256 amount;
        uint256 nonce;
        bytes relayerSignature;
        address originSender;
    }

    function xcall(XCallArgs memory xCallArgs) external;

    function execute(ExecuteArgs calldata _args) external returns (bytes32);
}
