module villages_finance::timebank {

use std::signer;
use std::error;
use std::vector;
use aptos_framework::event;
use aptos_framework::big_ordered_map;
use villages_finance::time_token;
use villages_finance::members;
use villages_finance::compliance;
use villages_finance::registry_config;
use villages_finance::event_history;
use std::option;

/// Error codes
const E_NOT_INITIALIZED: u64 = 1;
const E_NOT_VALIDATOR: u64 = 2;
const E_REQUEST_NOT_FOUND: u64 = 3;
const E_INVALID_STATUS: u64 = 4;
const E_ZERO_HOURS: u64 = 5;
const E_NOT_MEMBER: u64 = 6;
const E_INVALID_REGISTRY: u64 = 7;
const E_NOT_AUTHORIZED: u64 = 8;

/// Service request status
public enum RequestStatus has copy, drop, store {
    Pending,
    Approved,
    Rejected,
}

/// Service request struct
struct ServiceRequest has store {
    requester: address,
    hours: u64,
    activity_id: u64,
    status: RequestStatus,
    created_at: u64,
}

/// TimeBank object storing service requests
struct TimeBank has key {
    requests: aptos_framework::big_ordered_map::BigOrderedMap<u64, ServiceRequest>,
    request_counter: u64,
}

/// Events
#[event]
struct RequestCreatedEvent has drop, store {
    request_id: u64,
    requester: address,
    hours: u64,
    activity_id: u64,
}

#[event]
struct RequestApprovedEvent has drop, store {
    request_id: u64,
    approver: address,
    hours: u64,
}

#[event]
struct RequestRejectedEvent has drop, store {
    request_id: u64,
    rejector: address,
}

#[event]
struct RequestCancelledEvent has drop, store {
    request_id: u64,
    requester: address,
}

#[event]
struct RequestUpdatedEvent has drop, store {
    request_id: u64,
    requester: address,
    old_hours: u64,
    new_hours: u64,
}

/// Initialize TimeBank
/// Initialize TimeBank
/// Idempotent: safe to call multiple times
public fun initialize(admin: &signer) {
    let admin_addr = signer::address_of(admin);
    // Explicit check for idempotency - no assert, just conditional creation
    if (!exists<TimeBank>(admin_addr)) {
        move_to(admin, TimeBank {
            // Use new_with_type_size_hints - Move 2.0 compiler may not statically infer constant size
            // Size calculation: address (16) + 4 u64s (32) + enum (1) + overhead = ~50-100 bytes
            requests: aptos_framework::big_ordered_map::new_with_type_size_hints<u64, ServiceRequest>(8, 8, 50, 200),
            request_counter: 0,
        });
    };
}

/// Create a service request
public entry fun create_request(
    requester: &signer,
    hours: u64,
    activity_id: u64,
    members_registry_addr: address,
    bank_registry_addr: address,
) acquires TimeBank {
    assert!(hours > 0, error::invalid_argument(E_ZERO_HOURS));
    
    let requester_addr = signer::address_of(requester);
    
    // Validate registries
    assert!(exists<TimeBank>(bank_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    assert!(registry_config::validate_members_registry(members_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    
    // Check requester is a member
    assert!(
        members::is_member_with_registry(requester_addr, members_registry_addr),
        error::permission_denied(E_NOT_MEMBER)
    );
    
    // Use shared registry address
    assert!(exists<TimeBank>(bank_registry_addr), error::not_found(E_NOT_INITIALIZED));
    
    let bank = borrow_global_mut<TimeBank>(bank_registry_addr);
    let request_id = bank.request_counter;
    bank.request_counter = bank.request_counter + 1;
    
    let request = ServiceRequest {
        requester: requester_addr,
        hours,
        activity_id,
        status: RequestStatus::Pending,
        created_at: request_id, // In production, use timestamp
    };
    
    aptos_framework::big_ordered_map::add(&mut bank.requests, request_id, request);

    event::emit(RequestCreatedEvent {
        request_id,
        requester: requester_addr,
        hours,
        activity_id,
    });
    
    // Record in event history
    event_history::record_user_event(
        requester_addr,
        event_history::event_type_request_created(),
        option::some(hours),
        option::none(),
        option::none(),
        option::some(request_id),
        option::none(),
        option::none(),
    );
}

/// Approve a service request (validator/admin only)
public entry fun approve_request(
    validator: &signer,
    request_id: u64,
    members_registry_addr: address,
    compliance_registry_addr: address,
    bank_registry_addr: address,
    time_token_admin_addr: address,
) acquires TimeBank {
    let validator_addr = signer::address_of(validator);
    
    // Validate registries
    assert!(exists<TimeBank>(bank_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    assert!(registry_config::validate_members_registry(members_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    assert!(registry_config::validate_compliance_registry(compliance_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    
    // Check if validator has Validator or Admin role
    assert!(
        members::has_role_with_registry(validator_addr, 3, members_registry_addr) || // Validator
        members::has_role_with_registry(validator_addr, 0, members_registry_addr),   // Admin
        error::permission_denied(E_NOT_VALIDATOR)
    );
    
    // Use shared registry address
    assert!(exists<TimeBank>(bank_registry_addr), error::not_found(E_NOT_INITIALIZED));
    
    let bank = borrow_global_mut<TimeBank>(bank_registry_addr);
    assert!(aptos_framework::big_ordered_map::contains(&bank.requests, &request_id), 
        error::not_found(E_REQUEST_NOT_FOUND));
    
    let request = aptos_framework::big_ordered_map::borrow_mut(&mut bank.requests, &request_id);
    assert!(request.status is RequestStatus::Pending, error::invalid_state(E_INVALID_STATUS));
    
    // Check compliance/KYC before minting
    assert!(
        compliance::is_whitelisted(request.requester, compliance_registry_addr),
        error::permission_denied(1) // E_NOT_WHITELISTED
    );
    
    // Update status
    request.status = RequestStatus::Approved;
    
    // Mint TimeTokens using FA standard
    time_token::mint(validator, request.requester, request.hours, time_token_admin_addr);

    event::emit(RequestApprovedEvent {
        request_id,
        approver: validator_addr,
        hours: request.hours,
    });
}

/// Reject a service request (validator/admin only)
public entry fun reject_request(
    validator: &signer,
    request_id: u64,
    members_registry_addr: address,
    bank_registry_addr: address,
) acquires TimeBank {
    let validator_addr = signer::address_of(validator);
    
    // Validate registries
    assert!(exists<TimeBank>(bank_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    assert!(registry_config::validate_members_registry(members_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    
    // Check if validator has Validator or Admin role
    assert!(
        members::has_role_with_registry(validator_addr, 3, members_registry_addr) || // Validator
        members::has_role_with_registry(validator_addr, 0, members_registry_addr),   // Admin
        error::permission_denied(E_NOT_VALIDATOR)
    );
    
    // Use shared registry address
    assert!(exists<TimeBank>(bank_registry_addr), error::not_found(E_NOT_INITIALIZED));
    
    let bank = borrow_global_mut<TimeBank>(bank_registry_addr);
    assert!(aptos_framework::big_ordered_map::contains(&bank.requests, &request_id), 
        error::not_found(E_REQUEST_NOT_FOUND));
    
    let request = aptos_framework::big_ordered_map::borrow_mut(&mut bank.requests, &request_id);
    assert!(request.status is RequestStatus::Pending, error::invalid_state(E_INVALID_STATUS));
    
    let requester_addr = request.requester;
    request.status = RequestStatus::Rejected;

    event::emit(RequestRejectedEvent {
        request_id,
        rejector: validator_addr,
    });
    
    // Record in event history
    event_history::record_user_event(
        requester_addr,
        event_history::event_type_request_rejected(),
        option::none(),
        option::none(),
        option::none(),
        option::some(request_id),
        option::some(validator_addr),
        option::none(),
    );
}

/// Get request details (view function)
#[view]
public fun get_request(request_id: u64, bank_addr: address): (address, u64, u64, u8, u64) {
    if (!exists<TimeBank>(bank_addr)) {
        abort error::not_found(E_NOT_INITIALIZED)
    };
    let bank = borrow_global<TimeBank>(bank_addr);
    if (!aptos_framework::big_ordered_map::contains(&bank.requests, &request_id)) {
        abort error::not_found(E_REQUEST_NOT_FOUND)
    };
    let request = aptos_framework::big_ordered_map::borrow(&bank.requests, &request_id);
    let status_u8 = if (request.status is RequestStatus::Pending) {
                    0
    } else if (request.status is RequestStatus::Approved) {
                    1
    } else {
        2
    };
    (request.requester, request.hours, request.activity_id, status_u8, request.created_at)
}

/// List all requests (view function)
/// Returns vector of request IDs, optionally filtered by status
/// Note: For MVP, iterates through request_counter. For scale, consider pagination.
#[view]
public fun list_requests(bank_addr: address, status_filter: u8): vector<u64> {
    let result = vector::empty<u64>();
    if (!exists<TimeBank>(bank_addr)) {
        return result
    };
    let bank = borrow_global<TimeBank>(bank_addr);
    let counter = bank.request_counter;
    let i = 0;
    // Use 255 as sentinel value for "no filter"
    let filter_active = status_filter != 255;
    while (i < counter) {
        if (aptos_framework::big_ordered_map::contains(&bank.requests, &i)) {
            if (filter_active) {
                let request = aptos_framework::big_ordered_map::borrow(&bank.requests, &i);
                let request_status = if (request.status is RequestStatus::Pending) {
                    0
                } else if (request.status is RequestStatus::Approved) {
                    1
                } else {
                    2
                };
                if (request_status == status_filter) {
                    vector::push_back(&mut result, i);
                }
            } else {
                vector::push_back(&mut result, i);
            }
        };
        i = i + 1;
    };
    result
}

/// List requests by member (view function)
/// Returns vector of request IDs created by a specific volunteer
#[view]
public fun list_requests_by_member(member: address, bank_addr: address): vector<u64> {
    let result = vector::empty<u64>();
    if (!exists<TimeBank>(bank_addr)) {
        return result
    };
    let bank = borrow_global<TimeBank>(bank_addr);
    let counter = bank.request_counter;
    let i = 0;
    while (i < counter) {
        if (aptos_framework::big_ordered_map::contains(&bank.requests, &i)) {
            let request = aptos_framework::big_ordered_map::borrow(&bank.requests, &i);
            if (request.requester == member) {
                vector::push_back(&mut result, i);
            }
        };
        i = i + 1;
    };
    result
}

/// Bulk approve requests (staff/validator only)
/// Processes multiple requests in a single transaction
public entry fun bulk_approve_requests(
    validator: &signer,
    request_ids: vector<u64>,
    bank_registry_addr: address,
    members_registry_addr: address,
    time_token_admin_addr: address,
) acquires TimeBank {
    let validator_addr = signer::address_of(validator);
    
    // Validate registry exists
    assert!(exists<TimeBank>(bank_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    assert!(members::has_role_with_registry(validator_addr, members::validator_role_u8(), members_registry_addr), 
        error::permission_denied(E_NOT_VALIDATOR));
    
    let bank = borrow_global_mut<TimeBank>(bank_registry_addr);
    let batch_size = vector::length(&request_ids);
    assert!(batch_size > 0, error::invalid_argument(1));
    assert!(batch_size <= 50, error::invalid_argument(2)); // Limit batch size
    
    let approved_count = 0;
    let failed_ids = vector::empty<u64>();
    let i = 0;
    
    while (i < batch_size) {
        let request_id = *vector::borrow(&request_ids, i);
        if (aptos_framework::big_ordered_map::contains(&bank.requests, &request_id)) {
            let request = aptos_framework::big_ordered_map::borrow_mut(&mut bank.requests, &request_id);
            if (request.status is RequestStatus::Pending) {
                request.status = RequestStatus::Approved;
                
                // Mint Time Tokens using FA standard
                time_token::mint(validator, request.requester, request.hours, time_token_admin_addr);
                
                event::emit(RequestApprovedEvent {
                    request_id,
                    approver: validator_addr,
                    hours: request.hours,
                });
                
                // Record in event history
                event_history::record_user_event(
                    request.requester,
                    event_history::event_type_request_approved(),
                    option::some(request.hours),
                    option::none(),
                    option::none(),
                    option::some(request_id),
                    option::some(validator_addr),
                    option::none(),
                );
                
                approved_count = approved_count + 1;
            } else {
                vector::push_back(&mut failed_ids, request_id);
            };
        } else {
            vector::push_back(&mut failed_ids, request_id);
        };
        i = i + 1;
    };
    
    // In production, could emit summary event with approved_count and failed_ids
}

/// Bulk reject requests (staff/validator only)
public entry fun bulk_reject_requests(
    validator: &signer,
    request_ids: vector<u64>,
    reason: vector<u8>,
    bank_registry_addr: address,
    members_registry_addr: address,
) acquires TimeBank {
    let validator_addr = signer::address_of(validator);
    
    // Validate registry exists
    assert!(exists<TimeBank>(bank_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    assert!(members::has_role_with_registry(validator_addr, members::validator_role_u8(), members_registry_addr), 
        error::permission_denied(E_NOT_VALIDATOR));
    
    let bank = borrow_global_mut<TimeBank>(bank_registry_addr);
    let batch_size = vector::length(&request_ids);
    assert!(batch_size > 0, error::invalid_argument(1));
    assert!(batch_size <= 50, error::invalid_argument(2)); // Limit batch size
    
    let rejected_count = 0;
    let failed_ids = vector::empty<u64>();
    let i = 0;
    
    while (i < batch_size) {
        let request_id = *vector::borrow(&request_ids, i);
        if (aptos_framework::big_ordered_map::contains(&bank.requests, &request_id)) {
            let request = aptos_framework::big_ordered_map::borrow_mut(&mut bank.requests, &request_id);
            if (request.status is RequestStatus::Pending) {
                request.status = RequestStatus::Rejected;
                
                event::emit(RequestRejectedEvent {
                    request_id,
                    rejector: validator_addr,
                });
                
                // Record in event history
                event_history::record_user_event(
                    request.requester,
                    event_history::event_type_request_rejected(),
                    option::none(),
                    option::none(),
                    option::none(),
                    option::some(request_id),
                    option::some(validator_addr),
                    option::none(),
                );
                
                rejected_count = rejected_count + 1;
            } else {
                vector::push_back(&mut failed_ids, request_id);
            };
        } else {
            vector::push_back(&mut failed_ids, request_id);
        };
        i = i + 1;
    };
    
    // In production, could emit summary event with rejected_count and failed_ids
}

/// Get volunteer statistics (view function)
/// Returns (total_requests, approved_hours, pending_requests, total_hours_earned)
#[view]
public fun get_volunteer_stats(member: address, bank_addr: address): (u64, u64, u64, u64) {
    let total_requests = 0;
    let approved_hours = 0;
    let pending_requests = 0;
    let total_hours_earned = 0;
    
    if (!exists<TimeBank>(bank_addr)) {
        return (total_requests, approved_hours, pending_requests, total_hours_earned)
    };
    
    let bank = borrow_global<TimeBank>(bank_addr);
    let counter = bank.request_counter;
    let i = 0;
    while (i < counter) {
        if (aptos_framework::big_ordered_map::contains(&bank.requests, &i)) {
            let request = aptos_framework::big_ordered_map::borrow(&bank.requests, &i);
            if (request.requester == member) {
                total_requests = total_requests + 1;
                if (request.status is RequestStatus::Approved) {
                    approved_hours = approved_hours + request.hours;
                    total_hours_earned = total_hours_earned + request.hours;
                } else if (request.status is RequestStatus::Pending) {
                    pending_requests = pending_requests + 1;
                }
            }
        };
        i = i + 1;
    };
    (total_requests, approved_hours, pending_requests, total_hours_earned)
}

/// Cancel a pending request (only requester can cancel)
public entry fun cancel_request(
    requester: &signer,
    request_id: u64,
    bank_registry_addr: address,
    members_registry_addr: address,
) acquires TimeBank {
    let requester_addr = signer::address_of(requester);
    
    // Validate registries
    assert!(exists<TimeBank>(bank_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    assert!(registry_config::validate_members_registry(members_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    
    // Verify requester is a member
    assert!(members::is_member_with_registry(requester_addr, members_registry_addr), error::permission_denied(E_NOT_MEMBER));
    
    assert!(exists<TimeBank>(bank_registry_addr), error::not_found(E_NOT_INITIALIZED));
    let bank = borrow_global_mut<TimeBank>(bank_registry_addr);
    
    assert!(aptos_framework::big_ordered_map::contains(&bank.requests, &request_id),
        error::not_found(E_REQUEST_NOT_FOUND));
    
    let request = aptos_framework::big_ordered_map::borrow_mut(&mut bank.requests, &request_id);
    
    // Verify requester owns this request
    assert!(request.requester == requester_addr, error::permission_denied(E_NOT_AUTHORIZED));
    
    // Only allow cancellation if status is Pending
    assert!(request.status is RequestStatus::Pending, error::invalid_state(E_INVALID_STATUS));
    
    // Update status to Rejected (represents cancellation)
    request.status = RequestStatus::Rejected;
    
    event::emit(RequestCancelledEvent {
        request_id,
        requester: requester_addr,
    });
}

/// Update request details (only requester can update, only if Pending)
public entry fun update_request(
    requester: &signer,
    request_id: u64,
    new_hours: u64,
    bank_registry_addr: address,
    members_registry_addr: address,
) acquires TimeBank {
    assert!(new_hours > 0, error::invalid_argument(E_ZERO_HOURS));
    
    let requester_addr = signer::address_of(requester);
    
    // Validate registries
    assert!(exists<TimeBank>(bank_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    assert!(registry_config::validate_members_registry(members_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    
    // Verify requester is a member
    assert!(members::is_member_with_registry(requester_addr, members_registry_addr), error::permission_denied(E_NOT_MEMBER));
    
    assert!(exists<TimeBank>(bank_registry_addr), error::not_found(E_NOT_INITIALIZED));
    let bank = borrow_global_mut<TimeBank>(bank_registry_addr);
    
    assert!(aptos_framework::big_ordered_map::contains(&bank.requests, &request_id),
        error::not_found(E_REQUEST_NOT_FOUND));
    
    let request = aptos_framework::big_ordered_map::borrow_mut(&mut bank.requests, &request_id);
    
    // Verify requester owns this request
    assert!(request.requester == requester_addr, error::permission_denied(E_NOT_AUTHORIZED));
    
    // Only allow update if status is Pending
    assert!(request.status is RequestStatus::Pending, error::invalid_state(E_INVALID_STATUS));
    
    let old_hours = request.hours;
    request.hours = new_hours;
    
    event::emit(RequestUpdatedEvent {
        request_id,
        requester: requester_addr,
        old_hours,
        new_hours,
    });
}

#[test_only]
use villages_finance::admin;

#[test_only]
public fun initialize_for_test(admin: &signer) {
    admin::initialize_for_test(admin);
    let admin_addr = signer::address_of(admin);
    if (!exists<TimeBank>(admin_addr)) {
        initialize(admin);
    };
}

}
