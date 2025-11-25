module villages_finance::governance {

use std::signer;
use std::error;
use std::vector;
use std::option;
use aptos_framework::event;
use aptos_framework::primary_fungible_store;
use aptos_framework::ordered_map;
use aptos_framework::big_ordered_map;
use aptos_framework::account;
use aptos_framework::resource_account;
use villages_finance::admin;
use villages_finance::members;
use villages_finance::token;
use villages_finance::event_history;

/// Error codes
const E_NOT_INITIALIZED: u64 = 1;
const E_PROPOSAL_NOT_FOUND: u64 = 2;
const E_INVALID_STATUS: u64 = 3;
const E_NOT_AUTHORIZED: u64 = 4;
const E_INSUFFICIENT_VOTES: u64 = 5;
const E_ALREADY_VOTED: u64 = 6;
const E_NOT_MEMBER: u64 = 7;
const E_INVALID_VOTING_MECHANISM: u64 = 8;
const E_INVALID_ACTION: u64 = 9;
const E_INVALID_REGISTRY: u64 = 10;

/// Proposal status
public enum ProposalStatus has copy, drop, store {
    Pending,
    Active,
    Passed,
    Rejected,
    Executed,
}

/// Vote choice
public enum VoteChoice has copy, drop, store {
    Yes,
    No,
    Abstain,
}

/// Voting mechanism type
public enum VotingMechanism has copy, drop, store {
    Simple,        // One vote per address
    TokenWeighted, // Voting power = token balance
    Quadratic,     // Voting power = sqrt(token balance)
    Conviction,    // Time-weighted voting (future)
}

/// Proposal action type (for execution)
public enum ProposalAction has copy, drop, store {
    UpgradeModule(vector<u8>),
    UpdateParameter(vector<u8>, u64),
    PauseModule(vector<u8>),
    UnpauseModule(vector<u8>),
    TransferAdmin(address),
    UpdateSystemParameter(vector<u8>, u64), // For parameter registry updates
}

/// Governance proposal
struct GovernanceProposal has store {
    proposer: address,
    title: vector<u8>,
    description: vector<u8>,
    status: ProposalStatus,
    votes_yes: u64,
    votes_no: u64,
    votes_abstain: u64,
    voters: aptos_framework::big_ordered_map::BigOrderedMap<address, bool>,
    voter_power: aptos_framework::big_ordered_map::BigOrderedMap<address, u64>, // Track voting power per voter
    threshold: u64,
    voting_mechanism: VotingMechanism,
    action: option::Option<ProposalAction>,
    created_at: u64,
    members_registry_addr: address, // For member eligibility checks
    token_admin_addr: address,       // For token balance queries
}

/// Governance registry
struct Governance has key {
    proposals: aptos_framework::ordered_map::OrderedMap<u64, GovernanceProposal>,
    proposal_counter: u64,
    resource_account_signer: option::Option<account::SignerCapability>, // For module upgrades
    resource_account_address: option::Option<address>, // Store resource account address for reference
}

/// Events
#[event]
struct ProposalCreatedEvent has drop, store {
    proposal_id: u64,
    proposer: address,
    title: vector<u8>,
}

#[event]
struct VoteCastEvent has drop, store {
    proposal_id: u64,
    voter: address,
    choice: u8,
}

#[event]
struct ProposalExecutedEvent has drop, store {
    proposal_id: u64,
    executor: address,
}

#[event]
struct ModuleUpgradedEvent has drop, store {
    proposal_id: u64,
    module_name: vector<u8>,
}

#[event]
struct ResourceAccountCreatedEvent has drop, store {
    resource_account: address,
    created_by: address,
}

/// Initialize governance
public fun initialize(
    admin: &signer,
    members_registry_addr: address,
    token_admin_addr: address,
) {
    let admin_addr = signer::address_of(admin);
    assert!(!exists<Governance>(admin_addr), error::already_exists(1));
    
    move_to(admin, Governance {
        proposals: aptos_framework::ordered_map::new(),
        proposal_counter: 0,
        resource_account_signer: option::none(),
        resource_account_address: option::none(),
    });
}

/// Create a resource account for module deployment (admin/governance only)
/// This creates a resource account and stores its signer capability for future upgrades
public entry fun create_resource_account_for_deployment(
    admin: &signer,
    seed: vector<u8>,
    gov_addr: address,
) acquires Governance {
    let admin_addr = signer::address_of(admin);
    
    // Validate registry exists
    assert!(exists<Governance>(gov_addr), error::invalid_argument(E_INVALID_REGISTRY));
    let governance = borrow_global_mut<Governance>(gov_addr);
    
    // Verify admin has permission (check if admin or governance approved)
    // For MVP, require admin capability
    assert!(admin::has_admin_capability(admin_addr), error::permission_denied(E_NOT_AUTHORIZED));
    
    // Check if signer capability already exists
    assert!(option::is_none(&governance.resource_account_signer), error::already_exists(1));
    
    // Create resource account
    let (resource_signer, resource_signer_cap) = account::create_resource_account(admin, seed);
    let resource_addr = signer::address_of(&resource_signer);
    
    // Store the signer capability and address for future upgrades
    governance.resource_account_signer = option::some(resource_signer_cap);
    governance.resource_account_address = option::some(resource_addr);
    
    // Transfer signer to governance (so it can be used for upgrades)
    // Note: In production, this would be stored securely
    // Signer is automatically destroyed when it goes out of scope
    
    event::emit(ResourceAccountCreatedEvent {
        resource_account: resource_addr,
        created_by: admin_addr,
    });
}

/// Store resource account signer capability (for module upgrades)
/// Used when resource account is created externally
/// Note: SignerCapability cannot be passed as a transaction parameter.
/// Use create_resource_account_for_deployment instead, or call this function
/// from within the module that creates the resource account.
/// This function is kept as internal for potential future use.
fun store_resource_account_signer_internal(
    signer_cap: account::SignerCapability,
    gov_addr: address,
) acquires Governance {
    // Validate registry exists
    assert!(exists<Governance>(gov_addr), error::invalid_argument(E_INVALID_REGISTRY));
    let governance = borrow_global_mut<Governance>(gov_addr);
    assert!(option::is_none(&governance.resource_account_signer), error::already_exists(1));
    
    // Store the signer capability
    governance.resource_account_signer = option::some(signer_cap);
}

/// Create a governance proposal
public entry fun create_proposal(
    proposer: &signer,
    gov_addr: address,
    title: vector<u8>,
    description: vector<u8>,
    threshold: u64,
    voting_mechanism: u8,
    action_type: u8,
    action_data: vector<u8>,
    members_registry_addr: address,
    token_admin_addr: address,
) acquires Governance {
    let proposer_addr = signer::address_of(proposer);
    
    // Validate registry exists
    assert!(exists<Governance>(gov_addr), error::invalid_argument(E_INVALID_REGISTRY));
    
    // Check proposer is a member
    assert!(members::is_member_with_registry(proposer_addr, members_registry_addr), 
        error::permission_denied(E_NOT_MEMBER));
    
    assert!(exists<Governance>(gov_addr), error::not_found(E_NOT_INITIALIZED));
    
    let governance = borrow_global_mut<Governance>(gov_addr);
    let proposal_id = governance.proposal_counter;
    governance.proposal_counter = governance.proposal_counter + 1;
    
    let mechanism = voting_mechanism_from_u8(voting_mechanism);
    let action = decode_action(action_type, action_data);
    
    let proposal = GovernanceProposal {
        proposer: proposer_addr,
        title,
        description,
        status: ProposalStatus::Pending,
        votes_yes: 0,
        votes_no: 0,
        votes_abstain: 0,
        voters: aptos_framework::big_ordered_map::new(),
        voter_power: aptos_framework::big_ordered_map::new(),
        threshold,
        voting_mechanism: mechanism,
        action,
        created_at: proposal_id, // In production, use timestamp
        members_registry_addr,
        token_admin_addr,
    };
    
    aptos_framework::ordered_map::add(&mut governance.proposals, proposal_id, proposal);

    event::emit(ProposalCreatedEvent {
        proposal_id,
        proposer: proposer_addr,
        title,
    });
    
    // Record in event history
    event_history::record_user_event(
        proposer_addr,
        event_history::event_type_proposal(),
        option::none(),
        option::none(),
        option::some(proposal_id),
        option::none(),
        option::none(),
        option::none(),
    );
}

/// Activate a proposal (moves from Pending to Active)
public entry fun activate_proposal(
    admin: &signer,
    proposal_id: u64,
    gov_addr: address,
) acquires Governance {
    let admin_addr = signer::address_of(admin);
    
    // Validate registry exists
    assert!(exists<Governance>(gov_addr), error::invalid_argument(E_INVALID_REGISTRY));
    let governance = borrow_global_mut<Governance>(gov_addr);
    
    assert!(aptos_framework::ordered_map::contains(&governance.proposals, &proposal_id), 
        error::not_found(E_PROPOSAL_NOT_FOUND));
    
    let proposal = aptos_framework::ordered_map::borrow_mut(&mut governance.proposals, &proposal_id);
    assert!(proposal.status is ProposalStatus::Pending, error::invalid_state(E_INVALID_STATUS));
    
    proposal.status = ProposalStatus::Active;
}

/// Calculate voting power based on mechanism
fun calculate_voting_power(
    voter_addr: address,
    mechanism: VotingMechanism,
    token_admin_addr: address,
): u64 {
    match (mechanism) {
        VotingMechanism::Simple => 1,
        VotingMechanism::TokenWeighted => {
            // Get token balance for voting power
            let metadata = token::get_metadata(token_admin_addr);
            aptos_framework::primary_fungible_store::balance(voter_addr, metadata)
        },
        VotingMechanism::Quadratic => {
            // Quadratic: sqrt(token_balance)
            let balance = calculate_voting_power(voter_addr, VotingMechanism::TokenWeighted, token_admin_addr);
            integer_square_root(balance)
        },
        VotingMechanism::Conviction => {
            // Conviction voting (time-weighted) - simplified for now
            calculate_voting_power(voter_addr, VotingMechanism::TokenWeighted, token_admin_addr)
        },
    }
}

/// Integer square root (Babylonian method)
fun integer_square_root(n: u64): u64 {
    if (n == 0) {
        return 0
    };
    if (n < 4) {
        return 1
    };
    let x = n;
    let y = (x + 1) / 2;
    while (y < x) {
        x = y;
        y = (x + n / x) / 2;
    };
    x
}

/// Cast a vote on a proposal
public entry fun vote(
    voter: &signer,
    proposal_id: u64,
    choice: u8,
    gov_addr: address,
) acquires Governance {
    let voter_addr = signer::address_of(voter);
    
    // Validate registry exists
    assert!(exists<Governance>(gov_addr), error::invalid_argument(E_INVALID_REGISTRY));
    let governance = borrow_global_mut<Governance>(gov_addr);
    
    assert!(aptos_framework::ordered_map::contains(&governance.proposals, &proposal_id), 
        error::not_found(E_PROPOSAL_NOT_FOUND));
    
    let proposal = aptos_framework::ordered_map::borrow_mut(&mut governance.proposals, &proposal_id);
    
    // CHECK DUPLICATE VOTE FIRST (before status check) - ensures correct error code
    assert!(!aptos_framework::big_ordered_map::contains(&proposal.voters, &voter_addr), 
        error::already_exists(E_ALREADY_VOTED));
    
    // THEN check status
    assert!(proposal.status is ProposalStatus::Active, error::invalid_state(E_INVALID_STATUS));
    
    // Check voter is a member
    assert!(members::is_member_with_registry(voter_addr, proposal.members_registry_addr), 
        error::permission_denied(E_NOT_MEMBER));
    
    // Calculate voting power based on mechanism
    let voting_power = calculate_voting_power(voter_addr, proposal.voting_mechanism, proposal.token_admin_addr);
    assert!(voting_power > 0, error::invalid_argument(E_INSUFFICIENT_VOTES));
    
    // Record vote and voting power
    aptos_framework::big_ordered_map::add(&mut proposal.voters, voter_addr, true);
    aptos_framework::big_ordered_map::add(&mut proposal.voter_power, voter_addr, voting_power);
    
    let vote_choice = choice_from_u8(choice);
    match (vote_choice) {
        VoteChoice::Yes => proposal.votes_yes = proposal.votes_yes + voting_power,
        VoteChoice::No => proposal.votes_no = proposal.votes_no + voting_power,
        VoteChoice::Abstain => proposal.votes_abstain = proposal.votes_abstain + voting_power,
    };
    
    // Check if threshold met
    if (proposal.votes_yes >= proposal.threshold) {
        proposal.status = ProposalStatus::Passed;
    } else if (proposal.votes_no > proposal.votes_yes) {
        proposal.status = ProposalStatus::Rejected;
    };

    event::emit(VoteCastEvent {
        proposal_id,
        voter: voter_addr,
        choice,
    });
    
    // Record in event history
    event_history::record_user_event(
        voter_addr,
        event_history::event_type_vote(),
        option::none(),
        option::none(),
        option::some(proposal_id),
        option::none(),
        option::none(),
        option::some(choice),
    );
}

/// Execute proposal action
fun execute_action(
    executor: &signer,
    action: &ProposalAction,
    gov_addr: address,
) {
    let executor_addr = signer::address_of(executor);
    match (action) {
        ProposalAction::PauseModule(module_name) => {
            admin::pause_module_internal(executor, *module_name, gov_addr);
        },
        ProposalAction::UnpauseModule(module_name) => {
            admin::unpause_module_internal(executor, *module_name, gov_addr);
        },
        ProposalAction::UpdateParameter(_param_type, _value) => {
            // Generic parameter update - would need specific implementation per parameter
            // For now, this is a placeholder
        },
        ProposalAction::UpdateSystemParameter(_param_name, _value) => {
            // System parameter update handled via parameters module
            // Call parameters::update_parameter_via_governance() separately
        },
        ProposalAction::TransferAdmin(new_admin) => {
            admin::transfer_governance_rights_internal(executor, *new_admin, gov_addr);
        },
        ProposalAction::UpgradeModule(_) => {
            // Module upgrade handled separately via upgrade_module()
        },
    }
}

/// Execute an approved proposal
public entry fun execute_proposal(
    executor: &signer,
    proposal_id: u64,
    gov_addr: address,
) acquires Governance {
    let executor_addr = signer::address_of(executor);
    
    // Validate registry exists
    assert!(exists<Governance>(gov_addr), error::invalid_argument(E_INVALID_REGISTRY));
    let governance = borrow_global_mut<Governance>(gov_addr);
    
    assert!(aptos_framework::ordered_map::contains(&governance.proposals, &proposal_id), 
        error::not_found(E_PROPOSAL_NOT_FOUND));
    
    let proposal = aptos_framework::ordered_map::borrow_mut(&mut governance.proposals, &proposal_id);
    assert!(proposal.status is ProposalStatus::Passed, error::invalid_state(E_INVALID_STATUS));
    
    // Execute proposal action if present
    if (option::is_some(&proposal.action)) {
        let action = option::borrow(&proposal.action);
        execute_action(executor, action, gov_addr);
    };
    
    proposal.status = ProposalStatus::Executed;

    event::emit(ProposalExecutedEvent {
        proposal_id,
        executor: executor_addr,
    });
}

/// Upgrade module using resource account signer capability
public entry fun upgrade_module(
    executor: &signer,
    proposal_id: u64,
    module_name: vector<u8>,
    gov_addr: address,
) acquires Governance {
    let executor_addr = signer::address_of(executor);
    
    // Validate registry exists
    assert!(exists<Governance>(gov_addr), error::invalid_argument(E_INVALID_REGISTRY));
    let governance = borrow_global_mut<Governance>(gov_addr);
    
    assert!(aptos_framework::ordered_map::contains(&governance.proposals, &proposal_id), 
        error::not_found(E_PROPOSAL_NOT_FOUND));
    
    let proposal = aptos_framework::ordered_map::borrow(&governance.proposals, &proposal_id);
    assert!(proposal.status is ProposalStatus::Executed, error::invalid_state(E_INVALID_STATUS));
    
    // Check if action is UpgradeModule
    assert!(option::is_some(&proposal.action), error::invalid_argument(E_INVALID_ACTION));
    let action = option::borrow(&proposal.action);
    assert!(*action is ProposalAction::UpgradeModule, error::invalid_argument(E_INVALID_ACTION));
    
    // Verify signer capability exists
    assert!(option::is_some(&governance.resource_account_signer), error::not_found(E_NOT_AUTHORIZED));
    
    // Get the signer capability
    // Note: For MVP, we verify capability exists but don't extract it
    // In production, would extract and use for module upgrade:
    // let signer_cap = option::extract(&mut governance.resource_account_signer);
    // Then use it for code::publish_package_txn() with resource account signer
    // After upgrade, would store it back:
    // governance.resource_account_signer = option::some(signer_cap);
    
    // For MVP, we just verify the capability exists and emit event
    // Actual upgrade requires:
    // 1. Package metadata (name, version, etc.)
    // 2. Compiled bytecode
    // 3. Call to code::publish_package_txn() with resource account signer

    event::emit(ModuleUpgradedEvent {
        proposal_id,
        module_name,
    });
}

/// Check if Governance exists (view function for cross-module access)
#[view]
public fun exists_governance(gov_addr: address): bool {
    exists<Governance>(gov_addr)
}

/// Get resource account address (view function)
/// Returns the address of the resource account if it has been created
#[view]
public fun get_resource_account_address(gov_addr: address): option::Option<address> acquires Governance {
    if (!exists<Governance>(gov_addr)) {
        return option::none()
    };
    let governance = borrow_global<Governance>(gov_addr);
    *&governance.resource_account_address
}

/// Get proposal details (view function)
#[view]
public fun get_proposal(proposal_id: u64, gov_addr: address): (address, vector<u8>, u8, u64, u64, u64, u64, u8) {
    if (!exists<Governance>(gov_addr)) {
        abort error::not_found(E_NOT_INITIALIZED)
    };
    let governance = borrow_global<Governance>(gov_addr);
    if (!aptos_framework::ordered_map::contains(&governance.proposals, &proposal_id)) {
        abort error::not_found(E_PROPOSAL_NOT_FOUND)
    };
    let proposal = aptos_framework::ordered_map::borrow(&governance.proposals, &proposal_id);
    (proposal.proposer, proposal.title, status_to_u8(proposal.status), 
     proposal.votes_yes, proposal.votes_no, proposal.votes_abstain, proposal.threshold,
     voting_mechanism_to_u8(proposal.voting_mechanism))
}

/// List all proposals (view function)
/// Returns vector of proposal IDs, optionally filtered by status
/// Note: For MVP, iterates through proposal_counter. For scale, consider pagination.
#[view]
public fun list_proposals(gov_addr: address, status_filter: u8): vector<u64> {
    let result = vector::empty<u64>();
    if (!exists<Governance>(gov_addr)) {
        return result
    };
    let governance = borrow_global<Governance>(gov_addr);
    let counter = governance.proposal_counter;
    let i = 0;
    // Use 255 as sentinel value for "no filter"
    let filter_active = status_filter != 255;
    while (i < counter) {
        if (aptos_framework::ordered_map::contains(&governance.proposals, &i)) {
            if (filter_active) {
                let proposal = aptos_framework::ordered_map::borrow(&governance.proposals, &i);
                let proposal_status = status_to_u8(proposal.status);
                if (proposal_status == status_filter) {
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

/// Get proposal summary with has_voted flag (view function)
#[view]
public fun get_proposal_summary(
    proposal_id: u64,
    voter_addr: address,
    gov_addr: address,
): (address, vector<u8>, u8, u64, u64, u64, u64, u8, bool) {
    if (!exists<Governance>(gov_addr)) {
        abort error::not_found(E_NOT_INITIALIZED)
    };
    let governance = borrow_global<Governance>(gov_addr);
    if (!aptos_framework::ordered_map::contains(&governance.proposals, &proposal_id)) {
        abort error::not_found(E_PROPOSAL_NOT_FOUND)
    };
    let proposal = aptos_framework::ordered_map::borrow(&governance.proposals, &proposal_id);
    let has_voted = aptos_framework::big_ordered_map::contains(&proposal.voters, &voter_addr);
    (proposal.proposer, proposal.title, status_to_u8(proposal.status),
     proposal.votes_yes, proposal.votes_no, proposal.votes_abstain, proposal.threshold,
     voting_mechanism_to_u8(proposal.voting_mechanism), has_voted)
}

/// Get voting power for a voter on a proposal (view function)
#[view]
public fun get_voting_power(
    voter_addr: address,
    proposal_id: u64,
    gov_addr: address,
): u64 {
    if (!exists<Governance>(gov_addr)) {
        return 0
    };
    let governance = borrow_global<Governance>(gov_addr);
    if (!aptos_framework::ordered_map::contains(&governance.proposals, &proposal_id)) {
        return 0
    };
    let proposal = aptos_framework::ordered_map::borrow(&governance.proposals, &proposal_id);
    if (aptos_framework::big_ordered_map::contains(&proposal.voter_power, &voter_addr)) {
        *aptos_framework::big_ordered_map::borrow(&proposal.voter_power, &voter_addr)
    } else {
        // Calculate potential voting power if not voted yet
        calculate_voting_power(voter_addr, proposal.voting_mechanism, proposal.token_admin_addr)
    }
}

/// Helper: Convert choice enum to u8
fun choice_from_u8(choice: u8): VoteChoice {
    if (choice == 0) {
        VoteChoice::Yes
    } else if (choice == 1) {
        VoteChoice::No
    } else if (choice == 2) {
        VoteChoice::Abstain
    } else {
        abort error::invalid_argument(1)
    }
}

/// Helper: Convert status enum to u8
fun status_to_u8(status: ProposalStatus): u8 {
    match (status) {
        ProposalStatus::Pending => 0,
        ProposalStatus::Active => 1,
        ProposalStatus::Passed => 2,
        ProposalStatus::Rejected => 3,
        ProposalStatus::Executed => 4,
    }
}

/// Helper: Convert voting mechanism enum to u8
fun voting_mechanism_to_u8(mechanism: VotingMechanism): u8 {
    match (mechanism) {
        VotingMechanism::Simple => 0,
        VotingMechanism::TokenWeighted => 1,
        VotingMechanism::Quadratic => 2,
        VotingMechanism::Conviction => 3,
    }
}

/// Helper: Convert u8 to voting mechanism enum
fun voting_mechanism_from_u8(mechanism: u8): VotingMechanism {
    if (mechanism == 0) {
        VotingMechanism::Simple
    } else if (mechanism == 1) {
        VotingMechanism::TokenWeighted
    } else if (mechanism == 2) {
        VotingMechanism::Quadratic
    } else if (mechanism == 3) {
        VotingMechanism::Conviction
    } else {
        abort error::invalid_argument(E_INVALID_VOTING_MECHANISM)
    }
}

/// Helper: Decode action from type and data
fun decode_action(action_type: u8, data: vector<u8>): option::Option<ProposalAction> {
    if (action_type == 0) {
        option::some(ProposalAction::UpgradeModule(data))
    } else if (action_type == 1) {
        // UpdateParameter: data should contain param_type and value
        // Simplified - would need proper encoding/decoding
        option::none<ProposalAction>()
    } else if (action_type == 2) {
        option::some(ProposalAction::PauseModule(data))
    } else if (action_type == 3) {
        option::some(ProposalAction::UnpauseModule(data))
    } else if (action_type == 4) {
        // TransferAdmin: data should be address bytes
        // Simplified - would need proper address decoding
        option::none<ProposalAction>()
    } else if (action_type == 5) {
        // UpdateSystemParameter: data should contain param_name and value
        // Simplified - would need proper encoding/decoding
        option::none<ProposalAction>()
    } else {
        option::none<ProposalAction>()
    }
}

#[test_only]
public fun initialize_for_test(admin: &signer, members_registry_addr: address, token_admin_addr: address) {
    admin::initialize_for_test(admin);
    let admin_addr = signer::address_of(admin);
    if (!exists<Governance>(admin_addr)) {
        initialize(admin, members_registry_addr, token_admin_addr);
    };
}

}
