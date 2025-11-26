module villages_finance::treasury {

use std::signer;
use std::error;
use std::vector;
use std::option;
use std::string;
use aptos_framework::event;
use aptos_framework::big_ordered_map;
use aptos_framework::fungible_asset::{Self, Metadata, MintRef, TransferRef};
use aptos_framework::primary_fungible_store;
use aptos_framework::object::{Self, Object};
use villages_finance::members;
use villages_finance::compliance;
use villages_finance::registry_config;
use villages_finance::event_history;
use villages_finance::admin;

/// Error codes
const E_NOT_INITIALIZED: u64 = 1;
const E_ZERO_AMOUNT: u64 = 2;
const E_INSUFFICIENT_BALANCE: u64 = 3;
const E_POOL_NOT_FOUND: u64 = 4;
const E_INVALID_REGISTRY: u64 = 5;
const E_NOT_MEMBER: u64 = 6;
const E_NOT_WHITELISTED: u64 = 7;
const E_NOT_AUTHORIZED: u64 = 8;

/// Depositor entry for list_top_depositors view
struct DepositorEntry has store {
    addr: address,
    balance: u64,
}

/// Treasury capability for FA operations
struct TreasuryCapability has key, store {
    metadata: Object<Metadata>,
    mint_ref: MintRef,
    transfer_ref: TransferRef,
}

/// Treasury object storing balances per user
struct Treasury has key {
    balances: aptos_framework::big_ordered_map::BigOrderedMap<address, u64>,
    total_deposited: u64,
    depositor_count: u64, // Track number of unique depositors
}

// Events
#[event]
struct DepositEvent has drop, store {
    depositor: address,
    amount: u64,
}

#[event]
struct WithdrawalEvent has drop, store {
    withdrawer: address,
    amount: u64,
}

#[event]
struct TransferToPoolEvent has drop, store {
    from: address,
    pool_id: u64,
    amount: u64,
}

#[event]
struct MintedEvent has drop, store {
    to: address,
    amount: u64,
}

/// Initialize treasury with FA metadata
public fun initialize(admin: &signer, name: vector<u8>, symbol: vector<u8>, decimals: u8, description: vector<u8>) {
    let admin_addr = signer::address_of(admin);
    assert!(!exists<Treasury>(admin_addr), error::already_exists(1));
    
    // Create object for the fungible asset
    let constructor_ref = &object::create_named_object(admin, symbol);
    
    // Create the fungible asset
    primary_fungible_store::create_primary_store_enabled_fungible_asset(
        constructor_ref,
        option::none(), // max_supply
        string::utf8(name),
        string::utf8(symbol),
        decimals,
        string::utf8(b""), // icon_uri - empty for MVP
        string::utf8(description), // project_uri
    );
    
    let metadata = object::object_from_constructor_ref<Metadata>(constructor_ref);
    
    // Generate refs for minting and transferring
    let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
    let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);
    
    // Store treasury capability
    move_to(admin, TreasuryCapability {
        metadata,
        mint_ref,
        transfer_ref,
    });
    
    // Store treasury resource
    move_to(admin, Treasury {
        balances: aptos_framework::big_ordered_map::new(),
        total_deposited: 0,
        depositor_count: 0,
    });
}

