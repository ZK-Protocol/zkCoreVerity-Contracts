# Deployed Contracts

ZKProtocol is **already deployed** on multiple networks. Anyone can use the factory contracts to create their own privacy tokens without any permission.

## Live Networks

### Base Mainnet

**Network Details**:
- Chain ID: `8453`
- RPC: `https://mainnet.base.org`
- Explorer: `https://basescan.org`

**Factory Contract**:
```
0x23ceEF8fFd28A00108B7173Dc467285B31b631BF
```
[View on BaseScan](https://basescan.org/address/0x23ceEF8fFd28A00108B7173Dc467285B31b631BF)

**Core Contracts**:
| Contract | Address |
|----------|---------|
| Factory | `0x23ceEF8fFd28A00108B7173Dc467285B31b631BF` |
| Implementation | `0x8C943ea84880da470d092a49d8808eD5c1860A66` |

**Verifier Contracts**:
| Verifier | Address |
|----------|---------|
| Mint | `0x3387AF805493fEb4d5a1122715e9FcCCBF01deFc` |
| Mint Rollover | `0xD2F83E51F0F1eB256201541EbA45adD6D16875A6` |
| Active Transfer | `0xa92a3bD3ea8F568955f5f955aF7C4D3B6c60c125` |
| Finalized Transfer | `0xEce105467177FB2d0C6CF6BAfa6Bd3bC5010E9e9` |
| Rollover Transfer | `0xb80a48BaafE9c002B2fE81386C121cfe275f8469` |

**Example Privacy Token**:
- Address: `0x5eCD591e44bc412cfb7152b665699aF07096A5D0`
- Name: `ZK Protocol`
- Symbol: `ZK`
- Max Supply: `21,000,000 ZK`
- Mint Price: `0.003 ETH`
- Mint Amount: `1,000 ZK` per mint

[View Token on BaseScan](https://basescan.org/address/0x5eCD591e44bc412cfb7152b665699aF07096A5D0)

---

### BNB Smart Chain (BSC)

**Network Details**:
- Chain ID: `56`
- RPC: `https://bsc-dataseed.binance.org`
- Explorer: `https://bscscan.com`

**Factory Contract**:
```
0x46e343F882C793D08971Fb30073eE9570a505457
```
[View on BscScan](https://bscscan.com/address/0x46e343F882C793D08971Fb30073eE9570a505457)

**Core Contracts**:
| Contract | Address |
|----------|---------|
| Factory | `0x46e343F882C793D08971Fb30073eE9570a505457` |
| Implementation | `0x8dbbFE6DE3Fb3F05E774B9873c13BC63F81Fd712` |

**Verifier Contracts**:
| Verifier | Address |
|----------|---------|
| Mint | `0xa3d0A0287856E4655447E658b351aA447612902d` |
| Mint Rollover | `0x93A054024de4dB177706A59D70Dde7b26104f7c1` |
| Active Transfer | `0x1aeb8091af7Cfd8273740542b903E90904B1BaC7` |
| Finalized Transfer | `0x396dD199F7aA0035b23116201e72FA94bD82f7F8` |
| Rollover Transfer | `0x3d09c06BBd64822DDBa82a3C2Ce94707f97E6575` |

**Example Privacy Token**:
- Address: `0x8a64A1128cC55BF72180D8f2A5C75fE1FEf8D933`
- Name: `4444`
- Symbol: `4`
- Max Supply: `21,000,000 tokens`
- Mint Price: `0.008 BNB`
- Mint Amount: `1,000 tokens` per mint

[View Token on BscScan](https://bscscan.com/address/0x8a64A1128cC55BF72180D8f2A5C75fE1FEf8D933)

---

## How to Create Your Own Privacy Token

**You don't need to deploy anything!** Simply interact with the existing factory contract on your preferred network.

### Method 1: Using Block Explorer (Easiest)

#### On Base:

1. Go to the factory contract on BaseScan:
   ```
   https://basescan.org/address/0x23ceEF8fFd28A00108B7173Dc467285B31b631BF#writeContract
   ```

2. Click "Connect Wallet"

3. Find the `createToken` function

4. Fill in the parameters:
   ```
   name: "My Privacy Token"
   symbol: "MPT"
   maxSupply: 1000000000000000000000000  // 1M tokens (in wei)
   mintPrice: 5000000000000000           // 0.005 ETH (in wei)
   mintAmount: 100000000000000000000     // 100 tokens (in wei)
   ```

5. Set the value to `0.0005 ETH` (creation fee)

6. Click "Write" to submit the transaction

7. Once confirmed, find your token address in the transaction logs under `TokenCreated` event

#### On BSC:

Same process, but use:
```
https://bscscan.com/address/0x46e343F882C793D08971Fb30073eE9570a505457#writeContract
```

### Method 2: Using Web3 Library (ethers.js)

```javascript
const { ethers } = require("ethers");

// Connect to network
const provider = new ethers.providers.JsonRpcProvider("https://mainnet.base.org");
const wallet = new ethers.Wallet(YOUR_PRIVATE_KEY, provider);

// Factory contract
const factoryAddress = "0x23ceEF8fFd28A00108B7173Dc467285B31b631BF";
const factoryABI = [
    "function createToken(string name, string symbol, uint256 maxSupply, uint256 mintPrice, uint256 mintAmount) payable",
    "function creationFee() view returns (uint256)",
    "event TokenCreated(address indexed tokenAddress, address indexed creator, string name, string symbol, uint256 maxSupply, uint256 mintAmount, uint256 mintPrice, uint256 subTreeHeight, uint256 rootTreeHeight)"
];

const factory = new ethers.Contract(factoryAddress, factoryABI, wallet);

// Get creation fee
const creationFee = await factory.creationFee();
console.log("Creation fee:", ethers.utils.formatEther(creationFee), "ETH");

// Create token
const tx = await factory.createToken(
    "My Privacy Token",                    // name
    "MPT",                                 // symbol
    ethers.utils.parseEther("1000000"),    // maxSupply: 1M tokens
    ethers.utils.parseEther("0.0005"),      // mintPrice: 0.0005 ETH per mint
    ethers.utils.parseEther("100"),        // mintAmount: 100 tokens per mint
    { value: creationFee }
);

console.log("Transaction hash:", tx.hash);
const receipt = await tx.wait();

// Extract token address from event
const event = receipt.events.find(e => e.event === "TokenCreated");
const tokenAddress = event.args.tokenAddress;

console.log("Privacy token created at:", tokenAddress);
```

### Method 3: Using Hardhat Script

```javascript
// scripts/create_my_token.js
const hre = require("hardhat");

async function main() {
    const [deployer] = await hre.ethers.getSigners();

    // Base mainnet factory
    const factoryAddress = "0x23ceEF8fFd28A00108B7173Dc467285B31b631BF";
    const factory = await hre.ethers.getContractAt("PrivacyTokenFactory", factoryAddress);

    const creationFee = await factory.creationFee();
    console.log("Creation fee:", hre.ethers.utils.formatEther(creationFee), "ETH");

    const tx = await factory.createToken(
        "My Privacy Token",
        "MPT",
        hre.ethers.utils.parseEther("1000000"),
        hre.ethers.utils.parseEther("0.0005"),
        hre.ethers.utils.parseEther("100"),
        { value: creationFee }
    );

    const receipt = await tx.wait();
    const event = receipt.events.find(e => e.event === "TokenCreated");

    console.log("Token created:", event.args.tokenAddress);
}

main();
```

Run with:
```bash
npx hardhat run scripts/create_my_token.js --network base
```

---

## Token Configuration Guidelines

### Parameter Recommendations

**maxSupply**:
- Recommended: `1,000,000` to `100,000,000` tokens
- Must be in wei: multiply by `10^18`
- Cannot be changed after creation

**mintPrice**:
- Base: `0.001` to `0.01` ETH typical
- BSC: `0.001` to `0.01` BNB typical
- Set to `0` for free minting (gas only)
- Creator receives 97.5% (platform takes 2.5%)

**mintAmount**:
- How many tokens each mint operation generates
- Recommended: `10` to `1000` tokens
- Should be reasonable fraction of maxSupply
- Must be in wei: multiply by `10^18`

### Examples

**Small Community Token**:
```javascript
name: "Privacy DAO"
symbol: "pDAO"
maxSupply: 100000 * 10^18      // 100K tokens
mintPrice: 0.001 * 10^18        // 0.001 ETH
mintAmount: 10 * 10^18          // 10 tokens per mint
// Result: Users pay 0.001 ETH to get 10 pDAO
```

**Larger Project Token**:
```javascript
name: "Privacy DeFi"
symbol: "pDEFI"
maxSupply: 21000000 * 10^18     // 21M tokens (Bitcoin-like)
mintPrice: 0.005 * 10^18        // 0.005 ETH
mintAmount: 100 * 10^18         // 100 tokens per mint
// Result: Users pay 0.005 ETH to get 100 pDEFI
```

**Free Fair Launch**:
```javascript
name: "Free Privacy Token"
symbol: "FPT"
maxSupply: 1000000 * 10^18      // 1M tokens
mintPrice: 0                     // FREE (gas only)
mintAmount: 1 * 10^18            // 1 token per mint
// Result: Users pay only gas to get 1 FPT
```

---

## Current Factory Settings

### Base Factory Configuration

```javascript
Platform Treasury: 0x6564d0b297AF4cCAe809f1606e8d3542AD989Ab8
Creation Fee: 0.0005 ETH
Platform Fee: 2.5% of mint revenue
Subtree Height: 16 (65,536 notes per subtree)
Root Tree Height: 20 (1,048,576 subtrees max)
```

### BSC Factory Configuration

```javascript
Platform Treasury: 0x6564d0b297AF4cCAe809f1606e8d3542AD989Ab8
Creation Fee: 0.005 BNB
Platform Fee: 2.5% of mint revenue
Subtree Height: 16 (65,536 notes per subtree)
Root Tree Height: 20 (1,048,576 subtrees max)
```

---

## Cryptographic Parameters

Both networks use identical cryptographic setup:

```javascript
Curve: Baby Jubjub (zk-SNARK friendly)
Hash: Poseidon
Empty Subtree Root: 0x2a7c7c9b6ce5880b9f6f228d72bf6a575a526f29c66ecceef8b753d38bba7323
Empty Finalized Root: 0x224ccc25981822d4c5b6fc199fbc74828488741c7151a6159ecfaab7c2a8bac9
Proof System: Groth16 (zk-SNARKs)
```

These roots are precomputed for empty Merkle trees and are consistent across all deployments.

---

## Integration Guide

### For Wallet Developers

To integrate ZKProtocol privacy tokens:

1. **Monitor Factory Events**: Watch for `TokenCreated` events to discover new privacy tokens

2. **Scan Token Events**: For each privacy token, monitor:
   - `Minted` - New notes created
   - `Transaction` - Private transfers
   - `NullifierSpent` - Notes spent
   - `CommitmentAppended` - Tree updates

3. **Decrypt Notes**: Use the encryption scheme to find notes belonging to your user

4. **Build Local Tree**: Maintain Merkle tree state for proof generation

5. **Generate Proofs**: Use circuit files and proving keys to create ZK proofs

### For DApp Developers

```javascript
// Example: Check if an address is a ZKProtocol privacy token
async function isPrivacyToken(address) {
    const token = new ethers.Contract(address, [
        "function activeSubtreeRoot() view returns (bytes32)",
        "function finalizedRoot() view returns (bytes32)",
        "function MINT_PRICE() view returns (uint256)",
        "function MINT_AMOUNT() view returns (uint256)"
    ], provider);

    try {
        await token.activeSubtreeRoot();
        await token.finalizedRoot();
        return true;
    } catch {
        return false;
    }
}
```

---

## Verification

All contracts are verified on their respective block explorers:

### Base
- Factory: [Verified on BaseScan](https://basescan.org/address/0x23ceEF8fFd28A00108B7173Dc467285B31b631BF#code)
- Verifiers: All verified and visible

### BSC
- Factory: [Verified on BscScan](https://bscscan.com/address/0x46e343F882C793D08971Fb30073eE9570a505457#code)
- Verifiers: All verified and visible

---

## Support & Community

- **Website**: [https://zkprotocol.xyz](https://zkprotocol.xyz)
- **Twitter**: [@0xzkprotocol](https://x.com/0xzkprotocol)
- **GitHub**: [ZK-Protocol](https://github.com/ZK-Protocol)
- **Email**: 0x.zero.protocol@gmail.com

---

## Important Notes

1. **No Redeployment Needed**: The factory and verifiers are already deployed. Just call `createToken()`.

2. **Permissionless**: Anyone can create a privacy token. No whitelist, no approval needed.

3. **Non-Upgradeable**: Once created, token parameters (maxSupply, mintPrice, mintAmount) are immutable.

4. **Privacy Trade-offs**: While amounts/addresses are private, the existence of transactions is public.

5. **Regulatory Compliance**: Users are responsible for compliance with local regulations.

---

**Start creating privacy tokens today. No deployment required, no permission needed.**
