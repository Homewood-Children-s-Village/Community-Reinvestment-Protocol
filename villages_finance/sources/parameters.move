module villages_finance::parameters {

use std::signer;
use std::error;
use std::vector;
use std::option;
use aptos_framework::event;
use aptos_framework::ordered_map;
use villages_finance::admin;
use villages_finance::governance;
use villages_finance::registry_config;
use villages_finance::event_history;

/// Error codes
const E_NOT_INITIALIZED: u64 = 1;
const E_PARAMETER_NOT_FOUND: u64 = 2;
const E_INVALID_VALUE: u64 = 3;
const E_NOT_AUTHORIZED: u64 = 4;
const E_INVALID_REGISTRY: u64 = 5;

/// Parameter entry for list_parameters view
struct ParameterEntry has store {
    name: vector<u8>,
    value: u64,
}

/// Parameter registry storing system parameters
struct ParameterRegistry has key {
    parameters: aptos_framework::ordered_map::OrderedMap<vector<u8>, u64>,
    change_history: aptos_framework::ordered_map::OrderedMap<u64, ParameterChange>, // History of changes
    change_counter: u64,
}

/// Parameter change record
struct ParameterChange has store {
    parameter_name: vector<u8>,
    old_value: u64,
    new_value: u64,
    changed_by: address,
    proposal_id: option::Option<u64>, // If changed via governance
    timestamp: u64,
}

/// Events
#[event]
struct ParameterUpdatedEvent has drop, store {
    parameter_name: vector<u8>,
    old_value: u64,
    new_value: u64,
    updated_by: address,
    proposal_id: option::Option<u64>,
}

/// Initialize parameter registry
public fun initialize(admin: &signer) {
    let admin_addr = signer::address_of(admin);
    assert!(!exists<ParameterRegistry>(admin_addr), error::already_exists(1));
    
    move_to(admin, ParameterRegistry {
        parameters: aptos_framework::ordered_map::new(),
        change_history: aptos_framework::ordered_map::new(),
        change_counter: 0,
    });
}

/// Set initial parameter (admin only, during initialization)
public entry fun set_parameter(
    admin: &signer,
    parameter_name: vector<u8>,
    value: u64,
    registry_addr: address,
) acquires ParameterRegistry {
    let admin_addr = signer::address_of(admin);
    
    // Validate registry exists
    assert!(exists<ParameterRegistry>(registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    assert!(admin::has_admin_capability(admin_addr), error::permission_denied(E_NOT_AUTHORIZED));
    
    let registry = borrow_global_mut<ParameterRegistry>(registry_addr);
    
    // Set parameter (allow overwrite during initialization)
    aptos_framework::ordered_map::upsert(&mut registry.parameters, parameter_name, value);
}

/// Update parameter via governance proposal
public entry fun update_parameter_via_governance(
    executor: &signer,
    proposal_id: u64,
    parameter_name: vector<u8>,
    new_value: u64,
    gov_addr: address,
    registry_addr: address,
) acquires ParameterRegistry {
    let executor_addr = signer::address_of(executor);
    
    // Validate registries
    assert!(registry_config::validate_governance(gov_addr), error::invalid_argument(E_INVALID_REGISTRY));
    assert!(exists<ParameterRegistry>(registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    
    // Verify proposal is executed
    let (_, _, status, _, _, _, _, _) = governance::get_proposal(proposal_id, gov_addr);
    assert!(status == 3, error::invalid_state(E_NOT_AUTHORIZED)); // 3 = Executed
    
    assert!(exists<ParameterRegistry>(registry_addr), error::not_found(E_NOT_INITIALIZED));
    let registry = borrow_global_mut<ParameterRegistry>(registry_addr);
    
    // Get old value
    let old_value = if (aptos_framework::ordered_map::contains(&registry.parameters, &parameter_name)) {
        *aptos_framework::ordered_map::borrow(&registry.parameters, &parameter_name)
    } else {
        0 // Default if not set
    };
    
    // Update parameter
    aptos_framework::ordered_map::upsert(&mut registry.parameters, parameter_name, new_value);
    
    // Record change
    let change_id = registry.change_counter;
    registry.change_counter = registry.change_counter + 1;
    
    let change = ParameterChange {
        parameter_name,
        old_value,
        new_value,
        changed_by: executor_addr,
        proposal_id: option::some(proposal_id),
        timestamp: change_id, // In production, use actual timestamp
    };
    
    aptos_framework::ordered_map::add(&mut registry.change_history, change_id, change);
    
    event::emit(ParameterUpdatedEvent {
        parameter_name,
        old_value,
        new_value,
        updated_by: executor_addr,
        proposal_id: option::some(proposal_id),
    });
    
    // Record global event
    event_history::record_global_event(
        registry_addr,
        b"parameter_updated",
        executor_addr,
        option::none(),
        option::some(parameter_name),
        option::some(old_value),
        option::some(new_value),
        option::some(proposal_id),
    );
}

/// Get parameter value (view function)
#[view]
public fun get_parameter(parameter_name: vector<u8>, registry_addr: address): option::Option<u64> {
    if (!exists<ParameterRegistry>(registry_addr)) {
        return option::none()
    };
    let registry = borrow_global<ParameterRegistry>(registry_addr);
    if (aptos_framework::ordered_map::contains(&registry.parameters, &parameter_name)) {
        option::some(*aptos_framework::ordered_map::borrow(&registry.parameters, &parameter_name))
    } else {
        option::none()
    }
}

/// List all parameters (view function)
#[view]
public fun list_parameters(registry_addr: address): vector<ParameterEntry> {
    let result = vector::empty<ParameterEntry>();
    if (!exists<ParameterRegistry>(registry_addr)) {
        return result
    };
    let registry = borrow_global<ParameterRegistry>(registry_addr);
    let keys = aptos_framework::ordered_map::keys(&registry.parameters);
    let i = 0;
    let len = vector::length(&keys);
    while (i < len) {
        let key = *vector::borrow(&keys, i);
        let value = *aptos_framework::ordered_map::borrow(&registry.parameters, &key);
        vector::push_back(&mut result, ParameterEntry {
            name: key,
            value,
        });
        i = i + 1;
    };
    result
}

#[test_only]
public fun initialize_for_test(admin: &signer) {
    admin::initialize_for_test(admin);
    initialize(admin);
}

}
