# ZRC-20 Standard Specification

## Abstract

ZRC-20 (ZK Privacy ERC-20) is a token standard that brings native privacy to fungible assets on Ethereum and EVM-compatible chains. Unlike traditional privacy solutions that rely on mixing, ZRC-20 tokens are private from inception, using zero-knowledge proofs to hide transaction amounts, sender addresses, and recipient addresses while maintaining the familiar interface semantics of ERC-20.

## Motivation

The ERC-20 standard has become the de facto token standard for fungible assets, but it lacks privacy features. All balances and transactions are publicly visible on-chain, which:

- Exposes user financial privacy
- Reveals trading strategies to competitors
- Creates security risks for high-value holders
- Prevents confidential business transactions

ZRC-20 addresses these issues while maintaining developer familiarity and composability.

## Specification

### Interface

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IZRC20 {
    // ============================================
    // Metadata (ERC-20 Compatible)
    // ============================================

    /**
     * @notice Returns the name of the token
     */
    function name() external view returns (string memory);

    /**
     * @notice Returns the symbol of the token
     */
    function symbol() external view returns (string memory);

    /**
     * @notice Returns the number of decimals
     * @dev Always returns 18 for compatibility
     */
    function decimals() external view returns (uint8);

    /**
     * @notice Returns the total supply (public value only)
     * @dev This represents total minted amount, not distribution
     */
    function totalSupply() external view returns (uint256);

    // ============================================
    // State Accessors
    // ============================================

    /**
     * @notice Returns the current active subtree root
     */
    function activeSubtreeRoot() external view returns (bytes32);

    /**
     * @notice Returns the current finalized tree root
     */
    function finalizedRoot() external view returns (bytes32);

    /**
     * @notice Returns the price to mint tokens
     */
    function MINT_PRICE() external view returns (uint256);

    /**
     * @notice Returns the amount minted per transaction
     */
    function MINT_AMOUNT() external view returns (uint256);

    // ============================================
    // Core Operations
    // ============================================

    /**
     * @notice Mints new privacy tokens
     * @param proofType The type of mint proof:
     *        0 = Regular mint (subtree not full)
     *        1 = Rollover mint (subtree full, triggers archival)
     * @param proof ABI-encoded proof containing:
     *        - pA: Proof point A
     *        - pB: Proof point B
     *        - pC: Proof point C
     *        - publicSignals: Array of public inputs/outputs
     * @param encryptedNote Encrypted note for the recipient containing:
     *        - amount
     *        - salt
     *        - stealth private key
     *
     * @dev msg.value must equal MINT_PRICE
     *
     * Regular Mint (proofType = 0):
     * publicSignals = [
     *     newActiveRoot,      // New active subtree root after insertion
     *     oldActiveRoot,      // Current active subtree root
     *     newCommitment,      // Commitment being inserted
     *     mintAmount          // Amount being minted (must equal MINT_AMOUNT)
     * ]
     *
     * Rollover Mint (proofType = 1):
     * publicSignals = [
     *     newActiveRoot,      // New active subtree root (reset)
     *     newFinalizedRoot,   // New finalized root (includes old active)
     *     oldActiveRoot,      // Current active root (being archived)
     *     oldFinalizedRoot,   // Current finalized root
     *     newCommitment,      // Commitment being inserted
     *     mintAmount,         // Amount being minted
     *     subtreeIndex        // Current subtree index (for verification)
     * ]
     */
    function mint(
        uint8 proofType,
        bytes calldata proof,
        bytes calldata encryptedNote
    ) external payable;

    /**
     * @notice Executes a private transfer
     * @param proofType The type of transfer proof:
     *        0 = Active transfer (inputs from active subtree)
     *        1 = Finalized transfer (inputs from finalized tree)
     *        2 = Rollover transfer (triggers subtree rollover)
     * @param proof ABI-encoded proof (structure varies by type)
     * @param encryptedNotes Array of encrypted output notes (typically 2: recipient + change)
     *
     * Active Transfer (proofType = 0):
     * publicSignals = [
     *     ephemeralPublicKey[0],  // x-coordinate of ephemeral key
     *     ephemeralPublicKey[1],  // y-coordinate of ephemeral key
     *     newActiveRoot,          // Active root after outputs inserted
     *     numRealOutputs,         // Number of non-dummy outputs (1 or 2)
     *     oldActiveRoot,          // Active root before outputs
     *     nullifier[0],           // First input nullifier
     *     nullifier[1],           // Second input nullifier
     *     commitment[0],          // First output commitment
     *     commitment[1],          // Second output commitment
     *     spare[0],               // Reserved
     *     spare[1],               // Reserved
     *     viewTag                 // Single-byte scanning optimization
     * ]
     *
     * Finalized Transfer (proofType = 1):
     * publicSignals = [
     *     ephemeralPublicKey[0],
     *     ephemeralPublicKey[1],
     *     newActiveRoot,          // Active root after outputs
     *     numRealOutputs,
     *     oldFinalizedRoot,       // Finalized root (inputs)
     *     oldActiveRoot,          // Active root before outputs
     *     nullifier[0],
     *     nullifier[1],
     *     commitment[0],
     *     commitment[1],
     *     spare[0],
     *     spare[1],
     *     viewTag
     * ]
     *
     * Rollover Transfer (proofType = 2):
     * publicSignals = [
     *     ephemeralPublicKey[0],
     *     ephemeralPublicKey[1],
     *     newActiveRoot,          // New active root (reset)
     *     newFinalizedRoot,       // New finalized root
     *     oldActiveRoot,          // Old active root (being archived)
     *     oldFinalizedRoot,       // Old finalized root
     *     nullifier[0],           // Single input (capacity constraint)
     *     commitment[0],          // Single output (capacity constraint)
     *     spare[0],
     *     spare[1],
     *     viewTag,
     *     subtreeIndex            // For verification
     * ]
     */
    function transfer(
        uint8 proofType,
        bytes calldata proof,
        bytes[] calldata encryptedNotes
    ) external;

    // ============================================
    // Events
    // ============================================

    /**
     * @notice Emitted when a new commitment is added to the tree
     * @param subtreeIndex The index of the subtree
     * @param commitment The commitment value
     * @param leafIndex The position within the subtree
     * @param timestamp Block timestamp
     */
    event CommitmentAppended(
        uint32 indexed subtreeIndex,
        bytes32 commitment,
        uint32 indexed leafIndex,
        uint256 timestamp
    );

    /**
     * @notice Emitted when a nullifier is spent
     * @param nullifier The nullifier value
     */
    event NullifierSpent(bytes32 indexed nullifier);

    /**
     * @notice Emitted when a subtree is finalized (archived)
     * @param subtreeIndex The index of the subtree
     * @param root The final root of the subtree
     */
    event SubtreeFinalized(uint32 indexed subtreeIndex, bytes32 root);

    /**
     * @notice Emitted for every mint operation
     * @param minter The address that called mint
     * @param commitment The new commitment
     * @param encryptedNote The encrypted note data
     * @param subtreeIndex The subtree index
     * @param leafIndex The leaf index
     * @param timestamp Block timestamp
     */
    event Minted(
        address indexed minter,
        bytes32 commitment,
        bytes encryptedNote,
        uint32 subtreeIndex,
        uint32 leafIndex,
        uint256 timestamp
    );

    /**
     * @notice Emitted for every transfer operation
     * @param newCommitments The output commitments
     * @param encryptedNotes The encrypted output notes
     * @param ephemeralPublicKey The ephemeral key for decryption
     * @param viewTag Single-byte identifier for scanning
     */
    event Transaction(
        bytes32[2] newCommitments,
        bytes[] encryptedNotes,
        uint256[2] ephemeralPublicKey,
        uint256 viewTag
    );

    // ============================================
    // State Structure
    // ============================================

    /**
     * @notice Packed state for gas optimization
     */
    struct ContractState {
        uint32 currentSubtreeIndex;      // Current active subtree (0 to 2^20-1)
        uint32 nextLeafIndexInSubtree;   // Next insertion position (0 to 2^16-1)
        uint8 subTreeHeight;             // Height of subtree (typically 16)
        uint8 rootTreeHeight;            // Height of root tree (typically 20)
        bool initialized;                // Initialization guard
    }
}
```

## Behavioral Specification

### Initialization

ZRC-20 tokens are deployed via `PrivacyTokenFactory` using the clone pattern:

```solidity
function createToken(
    string calldata name,
    string calldata symbol,
    uint256 maxSupply,
    uint256 mintPrice,
    uint256 mintAmount
) external payable {
    // 1. Clone implementation
    address tokenProxy = Clones.clone(privacyTokenImplementation);

    // 2. Initialize with parameters
    PrivacyToken(tokenProxy).initialize(
        name,
        symbol,
        maxSupply,
        mintPrice,
        mintAmount,
        msg.sender,          // Creator becomes initiator
        platformTreasury,
        platformFeeBps,
        verifierAddresses,
        subtree_height,
        roottree_height,
        initialSubtreeEmptyRoot,
        initialFinalizedEmptyRoot
    );
}
```

### Minting Behavior

#### Regular Mint (proofType = 0)

**Preconditions**:
- `msg.value == MINT_PRICE`
- `totalSupply + MINT_AMOUNT <= MAX_SUPPLY`
- `nextLeafIndexInSubtree < SUBTREE_CAPACITY`

**State Changes**:
```
activeSubtreeRoot = newActiveRoot
nextLeafIndexInSubtree += 1
totalSupply += MINT_AMOUNT
```

**Events Emitted**:
- `CommitmentAppended(currentSubtreeIndex, commitment, leafIndex, timestamp)`
- `Minted(minter, commitment, encryptedNote, subtreeIndex, leafIndex, timestamp)`

#### Rollover Mint (proofType = 1)

**Preconditions**:
- `msg.value == MINT_PRICE`
- `totalSupply + MINT_AMOUNT <= MAX_SUPPLY`
- `nextLeafIndexInSubtree == SUBTREE_CAPACITY` (subtree full)

**State Changes**:
```
finalizedRoot = newFinalizedRoot        // Archive old active root
activeSubtreeRoot = newActiveRoot       // Start new subtree
currentSubtreeIndex += 1
nextLeafIndexInSubtree = 1              // New commitment at index 0
totalSupply += MINT_AMOUNT
```

**Events Emitted**:
- `SubtreeFinalized(oldSubtreeIndex, oldActiveRoot)`
- `CommitmentAppended(newSubtreeIndex, commitment, 0, timestamp)`
- `Minted(minter, commitment, encryptedNote, newSubtreeIndex, 0, timestamp)`

### Transfer Behavior

#### Active Transfer (proofType = 0)

**Preconditions**:
- Valid ZK proof
- Input commitments exist in active subtree
- Nullifiers not previously spent
- Sufficient capacity: `numRealOutputs <= SUBTREE_CAPACITY - nextLeafIndexInSubtree`
- `oldActiveRoot == activeSubtreeRoot`

**State Changes**:
```
activeSubtreeRoot = newActiveRoot
nextLeafIndexInSubtree += numRealOutputs
For each nullifier:
    nullifiers[nullifier] = true
