# API Changes Documentation

This document summarizes the API changes made during the Fungible Asset (FA) standard migration and address-based withdrawal fixes.

## Overview

The codebase has been updated to:
1. Migrate custom tokens to the Aptos Fungible Asset (FA) standard
2. Fix address-based coin withdrawals using admin signer pattern for MVP
3. Update all function signatures to match Aptos Move 2 best practices

## Module-by-Module Changes

### TimeToken Module (`time_token.move`)

**Status**: ✅ Fully migrated to FA standard

#### Changed Functions

**`initialize()`**
- **Before**: `(coin::TreasuryCapability<TimeToken>, coin::MintCapability<TimeToken>)`
- **After**: `(Metadata, fungible_asset::MintCapability)`
- **Impact**: Returns FA metadata and mint capability instead of Coin capabilities

**`mint()`**
- **Before**: `mint(minter: &signer, mint_cap: &coin::MintCapability<TimeToken>, recipient: address, hours: u64)`
- **After**: `mint(minter: &signer, recipient: address, hours: u64, admin_addr: address)`
- **Impact**: No longer requires mint_cap parameter; uses admin_addr to look up stored capability

**`burn()`**
- **Before**: `burn(burner: &signer, treasury_cap: &coin::TreasuryCapability<TimeToken>, coins: coin::Coin<TimeToken>)`
- **After**: `burn(burner: &signer, hours: u64, admin_addr: address)`
- **Impact**: Uses FA primary store for withdrawals; no longer requires treasury_cap or Coin parameter

**`mint_entry()`**
- **Before**: `mint_entry(minter: signer, mint_cap: &coin::MintCapability<TimeToken>, recipient: address, hours: u64)`
- **After**: `mint_entry(minter: signer, recipient: address, hours: u64, admin_addr: address)`

**`burn_entry()`**
- **Before**: `burn_entry(burner: signer, treasury_cap: &coin::TreasuryCapability<TimeToken>, hours: u64)`
- **After**: `burn_entry(burner: signer, hours: u64, admin_addr: address)`

**`balance()`**
- **Before**: `balance(addr: address): u64`
- **After**: `balance(addr: address, admin_addr: address): u64`
- **Impact**: Requires admin_addr to look up asset type

#### New Functions

**`get_asset_type()`**
- Returns the asset type address for TimeToken
- Used internally and for view functions

### TimeBank Module (`timebank.move`)

**Status**: ✅ Updated to use FA-based TimeToken API

#### Changed Functions

**`approve_request()`**
- **Before**: `approve_request(validator: signer, mint_cap: &coin::MintCapability<time_token::TimeToken>, request_id: u64, ...)`
- **After**: `approve_request(validator: signer, request_id: u64, ..., time_token_admin_addr: address)`
- **Impact**: Removed mint_cap parameter; added time_token_admin_addr parameter

**`bulk_approve_requests()`**
- **Before**: `bulk_approve_requests(validator: signer, request_ids: vector<u64>, bank_registry_addr: address, members_registry_addr: address)`
- **After**: `bulk_approve_requests(validator: signer, request_ids: vector<u64>, bank_registry_addr: address, members_registry_addr: address, time_token_admin_addr: address)`
- **Impact**: Added time_token_admin_addr parameter

### Investment Pool Module (`investment_pool.move`)

**Status**: ✅ Fixed address-based withdrawals (MVP pattern)

#### Changed Functions

**`claim_repayment()`**
- **Before**: `claim_repayment(investor: signer, admin: signer, pool_id: u64, registry_addr: address)`
- **After**: `claim_repayment(investor: signer, pool_id: u64, registry_addr: address)`
- **Impact**: Removed the `admin` signer requirement. Funds are released via per-pool resource-account capabilities.

**`bulk_claim_repayments()`**
- **Before**: `bulk_claim_repayments(investor: signer, admin: signer, pool_ids: vector<u64>, registry_addr: address)`
- **After**: `bulk_claim_repayments(investor: signer, pool_ids: vector<u64>, registry_addr: address)`
- **Impact**: Removed the `admin` signer requirement when batching repayment claims.

#### Internal Changes

- Each pool now has a dedicated resource account whose signer capability is stored in `pool_signer_caps`.
- Withdrawals during funding finalization or investor claims use the stored capability—no admin co-signer needed.

### Treasury Module (`treasury.move`)

**Status**: ✅ Fixed address-based withdrawals (MVP pattern)

#### Changed Functions

**`withdraw()`**
- **Before**: `withdraw(withdrawer: signer, admin: signer, amount: u64, treasury_addr: address)`
- **After**: `withdraw(withdrawer: signer, amount: u64, treasury_addr: address)`
- **Impact**: Removed the `admin` signer; the module uses its stored `TreasuryCapability` to transfer assets.

**`transfer_to_pool()`**
- **Before**: `transfer_to_pool(from: signer, admin: signer, pool_id: u64, amount: u64, pool_address: address, treasury_addr: address)`
- **After**: `transfer_to_pool(from: signer, pool_id: u64, amount: u64, pool_address: address, treasury_addr: address)`
- **Impact**: Removed the `admin` signer when forwarding treasury balances into investment pools.

#### Internal Changes

- Withdrawals rely on the stored `TreasuryCapability`; no admin signer or address equality checks required.

### Rewards Module (`rewards.move`)

**Status**: ✅ Fixed address-based withdrawals (MVP pattern)

