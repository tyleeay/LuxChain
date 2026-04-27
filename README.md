# LuxChain 🔐
> Blockchain-based luxury goods authenticity platform

A decentralized application (DApp) that leverages NFT technology 
to solve authenticity and provenance challenges in the luxury resale market.

## Deployed Contracts (Sepolia Testnet)

| Contract | Address |
|----------|---------|
| LuxToken | 0xef480c7F39e5f12e54a974e35D0b6b8a0Ad622a9 |
| LuxChain | 0x2BaFcb320928adB4bFDEC919D40a56Ea493e96A8 |
| LuxStaking | 0xfBDb434f1dd768a8b9C9c56b734D6C546135EB3b |
| LuxDAO | 0xFf8A4EC76CD7E548e9D4De78A9dc0BAFBE68c204 |

## Architecture

- **LuxToken (LUX)** — ERC-20 platform token with mint/burn mechanics
- **LuxChain** — ERC-1155 NFT + ERC-2981 royalty for luxury goods
- **LuxStaking** — Brand staking pool with trust score system
- **LuxDAO** — Governance contract for platform decisions

## How to Compile

1. Open [Remix IDE](https://remix.ethereum.org)
2. Upload all contracts from `/contracts` folder
3. Select compiler version `0.8.20`
4. Click **Compile**

## How to Deploy

Deploy in this order (each needs LuxToken address):

1. Deploy `LuxToken.sol`
2. Deploy `LuxChain.sol` → pass LuxToken address
3. Deploy `LuxStaking.sol` → pass LuxToken address
4. Deploy `LuxDAO.sol` → pass LuxToken address

After deploying, run these setup calls:
```
LuxToken → addMinter(LuxStaking address)
LuxToken → addMinter(LuxDAO address)
LuxChain → authorizeBrand(your address)
```

## How to Run Basic Tests

### Test 1 — Mint NFT with ETH
```
LuxChain → mintItem(nfcHash, ipfsCID, royaltyFee)
Value: 0.01 ETH
```

### Test 2 — Mint NFT with LUX token
```
LuxToken → approve(LuxChain address, 100000000000000000000)
LuxChain → mintItemWithLUX(nfcHash, ipfsCID, royaltyFee)
```

### Test 3 — Verify Authenticity
```
LuxChain → verifyAuthenticity(tokenId, nfcHash)
Returns: true (genuine) / false (counterfeit)
```

### Test 4 — Stake LUX
```
LuxToken → approve(LuxStaking address, 1000000000000000000000)
LuxStaking → stake(1000000000000000000000)
```

### Test 5 — DAO Governance
```
LuxDAO → createProposal("description")
LuxDAO → vote(proposalId, true)
LuxDAO → executeProposal(proposalId)
```

## Tech Stack
- Solidity ^0.8.20
- OpenZeppelin Contracts v5.0.0
- ERC-1155, ERC-2981, ERC-20
- Deployed on Sepolia Testnet
```