```

**Events Emitted**:
- `NullifierSpent(nullifier)` for each input
- `CommitmentAppended(...)` for each output
- `Transaction(commitments, encryptedNotes, ephemeralKey, viewTag)`

#### Finalized Transfer (proofType = 1)

**Preconditions**:
- Valid ZK proof
- Input commitments exist in finalized tree
- Nullifiers not previously spent
- Sufficient capacity for outputs
- `oldFinalizedRoot == finalizedRoot`
- `oldActiveRoot == activeSubtreeRoot`

**State Changes**:
```
activeSubtreeRoot = newActiveRoot       // Only active tree changes
nextLeafIndexInSubtree += numRealOutputs
For each nullifier:
    nullifiers[nullifier] = true
```

**Events Emitted**: Same as Active Transfer

**Special Property**: Does not modify finalized tree, enabling parallelization

#### Rollover Transfer (proofType = 2)

**Preconditions**:
- Valid ZK proof
- `nextLeafIndexInSubtree == SUBTREE_CAPACITY` (subtree full)
- Nullifier not previously spent
- `oldActiveRoot == activeSubtreeRoot`
- `oldFinalizedRoot == finalizedRoot`
- `currentSubtreeIndex == subtreeIndex` (from proof)

**State Changes**:
```
finalizedRoot = newFinalizedRoot
activeSubtreeRoot = newActiveRoot
currentSubtreeIndex += 1
nextLeafIndexInSubtree = 1
nullifiers[nullifier] = true
```

**Events Emitted**:
- `SubtreeFinalized(oldSubtreeIndex, oldActiveRoot)`
- `NullifierSpent(nullifier)`
- `CommitmentAppended(newSubtreeIndex, commitment, 0, timestamp)`
- `Transaction([commitment, 0x0], encryptedNotes, ephemeralKey, viewTag)`

**Special Property**: Only 1 input and 1 output due to capacity constraints

## Security Considerations

### Double-Spending Prevention

Each note can only be spent once:

```solidity
if (nullifiers[nullifier]) revert DoubleSpend(nullifier);
nullifiers[nullifier] = true;
```

Once a nullifier is marked as spent, it cannot be unspent. The ZK proof ensures that only the note owner can compute the correct nullifier.

### Commitment Uniqueness

```solidity
if (commitmentHashes[commitment]) revert CommitmentAlreadyExists(commitment);
commitmentHashes[commitment] = true;
```

This prevents replay of the same commitment, which could break tree integrity.

### Root Validation

All operations validate that the proof's claimed old root matches the contract's current state:

```solidity
if (activeSubtreeRoot != oldActiveRoot_from_proof)
    revert OldActiveRootMismatch(activeSubtreeRoot, oldActiveRoot_from_proof);
