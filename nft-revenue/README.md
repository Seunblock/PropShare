# NFT Fractional Ownership Smart Contract

This smart contract enables fractional ownership of NFTs with automated revenue distribution. It allows NFT owners to create vaults, sell shares of their NFTs, and distribute revenue among shareholders.

## Features

- Create NFT vaults with fractional ownership
- Transfer shares between users
- Automated revenue distribution system
- Support for multiple revenue types (rent, parking, event)
- Complete vault buyout functionality
- Real-time dividend calculations and claims

## Architecture

### Data Structures

#### Vaults
Stores information about each NFT vault:
- NFT owner and ID
- Total shares
- Accumulated revenue
- Last distribution timestamp
- Revenue per share
- Active status

#### Share Holdings
Tracks share ownership:
- Number of shares per holder
- Last claim timestamp

#### Revenue Periods
Records revenue distribution periods:
- Amount distributed
- Timestamp
- Revenue type

### Constants

- `SHARES_PER_NFT`: 1000 shares per NFT
- Error codes for various failure conditions
- Contract owner principal

## Public Functions

### Vault Management

```clarity
(create-vault (token-contract <nft-trait>) (nft-id uint))
```
Creates a new vault by depositing an NFT. The creator receives all initial shares.

### Share Management

```clarity
(transfer-shares (vault-id uint) (recipient principal) (amount uint))
```
Transfers shares between users. Automatically processes any pending dividends before transfer.

### Revenue Distribution

```clarity
(add-revenue (vault-id uint) (amount uint) (revenue-type (string-ascii 20)))
```
Adds revenue to a vault for distribution among shareholders. Only callable by contract owner.

```clarity
(claim-dividends (vault-id uint))
```
Claims available dividends for the caller based on their share ownership.

### Vault Liquidation

```clarity
(buyout-nft (token-contract <nft-trait>) (vault-id uint))
```
Allows a user owning all shares to buy out the vault and receive the NFT.

## Read-Only Functions

```clarity
(get-vault-info (vault-id uint))
(get-share-info (vault-id uint) (holder principal))
(get-unclaimed-dividends (vault-id uint) (holder principal))
(get-revenue-period (vault-id uint) (period uint))
```

## Usage Example

1. Create a vault:
```clarity
(contract-call? .nft-vault create-vault .my-nft-contract u123)
```

2. Transfer shares:
```clarity
(contract-call? .nft-vault transfer-shares u1 'ST1234567890ABCDEF u100)
```

3. Add revenue:
```clarity
(contract-call? .nft-vault add-revenue u1 u1000000 "rent")
```

4. Claim dividends:
```clarity
(contract-call? .nft-vault claim-dividends u1)
```

## Security Considerations

- Authorization checks on all sensitive operations
- Automatic dividend processing before share transfers
- Safe arithmetic operations
- Comprehensive error handling
- Proper principal management

## Error Codes

- `ERR-NOT-AUTHORIZED (u100)`: Caller not authorized
- `ERR-INVALID-VAULT (u101)`: Invalid vault ID
- `ERR-NO-DIVIDENDS (u102)`: No dividends available
- `ERR-ALREADY-CLAIMED (u103)`: Dividends already claimed
- `ERR-INSUFFICIENT-SHARES (u104)`: Insufficient shares
- `ERR-INACTIVE-VAULT (u105)`: Vault is inactive
- `ERR-ZERO-AMOUNT (u106)`: Amount must be greater than zero

## Requirements

- Clarity smart contract language
- SIP-009 compliant NFT contract
- Stacks blockchain

## Contract Deployment

1. Deploy the contract to the Stacks blockchain
2. Set the NFT contract address using `set-nft-contract`
3. The deploying address becomes the contract owner

## Testing

Recommended test scenarios:
1. Vault creation and initialization
2. Share transfers
3. Revenue distribution
4. Dividend calculations
5. Vault buyouts
6. Error conditions and edge cases