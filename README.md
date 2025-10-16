# ZKProtocol Contracts

> **Native Privacy Asset Protocol** - Next-Generation Privacy Infrastructure Based on Zero-Knowledge Proofs

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.20-blue)](https://soliditylang.org/)

## Overview

ZKProtocol is an open-source, permissionless infrastructure based on zero-knowledge proofs (zk-SNARKs), designed for Ethereum and its compatible multi-chain ecosystem to provide **native privacy asset issuance and trading capabilities**.

Unlike traditional mixing protocols, native privacy assets possess privacy attributes from their inception, allowing anyone to issue and use them as easily as ERC-20 tokens.

## 🚀 Live Deployments

**ZKProtocol is already deployed and ready to use!**

### Base Mainnet
- **Factory**: [`0x23ceEF8fFd28A00108B7173Dc467285B31b631BF`](https://basescan.org/address/0x23ceEF8fFd28A00108B7173Dc467285B31b631BF)
- **Chain ID**: 8453
- **Status**: ✅ Live

### BNB Smart Chain
- **Factory**: [`0x46e343F882C793D08971Fb30073eE9570a505457`](https://bscscan.com/address/0x46e343F882C793D08971Fb30073eE9570a505457)
- **Chain ID**: 56
- **Status**: ✅ Live

**👉 [View Complete Deployment Information](DEPLOYMENTS.md)**

**Anyone can create their own privacy token by calling `createToken()` on the factory contract. No permission required!**

### Key Features

- **ZRC-20 Standard**: Privacy token standard with ERC-20-like interface semantics
- **Factory Pattern**: Permissionless deployment of privacy tokens
- **Dual-Layer Merkle Tree**: Efficient state management with active and finalized trees
- **Multiple Transaction Modes**: Active, Finalized, and Rollover transfers
- **Privacy Preserving**: Amounts, senders, and recipients remain confidential
- **Gas Optimized**: Up to 60% reduction in gas costs compared to traditional L1 privacy solutions

## Architecture

The protocol consists of three main components:

### 1. Core Contracts

- **PrivacyToken.sol** - Main implementation of ZRC-20 privacy tokens
- **PrivacyTokenFactory.sol** - Factory for permissionless token deployment

### 2. Interface Contracts

- **IZRC20.sol** - Standard interface for privacy tokens
- **IVerifier.sol** - Interface for zk-SNARK verifiers

### 3. Verifier Contracts

Five specialized verifiers for different proof types:
- **ProveMintVerifier.sol** - Regular mint operations
- **ProveMintAndRolloverVerifier.sol** - Mint with subtree rollover
- **ProveActiveTransferVerifier.sol** - Transfers within active subtree
- **ProveFinalizedTransferVerifier.sol** - Transfers from finalized tree
- **ProveRolloverTransferVerifier.sol** - Transfer triggering rollover

## How It Works

### Dual-Layer Merkle Tree

```
┌─────────────────────────────────────┐
│         Root Tree (L2)              │
│    Height: 20 (1M+ subtrees)        │
│                                     │
│  ┌──────┬──────┬──────┬──────┐    │
│  │Root 0│Root 1│Root 2│ ...  │    │
│  └──┬───┴──────┴──────┴──────┘    │
│     │                               │
└─────┼───────────────────────────────┘
      │
      ▼
┌─────────────────────────────────────┐
│    Active Subtree (Current)         │
│    Height: 16 (65,536 leaves)       │
│                                     │
│  ┌────────────────────────────┐    │
│  │  Commitments (Notes)       │    │
│  │  [C₀, C₁, C₂, ..., Cₙ]    │    │
│  └────────────────────────────┘    │
└─────────────────────────────────────┘
```

### Transaction Flow

#### 1. Minting (Public → Private)

```solidity
// User pays MINT_PRICE in native token
// Generates ZK proof proving:
// - Payment of correct amount
// - Valid commitment generation
// - Proper tree insertion

privacyToken.mint{value: MINT_PRICE}(
    proofType,      // 0: Regular, 1: Rollover
    proof,          // ZK-SNARK proof
    encryptedNote   // Encrypted note for recipient
);
```

#### 2. Private Transfer

```solidity
// User generates ZK proof proving:
// - Ownership of input notes
// - Nullifiers are unspent
// - Input amount = Output amount
// - Valid Merkle membership

privacyToken.transfer(
    proofType,         // 0: Active, 1: Finalized, 2: Rollover
    proof,             // ZK-SNARK proof
    encryptedNotes     // Encrypted output notes
);
```

## ZRC-20 Standard

### Core Methods

```solidity
interface IZRC20 {
    // Metadata (like ERC-20)
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);

    // Privacy-specific
    function mint(
        uint8 proofType,
        bytes calldata proof,
        bytes calldata encryptedNote
    ) external payable;

    function transfer(
        uint8 proofType,
        bytes calldata proof,
        bytes[] calldata encryptedNotes
    ) external;
}
```

### Key Differences from ERC-20

| Feature | ERC-20 | ZRC-20 |
|---------|---------|---------|
| Balance Query | `balanceOf(address)` | None (client-side) |
| Transfer | `transfer(to, amount)` | `transfer(proof, notes)` |
| Visibility | Fully public | Fully private |
| State Storage | `address → balance` | Merkle tree commitments |
| Double-spend Prevention | Balance check | Nullifier mechanism |

## Events

### Minting Events

```solidity
event Minted(
    address indexed minter,
    bytes32 commitment,
    bytes encryptedNote,
    uint32 subtreeIndex,
    uint32 leafIndex,
    uint256 timestamp
);

event CommitmentAppended(
    uint32 indexed subtreeIndex,
    bytes32 commitment,
    uint32 indexed leafIndex,
    uint256 timestamp
);
```

### Transfer Events

```solidity
event Transaction(
    bytes32[2] newCommitments,
    bytes[] encryptedNotes,
    uint256[2] ephemeralPublicKey,
    uint256 viewTag
);

event NullifierSpent(bytes32 indexed nullifier);
```

### State Events

```solidity
event SubtreeFinalized(
    uint32 indexed subtreeIndex,
    bytes32 root
);
```

## Quick Start: Create Your Privacy Token

The protocol is already deployed! You can create your own privacy token in minutes.

### Option 1: Via Block Explorer (Easiest)

1. Visit the factory contract on [BaseScan](https://basescan.org/address/0x23ceEF8fFd28A00108B7173Dc467285B31b631BF#writeContract) or [BscScan](https://bscscan.com/address/0x46e343F882C793D08971Fb30073eE9570a505457#writeContract)

2. Connect your wallet

3. Call `createToken` with your parameters:
   ```
   name: "My Privacy Token"
   symbol: "MPT"
   maxSupply: 1000000000000000000000000  (1M tokens in wei)
   mintPrice: 5000000000000000           (0.005 ETH in wei)
   mintAmount: 100000000000000000000     (100 tokens in wei)
   value: 0.005 ETH (creation fee)
   ```

4. Your privacy token address will be in the transaction logs!

### Option 2: Via Web3 Code

```javascript
const factory = new ethers.Contract(
    "0x23ceEF8fFd28A00108B7173Dc467285B31b631BF",  // Base
    factoryABI,
    signer
);

const tx = await factory.createToken(
    "My Privacy Token",
    "MPT",
    ethers.utils.parseEther("1000000"),  // 1M max supply
    ethers.utils.parseEther("0.005"),    // 0.005 ETH per mint
    ethers.utils.parseEther("100"),      // 100 tokens per mint
    { value: ethers.utils.parseEther("0.005") }  // creation fee
);

const receipt = await tx.wait();
const tokenAddress = receipt.events.find(e => e.event === "TokenCreated").args.tokenAddress;
console.log("Token created at:", tokenAddress);
```

**📖 For detailed instructions, see [DEPLOYMENTS.md](DEPLOYMENTS.md)**

## Security Features

### Cryptographic Security

- **Elliptic Curve**: Baby Jubjub (zk-SNARK friendly)
- **Hash Function**: Poseidon (optimized for zero-knowledge)
- **Encryption**: ECDH + AES-GCM authenticated encryption
- **Randomness**: Cryptographically secure random generation

### Protocol Security

- **Double-spending Prevention**: Unique nullifier enforcement
- **Replay Protection**: Cryptographically bound proofs
- **State Integrity**: Tamper-evident Merkle commitment
- **Reentrancy Protection**: OpenZeppelin's ReentrancyGuard

### Validation Checks

```solidity
// Mint validations
- Correct payment amount
- Max supply not exceeded
- Valid ZK proof
- Commitment uniqueness
- Root consistency

// Transfer validations
- Valid ZK proof
- Unspent nullifiers
- Merkle membership
- Value conservation
- Sufficient subtree capacity
```

## Gas Optimization

### Performance Metrics

| Operation | Gas Cost | Generation Time |
|-----------|----------|-----------------|
| Regular Mint | ~250K | 1s |
| Rollover Mint | ~350K | 3-4s |
| Active Transfer | ~300K | 2-3s |
| Finalized Transfer | ~350K | 3-4s |
| Rollover Transfer | ~350K | 3-4s |

### Optimization Techniques

1. **Packed State Variables**: Minimize SSTORE operations
2. **Custom Errors**: Save gas vs. require strings
3. **Minimal Tree Updates**: Only active subtree modified
4. **Efficient Verifier Design**: Optimized Groth16 verification

## Use Cases

### DeFi Privacy

- **Private DEX**: Hidden trading amounts and strategies
- **Anonymous Lending**: Confidential collateral and positions
- **Shielded Yield Farming**: Private returns and positions

### DAO Governance

- **Anonymous Voting**: Prevent collusion and pressure
- **Private Proposals**: Confidential strategy discussions
- **Shielded Treasury**: Protected fund management

### Enterprise Payments

- **Confidential Settlements**: On-chain with privacy
- **Supply Chain Finance**: Protected trade secrets
- **Payroll Privacy**: Private salary distributions

### Gaming & Metaverse

- **Asset Privacy**: Hidden player wealth
- **Fair Competition**: Prevent wealth-based advantages
- **Cross-game Assets**: Private asset circulation

## Repository Structure

```
zkCoreVerity-Contracts/
├── contracts/
│   ├── core/
│   │   ├── PrivacyToken.sol
│   │   └── PrivacyTokenFactory.sol
│   ├── interfaces/
│   │   ├── IZRC20.sol
│   │   └── IVerifier.sol
│   └── verifiers/
│       ├── ProveMintVerifier.sol
│       ├── ProveMintAndRolloverVerifier.sol
│       ├── ProveActiveTransferVerifier.sol
│       ├── ProveFinalizedTransferVerifier.sol
│       └── ProveRolloverTransferVerifier.sol
├── docs/
│   ├── ARCHITECTURE.md
│   ├── ZRC20_SPECIFICATION.md
│   └── DEPLOYMENT_GUIDE.md
│   
├── scripts/
│   └── deploy.js
└── test/
    └── (test files)
```

## Documentation

- **[Deployed Contracts](DEPLOYMENTS.md)** - Live contract addresses and creation guide ⭐
- **[Architecture Overview](docs/ARCHITECTURE.md)** - System design and components
- **[ZRC-20 Specification](docs/ZRC20_SPECIFICATION.md)** - Complete standard specification

## Whitepaper

For a comprehensive understanding of the protocol's design, cryptographic primitives, and economic model, please read our [whitepaper](https://github.com/ZK-Protocol/Native-Privacy-Asset-Protocol-Whitepaper/blob/main/README.md).


## Community & Support

- **Website**: [https://zkprotocol.xyz](https://zkprotocol.xyz)
- **Twitter**: [@0xzkprotocol](https://x.com/0xzkprotocol)
- **GitHub**: [ZK-Protocol](https://github.com/ZK-Protocol)
- **Email**: 0x.zero.protocol@gmail.com

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This software is provided "as is", without warranty of any kind. Use at your own risk. The protocol is designed for educational and research purposes. Please ensure compliance with your local laws and regulations regarding privacy and cryptocurrency.

---

**Built with privacy in mind. Secured by zero-knowledge.**
