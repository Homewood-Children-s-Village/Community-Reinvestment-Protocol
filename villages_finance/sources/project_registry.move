module villages_finance::project_registry {

use std::signer;
use std::error;
use std::string;
use std::vector;
use aptos_framework::event;
use aptos_framework::big_ordered_map;
use villages_finance::members;
use villages_finance::admin;
use villages_finance::registry_config;

/// Error codes
const E_NOT_INITIALIZED: u64 = 1;
const E_PROJECT_NOT_FOUND: u64 = 2;
const E_NOT_AUTHORIZED: u64 = 3;
const E_INVALID_STATUS: u64 = 4;
const E_INVALID_REGISTRY: u64 = 5;
const E_NOT_ADMIN: u64 = 6;
const E_NOT_MEMBER: u64 = 7;

/// Project status
public enum ProjectStatus has copy, drop, store {
    Proposed,
    Approved,
    Active,
    Completed,
    Cancelled,
}

/// Project struct
struct Project has store {
    proposer: address,
    metadata_cid: vector<u8>, // IPFS CID
    target_usdc: u64,
    target_hours: u64,
    is_grant: bool,
    status: ProjectStatus,
    created_at: u64,
}

/// Project registry object
struct ProjectRegistry has key {
    projects: aptos_framework::big_ordered_map::BigOrderedMap<u64, Project>,
    project_counter: u64,
}

/// Events
#[event]
struct ProjectProposedEvent has drop, store {
    project_id: u64,
    proposer: address,
    target_usdc: u64,
    target_hours: u64,
}

#[event]
struct ProjectApprovedEvent has drop, store {
    project_id: u64,
    approver: address,
}

#[event]
struct ProjectStatusUpdatedEvent has drop, store {
    project_id: u64,
    old_status: u8,
    new_status: u8,
    updated_by: address,
}

/// Initialize project registry
/// Idempotent: safe to call multiple times
/// Note: Uses new_with_type_size_hints because Project contains vector<u8> (variable-sized)
public fun initialize(admin: &signer) {
    let admin_addr = signer::address_of(admin);
    // Explicit check for idempotency - no assert, just conditional creation
    if (!exists<ProjectRegistry>(admin_addr)) {
        move_to(admin, ProjectRegistry {
            // Use new_with_type_size_hints for variable-sized value type (Project contains vector<u8>)
            // Size calculation: address (16) + 2 u64s (16) + bool (1) + enum (1) + vector<u8> (50-200) + overhead = ~100-300 bytes
            // Increased max to 2048 to accommodate larger IPFS CIDs
            projects: aptos_framework::big_ordered_map::new_with_type_size_hints<u64, Project>(8, 8, 100, 2048),
            project_counter: 0,
        });
    };
}

/// Propose a new project
public entry fun propose_project(
    proposer: &signer,
    metadata_cid: vector<u8>,
    target_usdc: u64,
    target_hours: u64,
    is_grant: bool,
    registry_addr: address,
    members_registry_addr: address,
) acquires ProjectRegistry {
    let proposer_addr = signer::address_of(proposer);
    
    // Validate registries
    assert!(exists<ProjectRegistry>(registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    assert!(registry_config::validate_members_registry(members_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    
    // Check proposer is a member
    assert!(
        members::is_member_with_registry(proposer_addr, members_registry_addr),
        error::permission_denied(E_NOT_MEMBER)
    );
    
    assert!(exists<ProjectRegistry>(registry_addr), error::not_found(E_NOT_INITIALIZED));
    
    let registry = borrow_global_mut<ProjectRegistry>(registry_addr);
    let project_id = registry.project_counter;
    registry.project_counter = registry.project_counter + 1;
    
    let project = Project {
        proposer: proposer_addr,
        metadata_cid,
        target_usdc,
        target_hours,
        is_grant,
        status: ProjectStatus::Proposed,
        created_at: project_id, // In production, use timestamp
    };
    
    aptos_framework::big_ordered_map::add(&mut registry.projects, project_id, project);

    event::emit(ProjectProposedEvent {
        project_id,
        proposer: proposer_addr,
        target_usdc,
        target_hours,
    });
}

/// Approve a project (governance/admin only)
public entry fun approve_project(
    approver: &signer,
    project_id: u64,
    registry_addr: address,
) acquires ProjectRegistry {
    let approver_addr = signer::address_of(approver);
    
    // Verify admin role
    assert!(admin::has_admin_capability(approver_addr), error::permission_denied(E_NOT_ADMIN));
    
    // Validate registry exists
    assert!(exists<ProjectRegistry>(registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    let registry = borrow_global_mut<ProjectRegistry>(registry_addr);
    
    assert!(aptos_framework::big_ordered_map::contains(&registry.projects, &project_id), 
        error::not_found(E_PROJECT_NOT_FOUND));
    
    let project = aptos_framework::big_ordered_map::borrow_mut(&mut registry.projects, &project_id);
    assert!(project.status is ProjectStatus::Proposed, error::invalid_state(E_INVALID_STATUS));
    
    project.status = ProjectStatus::Approved;

    event::emit(ProjectApprovedEvent {
        project_id,
        approver: approver_addr,
    });
}

/// Update project status (admin only)
public entry fun update_status(
    admin: &signer,
    project_id: u64,
    new_status: u8,
    registry_addr: address,
) acquires ProjectRegistry {
    let admin_addr = signer::address_of(admin);
    
    // Verify admin role
    assert!(admin::has_admin_capability(admin_addr), error::permission_denied(E_NOT_ADMIN));
    
    // Validate registry exists
    assert!(exists<ProjectRegistry>(registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    let registry = borrow_global_mut<ProjectRegistry>(registry_addr);
    
    assert!(aptos_framework::big_ordered_map::contains(&registry.projects, &project_id), 
        error::not_found(E_PROJECT_NOT_FOUND));
    
    let project = aptos_framework::big_ordered_map::borrow_mut(&mut registry.projects, &project_id);
    let old_status = project.status;
    let old_status_u8 = status_to_u8(old_status);
    
    project.status = status_from_u8(new_status);

    event::emit(ProjectStatusUpdatedEvent {
        project_id,
        old_status: old_status_u8,
        new_status,
        updated_by: admin_addr,
    });
}

/// Get project details (view function)
#[view]
public fun get_project(project_id: u64, registry_addr: address): (address, vector<u8>, u64, u64, bool, u8, u64) {
    if (!exists<ProjectRegistry>(registry_addr)) {
        abort error::not_found(E_NOT_INITIALIZED)
    };
    let registry = borrow_global<ProjectRegistry>(registry_addr);
    if (!aptos_framework::big_ordered_map::contains(&registry.projects, &project_id)) {
        abort error::not_found(E_PROJECT_NOT_FOUND)
    };
    let project = aptos_framework::big_ordered_map::borrow(&registry.projects, &project_id);
    (project.proposer, project.metadata_cid, project.target_usdc, project.target_hours, 
     project.is_grant, status_to_u8(project.status), project.created_at)
}

/// List all projects (view function)
/// Returns vector of project IDs, optionally filtered by status
/// Note: For MVP, iterates through project_counter. For scale, consider pagination.
#[view]
public fun list_projects(registry_addr: address, status_filter: u8): vector<u64> {
    let result = vector::empty<u64>();
    if (!exists<ProjectRegistry>(registry_addr)) {
        return result
    };
    let registry = borrow_global<ProjectRegistry>(registry_addr);
    let counter = registry.project_counter;
    let i = 0;
    // Use 255 as sentinel value for "no filter"
    let filter_active = status_filter != 255;
    while (i < counter) {
        if (aptos_framework::big_ordered_map::contains(&registry.projects, &i)) {
            if (filter_active) {
                let project = aptos_framework::big_ordered_map::borrow(&registry.projects, &i);
                let project_status = status_to_u8(project.status);
                if (project_status == status_filter) {
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

/// List projects by proposer (view function)
/// Returns vector of project IDs created by a specific proposer
#[view]
public fun list_projects_by_proposer(proposer: address, registry_addr: address): vector<u64> {
    let result = vector::empty<u64>();
    if (!exists<ProjectRegistry>(registry_addr)) {
        return result
    };
    let registry = borrow_global<ProjectRegistry>(registry_addr);
    let counter = registry.project_counter;
    let i = 0;
    while (i < counter) {
        if (aptos_framework::big_ordered_map::contains(&registry.projects, &i)) {
            let project = aptos_framework::big_ordered_map::borrow(&registry.projects, &i);
            if (project.proposer == proposer) {
                vector::push_back(&mut result, i);
            }
        };
        i = i + 1;
    };
    result
}

/// Get borrower projects (view function)
/// Returns vector of project IDs for a specific borrower/proposer
/// Note: This is an alias for list_projects_by_proposer for clarity
#[view]
public fun get_borrower_projects(borrower: address, registry_addr: address): vector<u64> {
    list_projects_by_proposer(borrower, registry_addr)
}

/// Check if ProjectRegistry exists (view function for cross-module access)
#[view]
public fun exists_project_registry(registry_addr: address): bool {
    exists<ProjectRegistry>(registry_addr)
}

/// Check if project exists (view function for cross-module access)
#[view]
public fun project_exists(project_id: u64, registry_addr: address): bool {
    if (!exists<ProjectRegistry>(registry_addr)) {
        return false
    };
    let registry = borrow_global<ProjectRegistry>(registry_addr);
    aptos_framework::big_ordered_map::contains(&registry.projects, &project_id)
}

/// Get project target_usdc (view function for cross-module access)
#[view]
public fun get_project_target_usdc(project_id: u64, registry_addr: address): u64 {
    let (_, _, target_usdc, _, _, _, _) = get_project(project_id, registry_addr);
    target_usdc
}

/// Get project proposer (view function for cross-module access)
#[view]
public fun get_project_proposer(project_id: u64, registry_addr: address): address {
    let (proposer, _, _, _, _, _, _) = get_project(project_id, registry_addr);
    proposer
}

/// Helper: Convert status enum to u8
fun status_to_u8(status: ProjectStatus): u8 {
    match (status) {
        ProjectStatus::Proposed => 0,
        ProjectStatus::Approved => 1,
        ProjectStatus::Active => 2,
        ProjectStatus::Completed => 3,
        ProjectStatus::Cancelled => 4,
    }
}

/// Helper: Convert u8 to status enum
fun status_from_u8(status: u8): ProjectStatus {
    if (status == 0) {
        ProjectStatus::Proposed
    } else if (status == 1) {
        ProjectStatus::Approved
    } else if (status == 2) {
        ProjectStatus::Active
    } else if (status == 3) {
        ProjectStatus::Completed
    } else if (status == 4) {
        ProjectStatus::Cancelled
    } else {
        abort error::invalid_argument(E_INVALID_STATUS)
    }
}

#[test_only]
public fun initialize_for_test(admin: &signer) {
    admin::initialize_for_test(admin);
    let admin_addr = signer::address_of(admin);
    if (!exists<ProjectRegistry>(admin_addr)) {
        initialize(admin);
    };
}

}