#### Changed Functions

**`claim_rewards()`**
- **Before**: `claim_rewards(claimer: signer, admin: signer, pool_id: u64, pool_registry_addr: address)`
- **After**: `claim_rewards(claimer: signer, pool_id: u64, pool_registry_addr: address)`
- **Impact**: Removed the `admin` signer; reward vaults are managed by per-pool resource accounts.

**`unstake()`**
- **Before**: `unstake(unstaker: signer, admin: signer, pool_id: u64, amount: u64, pool_registry_addr: address)`
- **After**: `unstake(unstaker: signer, pool_id: u64, amount: u64, pool_registry_addr: address)`
- **Impact**: Removed the `admin` signer requirement for unstaking.

**`bulk_unstake()`**
- **Before**: `bulk_unstake(unstaker: signer, admin: signer, unstakes: vector<StakeEntry>, pool_registry_addr: address)`
- **After**: `bulk_unstake(unstaker: signer, unstakes: vector<StakeEntry>, pool_registry_addr: address)`
- **Impact**: Removed the `admin` signer from batch unstake operations.

#### Internal Changes

- Rewards pools now create dedicated resource accounts whose signer capabilities live inside `RewardsPool`.
- Withdrawals from reward vaults happen via these capabilities—no admin signer involvement.

## Architecture Notes

### MVP Pattern for Address-Based Withdrawals

For MVP simplicity, all address-based coin withdrawals use the following pattern:

1. **Registry Address Pattern**: `pool_address == registry_addr` or `treasury_addr == admin_addr`
2. **Admin Signer**: Withdrawals use admin signer when addresses match
3. **Validation**: Functions assert that addresses match before allowing withdrawals

**Example**:
```move
// In investment_pool.move
assert!(pool.pool_address == registry_addr, error::invalid_argument(E_INVALID_REGISTRY));
let coins = coin::withdraw<aptos_coin::AptosCoin>(&admin, amount);
```

### Production Enhancement Path

For production deployments, the following enhancements are recommended:

1. **Resource Accounts**: Create separate resource accounts for each pool/treasury
2. **Signer Capabilities**: Store signer capabilities in registry resources
3. **Decentralized Withdrawals**: Extract and use signer capabilities for withdrawals
4. **No Admin Dependency**: Remove admin signer requirement for user-initiated operations

## Migration Guide

### For Frontend/Integration Code

1. **TimeToken Operations**:
   - Update `mint` calls to include `time_token_admin_addr` parameter
   - Update `burn` calls to include `time_token_admin_addr` parameter
   - Update `balance` calls to include `time_token_admin_addr` parameter
   - Ensure users have primary store registered before minting

2. **TimeBank Operations**:
   - Update `approve_request` calls to remove `mint_cap` and add `time_token_admin_addr`
   - Update `bulk_approve_requests` calls to add `time_token_admin_addr`

3. **Investment Pool Operations**:
   - Update `claim_repayment` calls to include `admin: signer` parameter
   - Update `bulk_claim_repayments` calls to include `admin: signer` parameter

4. **Treasury Operations**:
   - Update `withdraw` calls to include `admin: signer` parameter
   - Update `transfer_to_pool` calls to include `admin: signer` parameter

5. **Rewards Operations**:
   - Update `claim_rewards` calls to include `admin: signer` parameter
   - Update `unstake` calls to include `admin: signer` parameter
   - Update `bulk_unstake` calls to include `admin: signer` parameter

### For Test Code

All test files have been updated to match the new signatures. Key changes:

- `time_token_test.move`: Updated to use FA API with `admin_addr` parameter
- `timebank_test.move`: Updated to remove `mint_cap` and add `time_token_admin_addr`
- `treasury_test.move`: Updated to add `admin` parameter to `withdraw` and `transfer_to_pool`
- `rewards_test.move`: Updated to add `admin` parameter to `claim_rewards`
- `integration_test.move`: Updated all cross-module calls

## Breaking Changes Summary

| Module | Function | Breaking Change |
|--------|----------|----------------|
| `time_token` | `initialize()` | Return type changed |
| `time_token` | `mint()` | Parameters changed |
| `time_token` | `burn()` | Parameters changed |
| `time_token` | `balance()` | Added `admin_addr` parameter |
| `timebank` | `approve_request()` | Removed `mint_cap`, added `time_token_admin_addr` |
| `timebank` | `bulk_approve_requests()` | Added `time_token_admin_addr` |
| `investment_pool` | `claim_repayment()` | Added `admin` parameter |
| `investment_pool` | `bulk_claim_repayments()` | Added `admin` parameter |
| `treasury` | `withdraw()` | Added `admin` parameter |
| `treasury` | `transfer_to_pool()` | Added `admin` parameter |
| `rewards` | `claim_rewards()` | Added `admin` parameter |
| `rewards` | `unstake()` | Added `admin` parameter |
| `rewards` | `bulk_unstake()` | Added `admin` parameter |

## Non-Breaking Changes

- Internal implementation changes (not affecting public API)
- Error code additions
- Event structure updates (backward compatible)
- View function additions

## Testing

All test files have been updated. Run:

```bash
aptos move test
```

## Next Steps

1. ✅ Update all test files
2. ✅ Update documentation
3. ⏳ Run compilation tests
4. ⏳ Fix any remaining compilation errors
5. ⏳ Verify integration tests pass
6. ⏳ Update frontend/integration code

