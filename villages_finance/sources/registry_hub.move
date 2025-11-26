module villages_finance::registry_hub {

use std::signer;
use std::error;
use aptos_framework::ordered_map;

/// Error codes
const E_ALREADY_INITIALIZED: u64 = 1;
const E_COMMUNITY_EXISTS: u64 = 2;
const E_COMMUNITY_NOT_FOUND: u64 = 3;
const E_NOT_AUTHORIZED: u64 = 4;

/// Configuration for a single community
public struct CommunityConfig has copy, drop, store {
    members_registry_addr: address,
    compliance_registry_addr: address,
    treasury_addr: address,
    pool_registry_addr: address,
    fractional_shares_addr: address,
    governance_addr: address,
    token_admin_addr: address,
    time_token_admin_addr: address,
}

/// Registry hub storing all community configs
struct RegistryHub has key {
    /// Owner of this hub
    admin: address,
    communities: aptos_framework::ordered_map::OrderedMap<u64, CommunityConfig>,
}

/// Initialize the hub under the caller's address
public entry fun initialize(admin: &signer) {
    let admin_addr = signer::address_of(admin);
    assert!(!exists<RegistryHub>(admin_addr), error::already_exists(E_ALREADY_INITIALIZED));
    move_to(admin, RegistryHub {
        admin: admin_addr,
        communities: aptos_framework::ordered_map::new(),
    });
}

/// Register a new community configuration
public entry fun register_community(
    admin: &signer,
    hub_addr: address,
    community_id: u64,
    members_registry_addr: address,
    compliance_registry_addr: address,
    treasury_addr: address,
    pool_registry_addr: address,
    fractional_shares_addr: address,
    governance_addr: address,
    token_admin_addr: address,
    time_token_admin_addr: address,
) acquires RegistryHub {
    assert!(exists<RegistryHub>(hub_addr), error::not_found(E_COMMUNITY_NOT_FOUND));
    let hub = borrow_global_mut<RegistryHub>(hub_addr);
    let admin_addr = signer::address_of(admin);
    assert!(hub.admin == admin_addr, error::permission_denied(E_NOT_AUTHORIZED));
    assert!(!aptos_framework::ordered_map::contains(&hub.communities, &community_id), error::already_exists(E_COMMUNITY_EXISTS));
    let config = CommunityConfig {
        members_registry_addr,
        compliance_registry_addr,
        treasury_addr,
        pool_registry_addr,
        fractional_shares_addr,
        governance_addr,
        token_admin_addr,
        time_token_admin_addr,
    };
    aptos_framework::ordered_map::add(&mut hub.communities, community_id, config);
}

/// Update an existing community configuration
public entry fun update_community(
    admin: &signer,
    hub_addr: address,
    community_id: u64,
    new_members_registry_addr: address,
    new_compliance_registry_addr: address,
    new_treasury_addr: address,
    new_pool_registry_addr: address,
    new_fractional_shares_addr: address,
    new_governance_addr: address,
    new_token_admin_addr: address,
    new_time_token_admin_addr: address,
) acquires RegistryHub {
    assert!(exists<RegistryHub>(hub_addr), error::not_found(E_COMMUNITY_NOT_FOUND));
    let hub = borrow_global_mut<RegistryHub>(hub_addr);
    let admin_addr = signer::address_of(admin);
    assert!(hub.admin == admin_addr, error::permission_denied(E_NOT_AUTHORIZED));
    assert!(aptos_framework::ordered_map::contains(&hub.communities, &community_id), error::not_found(E_COMMUNITY_NOT_FOUND));
    let config = aptos_framework::ordered_map::borrow_mut(&mut hub.communities, &community_id);
    config.members_registry_addr = new_members_registry_addr;
    config.compliance_registry_addr = new_compliance_registry_addr;
    config.treasury_addr = new_treasury_addr;
    config.pool_registry_addr = new_pool_registry_addr;
    config.fractional_shares_addr = new_fractional_shares_addr;
    config.governance_addr = new_governance_addr;
    config.token_admin_addr = new_token_admin_addr;
    config.time_token_admin_addr = new_time_token_admin_addr;
}

/// View: get full community config
#[view]
public fun get_community_config(hub_addr: address, community_id: u64): CommunityConfig {
    assert!(exists<RegistryHub>(hub_addr), error::not_found(E_COMMUNITY_NOT_FOUND));
    let hub = borrow_global<RegistryHub>(hub_addr);
    assert!(aptos_framework::ordered_map::contains(&hub.communities, &community_id), error::not_found(E_COMMUNITY_NOT_FOUND));
    *aptos_framework::ordered_map::borrow(&hub.communities, &community_id)
}

/// View helpers for individual addresses
#[view]
public fun members_registry_addr(hub_addr: address, community_id: u64): address {
    let config = get_community_config(hub_addr, community_id);
    config.members_registry_addr
}

#[view]
public fun compliance_registry_addr(hub_addr: address, community_id: u64): address {
    let config = get_community_config(hub_addr, community_id);
    config.compliance_registry_addr
}

#[view]
public fun treasury_addr(hub_addr: address, community_id: u64): address {
    let config = get_community_config(hub_addr, community_id);
    config.treasury_addr
}

#[view]
public fun pool_registry_addr(hub_addr: address, community_id: u64): address {
    let config = get_community_config(hub_addr, community_id);
    config.pool_registry_addr
}

#[view]
public fun fractional_shares_addr(hub_addr: address, community_id: u64): address {
    let config = get_community_config(hub_addr, community_id);
    config.fractional_shares_addr
}

#[view]
public fun governance_addr(hub_addr: address, community_id: u64): address {
    let config = get_community_config(hub_addr, community_id);
    config.governance_addr
}

#[view]
public fun token_admin_addr(hub_addr: address, community_id: u64): address {
    let config = get_community_config(hub_addr, community_id);
    config.token_admin_addr
}

#[view]
public fun time_token_admin_addr(hub_addr: address, community_id: u64): address {
    let config = get_community_config(hub_addr, community_id);
    config.time_token_admin_addr
}


}