```

This prevents:
- Stale proof attacks
- Concurrent transaction conflicts
- Malicious root manipulation

### Amount Conservation

ZK circuits enforce that `sum(inputs) == sum(outputs)`, preventing inflation attacks.

### Merkle Tree Integrity

The ZK proof verifies:
1. Input commitments are valid tree members
2. Output commitments correctly update the tree
3. Tree transitions follow valid Merkle update rules

## Privacy Guarantees

### What is Hidden

1. **Transaction Amounts**: Only prover knows input/output values
2. **Sender Identity**: No link between sender address and inputs
3. **Recipient Identity**: Stealth addresses hide recipients
4. **Account Balances**: No public balance tracking
5. **Transaction Graph**: Cannot link inputs to outputs

### What is Revealed

1. **Total Supply**: Public counter of total minted amount
2. **Transaction Existence**: That a transaction occurred (via events)
3. **Nullifier Spent**: That some note was spent (but not which commitment)
4. **Tree Growth**: Number of commitments (but not their values)

### Scanning Mechanism

Recipients must scan all transactions to find their notes:

```
For each Transaction event:
    1. Check viewTag matches (99.6% filtered out)
    2. Compute shared secret: S = privateKey · ephemeralPublicKey
    3. Derive decryption key from shared secret
    4. Attempt to decrypt note
    5. If successful, note belongs to this wallet
