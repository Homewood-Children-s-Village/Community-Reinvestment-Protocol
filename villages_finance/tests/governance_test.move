#[test_only]
module villages_finance::governance_test;

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
    
    // Register voters as members
    members::register_member(&admin, signer::address_of(&voter1), 2); // Depositor
    members::register_member(&admin, signer::address_of(&voter2), 2); // Depositor
    
    // Initialize token
    let name = string::utf8(b"Test Token");
    let symbol = string::utf8(b"TEST");
    let (_, _) = token::initialize_for_test(&admin, name, symbol);
    
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
    
    members::register_member(&admin, signer::address_of(&voter1), 2);
    
    let name = string::utf8(b"Test Token");
    let symbol = string::utf8(b"TEST");
    let (_, _) = token::initialize_for_test(&admin, name, symbol);
    
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
#[expected_failure(abort_code = 6, location = governance)]
fun test_double_vote(admin: signer, voter1: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    members::register_member(&admin, signer::address_of(&voter1), 2);
    
    let name = string::utf8(b"Test Token");
    let symbol = string::utf8(b"TEST");
    let (_, _) = token::initialize_for_test(&admin, name, symbol);
    
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
#[expected_failure(abort_code = 7, location = governance)]
fun test_vote_requires_membership(admin: signer, voter1: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    // voter1 is NOT registered as member
    
    let name = string::utf8(b"Test Token");
    let symbol = string::utf8(b"TEST");
    let (_, _) = token::initialize_for_test(&admin, name, symbol);
    
    governance::initialize_for_test(&admin, admin_addr, admin_addr);
    
    let gov_addr = admin_addr;
    let title = vector::empty<u8>();
    let description = vector::empty<u8>();
    governance::create_proposal(&admin, gov_addr, title, description, 1, 0, 0, vector::empty<u8>(), admin_addr, admin_addr);
    
    governance::activate_proposal(&admin, 0, gov_addr);
    governance::vote(&voter1, 0, 0, gov_addr); // Should fail - not a member
}

