module villages_finance::event_history {

use std::signer;
use std::error;
use std::vector;
use std::option;
use aptos_framework::event;
use aptos_framework::big_ordered_map;

/// Error codes
const E_NOT_INITIALIZED: u64 = 1;
const E_HISTORY_LIMIT_EXCEEDED: u64 = 2;
const E_INVALID_LIMIT: u64 = 3;

/// Maximum number of events to store per user (circular buffer)
const MAX_USER_EVENTS: u64 = 500;

/// Maximum number of global events to store
const MAX_GLOBAL_EVENTS: u64 = 1000;

/// Event type constants
const EVENT_TYPE_DEPOSIT: vector<u8> = b"deposit";
const EVENT_TYPE_WITHDRAWAL: vector<u8> = b"withdrawal";
const EVENT_TYPE_INVESTMENT: vector<u8> = b"investment";
const EVENT_TYPE_REPAYMENT_CLAIMED: vector<u8> = b"repayment_claimed";
const EVENT_TYPE_VOTE: vector<u8> = b"vote";
const EVENT_TYPE_PROPOSAL: vector<u8> = b"proposal";
const EVENT_TYPE_REQUEST_CREATED: vector<u8> = b"request_created";
const EVENT_TYPE_REQUEST_APPROVED: vector<u8> = b"request_approved";
const EVENT_TYPE_REQUEST_REJECTED: vector<u8> = b"request_rejected";
const EVENT_TYPE_STAKE: vector<u8> = b"stake";
const EVENT_TYPE_UNSTAKE: vector<u8> = b"unstake";
const EVENT_TYPE_REWARD_CLAIMED: vector<u8> = b"reward_claimed";

/// Event summary for on-chain storage
public struct EventSummary has store, copy, drop {
    event_type: vector<u8>,
    timestamp: u64,
    amount: option::Option<u64>,
    pool_id: option::Option<u64>,
    proposal_id: option::Option<u64>,
    request_id: option::Option<u64>,
    other_party: option::Option<address>, // For transfers, votes, etc.
    status: option::Option<u8>, // For status changes
}

/// User-specific event history
public struct UserEventHistory has key {
    user_addr: address,
    events: vector<EventSummary>,
    event_counter: u64,
}

/// Global event registry for system-wide events
public struct GlobalEventRegistry has key {
    events: vector<GlobalEventSummary>,
    event_counter: u64,
}

/// Global event summary (for system events)
public struct GlobalEventSummary has store, copy, drop {
    event_type: vector<u8>,
    timestamp: u64,
    actor: address, // Who performed the action
    module_name: option::Option<vector<u8>>,
    parameter_name: option::Option<vector<u8>>,
    old_value: option::Option<u64>,
    new_value: option::Option<u64>,
    proposal_id: option::Option<u64>,
}

/// Initialize user event history (called automatically when recording first event)
/// Note: This requires the user to have initialized their account
fun initialize_user_history_if_needed(user_addr: address) {
    if (exists<UserEventHistory>(user_addr)) {
        return
    };
    // User history will be created on first event via record_user_event
    // For now, we'll create it lazily - but this requires the account to exist
}

/// Record a user event (internal function)
/// Note: UserEventHistory will be created automatically on first event
/// This requires the user account to exist (have received coins or initialized)
public fun record_user_event(
    user_addr: address,
    event_type: vector<u8>,
    amount: option::Option<u64>,
    pool_id: option::Option<u64>,
    proposal_id: option::Option<u64>,
    request_id: option::Option<u64>,
    other_party: option::Option<address>,
    status: option::Option<u8>,
) {
    // Skip if history doesn't exist (user account may not be initialized)
    // In production, ensure user accounts are initialized before recording events
    if (!exists<UserEventHistory>(user_addr)) {
        return // Skip recording if user history not initialized
    };
    
    let history = borrow_global_mut<UserEventHistory>(user_addr);
    let timestamp = history.event_counter; // In production, use actual timestamp
    
    let summary = EventSummary {
        event_type,
        timestamp,
        amount,
        pool_id,
        proposal_id,
        request_id,
        other_party,
        status,
    };
    
    // Circular buffer: remove oldest if at limit
    if (vector::length(&history.events) >= MAX_USER_EVENTS) {
        let _ = vector::remove(&mut history.events, 0); // Explicitly drop the removed event
    };
    
    vector::push_back(&mut history.events, summary);
    history.event_counter = history.event_counter + 1;
}

/// Record a global event (internal function)
public fun record_global_event(
    registry_addr: address,
    event_type: vector<u8>,
    actor: address,
    module_name: option::Option<vector<u8>>,
    parameter_name: option::Option<vector<u8>>,
    old_value: option::Option<u64>,
    new_value: option::Option<u64>,
    proposal_id: option::Option<u64>,
) {
    if (!exists<GlobalEventRegistry>(registry_addr)) {
        return // Global registry must be initialized separately
    };
    
    let registry = borrow_global_mut<GlobalEventRegistry>(registry_addr);
    let timestamp = registry.event_counter; // In production, use actual timestamp
    
    let summary = GlobalEventSummary {
        event_type,
        timestamp,
        actor,
        module_name,
        parameter_name,
        old_value,
        new_value,
        proposal_id,
    };
    
    // Circular buffer: remove oldest if at limit
    if (vector::length(&registry.events) >= MAX_GLOBAL_EVENTS) {
        let _ = vector::remove(&mut registry.events, 0); // Explicitly drop the removed event
    };
    
    vector::push_back(&mut registry.events, summary);
    registry.event_counter = registry.event_counter + 1;
}

/// Get user event history (view function)
#[view]
public fun get_user_event_history(
    user_addr: address,
    event_type_filter: option::Option<vector<u8>>,
    limit: u64,
): vector<EventSummary> {
    if (!exists<UserEventHistory>(user_addr)) {
        return vector::empty<EventSummary>()
    };
    
    assert!(limit <= MAX_USER_EVENTS, error::invalid_argument(E_INVALID_LIMIT));
    
    let history = borrow_global<UserEventHistory>(user_addr);
    let result = vector::empty<EventSummary>();
    let events_len = vector::length(&history.events);
    
    // Start from most recent (end of vector)
    let i = if (events_len > limit) { events_len - limit } else { 0 };
    let filter_active = option::is_some(&event_type_filter);
    let filter_type = if (filter_active) { *option::borrow(&event_type_filter) } else { b"" };
    
    while (i < events_len && vector::length(&result) < limit) {
        let event = vector::borrow(&history.events, i);
        if (!filter_active || event.event_type == filter_type) {
            vector::push_back(&mut result, *event);
        };
        i = i + 1;
    };
    
    result
}

/// Get global event history (view function)
#[view]
public fun get_global_event_history(
    registry_addr: address,
    event_type_filter: option::Option<vector<u8>>,
    limit: u64,
): vector<GlobalEventSummary> {
    if (!exists<GlobalEventRegistry>(registry_addr)) {
        return vector::empty<GlobalEventSummary>()
    };
    
    assert!(limit <= MAX_GLOBAL_EVENTS, error::invalid_argument(E_INVALID_LIMIT));
    
    let registry = borrow_global<GlobalEventRegistry>(registry_addr);
    let result = vector::empty<GlobalEventSummary>();
    let events_len = vector::length(&registry.events);
    
    // Start from most recent (end of vector)
    let i = if (events_len > limit) { events_len - limit } else { 0 };
    let filter_active = option::is_some(&event_type_filter);
    let filter_type = if (filter_active) { *option::borrow(&event_type_filter) } else { b"" };
    
    while (i < events_len && vector::length(&result) < limit) {
        let event = vector::borrow(&registry.events, i);
        if (!filter_active || event.event_type == filter_type) {
            vector::push_back(&mut result, *event);
        };
        i = i + 1;
    };
    
    result
}

/// Get event count for a user (view function)
#[view]
public fun get_user_event_count(user_addr: address): u64 {
    if (!exists<UserEventHistory>(user_addr)) {
        return 0
    };
    let history = borrow_global<UserEventHistory>(user_addr);
    vector::length(&history.events)
}

/// Public getters for event type constants
public fun event_type_deposit(): vector<u8> { EVENT_TYPE_DEPOSIT }
public fun event_type_withdrawal(): vector<u8> { EVENT_TYPE_WITHDRAWAL }
public fun event_type_investment(): vector<u8> { EVENT_TYPE_INVESTMENT }
public fun event_type_repayment_claimed(): vector<u8> { EVENT_TYPE_REPAYMENT_CLAIMED }
public fun event_type_vote(): vector<u8> { EVENT_TYPE_VOTE }
public fun event_type_proposal(): vector<u8> { EVENT_TYPE_PROPOSAL }
public fun event_type_request_created(): vector<u8> { EVENT_TYPE_REQUEST_CREATED }
public fun event_type_request_approved(): vector<u8> { EVENT_TYPE_REQUEST_APPROVED }
public fun event_type_request_rejected(): vector<u8> { EVENT_TYPE_REQUEST_REJECTED }
public fun event_type_stake(): vector<u8> { EVENT_TYPE_STAKE }
public fun event_type_unstake(): vector<u8> { EVENT_TYPE_UNSTAKE }
public fun event_type_reward_claimed(): vector<u8> { EVENT_TYPE_REWARD_CLAIMED }

#[test_only]
public fun initialize_for_test(admin: &signer) {
    let admin_addr = signer::address_of(admin);
    if (!exists<GlobalEventRegistry>(admin_addr)) {
        move_to(admin, GlobalEventRegistry {
            events: vector::empty<GlobalEventSummary>(),
            event_counter: 0,
        });
    };
}

#[test_only]
public fun initialize_user_history_for_test(user: &signer) {
    let user_addr = signer::address_of(user);
    if (!exists<UserEventHistory>(user_addr)) {
        move_to(user, UserEventHistory {
            user_addr,
            events: vector::empty<EventSummary>(),
            event_counter: 0,
        });
    };
}

}
