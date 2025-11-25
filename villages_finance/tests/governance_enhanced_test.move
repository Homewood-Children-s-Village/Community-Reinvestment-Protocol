#[test_only]
module villages_finance::governance_enhanced_test {

use villages_finance::governance;
use villages_finance::admin;
use villages_finance::members;
use villages_finance::token;
use aptos_framework::fungible_asset;
use aptos_framework::primary_fungible_store;
use std::signer;
use std::vector;
use std::string;

#[test(admin = @0x1, voter1 = @0x2, voter2 = @0x3)]
fun test_token_weighted_voting(admin: signer, voter1: signer, voter2: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    members::register_member(&admin, signer::address_of(&voter1), 2);
    members::register_member(&admin, signer::address_of(&voter2), 2);
    
    // Initialize token and mint to voters
    let name = string::utf8(b"Test Token");
    let symbol = string::utf8(b"TEST");
    let metadata = token::initialize_for_test(&admin, name, symbol);
    
    // Mint tokens: voter1 gets 100, voter2 gets 50
    let admin_addr = signer::address_of(&admin);
    token::mint_entry(&admin, signer::address_of(&voter1), 100, admin_addr);
    token::mint_entry(&admin, signer::address_of(&voter2), 50, admin_addr);
    
    governance::initialize_for_test(&admin, admin_addr, admin_addr);
    
    let gov_addr = admin_addr;
    let title = vector::empty<u8>();
    let description = vector::empty<u8>();
    let threshold = 100; // Need 100 voting power
    let voting_mechanism = 1; // TokenWeighted
    let action_type = 0;
    let action_data = vector::empty<u8>();
    
    governance::create_proposal(&admin, gov_addr, title, description, threshold, voting_mechanism, action_type, action_data, admin_addr, admin_addr);
    
    governance::activate_proposal(&admin, 0, gov_addr);
    
    // Vote yes - voter1 has 100 tokens, voter2 has 50 tokens
    governance::vote(&voter1, 0, 0, gov_addr);
    governance::vote(&voter2, 0, 0, gov_addr);
    
    // Check status - should pass with 150 total voting power
    let (_, _, status, yes, _, _, _, mechanism) = governance::get_proposal(0, gov_addr);
    assert!(status == 2, 0); // Passed
    assert!(yes == 150, 1); // Token-weighted: 100 + 50
    assert!(mechanism == 1, 2); // TokenWeighted
    
    // Check voting power
    let power1 = governance::get_voting_power(signer::address_of(&voter1), 0, gov_addr);
    assert!(power1 == 100, 3);
    
    let power2 = governance::get_voting_power(signer::address_of(&voter2), 0, gov_addr);
    assert!(power2 == 50, 4);
}

#[test(admin = @0x1, voter1 = @0x2)]
fun test_quadratic_voting(admin: signer, voter1: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    members::register_member(&admin, signer::address_of(&voter1), 2);
    
    let name = string::utf8(b"Test Token");
    let symbol = string::utf8(b"TEST");
    let _metadata = token::initialize_for_test(&admin, name, symbol);
    let admin_addr = signer::address_of(&admin);
    
    // Mint 100 tokens to voter1
    token::mint_entry(&admin, signer::address_of(&voter1), 100, admin_addr);
    
    governance::initialize_for_test(&admin, admin_addr, admin_addr);
    
    let gov_addr = admin_addr;
    let title = vector::empty<u8>();
    let description = vector::empty<u8>();
    let threshold = 10; // Need 10 voting power (sqrt(100) = 10)
    let voting_mechanism = 2; // Quadratic
    let action_type = 0;
    let action_data = vector::empty<u8>();
    
    governance::create_proposal(&admin, gov_addr, title, description, threshold, voting_mechanism, action_type, action_data, admin_addr, admin_addr);
    
    governance::activate_proposal(&admin, 0, gov_addr);
    governance::vote(&voter1, 0, 0, gov_addr);
    
    // Check status - quadratic: sqrt(100) = 10 voting power
    let (_, _, status, yes, _, _, _, mechanism) = governance::get_proposal(0, gov_addr);
    assert!(status == 2, 0); // Passed
    assert!(yes == 10, 1); // Quadratic: sqrt(100) = 10
    assert!(mechanism == 2, 2); // Quadratic
}

}