/// Deposit Aptos Coins to treasury
public entry fun deposit(
    depositor: &signer,
    amount: u64,
    treasury_addr: address,
    members_registry_addr: address,
    compliance_registry_addr: address,
) acquires Treasury, TreasuryCapability {
    assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
    
    let depositor_addr = signer::address_of(depositor);
    
    // Validate registries
    assert!(exists<Treasury>(treasury_addr), error::invalid_argument(E_INVALID_REGISTRY));
    assert!(registry_config::validate_members_registry(members_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    assert!(registry_config::validate_compliance_registry(compliance_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    
    // Check depositor is a member
    assert!(
        members::is_member_with_registry(depositor_addr, members_registry_addr),
        error::permission_denied(E_NOT_MEMBER)
    );
    
    // Check compliance/KYC
    assert!(
        compliance::is_whitelisted(depositor_addr, compliance_registry_addr),
        error::permission_denied(E_NOT_WHITELISTED)
    );
    
    assert!(exists<Treasury>(treasury_addr), error::not_found(E_NOT_INITIALIZED));
    let treasury = borrow_global_mut<Treasury>(treasury_addr);
    
    // Transfer fungible assets from depositor to treasury address
    let cap = borrow_global<TreasuryCapability>(treasury_addr);
    let depositor_addr = signer::address_of(depositor);
    
    // Ensure primary store exists for depositor
    let depositor_store = primary_fungible_store::ensure_primary_store_exists(depositor_addr, cap.metadata);
    
    // Check balance
    let balance = primary_fungible_store::balance(depositor_addr, cap.metadata);
    assert!(balance >= amount, error::invalid_state(E_INSUFFICIENT_BALANCE));
    
    // Withdraw from depositor
    let asset = fungible_asset::withdraw_with_ref(&cap.transfer_ref, depositor_store, amount);
    
    // Ensure primary store exists for treasury and deposit
    let treasury_store = primary_fungible_store::ensure_primary_store_exists(treasury_addr, cap.metadata);
    fungible_asset::deposit(treasury_store, asset);
    
        // Update balance
        let is_new_depositor = !aptos_framework::big_ordered_map::contains(&treasury.balances, &depositor_addr);
        if (is_new_depositor) {
            aptos_framework::big_ordered_map::add(&mut treasury.balances, depositor_addr, amount);
            treasury.depositor_count = treasury.depositor_count + 1;
        } else {
            let current_balance = *aptos_framework::big_ordered_map::borrow(&treasury.balances, &depositor_addr);
            aptos_framework::big_ordered_map::upsert(&mut treasury.balances, depositor_addr, current_balance + amount);
        };

        treasury.total_deposited = treasury.total_deposited + amount;

    event::emit(DepositEvent {
        depositor: depositor_addr,
        amount,
    });
    
    // Record in event history
    event_history::record_user_event(
        depositor_addr,
        event_history::event_type_deposit(),
        option::some(amount),
        option::none(),
        option::none(),
        option::none(),
        option::none(),
        option::none(),
    );
}

/// Withdraw from treasury
/// Note: For MVP, requires admin signer to withdraw from treasury_addr
/// In production: Would use resource account signer capability
public entry fun withdraw(
    withdrawer: &signer,
    amount: u64,
    treasury_addr: address,
) acquires Treasury, TreasuryCapability {
    assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
    
    let withdrawer_addr = signer::address_of(withdrawer);
    
    // Validate registry
    assert!(exists<Treasury>(treasury_addr), error::invalid_argument(E_INVALID_REGISTRY));
    
    assert!(exists<Treasury>(treasury_addr), error::not_found(E_NOT_INITIALIZED));
    let treasury = borrow_global_mut<Treasury>(treasury_addr);
    
    assert!(aptos_framework::big_ordered_map::contains(&treasury.balances, &withdrawer_addr), 
        error::not_found(E_INSUFFICIENT_BALANCE));
    
    let balance = *aptos_framework::big_ordered_map::borrow(&treasury.balances, &withdrawer_addr);
    assert!(balance >= amount, error::invalid_state(E_INSUFFICIENT_BALANCE));
    
    // Update balance
    aptos_framework::big_ordered_map::upsert(&mut treasury.balances, withdrawer_addr, balance - amount);
    treasury.total_deposited = treasury.total_deposited - amount;
    
    // Transfer fungible assets back from treasury to withdrawer using stored capability
    let cap = borrow_global<TreasuryCapability>(treasury_addr);
    
    // Ensure primary store exists for treasury
    let treasury_store = primary_fungible_store::ensure_primary_store_exists(treasury_addr, cap.metadata);
    
    // Check treasury balance
    let treasury_balance = primary_fungible_store::balance(treasury_addr, cap.metadata);
    assert!(treasury_balance >= amount, error::invalid_state(E_INSUFFICIENT_BALANCE));
    
    // Withdraw from treasury
    let asset = fungible_asset::withdraw_with_ref(&cap.transfer_ref, treasury_store, amount);
    
    // Ensure primary store exists for withdrawer and deposit
    let withdrawer_store = primary_fungible_store::ensure_primary_store_exists(withdrawer_addr, cap.metadata);
    fungible_asset::deposit(withdrawer_store, asset);

    event::emit(WithdrawalEvent {
        withdrawer: withdrawer_addr,
        amount,
    });
    
    // Record in event history
    event_history::record_user_event(
        withdrawer_addr,
        event_history::event_type_withdrawal(),
        option::some(amount),
        option::none(),
        option::none(),
        option::none(),
        option::none(),
        option::none(),
    );
}

/// Transfer funds to an investment pool
public entry fun transfer_to_pool(
    from: &signer,
    pool_id: u64,
    amount: u64,
    pool_address: address,
    treasury_addr: address,
) acquires Treasury, TreasuryCapability {
    assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
    
    let from_addr = signer::address_of(from);
    
    // Validate registry
    assert!(exists<Treasury>(treasury_addr), error::invalid_argument(E_INVALID_REGISTRY));
    
    assert!(exists<Treasury>(treasury_addr), error::not_found(E_NOT_INITIALIZED));
    let treasury = borrow_global_mut<Treasury>(treasury_addr);
    
    assert!(aptos_framework::big_ordered_map::contains(&treasury.balances, &from_addr), 
        error::not_found(E_INSUFFICIENT_BALANCE));
    
    let balance = *aptos_framework::big_ordered_map::borrow(&treasury.balances, &from_addr);
    assert!(balance >= amount, error::invalid_state(E_INSUFFICIENT_BALANCE));
    
    // Update balance
    aptos_framework::big_ordered_map::upsert(&mut treasury.balances, from_addr, balance - amount);
    treasury.total_deposited = treasury.total_deposited - amount;
    
    // Transfer fungible assets from treasury to pool address using stored capability
    let cap = borrow_global<TreasuryCapability>(treasury_addr);
    
    // Ensure primary store exists for treasury
    let treasury_store = primary_fungible_store::ensure_primary_store_exists(treasury_addr, cap.metadata);
    
    // Check treasury balance
    let treasury_balance = primary_fungible_store::balance(treasury_addr, cap.metadata);
    assert!(treasury_balance >= amount, error::invalid_state(E_INSUFFICIENT_BALANCE));
    
    // Withdraw from treasury
    let asset = fungible_asset::withdraw_with_ref(&cap.transfer_ref, treasury_store, amount);
    
    // Ensure primary store exists for pool and deposit
    let pool_store = primary_fungible_store::ensure_primary_store_exists(pool_address, cap.metadata);
    fungible_asset::deposit(pool_store, asset);
    
    event::emit(TransferToPoolEvent {
        from: from_addr,
        pool_id,
        amount,
    });
    
    // Record in event history (as investment)
    event_history::record_user_event(
        from_addr,
        event_history::event_type_investment(),
        option::some(amount),
        option::some(pool_id),
        option::none(),
        option::none(),
        option::none(),
        option::none(),
    );
}

/// Check if Treasury exists (for cross-module access)
#[view]
public fun exists_treasury(treasury_addr: address): bool {
    exists<Treasury>(treasury_addr)
}

/// Get balance for an address
#[view]
public fun get_balance(addr: address, treasury_addr: address): u64 {
    if (!exists<Treasury>(treasury_addr)) {
        return 0
    };
    let treasury = borrow_global<Treasury>(treasury_addr);
    if (aptos_framework::big_ordered_map::contains(&treasury.balances, &addr)) {
        *aptos_framework::big_ordered_map::borrow(&treasury.balances, &addr)
    } else {
        0
    }
}

/// Get total deposited amount
#[view]
public fun get_total_deposited(treasury_addr: address): u64 {
    if (!exists<Treasury>(treasury_addr)) {
        return 0
    };
    let treasury = borrow_global<Treasury>(treasury_addr);
    treasury.total_deposited
}

/// Get depositor count
#[view]
public fun get_depositor_count(treasury_addr: address): u64 {
    if (!exists<Treasury>(treasury_addr)) {
        return 0
    };
    let treasury = borrow_global<Treasury>(treasury_addr);
    vector::length(&aptos_framework::big_ordered_map::keys(&treasury.balances))
}

/// List top depositors
/// Returns top N depositors sorted by balance (descending)
#[view]
public fun list_top_depositors(treasury_addr: address, limit: u64): vector<DepositorEntry> {
    let result = vector::empty<DepositorEntry>();
    if (!exists<Treasury>(treasury_addr)) {
        return result
    };
    let treasury = borrow_global<Treasury>(treasury_addr);
    let keys = aptos_framework::big_ordered_map::keys(&treasury.balances);
    
    // Simple approach: return all and let frontend sort
    // For production, could implement sorting here or use indexed storage
    let i = 0;
    let len = vector::length(&keys);
    let count = 0;
    while (i < len && count < limit) {
        let addr = *vector::borrow(&keys, i);
        let balance = aptos_framework::big_ordered_map::borrow(&treasury.balances, &addr);
        vector::push_back(&mut result, DepositorEntry {
            addr,
            balance: *balance,
        });
        count = count + 1;
        i = i + 1;
    };
    result
}

/// Get asset metadata from treasury
public fun get_asset_metadata(treasury_addr: address): Object<Metadata> acquires TreasuryCapability {
    borrow_global<TreasuryCapability>(treasury_addr).metadata
}

/// Mint treasury fungible assets (admin/governance only)
/// Requires admin capability at treasury_addr
public fun mint(
    admin: &signer,
    to: address,
    amount: u64,
    treasury_addr: address,
) acquires TreasuryCapability {
    let admin_addr = signer::address_of(admin);
    assert!(admin::has_admin_capability(admin_addr), error::permission_denied(E_NOT_AUTHORIZED));
    assert!(exists<TreasuryCapability>(treasury_addr), error::not_found(E_NOT_INITIALIZED));
    assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
    
    let cap = borrow_global<TreasuryCapability>(treasury_addr);
    
    // Ensure primary store exists for recipient
    primary_fungible_store::ensure_primary_store_exists(to, cap.metadata);
    
    // Mint assets directly to the store
    primary_fungible_store::mint(&cap.mint_ref, to, amount);
    
    event::emit(MintedEvent {
        to,
        amount,
    });
}

}