```

The viewTag optimization reduces scanning cost by ~40%.

## Comparison with ERC-20

| Feature | ERC-20 | ZRC-20 |
|---------|--------|---------|
| `balanceOf(address)` | ✅ Public | ❌ No public balances |
| `transfer(to, amount)` | ✅ | ❌ Replaced by ZK proof |
| `approve(spender, amount)` | ✅ | ❌ Not supported |
| `transferFrom(from, to, amount)` | ✅ | ❌ Not supported |
| `totalSupply()` | ✅ | ✅ (but doesn't reveal distribution) |
| Amount Privacy | ❌ | ✅ |
| Sender Privacy | ❌ | ✅ |
| Recipient Privacy | ❌ | ✅ |
| Balance Privacy | ❌ | ✅ |

## Client-Side Responsibilities

Since balances are private, clients must:

### 1. Track Commitments

Monitor `CommitmentAppended` events and maintain local Merkle tree:

```javascript
contract.on("CommitmentAppended", (subtreeIndex, commitment, leafIndex, timestamp) => {
    localTree.insert(commitment, subtreeIndex, leafIndex);
});
```

### 2. Scan for Notes

Monitor `Transaction` events and decrypt relevant notes:

```javascript
contract.on("Transaction", async (commitments, encryptedNotes, ephemeralKey, viewTag) => {
    // Quick filter by viewTag
    if (computeViewTag(ephemeralKey) !== myViewTag) return;

    // Attempt decryption
    for (const encNote of encryptedNotes) {
        const note = await tryDecrypt(encNote, myPrivateKey, ephemeralKey);
        if (note) {
            myNotes.push(note);
            myBalance += note.amount;
        }
    }
});
```

### 3. Track Nullifiers

Monitor `NullifierSpent` events to mark own notes as spent:

```javascript
contract.on("NullifierSpent", (nullifier) => {
    const myNote = myNotes.find(n => computeNullifier(n) === nullifier);
    if (myNote) {
        myNote.spent = true;
        myBalance -= myNote.amount;
    }
});
```

### 4. Generate Proofs

Use client-side ZK proof generation libraries (e.g., snarkjs) to create proofs before submitting transactions.

## Gas Optimization Techniques

### 1. Packed State

```solidity
struct ContractState {
    uint32 currentSubtreeIndex;    // 4 bytes
    uint32 nextLeafIndexInSubtree; // 4 bytes
    uint8 subTreeHeight;           // 1 byte
    uint8 rootTreeHeight;          // 1 byte
    bool initialized;              // 1 byte
}
// Total: 11 bytes (fits in single storage slot)
```

**Savings**: ~20K gas per state update vs. separate variables

### 2. Custom Errors

```solidity
error InvalidProof();                    // vs. require(valid, "Invalid proof")
error DoubleSpend(bytes32 nullifier);   // vs. require(!spent, "Double spend")
```

**Savings**: ~50 gas per revert

### 3. Immutable Configuration

```solidity
address public immutable initiator;
uint256 public immutable MAX_SUPPLY;
uint256 public immutable MINT_PRICE;
uint256 public immutable MINT_AMOUNT;
```

**Savings**: ~2100 gas per read (vs. SLOAD)

### 4. Minimal Tree Updates

Only the active subtree is updated on-chain. The finalized tree grows logarithmically with total notes.

**Result**: 60% gas reduction vs. single-tree designs

## Extending the Standard

### Optional Viewing Keys

For compliance, implementations may add:

```solidity
mapping(address => bytes) public viewingKeys;

function registerViewingKey(bytes calldata key) external {
    viewingKeys[msg.sender] = key;
}
```

This allows users to optionally disclose their transaction history to auditors.

### Withdrawal to Public ERC-20

Implementations may add a `withdraw` function:

```solidity
function withdraw(
    bytes calldata proof,
    address recipient,
    uint256 amount
) external;
```

This would burn the private note and mint public ERC-20 tokens.

## Reference Implementation

See `contracts/core/PrivacyToken.sol` for the canonical implementation.

## Copyright

Copyright © 2025 ZKProtocol. Licensed under MIT License.
