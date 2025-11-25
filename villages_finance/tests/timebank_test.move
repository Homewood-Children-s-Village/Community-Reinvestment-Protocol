#[test_only]
module villages_finance::timebank_test {

use villages_finance::timebank;
use villages_finance::admin;
use villages_finance::time_token;
use villages_finance::members;
use villages_finance::compliance;
use aptos_framework::fungible_asset;
use aptos_framework::primary_fungible_store;
use std::signer;

#[test(admin = @0x1, user1 = @0x2)]
fun test_create_request(admin: signer, user1: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    timebank::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let user1_addr = signer::address_of(&user1);
    
    // Register user1 as member
    members::register_member(&admin, user1_addr, 2); // Depositor
    members::accept_membership(&user1, admin_addr);
    
    let hours = 5;
    let activity_id = 1;
    let bank_registry_addr = admin_addr; // Shared registry
    timebank::create_request(&user1, hours, activity_id, admin_addr, bank_registry_addr);
    
    // Check request was created
    let (requester, req_hours, req_activity, status, _) = timebank::get_request(0, bank_registry_addr);
    assert!(requester == user1_addr, 0);
    assert!(req_hours == hours, 1);
    assert!(req_activity == activity_id, 2);
    assert!(status == 0, 3); // Pending
}

#[test(admin = @0x1)]
#[expected_failure(abort_code = 5, location = timebank)]
fun test_create_request_zero_hours(admin: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    timebank::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let bank_registry_addr = admin_addr;
    timebank::create_request(&admin, 0, 1, admin_addr, bank_registry_addr);
}

#[test(admin = @0x1, user1 = @0x2)]
fun test_approve_request(admin: signer, user1: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    compliance::initialize_for_test(&admin);
    timebank::initialize_for_test(&admin);
    let metadata = time_token::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let user1_addr = signer::address_of(&user1);
    
    // Primary store is automatically created when minting
    
    // Register user1 as member and whitelist
    members::register_member(&admin, user1_addr, 2); // Depositor
    members::accept_membership(&user1, admin_addr);
    compliance::whitelist_address(&admin, user1_addr);
    
    // Create request
    let hours = 10;
    let bank_registry_addr = admin_addr; // Shared registry
    timebank::create_request(&user1, hours, 1, admin_addr, bank_registry_addr);
    
    // Approve request (admin is validator/admin)
    // Updated: no mint_cap parameter, add time_token_admin_addr
    timebank::approve_request(&admin, 0, admin_addr, admin_addr, bank_registry_addr, admin_addr);
    
    // Check request status
    let (_, _, _, status, _) = timebank::get_request(0, bank_registry_addr);
    assert!(status == 1, 0); // Approved
    
    // Check TimeToken balance
    let balance = time_token::balance(user1_addr, admin_addr);
    assert!(balance == hours, 1);
}

#[test(admin = @0x1)]
fun test_reject_request(admin: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    timebank::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let bank_registry_addr = admin_addr;
    
    // Create request
    timebank::create_request(&admin, 5, 1, admin_addr, bank_registry_addr);
    
    // Reject request
    timebank::reject_request(&admin, 0, admin_addr, bank_registry_addr);
    
    // Check request status
    let (_, _, _, status, _) = timebank::get_request(0, bank_registry_addr);
    assert!(status == 2, 0); // Rejected
}

#[test(admin = @0x1, user1 = @0x2)]
#[expected_failure(abort_code = 6, location = timebank)]
fun test_create_request_requires_membership(admin: signer, user1: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    timebank::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let bank_registry_addr = admin_addr;
    
    // user1 is NOT registered as member - should fail
    timebank::create_request(&user1, 5, 1, admin_addr, bank_registry_addr);
}

}
