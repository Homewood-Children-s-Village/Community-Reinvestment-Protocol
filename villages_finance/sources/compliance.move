module villages_finance::compliance {

use std::signer;
use std::error;
use std::vector;
use aptos_framework::event;
use aptos_framework::ordered_map;
use villages_finance::admin;

/// Error codes
const E_NOT_ADMIN: u64 = 1;
const E_ADDRESS_NOT_WHITELISTED: u64 = 2;
const E_ADDRESS_ALREADY_WHITELISTED: u64 = 3;

/// Compliance registry object storing whitelisted addresses
struct ComplianceRegistry has key {
    whitelist: aptos_framework::ordered_map::OrderedMap<address, bool>,
    counter: u64,
}

/// Events
#[event]
struct AddressWhitelistedEvent has drop, store {
    address: address,
    whitelisted_by: address,
}

#[event]
struct AddressRemovedEvent has drop, store {
    address: address,
    removed_by: address,
}

/// Initialize the compliance registry
public fun initialize(admin: &signer) {
    let admin_addr = signer::address_of(admin);
    assert!(!exists<ComplianceRegistry>(admin_addr), error::already_exists(1));
    
    move_to(admin, ComplianceRegistry {
        whitelist: aptos_framework::ordered_map::new(),
        counter: 0,
    });
}

/// Bulk whitelist addresses (admin only)
public entry fun bulk_whitelist_addresses(
    admin: signer,
    addresses: vector<address>,
    registry_addr: address,
) acquires ComplianceRegistry {
    let admin_addr = signer::address_of(&admin);
    
    // Validate registry exists
    assert!(exists<ComplianceRegistry>(registry_addr), error::invalid_argument(4));
    assert!(admin::has_admin_capability(admin_addr), error::permission_denied(E_NOT_ADMIN));
    
    let registry = borrow_global_mut<ComplianceRegistry>(registry_addr);
    let batch_size = vector::length(&addresses);
    assert!(batch_size > 0, error::invalid_argument(1));
    assert!(batch_size <= 100, error::invalid_argument(2)); // Limit batch size
    
    let success_count = 0;
    let failed_addresses = vector::empty<address>();
    let i = 0;
    
    while (i < batch_size) {
        let addr = *vector::borrow(&addresses, i);
        if (!aptos_framework::ordered_map::contains(&registry.whitelist, &addr)) {
            aptos_framework::ordered_map::add(&mut registry.whitelist, addr, true);
            registry.counter = registry.counter + 1;
            
            event::emit(AddressWhitelistedEvent {
                address: addr,
                whitelisted_by: admin_addr,
            });
            
            success_count = success_count + 1;
        } else {
            vector::push_back(&mut failed_addresses, addr);
        };
        i = i + 1;
    };
}

/// Bulk remove addresses from whitelist (admin only)
public entry fun bulk_remove_from_whitelist(
    admin: signer,
    addresses: vector<address>,
    registry_addr: address,
) acquires ComplianceRegistry {
    let admin_addr = signer::address_of(&admin);
    
    // Validate registry exists
    assert!(exists<ComplianceRegistry>(registry_addr), error::invalid_argument(4));
    assert!(admin::has_admin_capability(admin_addr), error::permission_denied(E_NOT_ADMIN));
    
    let registry = borrow_global_mut<ComplianceRegistry>(registry_addr);
    let batch_size = vector::length(&addresses);
    assert!(batch_size > 0, error::invalid_argument(1));
    assert!(batch_size <= 100, error::invalid_argument(2)); // Limit batch size
    
    let success_count = 0;
    let failed_addresses = vector::empty<address>();
    let i = 0;
    
    while (i < batch_size) {
        let addr = *vector::borrow(&addresses, i);
        if (aptos_framework::ordered_map::contains(&registry.whitelist, &addr)) {
            aptos_framework::ordered_map::remove(&mut registry.whitelist, &addr);
            
            event::emit(AddressRemovedEvent {
                address: addr,
                removed_by: admin_addr,
            });
            
            success_count = success_count + 1;
        } else {
            vector::push_back(&mut failed_addresses, addr);
        };
        i = i + 1;
    };
}

/// Whitelist an address (admin only, called after off-chain KYC verification)
public entry fun whitelist_address(
    admin: signer,
    addr: address,
) acquires ComplianceRegistry {
    let admin_addr = signer::address_of(&admin);
    assert!(exists<ComplianceRegistry>(admin_addr), error::not_found(1));
    
    let registry = borrow_global_mut<ComplianceRegistry>(admin_addr);
    assert!(!aptos_framework::ordered_map::contains(&registry.whitelist, &addr), 
        error::already_exists(E_ADDRESS_ALREADY_WHITELISTED));
    
    aptos_framework::ordered_map::add(&mut registry.whitelist, addr, true);
    registry.counter = registry.counter + 1;

    event::emit(AddressWhitelistedEvent {
        address: addr,
        whitelisted_by: admin_addr,
    });
}

/// Remove an address from whitelist (admin only)
public entry fun remove_from_whitelist(
    admin: signer,
    addr: address,
) acquires ComplianceRegistry {
    let admin_addr = signer::address_of(&admin);
    assert!(exists<ComplianceRegistry>(admin_addr), error::not_found(1));
    
    let registry = borrow_global_mut<ComplianceRegistry>(admin_addr);
    assert!(aptos_framework::ordered_map::contains(&registry.whitelist, &addr), 
        error::not_found(E_ADDRESS_NOT_WHITELISTED));
    
    aptos_framework::ordered_map::remove(&mut registry.whitelist, &addr);

    event::emit(AddressRemovedEvent {
        address: addr,
        removed_by: admin_addr,
    });
}

/// Check if an address is whitelisted (view function)
#[view]
public fun is_whitelisted(addr: address, registry_addr: address): bool {
    if (!exists<ComplianceRegistry>(registry_addr)) {
        return false
    };
    let registry = borrow_global<ComplianceRegistry>(registry_addr);
    aptos_framework::ordered_map::contains(&registry.whitelist, &addr)
}

/// List all whitelisted addresses (view function)
#[view]
public fun list_whitelisted_addresses(registry_addr: address): vector<address> {
    let result = vector::empty<address>();
    if (!exists<ComplianceRegistry>(registry_addr)) {
        return result
    };
    let registry = borrow_global<ComplianceRegistry>(registry_addr);
    aptos_framework::ordered_map::keys(&registry.whitelist)
}

/// Get total number of whitelisted addresses (view function)
#[view]
public fun get_whitelist_count(registry_addr: address): u64 {
    if (!exists<ComplianceRegistry>(registry_addr)) {
        return 0
    };
    let registry = borrow_global<ComplianceRegistry>(registry_addr);
    registry.counter
}

/// Check if ComplianceRegistry exists (view function for cross-module access)
#[view]
public fun exists_compliance_registry(registry_addr: address): bool {
    exists<ComplianceRegistry>(registry_addr)
}

#[test_only]
public fun initialize_for_test(admin: &signer) {
    initialize(admin);
}

}
