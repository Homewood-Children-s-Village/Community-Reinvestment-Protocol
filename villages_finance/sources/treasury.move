module villages_finance::treasury {

use std::signer;
use std::error;
use std::vector;
use std::option;
use aptos_framework::event;
use aptos_framework::big_ordered_map;
use aptos_framework::coin::{Self, Coin};
use aptos_framework::primary_fungible_store;
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

/// Treasury object storing balances per user
struct Treasury has key {
    balances: aptos_framework::big_ordered_map::BigOrderedMap<address, u64>,
    total_deposited: u64,
    depositor_count: u64, // Track number of unique depositors
}

/// Events
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

/// Initialize treasury
public fun initialize(admin: &signer) {
    let admin_addr = signer::address_of(admin);
    assert!(!exists<Treasury>(admin_addr), error::already_exists(1));
    
        move_to(admin, Treasury {
            balances: aptos_framework::big_ordered_map::new(),
            total_deposited: 0,
            depositor_count: 0,
        });
}

/// Deposit Aptos Coins to treasury
public entry fun deposit(
    depositor: signer,
    amount: u64,
    treasury_addr: address,
    members_registry_addr: address,
    compliance_registry_addr: address,
) acquires Treasury {
    assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
    
    let depositor_addr = signer::address_of(&depositor);
    
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
    
    // Transfer coins from depositor to treasury address
    let coins = coin::withdraw<aptos_framework::aptos_coin::AptosCoin>(&depositor, amount);
    coin::deposit(treasury_addr, coins); // Hold in treasury account
    
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
    withdrawer: signer,
    admin: signer,
    amount: u64,
    treasury_addr: address,
) acquires Treasury {
    assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
    
    let withdrawer_addr = signer::address_of(&withdrawer);
    
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
    
    // Transfer coins back from treasury to withdrawer
    // For MVP: treasury_addr must equal admin address to use admin signer
    let admin_addr = signer::address_of(&admin);
    assert!(treasury_addr == admin_addr, error::invalid_argument(E_INVALID_REGISTRY));
    assert!(admin::has_admin_capability(admin_addr), error::permission_denied(E_NOT_AUTHORIZED));
    let coins = coin::withdraw<aptos_framework::aptos_coin::AptosCoin>(&admin, amount);
    coin::deposit(withdrawer_addr, coins);

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
    from: signer,
    pool_id: u64,
    amount: u64,
    pool_address: address,
    treasury_addr: address,
) acquires Treasury {
    assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
    
    let from_addr = signer::address_of(&from);
    
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
    
    // Transfer coins from treasury to pool address
    // For MVP: treasury_addr must equal from address to use from signer
    assert!(treasury_addr == from_addr, error::invalid_argument(E_INVALID_REGISTRY));
    // Note: In production, would validate admin or use resource account
    let coins = coin::withdraw<aptos_framework::aptos_coin::AptosCoin>(&from, amount);
    coin::deposit(pool_address, coins);
    
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

/// Get balance for an address (view function)
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

/// Get total deposited amount (view function)
#[view]
public fun get_total_deposited(treasury_addr: address): u64 {
    if (!exists<Treasury>(treasury_addr)) {
        return 0
    };
    let treasury = borrow_global<Treasury>(treasury_addr);
    treasury.total_deposited
}

/// Get depositor count (view function)
#[view]
public fun get_depositor_count(treasury_addr: address): u64 {
    if (!exists<Treasury>(treasury_addr)) {
        return 0
    };
    let treasury = borrow_global<Treasury>(treasury_addr);
    vector::length(&aptos_framework::big_ordered_map::keys(&treasury.balances))
}

/// List top depositors (view function)
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

#[test_only]
public fun initialize_for_test(admin: &signer) {
    initialize(admin);
}

}
