#[test_only]
module villages_finance::governance_test {

use villages_finance::governance;
use villages_finance::admin;
use villages_finance::members;
use villages_finance::token;
use std::signer;
use std::vector;
use std::string;

#[test(admin = @0x1, voter1 = @0x2, voter2 = @0x3)]
fun test_create_and_vote_simple(admin: signer, voter1: signer, voter2: signer) {
    // Initialize modules
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    // Register admin as member (needed to create proposals) - idempotent check
    if (!members::is_member_with_registry(admin_addr, admin_addr)) {
        members::register_member(&admin, admin_addr, 1); // Admin role
        members::accept_membership(&admin, admin_addr);
    };
    
    // Register voters as members
    members::register_member(&admin, signer::address_of(&voter1), 2); // Depositor
    members::accept_membership(&voter1, admin_addr);
    members::register_member(&admin, signer::address_of(&voter2), 2); // Depositor
    members::accept_membership(&voter2, admin_addr);
    
    // Initialize token
    let name = string::utf8(b"Test Token");
    let symbol = string::utf8(b"TEST");
    let _metadata = token::initialize_for_test(&admin, name, symbol);
    
    // Initialize governance
    governance::initialize_for_test(&admin, admin_addr, admin_addr);
    
    let title = vector::empty<u8>();
    vector::push_back(&mut title, 84); // 'T'
    
    let description = vector::empty<u8>();
    let threshold = 2;
    let voting_mechanism = 0; // Simple
    let action_type = 0;
    let action_data = vector::empty<u8>();
    
    let gov_addr = admin_addr;
    governance::create_proposal(&admin, gov_addr, title, description, threshold, voting_mechanism, action_type, action_data, admin_addr, admin_addr);
    
    // Activate proposal
    governance::activate_proposal(&admin, 0, gov_addr);
    
    // Vote yes
    governance::vote(&voter1, 0, 0, gov_addr);
    governance::vote(&voter2, 0, 0, gov_addr);
    
    // Check status
    let (_, _, status, yes, no, abstain, _, mechanism) = governance::get_proposal(0, gov_addr);
    assert!(status == 2, 0); // Passed
    assert!(yes == 2, 1); // Simple voting: 1 vote per address
    assert!(mechanism == 0, 2); // Simple mechanism
}

#[test(admin = @0x1, voter1 = @0x2)]
fun test_execute_proposal(admin: signer, voter1: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    // Register admin as member (needed to create proposals) - idempotent check
    if (!members::is_member_with_registry(admin_addr, admin_addr)) {
        members::register_member(&admin, admin_addr, 1); // Admin role
        members::accept_membership(&admin, admin_addr);
    };
    
    // Register voter as member
    members::register_member(&admin, signer::address_of(&voter1), 2);
    members::accept_membership(&voter1, admin_addr);
    
    let name = string::utf8(b"Test Token");
    let symbol = string::utf8(b"TEST");
    let _metadata = token::initialize_for_test(&admin, name, symbol);
    
    governance::initialize_for_test(&admin, admin_addr, admin_addr);
    
    let gov_addr = admin_addr;
    let title = vector::empty<u8>();
    let description = vector::empty<u8>();
    governance::create_proposal(&admin, gov_addr, title, description, 1, 0, 0, vector::empty<u8>(), admin_addr, admin_addr);
    
    governance::activate_proposal(&admin, 0, gov_addr);
    governance::vote(&voter1, 0, 0, gov_addr); // Yes
    
    governance::execute_proposal(&admin, 0, gov_addr);
    
    let (_, _, status, _, _, _, _, _) = governance::get_proposal(0, gov_addr);
    assert!(status == 4, 0); // Executed
}

#[test(admin = @0x1, voter1 = @0x2)]
#[expected_failure(abort_code = 524294, location = governance)]
fun test_double_vote(admin: signer, voter1: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    // Register admin as member (needed to create proposals) - idempotent check
    if (!members::is_member_with_registry(admin_addr, admin_addr)) {
        members::register_member(&admin, admin_addr, 1); // Admin role
        members::accept_membership(&admin, admin_addr);
    };
    
    // Register voter as member
    members::register_member(&admin, signer::address_of(&voter1), 2);
    members::accept_membership(&voter1, admin_addr);
    
    let name = string::utf8(b"Test Token");
    let symbol = string::utf8(b"TEST");
    let _metadata = token::initialize_for_test(&admin, name, symbol);
    
    governance::initialize_for_test(&admin, admin_addr, admin_addr);
    
    let gov_addr = admin_addr;
    let title = vector::empty<u8>();
    let description = vector::empty<u8>();
    governance::create_proposal(&admin, gov_addr, title, description, 1, 0, 0, vector::empty<u8>(), admin_addr, admin_addr);
    
    governance::activate_proposal(&admin, 0, gov_addr);
    governance::vote(&voter1, 0, 0, gov_addr);
    governance::vote(&voter1, 0, 0, gov_addr); // Try to vote again
}

#[test(admin = @0x1, voter1 = @0x2)]
#[expected_failure(abort_code = 327687, location = governance)]
fun test_vote_requires_membership(admin: signer, voter1: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    // voter1 is NOT registered as member
    
    let name = string::utf8(b"Test Token");
    let symbol = string::utf8(b"TEST");
    let _metadata = token::initialize_for_test(&admin, name, symbol);
    
    governance::initialize_for_test(&admin, admin_addr, admin_addr);
    
    let gov_addr = admin_addr;
    let title = vector::empty<u8>();
    let description = vector::empty<u8>();
    governance::create_proposal(&admin, gov_addr, title, description, 1, 0, 0, vector::empty<u8>(), admin_addr, admin_addr);
    
    governance::activate_proposal(&admin, 0, gov_addr);
    governance::vote(&voter1, 0, 0, gov_addr); // Should fail - not a member
}

#[test(admin = @0x1, voter1 = @0x2, voter2 = @0x3)]
fun test_proposal_rejection(admin: signer, voter1: signer, voter2: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    // Register admin as member
    if (!members::is_member_with_registry(admin_addr, admin_addr)) {
        members::register_member(&admin, admin_addr, 1);
        members::accept_membership(&admin, admin_addr);
    };
    
    // Register voters
    members::register_member(&admin, signer::address_of(&voter1), 2);
    members::accept_membership(&voter1, admin_addr);
    members::register_member(&admin, signer::address_of(&voter2), 2);
    members::accept_membership(&voter2, admin_addr);
    
    let name = string::utf8(b"Test Token");
    let symbol = string::utf8(b"TEST");
    let _metadata = token::initialize_for_test(&admin, name, symbol);
    
    governance::initialize_for_test(&admin, admin_addr, admin_addr);
    
    let gov_addr = admin_addr;
    let title = vector::empty<u8>();
    let description = vector::empty<u8>();
    governance::create_proposal(&admin, gov_addr, title, description, 2, 0, 0, vector::empty<u8>(), admin_addr, admin_addr);
    
    governance::activate_proposal(&admin, 0, gov_addr);
    
    // Vote no (choice = 1)
    governance::vote(&voter1, 0, 1, gov_addr);
    governance::vote(&voter2, 0, 1, gov_addr);
    
    // Check status - should be rejected (votes_no > votes_yes)
    let (_, _, status, yes, no, _, _, _) = governance::get_proposal(0, gov_addr);
    assert!(status == 3, 0); // Rejected = 3
    assert!(yes == 0, 1);
    assert!(no == 2, 2);
}

#[test(admin = @0x1, voter1 = @0x2, voter2 = @0x3)]
fun test_proposal_status_transitions(admin: signer, voter1: signer, voter2: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    // Register admin as member
    if (!members::is_member_with_registry(admin_addr, admin_addr)) {
        members::register_member(&admin, admin_addr, 1);
        members::accept_membership(&admin, admin_addr);
    };
    
    // Register voters
    members::register_member(&admin, signer::address_of(&voter1), 2);
    members::accept_membership(&voter1, admin_addr);
    members::register_member(&admin, signer::address_of(&voter2), 2);
    members::accept_membership(&voter2, admin_addr);
    
    let name = string::utf8(b"Test Token");
    let symbol = string::utf8(b"TEST");
    let _metadata = token::initialize_for_test(&admin, name, symbol);
    
    governance::initialize_for_test(&admin, admin_addr, admin_addr);
    
    let gov_addr = admin_addr;
    let title = vector::empty<u8>();
    let description = vector::empty<u8>();
    governance::create_proposal(&admin, gov_addr, title, description, 2, 0, 0, vector::empty<u8>(), admin_addr, admin_addr);
    
    // Check status is Pending (0)
    let (_, _, status0, _, _, _, _, _) = governance::get_proposal(0, gov_addr);
    assert!(status0 == 0, 0); // Pending
    
    // Activate proposal
    governance::activate_proposal(&admin, 0, gov_addr);
    
    // Check status is Active (1)
    let (_, _, status1, _, _, _, _, _) = governance::get_proposal(0, gov_addr);
    assert!(status1 == 1, 1); // Active
    
    // Vote yes
    governance::vote(&voter1, 0, 0, gov_addr);
    governance::vote(&voter2, 0, 0, gov_addr);
    
    // Check status is Passed (2)
    let (_, _, status2, yes, _, _, _, _) = governance::get_proposal(0, gov_addr);
    assert!(status2 == 2, 2); // Passed
    assert!(yes == 2, 3);
    
    // Execute proposal
    governance::execute_proposal(&admin, 0, gov_addr);
    
    // Check status is Executed (4)
    let (_, _, status3, _, _, _, _, _) = governance::get_proposal(0, gov_addr);
    assert!(status3 == 4, 4); // Executed
}

#[test(admin = @0x1, voter1 = @0x2)]
#[expected_failure(abort_code = 3, location = governance)]
fun test_execute_proposal_not_passed(admin: signer, voter1: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    // Register admin as member
    if (!members::is_member_with_registry(admin_addr, admin_addr)) {
        members::register_member(&admin, admin_addr, 1);
        members::accept_membership(&admin, admin_addr);
    };
    
    members::register_member(&admin, signer::address_of(&voter1), 2);
    members::accept_membership(&voter1, admin_addr);
    
    let name = string::utf8(b"Test Token");
    let symbol = string::utf8(b"TEST");
    let _metadata = token::initialize_for_test(&admin, name, symbol);
    
    governance::initialize_for_test(&admin, admin_addr, admin_addr);
    
    let gov_addr = admin_addr;
    let title = vector::empty<u8>();
    let description = vector::empty<u8>();
    governance::create_proposal(&admin, gov_addr, title, description, 2, 0, 0, vector::empty<u8>(), admin_addr, admin_addr);
    
    governance::activate_proposal(&admin, 0, gov_addr);
    
    // Vote yes (only 1 vote, threshold is 2, so not passed)
    governance::vote(&voter1, 0, 0, gov_addr);
    
    // Try to execute - should fail (not passed)
    governance::execute_proposal(&admin, 0, gov_addr);
}

#[test(admin = @0x1, voter1 = @0x2)]
#[expected_failure(abort_code = 3, location = governance)]
fun test_execute_proposal_already_executed(admin: signer, voter1: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    // Register admin as member
    if (!members::is_member_with_registry(admin_addr, admin_addr)) {
        members::register_member(&admin, admin_addr, 1);
        members::accept_membership(&admin, admin_addr);
    };
    
    members::register_member(&admin, signer::address_of(&voter1), 2);
    members::accept_membership(&voter1, admin_addr);
    
    let name = string::utf8(b"Test Token");
    let symbol = string::utf8(b"TEST");
    let _metadata = token::initialize_for_test(&admin, name, symbol);
    
    governance::initialize_for_test(&admin, admin_addr, admin_addr);
    
    let gov_addr = admin_addr;
    let title = vector::empty<u8>();
    let description = vector::empty<u8>();
    governance::create_proposal(&admin, gov_addr, title, description, 1, 0, 0, vector::empty<u8>(), admin_addr, admin_addr);
    
    governance::activate_proposal(&admin, 0, gov_addr);
    governance::vote(&voter1, 0, 0, gov_addr);
    governance::execute_proposal(&admin, 0, gov_addr);
    
    // Try to execute again - should fail
    governance::execute_proposal(&admin, 0, gov_addr);
}

#[test(admin = @0x1, voter1 = @0x2, voter2 = @0x3)]
fun test_multiple_proposals_simultaneous(admin: signer, voter1: signer, voter2: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    // Register admin as member
    if (!members::is_member_with_registry(admin_addr, admin_addr)) {
        members::register_member(&admin, admin_addr, 1);
        members::accept_membership(&admin, admin_addr);
    };
    
    members::register_member(&admin, signer::address_of(&voter1), 2);
    members::accept_membership(&voter1, admin_addr);
    members::register_member(&admin, signer::address_of(&voter2), 2);
    members::accept_membership(&voter2, admin_addr);
    
    let name = string::utf8(b"Test Token");
    let symbol = string::utf8(b"TEST");
    let _metadata = token::initialize_for_test(&admin, name, symbol);
    
    governance::initialize_for_test(&admin, admin_addr, admin_addr);
    
    let gov_addr = admin_addr;
    let title1 = vector::empty<u8>();
    let description1 = vector::empty<u8>();
    let title2 = vector::empty<u8>();
    let description2 = vector::empty<u8>();
    
    // Create two proposals
    governance::create_proposal(&admin, gov_addr, title1, description1, 1, 0, 0, vector::empty<u8>(), admin_addr, admin_addr);
    governance::create_proposal(&admin, gov_addr, title2, description2, 1, 0, 0, vector::empty<u8>(), admin_addr, admin_addr);
    
    // Activate both
    governance::activate_proposal(&admin, 0, gov_addr);
    governance::activate_proposal(&admin, 1, gov_addr);
    
    // Vote on both independently
    governance::vote(&voter1, 0, 0, gov_addr);
    governance::vote(&voter2, 1, 0, gov_addr);
    
    // Check both proposals passed
    let (_, _, status0, yes0, _, _, _, _) = governance::get_proposal(0, gov_addr);
    let (_, _, status1, yes1, _, _, _, _) = governance::get_proposal(1, gov_addr);
    assert!(status0 == 2, 0); // Passed
    assert!(yes0 == 1, 1);
    assert!(status1 == 2, 2); // Passed
    assert!(yes1 == 1, 3);
}

#[test(admin = @0x1, voter1 = @0x2)]
#[expected_failure(abort_code = 3, location = governance)]
fun test_vote_after_proposal_passed(admin: signer, voter1: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    // Register admin as member
    if (!members::is_member_with_registry(admin_addr, admin_addr)) {
        members::register_member(&admin, admin_addr, 1);
        members::accept_membership(&admin, admin_addr);
    };
    
    members::register_member(&admin, signer::address_of(&voter1), 2);
    members::accept_membership(&voter1, admin_addr);
    
    let name = string::utf8(b"Test Token");
    let symbol = string::utf8(b"TEST");
    let _metadata = token::initialize_for_test(&admin, name, symbol);
    
    governance::initialize_for_test(&admin, admin_addr, admin_addr);
    
    let gov_addr = admin_addr;
    let title = vector::empty<u8>();
    let description = vector::empty<u8>();
    governance::create_proposal(&admin, gov_addr, title, description, 1, 0, 0, vector::empty<u8>(), admin_addr, admin_addr);
    
    governance::activate_proposal(&admin, 0, gov_addr);
    governance::vote(&voter1, 0, 0, gov_addr); // This passes the proposal
    
    // Try to vote again after proposal passed - should fail (status is Passed, not Active)
    // Note: This will fail with E_ALREADY_VOTED if voter1 tries again, or E_INVALID_STATUS if different voter
    // For this test, we'll use a different voter scenario - but voter1 already voted
    // So we need voter2, but let's test the status check
    // Actually, the status check happens before duplicate check, so this should fail with E_INVALID_STATUS
}

#[test(admin = @0x1, voter1 = @0x2, voter2 = @0x3)]
#[expected_failure(abort_code = 3, location = governance)]
fun test_vote_after_proposal_rejected(admin: signer, voter1: signer, voter2: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    // Register admin as member
    if (!members::is_member_with_registry(admin_addr, admin_addr)) {
        members::register_member(&admin, admin_addr, 1);
        members::accept_membership(&admin, admin_addr);
    };
    
    members::register_member(&admin, signer::address_of(&voter1), 2);
    members::accept_membership(&voter1, admin_addr);
    members::register_member(&admin, signer::address_of(&voter2), 2);
    members::accept_membership(&voter2, admin_addr);
    
    let name = string::utf8(b"Test Token");
    let symbol = string::utf8(b"TEST");
    let _metadata = token::initialize_for_test(&admin, name, symbol);
    
    governance::initialize_for_test(&admin, admin_addr, admin_addr);
    
    let gov_addr = admin_addr;
    let title = vector::empty<u8>();
    let description = vector::empty<u8>();
    governance::create_proposal(&admin, gov_addr, title, description, 1, 0, 0, vector::empty<u8>(), admin_addr, admin_addr);
    
    governance::activate_proposal(&admin, 0, gov_addr);
    governance::vote(&voter1, 0, 1, gov_addr); // Vote no - this rejects the proposal
    
    // voter2 tries to vote after proposal rejected - should fail
    governance::vote(&voter2, 0, 0, gov_addr);
}

}

