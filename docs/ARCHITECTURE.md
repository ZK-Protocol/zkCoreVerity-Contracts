# ZKProtocol Architecture Documentation

## Table of Contents

1. [System Overview](#system-overview)
2. [Core Components](#core-components)
3. [Dual-Layer Merkle Tree](#dual-layer-merkle-tree)
4. [Transaction Modes](#transaction-modes)
5. [Privacy Model](#privacy-model)
6. [State Management](#state-management)
7. [ZK Proof System](#zk-proof-system)
8. [Economic Model](#economic-model)

## System Overview

ZKProtocol implements a native privacy asset protocol using zero-knowledge proofs (zk-SNARKs) on Ethereum. The architecture is designed around three key principles:

1. **Privacy by Default**: Assets are private from inception, not through post-hoc mixing
2. **Permissionless Deployment**: Anyone can create privacy tokens via factory pattern
3. **Efficient State Management**: Dual-layer Merkle tree optimizes gas costs

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    User Applications                         │
│              (Wallets, DApps, Scanners)                     │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                   ZKProtocol Layer                          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         PrivacyTokenFactory (Singleton)              │  │
│  └────────────────────┬─────────────────────────────────┘  │
│                       │ Creates                             │
│                       ▼                                     │
│  ┌──────────────────────────────────────────────────────┐  │
│  │     PrivacyToken Instance (ZRC-20)                   │  │
│  │  - Dual-layer Merkle Tree State                      │  │
│  │  - Commitment Management                             │  │
│  │  - Nullifier Tracking                                │  │
│  └────────────────────┬─────────────────────────────────┘  │
│                       │ Verifies with                       │
│                       ▼                                     │
│  ┌──────────────────────────────────────────────────────┐  │
│  │           ZK Verifier Contracts (5 types)            │  │
│  │  - ProveMint          - ProveActiveTransfer          │  │
│  │  - ProveMintRollover  - ProveFinalizedTransfer       │  │
│  │  - ProveRolloverTransfer                             │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              Ethereum / EVM-Compatible Chain                │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. PrivacyTokenFactory

**Purpose**: Singleton factory for deploying ZRC-20 privacy tokens

**Key Responsibilities**:
- Deploys minimal proxy clones of PrivacyToken implementation
- Manages shared verifier contracts
- Configures platform fees and treasury
- Maintains consistent tree parameters across all tokens

**State Variables**:
```solidity
address public immutable privacyTokenImplementation;  // Base implementation
address public platformTreasury;                      // Fee recipient
uint256 public platformFeeBps;                        // Platform fee (basis points)
uint256 public creationFee;                          // Token creation fee

// Shared verifiers
IVerifier public mintVerifier;
IVerifier public mintRolloverVerifier;
IVerifier public activeTransferVerifier;
IVerifier public finalizedTransferVerifier;
IVerifier public rolloverTransferVerifier;

// Tree configuration
uint8 public subtree_height;              // Default: 16
uint8 public roottree_height;             // Default: 20
bytes32 public initialSubtreeEmptyRoot;   // Precomputed empty tree root
bytes32 public initialFinalizedEmptyRoot; // Precomputed empty tree root
```

**Key Functions**:
```solidity
function createToken(
    string name,
    string symbol,
    uint256 maxSupply,
    uint256 mintPrice,
    uint256 mintAmount
) external payable;
```

### 2. PrivacyToken (ZRC-20 Implementation)

**Purpose**: Individual privacy token contract managing private state

**Key Responsibilities**:
- Maintain dual-layer Merkle tree state
- Verify ZK proofs for mints and transfers
- Track nullifiers to prevent double-spending
- Emit events for client synchronization

**State Structure**:
```solidity
// Configuration (immutable after initialization)
string private _name;
string private _symbol;
uint256 public MAX_SUPPLY;
uint256 public MINT_PRICE;
uint256 public MINT_AMOUNT;
address public initiator;

// Verifier references
IActiveTransferVerifier public activeTransferVerifier;
IFinalizedTransferVerifier public finalizedTransferVerifier;
ITransferRolloverVerifier public rolloverTransferVerifier;
IMintVerifier public mintVerifier;
IMintRolloverVerifier public mintRolloverVerifier;

// Dynamic state
mapping(bytes32 => bool) public nullifiers;           // Spent note tracking
mapping(bytes32 => bool) public commitmentHashes;     // Duplicate prevention
uint256 public totalSupply;

// Tree state
bytes32 public activeSubtreeRoot;
bytes32 public finalizedRoot;
ContractState public state;  // Packed: indices, heights, initialized flag
```

### 3. Verifier Contracts

Five specialized verifiers implement Groth16 proof verification for different operations:

| Verifier | Purpose | Public Signals |
|----------|---------|----------------|
| ProveMintVerifier | Regular mint | 4: newActiveRoot, oldActiveRoot, commitment, amount |
| ProveMintAndRolloverVerifier | Mint triggering rollover | 7: newActiveRoot, newFinalizedRoot, oldActiveRoot, oldFinalizedRoot, commitment, amount, subtreeIndex |
| ProveActiveTransferVerifier | Transfer within active tree | 12: ephemeralPubKey[2], newActiveRoot, numOutputs, oldActiveRoot, nullifiers[2], commitments[2], spare[2], viewTag |
| ProveFinalizedTransferVerifier | Transfer from finalized tree | 13: ephemeralPubKey[2], newActiveRoot, numOutputs, oldFinalizedRoot, oldActiveRoot, nullifiers[2], commitments[2], spare[2], viewTag |
| ProveRolloverTransferVerifier | Transfer triggering rollover | 12: ephemeralPubKey[2], newActiveRoot, newFinalizedRoot, oldActiveRoot, oldFinalizedRoot, nullifiers[1], commitments[1], spare[2], viewTag, subtreeIndex |

## Dual-Layer Merkle Tree

### Design Rationale

Traditional privacy protocols use a single large Merkle tree, which becomes expensive to update as it grows. The dual-layer design optimizes for:

1. **Gas Efficiency**: Only small active subtree updated on-chain
2. **Scalability**: Supports billions of notes with minimal gas increase
3. **Parallelization**: Finalized transfers can be batched efficiently

### Architecture

```
Root Tree (Layer 2)
├─ Height: 20 levels
├─ Capacity: 2^20 = 1,048,576 subtrees
├─ Stores: Finalized subtree roots
└─ Updates: Only when subtree fills (rare)

Active Subtree (Layer 1)
├─ Height: 16 levels
├─ Capacity: 2^16 = 65,536 leaves
├─ Stores: Recent commitments
└─ Updates: Every mint/transfer
```

### State Transition Diagram

```
Initial State:
┌─────────────────────────────┐
│ activeSubtreeRoot = EMPTY   │
│ finalizedRoot = EMPTY       │
│ currentSubtreeIndex = 0     │
│ nextLeafIndex = 0           │
└─────────────────────────────┘

After Regular Mint (nextLeafIndex < CAPACITY):
┌─────────────────────────────┐
│ activeSubtreeRoot = NEW     │ ← Updated
│ finalizedRoot = unchanged   │
│ currentSubtreeIndex = same  │
│ nextLeafIndex += 1          │ ← Incremented
└─────────────────────────────┘

After Rollover Mint (nextLeafIndex == CAPACITY):
┌─────────────────────────────┐
│ activeSubtreeRoot = NEW     │ ← Reset to new subtree
│ finalizedRoot = NEW         │ ← Updated with old active root
│ currentSubtreeIndex += 1    │ ← Incremented
│ nextLeafIndex = 1           │ ← Reset (new commitment at index 0)
└─────────────────────────────┘
```

### Tree Update Logic

**Regular Insertion** (Active Tree):
```solidity
// Verify old root matches expected empty position
oldPathValidator.verify(
    leaf: 0,                    // Position must be empty
    path: insertionPathElements,
    root: activeSubtreeRoot     // Must match current root
);

// Calculate new root with commitment
newRoot = calculateRoot(
    leaf: newCommitment,
    path: insertionPathElements
);

activeSubtreeRoot = newRoot;
nextLeafIndexInSubtree++;
```

**Rollover Insertion** (Both Trees):
```solidity
// Verify active tree is full
require(nextLeafIndexInSubtree == SUBTREE_CAPACITY);

// Archive current active subtree to root tree
finalizedRoot = updateRootTree(
    leaf: activeSubtreeRoot,    // Old active root becomes leaf
    index: currentSubtreeIndex,
    path: rootTreePath,
    oldRoot: finalizedRoot
);

// Start new active subtree
activeSubtreeRoot = calculateRoot(
    leaf: newCommitment,
    path: emptySubtreePath
);

currentSubtreeIndex++;
nextLeafIndexInSubtree = 1;
```

## Transaction Modes

The protocol supports five distinct transaction types, each optimized for different scenarios:

### 1. Regular Mint

**When**: Initial minting when subtree not full
**Gas Cost**: ~250K
**Proof Type**: 0

```solidity
mint{value: MINT_PRICE}(
    proofType: 0,
    proof: abi.encode(pA, pB, pC, [
        newActiveRoot,
        oldActiveRoot,
        newCommitment,
        mintAmount
    ]),
    encryptedNote: encryptedData
)
```

**State Changes**:
- ✅ activeSubtreeRoot updated
- ❌ finalizedRoot unchanged
- ❌ subtreeIndex unchanged

### 2. Rollover Mint

**When**: Minting when subtree exactly full
**Gas Cost**: ~350K
**Proof Type**: 1

```solidity
mint{value: MINT_PRICE}(
    proofType: 1,
    proof: abi.encode(pA, pB, pC, [
        newActiveRoot,
        newFinalizedRoot,
        oldActiveRoot,
        oldFinalizedRoot,
        newCommitment,
        mintAmount,
        subtreeIndex
    ]),
    encryptedNote: encryptedData
)
```

**State Changes**:
- ✅ activeSubtreeRoot reset to new tree
- ✅ finalizedRoot updated
- ✅ subtreeIndex incremented
- ✅ nextLeafIndex reset to 1

### 3. Active Transfer

**When**: Spending notes from current active subtree
**Gas Cost**: ~300K
**Proof Type**: 0

```solidity
transfer(
    proofType: 0,
    proof: abi.encode(pA, pB, pC, publicSignals),
    encryptedNotes: [recipientNote, changeNote]
)
```

**Proof Requirements**:
- Input commitments in active subtree Merkle tree
- Valid nullifiers (not spent)
- Value conservation (inputs = outputs)
- Sufficient capacity for output commitments

### 4. Finalized Transfer

**When**: Spending notes from archived subtrees
**Gas Cost**: ~350K
**Proof Type**: 1

```solidity
transfer(
    proofType: 1,
    proof: abi.encode(pA, pB, pC, publicSignals),
    encryptedNotes: [recipientNote, changeNote]
)
```

**Proof Requirements**:
- Input commitments in finalized root tree
- Outputs go to active subtree
- Allows parallel processing (doesn't modify finalized tree)

### 5. Rollover Transfer

**When**: Transfer when active subtree exactly full
**Gas Cost**: ~350K
**Proof Type**: 2

```solidity
transfer(
    proofType: 2,
    proof: abi.encode(pA, pB, pC, publicSignals),
    encryptedNotes: [recipientNote]  // Single output
)
```

**Special Properties**:
- Only 1 input, 1 output (due to capacity constraint)
- Triggers subtree rollover
- Most complex proof (updates both trees)

## Privacy Model

### Commitment Scheme

Each note is represented as a commitment:

```
commitment = Poseidon(stealthPublicKey, amount, salt)
```

**Properties**:
- **Binding**: Cannot change note content without invalidating commitment
- **Hiding**: Commitment reveals nothing about content
- **Unique**: Random salt ensures uniqueness

### Nullifier Mechanism

Prevents double-spending:

```
nullifier = Poseidon(stealthPrivateKey, commitment, nullifierSeed)
```

**Properties**:
- **Uniqueness**: Each note has exactly one nullifier
- **Unlinkability**: Nullifier cannot be linked to commitment (by external observers)
- **Ownership**: Only owner can compute valid nullifier

### Stealth Addresses

Recipients generate one-time addresses for each transaction:

```
1. Sender generates ephemeral key pair (r, R = r·G)
2. Compute shared secret: S = r·P (where P is recipient's public key)
3. Derive stealth public key: P' = P + Hash(S)·G
4. Only recipient can derive private key: p' = p + Hash(S)
```

### Note Encryption

```
1. ECDH Key Exchange:
   sharedSecret = ephemeralPrivateKey · recipientPublicKey

2. Derive Encryption Key:
   encryptionKey = KDF(sharedSecret)

3. Encrypt Note:
   ciphertext = AES-GCM.encrypt(
       key: encryptionKey,
       data: {amount, salt, stealthPrivateKey},
       iv: random
   )

4. Compute View Tag:
   viewTag = Hash(sharedSecret) mod 256
```

**View Tag Optimization**:
- Single byte identifier derived from shared secret
- Allows recipients to quickly filter relevant transactions
- 99.6% of transactions filtered out with single hash
- Reduces scanning cost by ~40%

## State Management

### Packed State Structure

Gas optimization through state packing:

```solidity
struct ContractState {
    uint32 currentSubtreeIndex;      // Current subtree (0 to 2^20-1)
    uint32 nextLeafIndexInSubtree;   // Next insertion position (0 to 2^16-1)
    uint8 subTreeHeight;             // 16 (fixed)
    uint8 rootTreeHeight;            // 20 (fixed)
    bool initialized;                // Initialization guard
}
```

**Storage Optimization**:
- Single SLOAD reads all state (saves ~2100 gas per read)
- Single SSTORE updates all state (saves ~20000 gas per update)

### Root Management

```solidity
// Active subtree root (frequently updated)
bytes32 public activeSubtreeRoot;

// Finalized root tree (infrequently updated)
bytes32 public finalizedRoot;

// Precomputed empty tree roots (gas savings)
bytes32 public EMPTY_SUBTREE_ROOT;
```

### Nullifier Set

```solidity
mapping(bytes32 => bool) public nullifiers;

function _spendNullifier(bytes32 nullifier) internal {
    require(!nullifiers[nullifier], "Double spend");
    nullifiers[nullifier] = true;
    emit NullifierSpent(nullifier);
}
```

**Security Properties**:
- Prevents double-spending
- Immutable once set (cannot be "unspent")
- Publicly verifiable

### Commitment Tracking

```solidity
mapping(bytes32 => bool) public commitmentHashes;

function _checkCommitmentUnique(bytes32 commitment) internal {
    require(!commitmentHashes[commitment], "Duplicate commitment");
    commitmentHashes[commitment] = true;
}
```

**Purpose**:
- Prevents commitment replay attacks
- Ensures tree state integrity
- Minimal storage overhead

## ZK Proof System

### Circuit Architecture

Each proof type uses a dedicated circuit:

```
ProveMint.circom (Regular Mint)
├─ Inputs: stealthPubKey, salt, amount, leafIndex, path
├─ Validates: Amount > 0, commitment formula, empty position
└─ Outputs: newActiveRoot

ProveMintAndRollover.circom (Rollover Mint)
├─ Inputs: Same as ProveMint + rootTreePath
├─ Validates: Subtree full, both tree updates valid
└─ Outputs: newActiveRoot, newFinalizedRoot

ProveActiveTransfer.circom
├─ Inputs: 2 input notes, 2 output notes, active tree path
├─ Validates: Ownership, membership, value conservation
└─ Outputs: nullifiers[2], commitments[2], newActiveRoot

ProveFinalizedTransfer.circom
├─ Inputs: 2 input notes from finalized tree
├─ Validates: Finalized tree membership, outputs to active
└─ Outputs: nullifiers[2], commitments[2], newActiveRoot

ProveRolloverTransfer.circom
├─ Inputs: 1 input note, 1 output note (capacity constraint)
├─ Validates: Both tree updates, rollover conditions
└─ Outputs: nullifiers[1], commitments[1], both roots
```

### Proof Components

**Groth16 Proof Format**:
```solidity
struct Proof {
    uint[2] pA;        // Elliptic curve point A
    uint[2][2] pB;     // Elliptic curve point B
    uint[2] pC;        // Elliptic curve point C
    uint[] pubSignals; // Public inputs/outputs
}
```

### Verification Flow

```
1. User generates proof off-chain (1-4 seconds)
   ├─ Witness generation (circuit evaluation)
   ├─ Proof generation (Groth16)
   └─ Encryption of output notes

2. Submit transaction to contract
   ├─ Decode proof from calldata
   ├─ Extract public signals
   └─ Validate business logic constraints

3. Verify ZK proof
   ├─ Call appropriate verifier contract
   ├─ Groth16 pairing check (~280K gas)
   └─ Return true/false

4. Update state if valid
   ├─ Spend nullifiers
   ├─ Append commitments
   ├─ Update tree roots
   └─ Emit events
```

### Security Guarantees

**Zero-Knowledge**: Verifier learns nothing except validity
**Soundness**: Cannot forge invalid proof (computational security)
**Completeness**: Valid witness always produces valid proof

## Economic Model

### Fee Structure

```solidity
// Factory creation fee
uint256 public creationFee = 0.0005 ether;  // Paid once to deploy token

// Minting fees (per token configuration)
uint256 public MINT_PRICE;     // Set by token creator
uint256 public platformFeeBps; // Platform fee (default 2.5% = 250 bps)

// Fee distribution on mint
platformShare = MINT_PRICE * platformFeeBps / 10000;
creatorShare = MINT_PRICE - platformShare;
```

### Fee Distribution

```solidity
function distributeFees() external {
    uint256 balance = address(this).balance;

    uint256 platformAmount = (balance * platformFeeBps) / 10000;
    uint256 initiatorAmount = balance - platformAmount;

    // Transfer to platform treasury
    platformTreasury.transfer(platformAmount);

    // Transfer to token creator
    initiator.transfer(initiatorAmount);
}
```

### Economic Incentives

1. **Platform**: Collects 2.5% of minting fees
2. **Token Creators**: Receive 97.5% of minting fees
3. **Users**: Pay gas + mint price for privacy

### Anti-Spam Mechanisms

- Creation fee prevents token spam
- Mint price configurable per token
- Gas costs natural rate limiter

---

**This architecture enables permissionless privacy asset creation while maintaining security, efficiency, and decentralization.**
