module villages_finance::fractional_asset {

use std::signer;
use std::error;
use aptos_framework::event;
use aptos_framework::big_ordered_map;

/// Error codes
const E_NOT_INITIALIZED: u64 = 1;
const E_POOL_NOT_FOUND: u64 = 2;
const E_INSUFFICIENT_SHARES: u64 = 3;
const E_ZERO_AMOUNT: u64 = 4;
const E_NOT_AUTHORIZED: u64 = 5;

/// Fractional shares object per pool
struct FractionalShares has key {
    pool_id: u64,
    shares: aptos_framework::big_ordered_map::BigOrderedMap<address, u64>,
    total_shares: u64,
}

/// Events
#[event]
struct SharesMintedEvent has drop, store {
    pool_id: u64,
    recipient: address,
    share_amount: u64,
}

#[event]
struct SharesBurnedEvent has drop, store {
    pool_id: u64,
    from: address,
    share_amount: u64,
}

#[event]
struct SharesTransferredEvent has drop, store {
    pool_id: u64,
    from: address,
    to: address,
    share_amount: u64,
}

/// Initialize fractional shares for a pool
public fun initialize(
    admin: &signer,
    pool_id: u64,
) {
    let admin_addr = signer::address_of(admin);
    assert!(!exists<FractionalShares>(admin_addr), error::already_exists(1));
    
    move_to(admin, FractionalShares {
        pool_id,
        shares: aptos_framework::big_ordered_map::new(),
        total_shares: 0,
    });
}

/// Mint shares (called by InvestmentPool)
public fun mint_shares(
    minter: &signer,
    pool_id: u64,
    recipient: address,
    share_amount: u64,
    shares_addr: address,
) acquires FractionalShares {
    assert!(share_amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
    
    // Initialize fractional shares if needed
    if (!exists<FractionalShares>(shares_addr)) {
        // This should be initialized when pool is created
        abort error::not_found(E_NOT_INITIALIZED)
    };
    
    let shares_obj = borrow_global_mut<FractionalShares>(shares_addr);
    assert!(shares_obj.pool_id == pool_id, error::invalid_argument(E_POOL_NOT_FOUND));
    
    // Update shares
    if (aptos_framework::big_ordered_map::contains(&shares_obj.shares, &recipient)) {
        let current = *aptos_framework::big_ordered_map::borrow(&shares_obj.shares, &recipient);
        aptos_framework::big_ordered_map::upsert(&mut shares_obj.shares, recipient, current + share_amount);
    } else {
        aptos_framework::big_ordered_map::add(&mut shares_obj.shares, recipient, share_amount);
    };
    
    shares_obj.total_shares = shares_obj.total_shares + share_amount;

    event::emit(SharesMintedEvent {
        pool_id,
        recipient,
        share_amount,
    });
}

/// Burn shares (for redemption)
public fun burn_shares(
    burner: &signer,
    pool_id: u64,
    share_amount: u64,
    shares_addr: address,
) acquires FractionalShares {
    assert!(share_amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
    
    let burner_addr = signer::address_of(burner);
    
    assert!(exists<FractionalShares>(shares_addr), error::not_found(E_NOT_INITIALIZED));
    let shares_obj = borrow_global_mut<FractionalShares>(shares_addr);
    assert!(shares_obj.pool_id == pool_id, error::invalid_argument(E_POOL_NOT_FOUND));
    
    assert!(aptos_framework::big_ordered_map::contains(&shares_obj.shares, &burner_addr), 
        error::not_found(E_INSUFFICIENT_SHARES));
    
    let current = *aptos_framework::big_ordered_map::borrow(&shares_obj.shares, &burner_addr);
    assert!(current >= share_amount, error::invalid_state(E_INSUFFICIENT_SHARES));
    
    // Update shares
    aptos_framework::big_ordered_map::upsert(&mut shares_obj.shares, burner_addr, current - share_amount);
    shares_obj.total_shares = shares_obj.total_shares - share_amount;

    event::emit(SharesBurnedEvent {
        pool_id,
        from: burner_addr,
        share_amount,
    });
}

/// Transfer shares (restricted - only within approved flows)
public entry fun transfer_shares(
    from: &signer,
    pool_id: u64,
    to: address,
    share_amount: u64,
    shares_addr: address,
) acquires FractionalShares {
    assert!(share_amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
    
    let from_addr = signer::address_of(from);
    assert!(exists<FractionalShares>(shares_addr), error::not_found(E_NOT_INITIALIZED));
    let shares_obj = borrow_global_mut<FractionalShares>(shares_addr);
    assert!(shares_obj.pool_id == pool_id, error::invalid_argument(E_POOL_NOT_FOUND));
    
    assert!(aptos_framework::big_ordered_map::contains(&shares_obj.shares, &from_addr), 
        error::not_found(E_INSUFFICIENT_SHARES));
    
    let current = *aptos_framework::big_ordered_map::borrow(&shares_obj.shares, &from_addr);
    assert!(current >= share_amount, error::invalid_state(E_INSUFFICIENT_SHARES));
    
    // Update from balance
    aptos_framework::big_ordered_map::upsert(&mut shares_obj.shares, from_addr, current - share_amount);
    
    // Update to balance
    if (aptos_framework::big_ordered_map::contains(&shares_obj.shares, &to)) {
        let to_current = *aptos_framework::big_ordered_map::borrow(&shares_obj.shares, &to);
        aptos_framework::big_ordered_map::upsert(&mut shares_obj.shares, to, to_current + share_amount);
    } else {
        aptos_framework::big_ordered_map::add(&mut shares_obj.shares, to, share_amount);
    };

    event::emit(SharesTransferredEvent {
        pool_id,
        from: from_addr,
        to,
        share_amount,
    });
}

/// Get shares for an address (view function)
#[view]
public fun get_shares(addr: address, pool_id: u64, shares_addr: address): u64 {
    if (!exists<FractionalShares>(shares_addr)) {
        return 0
    };
    let shares_obj = borrow_global<FractionalShares>(shares_addr);
    if (shares_obj.pool_id != pool_id) {
        return 0
    };
    if (aptos_framework::big_ordered_map::contains(&shares_obj.shares, &addr)) {
        *aptos_framework::big_ordered_map::borrow(&shares_obj.shares, &addr)
    } else {
        0
    }
}

/// Get total shares for a pool (view function)
#[view]
public fun get_total_shares(pool_id: u64, shares_addr: address): u64 {
    if (!exists<FractionalShares>(shares_addr)) {
        return 0
    };
    let shares_obj = borrow_global<FractionalShares>(shares_addr);
    if (shares_obj.pool_id != pool_id) {
        return 0
    };
    shares_obj.total_shares
}

/// Check if FractionalShares exists (view function for cross-module access)
#[view]
public fun exists_fractional_shares(shares_addr: address): bool {
    exists<FractionalShares>(shares_addr)
}

#[test_only]
use villages_finance::admin;

#[test_only]
public fun initialize_for_test(admin: &signer, pool_id: u64) {
    admin::initialize_for_test(admin);
    initialize(admin, pool_id);
}

}
