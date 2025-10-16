// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./PrivacyToken.sol"; 

/**
 * @title PrivacyTokenFactory
 * @dev A factory for creating and launching new privacy-enhanced tokens using a
 *      production-grade dual-verifier architecture.
 */
contract PrivacyTokenFactory is Ownable {
    // --- Immutable State ---
    address public immutable privacyTokenImplementation;

    // --- Platform Configuration (Managed by Owner) ---
    address public platformTreasury;
    uint256 public platformFeeBps;
    uint256 public creationFee;

    // --- Shared Verifiers (The core components provided by the platform) ---
    IVerifier public mintVerifier;
    IVerifier public mintRolloverVerifier;
    IVerifier public activeTransferVerifier;
    IVerifier public finalizedTransferVerifier;
    IVerifier public rolloverTransferVerifier;

    // --- Shared Constants for Tree Geometry ---
    uint8 public subtree_height;
    uint8 public roottree_height;
    bytes32 public initialSubtreeEmptyRoot;
    bytes32 public initialFinalizedEmptyRoot;


    // --- Events ---
    event TokenCreated(
        address indexed tokenAddress,
        address indexed creator,
        string name,
        string symbol,
        uint256 maxSupply,
        uint256 mintAmount,
        uint256 mintPrice,
        uint256 subTreeHeight,
        uint256 rootTreeHeight
    );

    event VerifiersUpdated(
        address newMintVerifier,
        address newMintRolloverVerifier,
        address newActiveTransferVerifier,
        address newFinalizedTransferVerifier,
        address newRolloverTransferVerifier
    );

    event PlatformFeeUpdated(uint256 newFeeBps);
    event TreasuryUpdated(address indexed newTreasury);
    event CreationFeeUpdated(uint256 newCreationFee);

    // --- Constructor ---
    constructor(
        address _implementation,
        address _treasury,
        address[5] memory _verifiers, // {mint, mintRollover, active, finalized, transferRollover}
        bytes32 _initialSubtreeEmptyRoot,
        bytes32 _initialFinalizedEmptyRoot
    ) Ownable(msg.sender) {
        require(_implementation != address(0), "Impl address cannot be zero");
        require(_treasury != address(0), "Treasury address cannot be zero");
        for (uint i = 0; i < _verifiers.length; i++) {
            require(_verifiers[i] != address(0), "Verifier address cannot be zero");
        }

        privacyTokenImplementation = _implementation;
        platformTreasury = _treasury;
        platformFeeBps = 250; // Default to 2.5%
        creationFee = 0.005 ether; // Set the initial creation fee
        subtree_height = 16;
        roottree_height = 20;
        
        mintVerifier = IVerifier(_verifiers[0]);
        mintRolloverVerifier = IVerifier(_verifiers[1]);
        activeTransferVerifier = IVerifier(_verifiers[2]);
        finalizedTransferVerifier = IVerifier(_verifiers[3]);
        rolloverTransferVerifier = IVerifier(_verifiers[4]);

        initialSubtreeEmptyRoot = _initialSubtreeEmptyRoot;
        initialFinalizedEmptyRoot = _initialFinalizedEmptyRoot;
    }

    // --- Core Functionality ---
    function createToken(
        string calldata name,
        string calldata symbol,
        uint256 maxSupply,
        uint256 mintPrice,
        uint256 mintAmount
    ) external payable {
        require(msg.value == creationFee, "Incorrect creation fee");
        require(bytes(name).length > 0 && bytes(symbol).length > 0, "Name and symbol required");
        require(maxSupply > 0, "Max supply must be positive");

        address tokenProxy = Clones.clone(privacyTokenImplementation);

        PrivacyToken(tokenProxy).initialize(
            name,
            symbol,
            maxSupply,
            mintPrice,
            mintAmount,
            msg.sender,
            platformTreasury,
            platformFeeBps,
            [
                address(mintVerifier),
                address(mintRolloverVerifier),
                address(activeTransferVerifier),
                address(finalizedTransferVerifier),
                address(rolloverTransferVerifier)
            ],
            subtree_height,
            roottree_height,
            initialSubtreeEmptyRoot,
            initialFinalizedEmptyRoot
        );

        emit TokenCreated(tokenProxy, msg.sender, name, symbol, maxSupply, mintAmount, mintPrice, subtree_height, roottree_height);
    }
    
    function setCreationFee(uint256 _newCreationFee) external onlyOwner {
        creationFee = _newCreationFee;
        emit CreationFeeUpdated(_newCreationFee);
    }

    function setTreeHeight(uint8 _subtree_height, uint8 _roottree_height) external onlyOwner {
        require(_subtree_height > 9, "Invalid subtree height");
        require(_roottree_height > 15, "Invalid roottree height");
        subtree_height = _subtree_height;
        roottree_height = _roottree_height;
    }

    
    function withdrawCreationFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "Factory: No fees to withdraw");
        (bool success, ) = platformTreasury.call{value: balance}("");
        require(success, "Factory: Fee withdrawal failed");
    }

    function setPlatformFeeBps(uint256 _newFeeBps) external onlyOwner {
        require(_newFeeBps <= 10000, "Factory: Fee cannot exceed 100%");
        platformFeeBps = _newFeeBps;
        emit PlatformFeeUpdated(_newFeeBps);
    }
    
    function setTreasury(address _newTreasury) external onlyOwner {
        require(_newTreasury != address(0), "Factory: Invalid treasury address");
        platformTreasury = _newTreasury;
        emit TreasuryUpdated(_newTreasury);
    }

     // --- Platform Management Functions (Owner-only) ---
    function setVerifiers(address[5] memory _newVerifiers) external onlyOwner {
        for (uint i = 0; i < _newVerifiers.length; i++) {
            require(_newVerifiers[i] != address(0), "New verifier address cannot be zero");
        }
        
        mintVerifier = IVerifier(_newVerifiers[0]);
        mintRolloverVerifier = IVerifier(_newVerifiers[1]);
        activeTransferVerifier = IVerifier(_newVerifiers[2]);
        finalizedTransferVerifier = IVerifier(_newVerifiers[3]);
        rolloverTransferVerifier = IVerifier(_newVerifiers[4]);

        emit VerifiersUpdated(
            _newVerifiers[0],
            _newVerifiers[1],
            _newVerifiers[2],
            _newVerifiers[3],
            _newVerifiers[4]
        );
    }
}