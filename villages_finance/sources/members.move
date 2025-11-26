module villages_finance::members {

use std::signer;
use std::error;
use std::vector;
use std::option;
use aptos_framework::event;
use aptos_framework::ordered_map;
use villages_finance::admin;
use villages_finance::registry_hub;

/// Error codes
const E_NOT_ADMIN: u64 = 1;
const E_MEMBER_NOT_FOUND: u64 = 2;
const E_MEMBER_ALREADY_EXISTS: u64 = 3;
const E_INVALID_ROLE: u64 = 4;
const E_REQUEST_NOT_FOUND: u64 = 5;
const E_REQUEST_ALREADY_PENDING: u64 = 6;
const E_INVALID_REQUEST_STATUS: u64 = 7;
const E_NOT_AUTHORIZED: u64 = 8;

/// Membership roles
public enum Role has copy, drop, store {
    Admin,
    Borrower,
    Depositor,
    Validator,
}

/// Member resource stored under each user's account
struct Member has key, store {
    role: Role,
}

/// Membership registry object - tracks all registered members
struct MembershipRegistry has key {
    registry: aptos_framework::ordered_map::OrderedMap<address, Role>,
    counter: u64,
}

/// Status of a membership request
public enum RequestStatus has copy, drop, store {
    Pending,
    Approved,
    Rejected,
}

/// Membership request data
struct MembershipRequest has store {
    requester: address,
    desired_role: Role,
    note: vector<u8>,
    status: RequestStatus,
}

/// Registry for membership requests
struct MembershipRequestRegistry has key {
    requests: aptos_framework::ordered_map::OrderedMap<u64, MembershipRequest>,
    address_to_request: aptos_framework::ordered_map::OrderedMap<address, u64>,
    counter: u64,
}

// Events
#[event]
struct MemberRegisteredEvent has drop, store {
    member: address,
    role: u8,
}

#[event]
struct RoleUpdatedEvent has drop, store {
    member: address,
    old_role: u8,
    new_role: u8,
}

#[event]
struct MembershipRevokedEvent has drop, store {
    member: address,
}

#[event]
struct MembershipRequestedEvent has drop, store {
    request_id: u64,
    requester: address,
    role: u8,
}

#[event]
struct MembershipRequestApprovedEvent has drop, store {
    request_id: u64,
    approver: address,
}

#[event]
struct MembershipRequestRejectedEvent has drop, store {
    request_id: u64,
    approver: address,
}

/// Initialize the membership registry
public fun initialize(admin: &signer) {
    assert!(!exists<MembershipRegistry>(@villages_finance), error::already_exists(1));
    
    let admin_addr = signer::address_of(admin);
    
    // Create registry at package address (will be set during deployment)
    // For now, we'll store it at admin address and update later
    move_to(admin, MembershipRegistry {
        registry: aptos_framework::ordered_map::new(),
        counter: 0,
    });

    // Initialize membership request registry alongside membership registry
    if (!exists<MembershipRequestRegistry>(admin_addr)) {
        move_to(admin, MembershipRequestRegistry {
            requests: aptos_framework::ordered_map::new(),
            address_to_request: aptos_framework::ordered_map::new(),
            counter: 0,
        });
    };

    // Register admin as first member
    register_member_internal(admin, admin_addr, admin_addr, Role::Admin);
}

/// Register a new member (admin only)
public entry fun register_member(
    admin: &signer,
    member_addr: address,
    role: u8,
) acquires MembershipRegistry, Member {
    let admin_addr = signer::address_of(admin);
    assert!(is_admin_with_registry(admin, admin_addr), error::permission_denied(E_NOT_ADMIN));
    
    let registry = borrow_global<MembershipRegistry>(admin_addr);
    assert!(!aptos_framework::ordered_map::contains(&registry.registry, &member_addr), error::already_exists(E_MEMBER_ALREADY_EXISTS));
    
    let role_enum = role_from_u8(role);
    register_member_internal(admin, admin_addr, member_addr, role_enum);
}

/// Internal function to register a member
fun register_member_internal(
    admin: &signer,
    registry_addr: address,
    member_addr: address,
    role: Role,
) acquires MembershipRegistry {
    let admin_addr = signer::address_of(admin);
    let registry = borrow_global_mut<MembershipRegistry>(registry_addr);
    
    // Store role in registry
    aptos_framework::ordered_map::add(&mut registry.registry, member_addr, role);
    registry.counter = registry.counter + 1;

    // Create Member resource if admin is registering themselves
    if (member_addr == admin_addr && !exists<Member>(member_addr)) {
        move_to(admin, Member { role });
    };

    event::emit(MemberRegisteredEvent {
        member: member_addr,
        role: role_to_u8(role),
    });
}

/// Bulk register members (admin only)
public entry fun bulk_register_members(
    admin: &signer,
    addresses: vector<address>,
    roles: vector<u8>,
    registry_addr: address,
) acquires MembershipRegistry {
    let admin_addr = signer::address_of(admin);
    
    // Validate registry exists
    assert!(exists<MembershipRegistry>(registry_addr), error::invalid_argument(5));
    assert!(admin::has_admin_capability(admin_addr), error::permission_denied(E_NOT_ADMIN));
    
    let batch_size = vector::length(&addresses);
    let roles_size = vector::length(&roles);
    assert!(batch_size > 0, error::invalid_argument(1));
    assert!(batch_size == roles_size, error::invalid_argument(2)); // Must match
    assert!(batch_size <= 100, error::invalid_argument(3)); // Limit batch size
    
    let registry = borrow_global_mut<MembershipRegistry>(registry_addr);
    let success_count = 0;
    let failed_addresses = vector::empty<address>();
    let i = 0;
    
    while (i < batch_size) {
        let addr = *vector::borrow(&addresses, i);
        let role_u8 = *vector::borrow(&roles, i);
        let role = role_from_u8(role_u8);
        
        if (!aptos_framework::ordered_map::contains(&registry.registry, &addr)) {
            aptos_framework::ordered_map::add(&mut registry.registry, addr, role);
            registry.counter = registry.counter + 1;
            
            event::emit(MemberRegisteredEvent {
                member: addr,
                role: role_u8,
            });
            
            success_count = success_count + 1;
        } else {
            vector::push_back(&mut failed_addresses, addr);
        };
        i = i + 1;
    };
}

/// Submit a membership request (non-members)
public entry fun request_membership(
    applicant: &signer,
    registry_addr: address,
    desired_role: u8,
    note: vector<u8>,
) acquires MembershipRegistry, MembershipRequestRegistry {
    let applicant_addr = signer::address_of(applicant);

    assert!(exists<MembershipRegistry>(registry_addr), error::not_found(1));

    // Ensure applicant is not already a member
    assert!(
        !aptos_framework::ordered_map::contains(&borrow_global<MembershipRegistry>(registry_addr).registry, &applicant_addr),
        error::already_exists(E_MEMBER_ALREADY_EXISTS)
    );

    assert!(exists<MembershipRequestRegistry>(registry_addr), error::not_found(E_REQUEST_NOT_FOUND));
    let requests = borrow_global_mut<MembershipRequestRegistry>(registry_addr);

    if (aptos_framework::ordered_map::contains(&requests.address_to_request, &applicant_addr)) {
        let request_id = *aptos_framework::ordered_map::borrow(&requests.address_to_request, &applicant_addr);
        let existing = aptos_framework::ordered_map::borrow(&requests.requests, &request_id);
        assert!(!(existing.status is RequestStatus::Pending), error::already_exists(E_REQUEST_ALREADY_PENDING));
    };

    let request_id = requests.counter;
    requests.counter = requests.counter + 1;

    let request = MembershipRequest {
        requester: applicant_addr,
        desired_role: role_from_u8(desired_role),
        note,
        status: RequestStatus::Pending,
    };

    aptos_framework::ordered_map::add(&mut requests.requests, request_id, request);
    aptos_framework::ordered_map::upsert(&mut requests.address_to_request, applicant_addr, request_id);

    event::emit(MembershipRequestedEvent {
        request_id,
        requester: applicant_addr,
        role: desired_role,
    });
}

/// Request membership using a community id resolved via RegistryHub
public entry fun request_membership_for_community(
    applicant: &signer,
    hub_addr: address,
    community_id: u64,
    desired_role: u8,
    note: vector<u8>,
) acquires MembershipRegistry, MembershipRequestRegistry {
    let registry_addr = registry_hub::members_registry_addr(hub_addr, community_id);
    request_membership(applicant, registry_addr, desired_role, note);
}

/// Approve a pending membership request (Admin or Validator)
public entry fun approve_membership(
    approver: &signer,
    request_id: u64,
    registry_addr: address,
) acquires MembershipRegistry, MembershipRequestRegistry, Member {
    let approver_addr = signer::address_of(approver);

    assert!(exists<MembershipRegistry>(registry_addr), error::not_found(1));

    // Permissions: Admin or Validator
    assert!(
        is_admin_with_registry(approver, registry_addr) ||
        has_role_with_registry(approver_addr, validator_role_u8(), registry_addr),
        error::permission_denied(E_NOT_AUTHORIZED)
    );

    assert!(exists<MembershipRequestRegistry>(registry_addr), error::not_found(E_REQUEST_NOT_FOUND));
    let requests = borrow_global_mut<MembershipRequestRegistry>(registry_addr);
    assert!(aptos_framework::ordered_map::contains(&requests.requests, &request_id), error::not_found(E_REQUEST_NOT_FOUND));

    let request = aptos_framework::ordered_map::borrow_mut(&mut requests.requests, &request_id);
    assert!(request.status is RequestStatus::Pending, error::invalid_state(E_INVALID_REQUEST_STATUS));

    let requester_addr = request.requester;
    let desired_role = request.desired_role;

    request.status = RequestStatus::Approved;
    remove_request_mapping(&mut requests.address_to_request, requester_addr);

    register_member_in_registry(registry_addr, requester_addr, desired_role);

    event::emit(MembershipRequestApprovedEvent {
        request_id,
        approver: approver_addr,
    });
}

/// Approve a membership request using a community id resolved via RegistryHub
public entry fun approve_membership_for_community(
    approver: &signer,
    hub_addr: address,
    community_id: u64,
    request_id: u64,
) acquires MembershipRegistry, MembershipRequestRegistry, Member {
    let registry_addr = registry_hub::members_registry_addr(hub_addr, community_id);
    approve_membership(approver, request_id, registry_addr);
}

/// Reject a pending membership request (Admin or Validator)
public entry fun reject_membership(
    approver: &signer,
    request_id: u64,
    registry_addr: address,
) acquires Member, MembershipRegistry, MembershipRequestRegistry {
    let approver_addr = signer::address_of(approver);

    assert!(exists<MembershipRegistry>(registry_addr), error::not_found(1));

    assert!(
        is_admin_with_registry(approver, registry_addr) ||
        has_role_with_registry(approver_addr, validator_role_u8(), registry_addr),
        error::permission_denied(E_NOT_AUTHORIZED)
    );

    assert!(exists<MembershipRequestRegistry>(registry_addr), error::not_found(E_REQUEST_NOT_FOUND));
    let requests = borrow_global_mut<MembershipRequestRegistry>(registry_addr);
    assert!(aptos_framework::ordered_map::contains(&requests.requests, &request_id), error::not_found(E_REQUEST_NOT_FOUND));

    let request = aptos_framework::ordered_map::borrow_mut(&mut requests.requests, &request_id);
    assert!(request.status is RequestStatus::Pending, error::invalid_state(E_INVALID_REQUEST_STATUS));

    request.status = RequestStatus::Rejected;
    remove_request_mapping(&mut requests.address_to_request, request.requester);

    event::emit(MembershipRequestRejectedEvent {
        request_id,
        approver: approver_addr,
    });
}

/// Reject membership request using a community id resolved via RegistryHub
public entry fun reject_membership_for_community(
    approver: &signer,
    hub_addr: address,
    community_id: u64,
    request_id: u64,
) acquires Member, MembershipRegistry, MembershipRequestRegistry {
    let registry_addr = registry_hub::members_registry_addr(hub_addr, community_id);
    reject_membership(approver, request_id, registry_addr);
}

/// Bulk update member roles (admin only)
public entry fun bulk_update_roles(
    admin: &signer,
    addresses: vector<address>,
    new_roles: vector<u8>,
    registry_addr: address,
) acquires MembershipRegistry, Member {
    let admin_addr = signer::address_of(admin);
    
    // Validate registry exists
    assert!(exists<MembershipRegistry>(registry_addr), error::invalid_argument(5));
    assert!(admin::has_admin_capability(admin_addr), error::permission_denied(E_NOT_ADMIN));
    
    let batch_size = vector::length(&addresses);
    let roles_size = vector::length(&new_roles);
    assert!(batch_size > 0, error::invalid_argument(1));
    assert!(batch_size == roles_size, error::invalid_argument(2)); // Must match
    assert!(batch_size <= 100, error::invalid_argument(3)); // Limit batch size
    
    let registry = borrow_global_mut<MembershipRegistry>(registry_addr);
    let success_count = 0;
    let failed_addresses = vector::empty<address>();
    let i = 0;
    
    while (i < batch_size) {
        let addr = *vector::borrow(&addresses, i);
        let new_role_u8 = *vector::borrow(&new_roles, i);
        let new_role = role_from_u8(new_role_u8);
        
        if (aptos_framework::ordered_map::contains(&registry.registry, &addr)) {
            let old_role = *aptos_framework::ordered_map::borrow(&registry.registry, &addr);
            aptos_framework::ordered_map::upsert(&mut registry.registry, addr, new_role);
            
            // Update Member resource if it exists
            if (exists<Member>(addr)) {
                let member = borrow_global_mut<Member>(addr);
                member.role = new_role;
            };
            
            event::emit(RoleUpdatedEvent {
                member: addr,
                old_role: role_to_u8(old_role),
                new_role: new_role_u8,
            });
            
            success_count = success_count + 1;
        } else {
            vector::push_back(&mut failed_addresses, addr);
        };
        i = i + 1;
    };
}

/// Accept membership and create Member resource (called by the member themselves)
/// Requires registry address where membership was registered
public entry fun accept_membership(
    member: &signer,
    registry_addr: address,
) acquires MembershipRegistry {
    let member_addr = signer::address_of(member);
    // Idempotent: if already a member, return early
    if (exists<Member>(member_addr)) {
        return
    };
    assert!(exists<MembershipRegistry>(registry_addr), error::not_found(1));
    
    let registry = borrow_global<MembershipRegistry>(registry_addr);
    assert!(aptos_framework::ordered_map::contains(&registry.registry, &member_addr), error::not_found(E_MEMBER_NOT_FOUND));
    
    let role = *aptos_framework::ordered_map::borrow(&registry.registry, &member_addr);
    move_to(member, Member { role });
}

/// Update a member's role (admin only)
public entry fun update_role(
    admin: &signer,
    member_addr: address,
    new_role: u8,
) acquires MembershipRegistry, Member {
    let admin_addr = signer::address_of(admin);
    assert!(is_admin_with_registry(admin, admin_addr), error::permission_denied(E_NOT_ADMIN));
    
    let registry = borrow_global_mut<MembershipRegistry>(admin_addr);
    assert!(aptos_framework::ordered_map::contains(&registry.registry, &member_addr), error::not_found(E_MEMBER_NOT_FOUND));
    
    let old_role = *aptos_framework::ordered_map::borrow(&registry.registry, &member_addr);
    let new_role_enum = role_from_u8(new_role);
    
    // Update registry
    aptos_framework::ordered_map::upsert(&mut registry.registry, member_addr, new_role_enum);
    
    // Update Member resource if it exists
    if (exists<Member>(member_addr)) {
        let member = borrow_global_mut<Member>(member_addr);
        member.role = new_role_enum;
    };

    event::emit(RoleUpdatedEvent {
        member: member_addr,
        old_role: role_to_u8(old_role),
        new_role: role_to_u8(new_role_enum),
    });
}

/// Revoke membership (admin only)
public entry fun revoke_membership(
    admin: &signer,
    member_addr: address,
) acquires MembershipRegistry, Member {
    let admin_addr = signer::address_of(admin);
    assert!(is_admin_with_registry(admin, admin_addr), error::permission_denied(E_NOT_ADMIN));
    
    let registry = borrow_global_mut<MembershipRegistry>(admin_addr);
    assert!(aptos_framework::ordered_map::contains(&registry.registry, &member_addr), error::not_found(E_MEMBER_NOT_FOUND));
    
    // Remove from registry
    aptos_framework::ordered_map::remove(&mut registry.registry, &member_addr);
    
    // Destroy member resource if it exists
    if (exists<Member>(member_addr)) {
        let Member { role: _ } = move_from<Member>(member_addr);
    };
    
    event::emit(MembershipRevokedEvent {
        member: member_addr,
    });
}

/// Get request ID for an address (view)
#[view]
public fun get_request_id_by_address(registry_addr: address, applicant_addr: address): option::Option<u64> {
    if (!exists<MembershipRequestRegistry>(registry_addr)) {
        return option::none()
    };
    let registry = borrow_global<MembershipRequestRegistry>(registry_addr);
    if (aptos_framework::ordered_map::contains(&registry.address_to_request, &applicant_addr)) {
        option::some(*aptos_framework::ordered_map::borrow(&registry.address_to_request, &applicant_addr))
    } else {
        option::none()
    }
}

/// List pending membership requests (view)
#[view]
public fun list_membership_requests(registry_addr: address, status_filter: u8): vector<u64> {
    let result = vector::empty<u64>();
    if (!exists<MembershipRequestRegistry>(registry_addr)) {
        return result
    };
    let registry = borrow_global<MembershipRequestRegistry>(registry_addr);
    let keys = aptos_framework::ordered_map::keys(&registry.requests);
    let len = vector::length(&keys);
    let i = 0;
    while (i < len) {
        let request_id = *vector::borrow(&keys, i);
        let request = aptos_framework::ordered_map::borrow(&registry.requests, &request_id);
        let status_u8 = request_status_to_u8(request.status);
        if (status_filter == 255 || status_filter == status_u8) {
            vector::push_back(&mut result, request_id);
        };
        i = i + 1;
    };
    result
}

/// Check if an address is an admin
public fun is_admin(account: &signer): bool {
    let addr = signer::address_of(account);
    if (exists<Member>(addr)) {
        let member = borrow_global<Member>(addr);
        return member.role is Role::Admin
    };
    // Check registry if Member resource doesn't exist yet
    // Registry is stored at admin address, so we need to check all potential admin addresses
    // For MVP, we'll check if addr has admin role in any registry
    // This is a simplified check - in production, registry would be in an object
    false
}

/// Helper to check admin status using registry address
public fun is_admin_with_registry(account: &signer, registry_addr: address): bool {
    let addr = signer::address_of(account);
    if (exists<Member>(addr)) {
        let member = borrow_global<Member>(addr);
        return member.role is Role::Admin
    };
    if (exists<MembershipRegistry>(registry_addr)) {
        let registry = borrow_global<MembershipRegistry>(registry_addr);
        if (aptos_framework::ordered_map::contains(&registry.registry, &addr)) {
            let role = aptos_framework::ordered_map::borrow(&registry.registry, &addr);
            return *role is Role::Admin
        }
    };
    false
}

/// Check if an address has a specific role (requires registry address)
public fun has_role_with_registry(addr: address, role: u8, registry_addr: address): bool {
    if (exists<Member>(addr)) {
        let member = borrow_global<Member>(addr);
        return role_to_u8(member.role) == role
    };
    // Check registry if Member resource doesn't exist yet
    if (exists<MembershipRegistry>(registry_addr)) {
        let registry = borrow_global<MembershipRegistry>(registry_addr);
        if (aptos_framework::ordered_map::contains(&registry.registry, &addr)) {
            let stored_role = aptos_framework::ordered_map::borrow(&registry.registry, &addr);
            return role_to_u8(*stored_role) == role
        }
    };
    false
}

/// Check if an address has a specific role (simplified - checks Member resource only)
public fun has_role(addr: address, role: u8): bool {
    if (exists<Member>(addr)) {
        let member = borrow_global<Member>(addr);
        return role_to_u8(member.role) == role
    };
    false
}

/// Get role of a member (checks Member resource only)
#[view]
public fun get_role(addr: address): option::Option<u8> {
    if (exists<Member>(addr)) {
        let member = borrow_global<Member>(addr);
        return option::some(role_to_u8(member.role))
    };
    option::none()
}

/// Get role of a member with registry address
#[view]
public fun get_role_with_registry(addr: address, registry_addr: address): option::Option<u8> {
    if (exists<Member>(addr)) {
        let member = borrow_global<Member>(addr);
        return option::some(role_to_u8(member.role))
    };
    // Check registry if Member resource doesn't exist yet
    if (exists<MembershipRegistry>(registry_addr)) {
        let registry = borrow_global<MembershipRegistry>(registry_addr);
        if (aptos_framework::ordered_map::contains(&registry.registry, &addr)) {
            let role = aptos_framework::ordered_map::borrow(&registry.registry, &addr);
            return option::some(role_to_u8(*role))
        }
    };
    option::none()
}

/// List all members
/// Returns vector of member addresses, optionally filtered by role
/// Note: OrderedMap supports iteration via keys_values()
#[view]
public fun list_members(registry_addr: address, role_filter: u8): vector<address> {
    let result = vector::empty<address>();
    if (!exists<MembershipRegistry>(registry_addr)) {
        return result
    };
    let registry = borrow_global<MembershipRegistry>(registry_addr);
    let keys = aptos_framework::ordered_map::keys(&registry.registry);
    
    // Use 255 as sentinel value for "no filter"
    let filter_active = role_filter != 255;
    let i = 0;
    let len = vector::length(&keys);
    while (i < len) {
        let addr = *vector::borrow(&keys, i);
        if (filter_active) {
            let role = aptos_framework::ordered_map::borrow(&registry.registry, &addr);
            let role_u8 = role_to_u8(*role);
            if (role_u8 == role_filter) {
                vector::push_back(&mut result, addr);
            }
        } else {
            vector::push_back(&mut result, addr);
        };
        i = i + 1;
    };
    result
}

/// Get member count
#[view]
public fun get_member_count(registry_addr: address): u64 {
    if (!exists<MembershipRegistry>(registry_addr)) {
        return 0
    };
    let registry = borrow_global<MembershipRegistry>(registry_addr);
    aptos_framework::ordered_map::length(&registry.registry)
}

/// Get member count by role
#[view]
public fun get_member_count_by_role(registry_addr: address, role: u8): u64 {
    let count = 0;
    if (!exists<MembershipRegistry>(registry_addr)) {
        return count
    };
    let registry = borrow_global<MembershipRegistry>(registry_addr);
    let keys = aptos_framework::ordered_map::keys(&registry.registry);
    let i = 0;
    let len = vector::length(&keys);
    while (i < len) {
        let addr = *vector::borrow(&keys, i);
        let member_role = aptos_framework::ordered_map::borrow(&registry.registry, &addr);
        if (role_to_u8(*member_role) == role) {
            count = count + 1;
        };
        i = i + 1;
    };
    count
}

/// Check if address is a member (checks Member resource only)
#[view]
public fun is_member(addr: address): bool {
    exists<Member>(addr)
}

/// Check if address is a member (with registry check)
#[view]
public fun is_member_with_registry(addr: address, registry_addr: address): bool {
    if (exists<Member>(addr)) {
        return true
    };
    // Check registry
    if (exists<MembershipRegistry>(registry_addr)) {
        let registry = borrow_global<MembershipRegistry>(registry_addr);
        return aptos_framework::ordered_map::contains(&registry.registry, &addr)
    };
    false
}

/// Check if MembershipRegistry exists (for cross-module access)
#[view]
public fun exists_membership_registry(registry_addr: address): bool {
    exists<MembershipRegistry>(registry_addr)
}

/// Helper: Convert role enum to u8
public fun role_to_u8(role: Role): u8 {
    match (role) {
        Role::Admin => 0,
        Role::Borrower => 1,
        Role::Depositor => 2,
        Role::Validator => 3,
    }
}

/// Get Validator role as u8 (helper for cross-module access)
public fun validator_role_u8(): u8 {
    3 // Role::Validator = 3
}

/// Helper: Convert u8 to role enum
fun role_from_u8(role: u8): Role {
    if (role == 0) {
        Role::Admin
    } else if (role == 1) {
        Role::Borrower
    } else if (role == 2) {
        Role::Depositor
    } else if (role == 3) {
        Role::Validator
    } else {
        abort error::invalid_argument(E_INVALID_ROLE)
    }
}

#[test_only]
public fun initialize_for_test(admin: &signer) {
    let admin_addr = signer::address_of(admin);
    if (!exists<MembershipRegistry>(admin_addr)) {
        initialize(admin);
    };
}


/// Helper: remove mapping once request resolved
fun remove_request_mapping(mapping: &mut aptos_framework::ordered_map::OrderedMap<address, u64>, addr: address) {
    if (aptos_framework::ordered_map::contains(mapping, &addr)) {
        aptos_framework::ordered_map::remove(mapping, &addr);
    };
}

/// Helper: add member directly to registry (without requiring admin signer)
fun register_member_in_registry(registry_addr: address, member_addr: address, role: Role) acquires MembershipRegistry {
    let registry = borrow_global_mut<MembershipRegistry>(registry_addr);
    assert!(!aptos_framework::ordered_map::contains(&registry.registry, &member_addr), error::already_exists(E_MEMBER_ALREADY_EXISTS));
    aptos_framework::ordered_map::add(&mut registry.registry, member_addr, role);
    registry.counter = registry.counter + 1;

    event::emit(MemberRegisteredEvent {
        member: member_addr,
        role: role_to_u8(role),
    });
}

/// Helper: convert request status to u8
fun request_status_to_u8(status: RequestStatus): u8 {
    match (status) {
        RequestStatus::Pending => 0,
        RequestStatus::Approved => 1,
        RequestStatus::Rejected => 2,
    }
}

}
