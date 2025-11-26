module villages_finance::admin {

use std::signer;
use std::error;
use std::vector;
use std::option;
use aptos_framework::event;
use aptos_framework::ordered_map;
use villages_finance::event_history;

/// Error codes
const E_NOT_ADMIN: u64 = 1;
const E_MODULE_NOT_FOUND: u64 = 2;
const E_MODULE_ALREADY_PAUSED: u64 = 3;
const E_MODULE_NOT_PAUSED: u64 = 4;
const E_INVALID_RATE: u64 = 5;

/// Admin capability resource - must be held to perform admin operations
struct AdminCapability has key, store {
    admin: address,
}

/// Module pause state
struct ModulePause has key {
    paused_modules: aptos_framework::ordered_map::OrderedMap<vector<u8>, bool>,
}

// Events
#[event]
struct ModulePausedEvent has drop, store {
    module_name: vector<u8>,
    paused_by: address,
}

#[event]
struct ModuleUnpausedEvent has drop, store {
    module_name: vector<u8>,
    unpaused_by: address,
}

#[event]
struct ParametersUpdatedEvent has drop, store {
    parameter_type: vector<u8>,
    old_value: u64,
    new_value: u64,
    updated_by: address,
}

#[event]
struct AdminActionEvent has drop, store {
    action_type: vector<u8>,
    target: address,
    performed_by: address,
    timestamp: u64,
}

#[event]
struct GovernanceRightsTransferredEvent has drop, store {
    old_admin: address,
    new_admin: address,
}

/// Initialize admin module
public fun initialize(admin: &signer) {
    let admin_addr = signer::address_of(admin);
    assert!(!exists<AdminCapability>(admin_addr), error::already_exists(1));
    assert!(!exists<ModulePause>(admin_addr), error::already_exists(2));
    
    // Create admin capability
    move_to(admin, AdminCapability { admin: admin_addr });
    
    // Initialize module pause registry
    move_to(admin, ModulePause {
        paused_modules: aptos_framework::ordered_map::new(),
    });
}

/// Internal function to pause a module (for governance)
public fun pause_module_internal(
    admin: &signer,
    module_name: vector<u8>,
    admin_addr: address,
) {
    let admin_addr_check = signer::address_of(admin);
    assert!(has_admin_capability(admin_addr_check), error::permission_denied(E_NOT_ADMIN));
    
    let pause_state = borrow_global_mut<ModulePause>(admin_addr);
    assert!(!aptos_framework::ordered_map::contains(&pause_state.paused_modules, &module_name), 
        error::already_exists(E_MODULE_ALREADY_PAUSED));
    
    aptos_framework::ordered_map::add(&mut pause_state.paused_modules, module_name, true);

    event::emit(ModulePausedEvent {
        module_name: module_name,
        paused_by: admin_addr_check,
    });
    
    // Record global event
    event_history::record_global_event(
        admin_addr_check,
        b"module_paused",
        admin_addr,
        option::some(module_name),
        option::none(),
        option::none(),
        option::none(),
        option::none(),
    );
}

/// Pause a module (admin only)
public entry fun pause_module(
    admin: &signer,
    module_name: vector<u8>,
) {
    let admin_addr = signer::address_of(admin);
    pause_module_internal(admin, module_name, admin_addr);
}

/// Internal function to unpause a module (for governance)
public fun unpause_module_internal(
    admin: &signer,
    module_name: vector<u8>,
    admin_addr: address,
) {
    let admin_addr_check = signer::address_of(admin);
    assert!(has_admin_capability(admin_addr_check), error::permission_denied(E_NOT_ADMIN));
    
    let pause_state = borrow_global_mut<ModulePause>(admin_addr);
    assert!(aptos_framework::ordered_map::contains(&pause_state.paused_modules, &module_name), 
        error::not_found(E_MODULE_NOT_PAUSED));
    
    aptos_framework::ordered_map::remove(&mut pause_state.paused_modules, &module_name);

    event::emit(ModuleUnpausedEvent {
        module_name: module_name,
        unpaused_by: admin_addr_check,
    });
    
    // Record global event
    event_history::record_global_event(
        admin_addr_check,
        b"module_unpaused",
        admin_addr,
        option::some(module_name),
        option::none(),
        option::none(),
        option::none(),
        option::none(),
    );
}

/// Unpause a module (admin only)
public entry fun unpause_module(
    admin: &signer,
    module_name: vector<u8>,
) {
    let admin_addr = signer::address_of(admin);
    unpause_module_internal(admin, module_name, admin_addr);
}

/// Check if a module is paused
#[view]
public fun is_module_paused(module_name: vector<u8>, admin_addr: address): bool {
    if (!exists<ModulePause>(admin_addr)) {
        return false
    };
    let pause_state = borrow_global<ModulePause>(admin_addr);
    aptos_framework::ordered_map::contains(&pause_state.paused_modules, &module_name)
}

/// List all paused modules
#[view]
public fun list_paused_modules(admin_addr: address): vector<vector<u8>> {
    let result = vector::empty<vector<u8>>();
    if (!exists<ModulePause>(admin_addr)) {
        return result
    };
    let pause_state = borrow_global<ModulePause>(admin_addr);
    aptos_framework::ordered_map::keys(&pause_state.paused_modules)
}

/// Update interest rate for a pool (admin only)
/// Note: This is a generic parameter update function
public entry fun update_interest_rate(
    admin: &signer,
    pool_id: u64,
    new_rate: u64,
) {
    let admin_addr = signer::address_of(admin);
    assert!(has_admin_capability(admin_addr), error::permission_denied(E_NOT_ADMIN));
    // Rate is typically in basis points (10000 = 100%), validate reasonable range
    assert!(new_rate <= 10000, error::invalid_argument(E_INVALID_RATE));
    
    // In a full implementation, this would update the pool's interest rate
    // For now, we just emit an event
    event::emit(ParametersUpdatedEvent {
        parameter_type: b"interest_rate",
        old_value: 0, // Would need to fetch from pool
        new_value: new_rate,
        updated_by: admin_addr,
    });
}

/// Internal function to transfer governance rights (for governance)
public fun transfer_governance_rights_internal(
    admin: &signer,
    new_admin_addr: address,
    admin_addr: address,
) {
    let admin_addr_check = signer::address_of(admin);
    assert!(has_admin_capability(admin_addr_check), error::permission_denied(E_NOT_ADMIN));
    assert!(admin_addr_check != new_admin_addr, error::invalid_argument(1));
    
    // Remove old admin capability
    let AdminCapability { admin: _ } = move_from<AdminCapability>(admin_addr_check);
    
    // Note: In Move, we cannot directly create resources for another address
    // The new admin would need to accept or we'd use a different pattern
    // For MVP, we emit an event and the new admin would need to call accept_admin_role
    
    event::emit(GovernanceRightsTransferredEvent {
        old_admin: admin_addr_check,
        new_admin: new_admin_addr,
    });
}

/// Transfer governance rights to a new admin (admin only)
public entry fun transfer_governance_rights(
    admin: &signer,
    new_admin_addr: address,
) {
    let admin_addr = signer::address_of(admin);
    transfer_governance_rights_internal(admin, new_admin_addr, admin_addr);
}

/// Check if an address has admin capability
public fun has_admin_capability(addr: address): bool {
    exists<AdminCapability>(addr)
}

/// Get admin capability (for use by other modules)
public fun get_admin_capability(addr: address): AdminCapability acquires AdminCapability {
    assert!(has_admin_capability(addr), error::permission_denied(E_NOT_ADMIN));
    move_from<AdminCapability>(addr)
}

/// Return admin capability (for use by other modules)
public fun return_admin_capability(cap: AdminCapability, admin: &signer) {
    let addr = signer::address_of(admin);
    // Destroy the old capability and create a new one
    // AdminCapability doesn't have drop, so we need to extract its fields
    let AdminCapability { admin: _old_admin } = cap;
    move_to(admin, AdminCapability { admin: addr });
}

/// Log admin action (for audit trail)
fun log_admin_action(
    admin_addr: address,
    action_type: vector<u8>,
    target: address,
) {
    event::emit(AdminActionEvent {
        action_type,
        target,
        performed_by: admin_addr,
        timestamp: 0, // In production, use actual timestamp
    });
}

/// Emergency pause all modules (admin only)
/// This is a critical admin function for emergency situations
public entry fun emergency_pause_all(
    admin: &signer,
    admin_addr: address,
) {
    let admin_addr_check = signer::address_of(admin);
    assert!(has_admin_capability(admin_addr_check), error::permission_denied(E_NOT_ADMIN));
    
    // Pause all critical modules
    // In production, would iterate through all modules
    log_admin_action(admin_addr_check, b"emergency_pause_all", admin_addr);
}

/// Get admin address
#[view]
public fun get_admin_address(admin_addr: address): option::Option<address> {
    if (exists<AdminCapability>(admin_addr)) {
        let cap = borrow_global<AdminCapability>(admin_addr);
        option::some(cap.admin)
    } else {
        option::none()
    }
}

#[test_only]
public fun initialize_for_test(admin: &signer) {
    let admin_addr = signer::address_of(admin);
    if (!exists<AdminCapability>(admin_addr)) {
        initialize(admin);
    };
}

#[test_only]
public fun create_admin_capability_for_test(admin: &signer) {
    let admin_addr = signer::address_of(admin);
    if (!exists<AdminCapability>(admin_addr)) {
        move_to(admin, AdminCapability { admin: admin_addr });
    };
}

}
