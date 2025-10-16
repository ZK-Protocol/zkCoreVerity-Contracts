// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IZRC20 {

    event CommitmentAppended(uint32 indexed subtreeIndex, bytes32 commitment, uint32 indexed leafIndex, uint256 timestamp);
    event NullifierSpent(bytes32 indexed nullifier);
    event SubtreeFinalized(uint32 indexed subtreeIndex, bytes32 root);

    event Minted(
        address indexed minter,
        bytes32 commitment,
        bytes encryptedNote,
        uint32 subtreeIndex,
        uint32 leafIndex,
        uint256 timestamp
    );

    event Transaction(
        bytes32[2] newCommitments, 
        bytes[] encryptedNotes, 
        uint256[2] ephemeralPublicKey, 
        uint256 viewTag
    );

    struct ContractState {
        uint32 currentSubtreeIndex;
        uint32 nextLeafIndexInSubtree;
        uint8 subTreeHeight;
        uint8 rootTreeHeight;
        bool initialized; 
    }

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function finalizedRoot() external view returns (bytes32);
    function activeSubtreeRoot() external view returns (bytes32);
    function MINT_PRICE() external view returns (uint256);
    function MINT_AMOUNT() external view returns (uint256);

    function mint(
        uint8 proofType,
        bytes calldata proof,
        bytes calldata encryptedNote
    ) external payable;

    // The proof calldata now contains all public signals
    function transfer(
        uint8 proofType,             // To route to the correct internal function
        bytes calldata proof,        // Contains pA, pB, pC, AND all publicSignals
        bytes[] calldata encryptedNotes // This data is not part of the proof
    ) external;

}