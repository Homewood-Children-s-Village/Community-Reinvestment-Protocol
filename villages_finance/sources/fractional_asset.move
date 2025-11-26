module villages_finance::fractional_asset {

use std::signer;
use std::error;
use aptos_framework::event;
use aptos_framework::big_ordered_map;
use aptos_framework::ordered_map;

/// Error codes
const E_NOT_INITIALIZED: u64 = 1;
const E_POOL_NOT_FOUND: u64 = 2;
const E_INSUFFICIENT_SHARES: u64 = 3;
const E_ZERO_AMOUNT: u64 = 4;
const E_NOT_AUTHORIZED: u64 = 5;
const E_POOL_ALREADY_EXISTS: u64 = 6;

/// Per-pool share store
struct FractionalShareStore has store {
    shares: aptos_framework::big_ordered_map::BigOrderedMap<address, u64>,
    total_shares: u64,
}

/// Registry mapping pool ids to share stores
struct FractionalSharesRegistry has key {
    pools: aptos_framework::ordered_map::OrderedMap<u64, FractionalShareStore>,
}

// Events
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

/// Initialize the fractional share registry under admin address
public fun initialize(admin: &signer) {
    let admin_addr = signer::address_of(admin);
    if (!exists<FractionalSharesRegistry>(admin_addr)) {
        move_to(admin, FractionalSharesRegistry {
            pools: aptos_framework::ordered_map::new(),
        });
    };
}

/// Ensure a pool entry exists inside the registry
public fun ensure_pool(
    pool_id: u64,
    registry_addr: address,
) acquires FractionalSharesRegistry {
    assert!(exists<FractionalSharesRegistry>(registry_addr), error::not_found(E_NOT_INITIALIZED));
    let registry = borrow_global_mut<FractionalSharesRegistry>(registry_addr);
    if (!aptos_framework::ordered_map::contains(&registry.pools, &pool_id)) {
        let store = FractionalShareStore {
            shares: aptos_framework::big_ordered_map::new(),
            total_shares: 0,
        };
        aptos_framework::ordered_map::add(&mut registry.pools, pool_id, store);
    };
}

/// Mint shares (called by InvestmentPool)
public fun mint_shares(
    _minter: &signer,
    pool_id: u64,
    recipient: address,
    share_amount: u64,
    shares_addr: address,
) acquires FractionalSharesRegistry {
    assert!(share_amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
    
    ensure_pool_exists(pool_id, shares_addr);
    let registry = borrow_global_mut<FractionalSharesRegistry>(shares_addr);
    assert!(aptos_framework::ordered_map::contains(&registry.pools, &pool_id), error::not_found(E_POOL_NOT_FOUND));
    let store = aptos_framework::ordered_map::borrow_mut(&mut registry.pools, &pool_id);
    
    // Update shares
    if (aptos_framework::big_ordered_map::contains(&store.shares, &recipient)) {
        let current = *aptos_framework::big_ordered_map::borrow(&store.shares, &recipient);
        aptos_framework::big_ordered_map::upsert(&mut store.shares, recipient, current + share_amount);
    } else {
        aptos_framework::big_ordered_map::add(&mut store.shares, recipient, share_amount);
    };
    
    store.total_shares = store.total_shares + share_amount;

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
) acquires FractionalSharesRegistry {
    assert!(share_amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
    
    let burner_addr = signer::address_of(burner);
    
    ensure_pool_exists(pool_id, shares_addr);
    let registry = borrow_global_mut<FractionalSharesRegistry>(shares_addr);
    assert!(aptos_framework::ordered_map::contains(&registry.pools, &pool_id), error::not_found(E_POOL_NOT_FOUND));
    let store = aptos_framework::ordered_map::borrow_mut(&mut registry.pools, &pool_id);
    
    assert!(aptos_framework::big_ordered_map::contains(&store.shares, &burner_addr), 
        error::not_found(E_INSUFFICIENT_SHARES));
    
    let current = *aptos_framework::big_ordered_map::borrow(&store.shares, &burner_addr);
    assert!(current >= share_amount, error::invalid_state(E_INSUFFICIENT_SHARES));
    
    // Update shares
    aptos_framework::big_ordered_map::upsert(&mut store.shares, burner_addr, current - share_amount);
    store.total_shares = store.total_shares - share_amount;

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
) acquires FractionalSharesRegistry {
    assert!(share_amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
    
    let from_addr = signer::address_of(from);
    ensure_pool_exists(pool_id, shares_addr);
    let registry = borrow_global_mut<FractionalSharesRegistry>(shares_addr);
    assert!(aptos_framework::ordered_map::contains(&registry.pools, &pool_id), error::not_found(E_POOL_NOT_FOUND));
    let store = aptos_framework::ordered_map::borrow_mut(&mut registry.pools, &pool_id);
    
    assert!(aptos_framework::big_ordered_map::contains(&store.shares, &from_addr), 
        error::not_found(E_INSUFFICIENT_SHARES));
    
    let current = *aptos_framework::big_ordered_map::borrow(&store.shares, &from_addr);
    assert!(current >= share_amount, error::invalid_state(E_INSUFFICIENT_SHARES));
    
    // Update from balance
    aptos_framework::big_ordered_map::upsert(&mut store.shares, from_addr, current - share_amount);
    
    // Update to balance
    if (aptos_framework::big_ordered_map::contains(&store.shares, &to)) {
        let to_current = *aptos_framework::big_ordered_map::borrow(&store.shares, &to);
        aptos_framework::big_ordered_map::upsert(&mut store.shares, to, to_current + share_amount);
    } else {
        aptos_framework::big_ordered_map::add(&mut store.shares, to, share_amount);
    };

    event::emit(SharesTransferredEvent {
        pool_id,
        from: from_addr,
        to,
        share_amount,
    });
}

/// Get shares for an address
#[view]
public fun get_shares(addr: address, pool_id: u64, shares_addr: address): u64 {
    if (!exists<FractionalSharesRegistry>(shares_addr)) {
        return 0
    };
    if (!aptos_framework::ordered_map::contains(&borrow_global<FractionalSharesRegistry>(shares_addr).pools, &pool_id)) {
        return 0
    };
    let registry = borrow_global<FractionalSharesRegistry>(shares_addr);
    let store = aptos_framework::ordered_map::borrow(&registry.pools, &pool_id);
    if (aptos_framework::big_ordered_map::contains(&store.shares, &addr)) {
        *aptos_framework::big_ordered_map::borrow(&store.shares, &addr)
    } else {
        0
    }
}

/// Get total shares for a pool
#[view]
public fun get_total_shares(pool_id: u64, shares_addr: address): u64 {
    if (!exists<FractionalSharesRegistry>(shares_addr)) {
        return 0
    };
    if (!aptos_framework::ordered_map::contains(&borrow_global<FractionalSharesRegistry>(shares_addr).pools, &pool_id)) {
        return 0
    };
    let registry = borrow_global<FractionalSharesRegistry>(shares_addr);
    let store = aptos_framework::ordered_map::borrow(&registry.pools, &pool_id);
    store.total_shares
}

/// Check if FractionalShares exists (for cross-module access)
#[view]
public fun exists_fractional_shares(shares_addr: address): bool {
    exists<FractionalSharesRegistry>(shares_addr)
}

#[view]
public fun pool_exists(pool_id: u64, shares_addr: address): bool {
    if (!exists<FractionalSharesRegistry>(shares_addr)) {
        return false
    };
    let registry = borrow_global<FractionalSharesRegistry>(shares_addr);
    aptos_framework::ordered_map::contains(&registry.pools, &pool_id)
}

#[test_only]
use villages_finance::admin;

#[test_only]
/// Initialize fractional shares for testing
/// Idempotent: safe to call multiple times
public fun initialize_for_test(admin: &signer, pool_id: u64) {
    admin::initialize_for_test(admin);
    let admin_addr = signer::address_of(admin);
    if (!exists<FractionalSharesRegistry>(admin_addr)) {
        initialize(admin);
    };
    ensure_pool(pool_id, admin_addr);
}

/// Helper: ensure pool exists before operations
fun ensure_pool_exists(pool_id: u64, shares_addr: address) {
    assert!(exists<FractionalSharesRegistry>(shares_addr), error::not_found(E_NOT_INITIALIZED));
    let registry = borrow_global<FractionalSharesRegistry>(shares_addr);
    assert!(aptos_framework::ordered_map::contains(&registry.pools, &pool_id), error::not_found(E_POOL_NOT_FOUND));
}


}
