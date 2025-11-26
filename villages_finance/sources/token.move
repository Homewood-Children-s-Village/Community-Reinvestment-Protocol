module villages_finance::token {

use std::signer;
use std::error;
use std::string;
use std::option;
use aptos_framework::event;
use aptos_framework::fungible_asset::{Self, FungibleAsset, Metadata, MintRef, BurnRef, TransferRef};
use aptos_framework::primary_fungible_store;
use aptos_framework::object::{Self, Object, ConstructorRef};
use aptos_framework::coin;

/// Error codes
const E_NOT_ADMIN: u64 = 1;
const E_ZERO_AMOUNT: u64 = 2;
const E_INSUFFICIENT_BALANCE: u64 = 3;

/// Mint capability stored in admin module
struct MintCapability has key, store {
    metadata: Object<Metadata>,
    mint_ref: MintRef,
    burn_ref: BurnRef,
    transfer_ref: TransferRef,
}

// Events
#[event]
struct MintedEvent has drop, store {
    to: address,
    amount: u64,
}

#[event]
struct BurnedEvent has drop, store {
    from: address,
    amount: u64,
}

/// Initialize the community token
/// Returns only the metadata object. MintCapability is stored at admin address.
public fun initialize(
    admin: &signer,
    name: string::String,
    symbol: string::String,
    decimals: u8,
    description: string::String,
    icon_uri: string::String,
): Object<Metadata> {
    // Create object for the fungible asset
    // Convert string to bytes for object creation (object::create_named_object requires vector<u8>)
    // Note: Dereferencing string::bytes() is necessary as it returns &vector<u8> but we need vector<u8>
    let symbol_bytes = *string::bytes(&symbol);
    let constructor_ref = &object::create_named_object(admin, symbol_bytes);
    let metadata_signer = &object::generate_signer(constructor_ref);
    
    // Create the fungible asset
    primary_fungible_store::create_primary_store_enabled_fungible_asset(
        constructor_ref,
        option::none(), // max_supply
        name,
        symbol,
        decimals,
        icon_uri,
        description,
    );
    
    let metadata = object::object_from_constructor_ref<Metadata>(constructor_ref);
    
    // Generate refs for minting, burning, and transferring
    let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
    let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
    let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);
    
    // Store mint capability struct
    let mint_cap = MintCapability {
        metadata,
        mint_ref,
        burn_ref,
        transfer_ref,
    };
    move_to(admin, mint_cap);
    
    metadata
}

/// Mint tokens (admin/governance only)
public fun mint(
    admin: &signer,
    to: address,
    amount: u64,
    admin_addr: address,
) acquires MintCapability {
    let admin_addr_check = signer::address_of(admin);
    assert!(exists<MintCapability>(admin_addr), error::permission_denied(E_NOT_ADMIN));
    assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
    
    let cap = borrow_global<MintCapability>(admin_addr);
    
    // Ensure primary store exists for recipient (mint will create it if needed)
    primary_fungible_store::ensure_primary_store_exists(to, cap.metadata);
    
    // Mint assets directly to the store
    primary_fungible_store::mint(&cap.mint_ref, to, amount);
    
    event::emit(MintedEvent {
        to,
        amount,
    });
}

/// Withdraw assets from primary store (helper for burn)
public fun withdraw(
    withdrawer: &signer,
    amount: u64,
    admin_addr: address,
): FungibleAsset acquires MintCapability {
    let withdrawer_addr = signer::address_of(withdrawer);
    assert!(exists<MintCapability>(admin_addr), error::permission_denied(E_NOT_ADMIN));
    assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
    
    let cap = borrow_global<MintCapability>(admin_addr);
    let store = primary_fungible_store::ensure_primary_store_exists(withdrawer_addr, cap.metadata);
    
    // Check balance
    let balance = primary_fungible_store::balance(withdrawer_addr, cap.metadata);
    assert!(balance >= amount, error::invalid_state(E_INSUFFICIENT_BALANCE));
    
    fungible_asset::withdraw_with_ref(&cap.transfer_ref, store, amount)
}

/// Burn tokens (admin/governance only)
public fun burn(
    admin: &signer,
    asset: FungibleAsset,
    admin_addr: address,
): u64 acquires MintCapability {
    let admin_addr_check = signer::address_of(admin);
    assert!(exists<MintCapability>(admin_addr), error::permission_denied(E_NOT_ADMIN));
    
    let amount = fungible_asset::amount(&asset);
    assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
    
    let cap = borrow_global<MintCapability>(admin_addr);
    fungible_asset::burn(&cap.burn_ref, asset);
    
    event::emit(BurnedEvent {
        from: admin_addr_check,
        amount,
    });
    
    amount
}

/// Get mint capability metadata object
public fun get_metadata(admin_addr: address): Object<Metadata> acquires MintCapability {
    let cap = borrow_global<MintCapability>(admin_addr);
    cap.metadata
}

/// Get asset type address from metadata (for backward compatibility)
public fun get_asset_type(admin_addr: address): address acquires MintCapability {
    object::object_address(&get_metadata(admin_addr))
}

/// Get balance for an address (for governance voting)
#[view]
public fun get_balance(addr: address, admin_addr: address): u64 acquires MintCapability {
    if (!exists<MintCapability>(admin_addr)) {
        return 0
    };
    let metadata = get_metadata(admin_addr);
    primary_fungible_store::balance(addr, metadata)
}

/// Get total supply
#[view]
public fun get_total_supply(admin_addr: address): u64 acquires MintCapability {
    if (!exists<MintCapability>(admin_addr)) {
        return 0
    };
    let metadata = get_metadata(admin_addr);
    let supply_opt = fungible_asset::supply(metadata);
    if (option::is_some(&supply_opt)) {
        let supply_u128 = *option::borrow(&supply_opt);
        // Cast u128 to u64 (may truncate for very large supplies)
        (supply_u128 as u64)
    } else {
        0
    }
}

#[view]
public fun is_initialized(admin_addr: address): bool {
    exists<MintCapability>(admin_addr)
}

/// Entry function to mint tokens
public entry fun mint_entry(
    admin: &signer,
    to: address,
    amount: u64,
    admin_addr: address,
) acquires MintCapability {
    mint(admin, to, amount, admin_addr);
}

/// Entry function to burn tokens
/// Withdraws the specified amount from the caller's primary store and burns it
public entry fun burn_entry(
    admin: &signer,
    amount: u64,
    admin_addr: address,
) acquires MintCapability {
    let asset = withdraw(admin, amount, admin_addr);
    burn(admin, asset, admin_addr);
}

#[test_only]
use villages_finance::admin;

#[test_only]
public fun initialize_for_test(
    admin: &signer,
    name: string::String,
    symbol: string::String,
): Object<Metadata> {
    let description = string::utf8(b"Community token for The Villages");
    let icon_uri = string::utf8(b"https://example.com/icon.png");
    initialize(admin, name, symbol, 8, description, icon_uri)
}

}
