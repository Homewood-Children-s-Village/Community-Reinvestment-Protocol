# Fungible Asset API Fixes - Comprehensive Summary

## Overview
Fixed critical API mismatches to align with Aptos Move 2 object-based Fungible Asset API. The codebase was using an outdated address-based API that doesn't exist in the current framework.

## Critical Issues Fixed

### 1. **Fungible Asset Creation API**
**Problem**: Code used non-existent `fungible_asset::create_fungible_asset()` function
**Solution**: Updated to use object-based API:
```move
// OLD (doesn't exist):
let (metadata, mint_cap) = fungible_asset::create_fungible_asset(...);

// NEW (correct):
let constructor_ref = &object::create_named_object(admin, symbol);
primary_fungible_store::create_primary_store_enabled_fungible_asset(
    constructor_ref,
    option::none(), // max_supply
    name, symbol, decimals, icon_uri, description
);
let metadata = object::object_from_constructor_ref<Metadata>(constructor_ref);
```

**Files Fixed**:
- `sources/token.move`
- `sources/time_token.move`

### 2. **MintCapability Type**
**Problem**: Tried to import `MintCapability` from `fungible_asset` module (doesn't exist)
**Solution**: Created local `MintCapability` struct storing `MintRef`, `BurnRef`, `TransferRef`:
```move
struct MintCapability has key, store {
    metadata: Object<Metadata>,
    mint_ref: MintRef,
    burn_ref: BurnRef,
    transfer_ref: TransferRef,
}
```

**Files Fixed**:
- `sources/token.move`
- `sources/time_token.move`

### 3. **Asset Identification - Address vs Object**
**Problem**: API functions expect `Object<Metadata>`, not `address`
**Solution**: Changed all asset identification from `address` to `Object<Metadata>`

**API Changes**:
- `primary_fungible_store::balance(addr, Object<Metadata>)` - not `(addr, address)`
- `primary_fungible_store::mint(&MintRef, addr, amount)` - not `(MintCapability, ...)`
- `fungible_asset::supply(Object<Metadata>)` - returns `Option<u128>`, not `u64`
- `fungible_asset::withdraw_with_ref(&TransferRef, store, amount)` - not `(store, amount)`
- `fungible_asset::burn(&BurnRef, asset)` - not `(asset)` alone

**Files Fixed**:
- `sources/token.move` - All balance/supply/withdraw calls
- `sources/time_token.move` - All balance/withdraw calls
- `sources/governance.move` - Voting power calculation

### 4. **Mint Function Implementation**
**Problem**: Mint function had placeholder `abort 999`
**Solution**: Implemented using correct API:
```move
primary_fungible_store::ensure_primary_store_exists(to, cap.metadata);
primary_fungible_store::mint(&cap.mint_ref, to, amount);
```

**Files Fixed**:
- `sources/token.move`
- `sources/time_token.move`

### 5. **Burn Function Implementation**
**Problem**: Burn function didn't use `BurnRef`
**Solution**: Updated to use `BurnRef`:
```move
let asset = fungible_asset::withdraw_with_ref(&cap.transfer_ref, store, amount);
fungible_asset::burn(&cap.burn_ref, asset);
```

**Files Fixed**:
- `sources/token.move`
- `sources/time_token.move`

### 6. **Withdraw Function**
**Problem**: Tests used non-existent `primary_fungible_store::withdraw(addr, address, amount)`
**Solution**: Added helper function using `withdraw_with_ref`:
```move
public fun withdraw(
    withdrawer: &signer,
    amount: u64,
    admin_addr: address,
): FungibleAsset acquires MintCapability {
    // Uses fungible_asset::withdraw_with_ref(&transfer_ref, store, amount)
}
```

**Files Fixed**:
- `sources/token.move` - Added `withdraw()` helper
- `tests/token_test.move` - Updated to use helper

### 7. **Test Updates**
**Problem**: Tests used old API patterns
**Solution**: Updated all tests to match new API:
- Removed `asset_type_from_metadata()` calls (not needed)
- Removed manual `create_primary_store_enabled_fungible_store()` calls (auto-created)
- Updated to use `Object<Metadata>` directly

**Files Fixed**:
- `tests/token_test.move`
- `tests/time_token_test.move`
- `tests/integration_test.move`
- `tests/timebank_test.move`

## API Pattern Summary

### Correct Pattern (from Aptos examples):

```move
// 1. Create object
let constructor_ref = &object::create_named_object(admin, symbol);

// 2. Create fungible asset
primary_fungible_store::create_primary_store_enabled_fungible_asset(
    constructor_ref, max_supply, name, symbol, decimals, icon_uri, project_uri
);

// 3. Get metadata object
let metadata = object::object_from_constructor_ref<Metadata>(constructor_ref);

// 4. Generate refs
let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);

// 5. Mint
primary_fungible_store::ensure_primary_store_exists(addr, metadata);
primary_fungible_store::mint(&mint_ref, addr, amount);

// 6. Balance
primary_fungible_store::balance(addr, metadata);

// 7. Withdraw
let store = primary_fungible_store::ensure_primary_store_exists(addr, metadata);
let asset = fungible_asset::withdraw_with_ref(&transfer_ref, store, amount);

// 8. Burn
fungible_asset::burn(&burn_ref, asset);

// 9. Supply
let supply_opt = fungible_asset::supply(metadata); // Returns Option<u128>
```

## Potential Remaining Issues

### 1. **Return Type Mismatches**
- `initialize()` now returns `(Object<Metadata>, MintCapability)` instead of `(Metadata, MintCapability)`
- Tests and other modules expecting `Metadata` may need updates

### 2. **Function Visibility**
- `withdraw()` function in `token.move` is `public` - consider if it should be `public(friend)` or internal

### 3. **Supply Return Type**
- `fungible_asset::supply()` returns `Option<u128>`, but we're converting to `u64`
- May need to handle overflow cases for very large supplies

### 4. **Unused Variables**
- Several `store` variables are created but not used (intentional - `ensure_primary_store_exists` creates store)

### 5. **Error Handling**
- `withdraw()` function checks `E_NOT_ADMIN` but should probably check if withdrawer owns the assets

## Files Modified

### Source Files:
1. `sources/token.move` - Complete rewrite of FA API usage
2. `sources/time_token.move` - Complete rewrite of FA API usage
3. `sources/governance.move` - Updated voting power calculation

### Test Files:
1. `tests/token_test.move` - Updated to use new API
2. `tests/time_token_test.move` - Updated to use new API
3. `tests/integration_test.move` - Updated to use new API
4. `tests/timebank_test.move` - Updated to use new API

## Next Steps

1. **Compile and Test**: Run `aptos move compile` and `aptos move test` to verify all changes
2. **Check Downstream**: Search for any other modules that might call `token::initialize()` or `time_token::initialize()` and expect `Metadata` type
3. **Review Error Codes**: Ensure error handling is appropriate for production
4. **Documentation**: Update any external documentation that references the old API

## Key Takeaways

1. **Always use `Object<Metadata>`** for asset identification, not `address`
2. **Store refs (MintRef/BurnRef/TransferRef)** in resources, not capabilities
3. **Use object-based creation API** with `constructor_ref`
4. **Primary stores are auto-created** - no need to manually register before minting
5. **All FA operations require refs** - mint needs `MintRef`, burn needs `BurnRef`, withdraw needs `TransferRef`

