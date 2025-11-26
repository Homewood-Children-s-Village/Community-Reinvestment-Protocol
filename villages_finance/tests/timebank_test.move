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
use std::vector;

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
#[expected_failure(abort_code = 65541, location = timebank)]
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
#[expected_failure(abort_code = 327686, location = timebank)]
fun test_create_request_requires_membership(admin: signer, user1: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    timebank::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let bank_registry_addr = admin_addr;
    
    // user1 is NOT registered as member - should fail
    timebank::create_request(&user1, 5, 1, admin_addr, bank_registry_addr);
}

#[test(admin = @0x1, user1 = @0x2, user2 = @0x3)]
fun test_bulk_approve_requests(admin: signer, user1: signer, user2: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    compliance::initialize_for_test(&admin);
    timebank::initialize_for_test(&admin);
    let metadata = time_token::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let user1_addr = signer::address_of(&user1);
    let user2_addr = signer::address_of(&user2);
    let bank_registry_addr = admin_addr;
    
    // Register and whitelist users
    members::register_member(&admin, user1_addr, 2);
    members::accept_membership(&user1, admin_addr);
    compliance::whitelist_address(&admin, user1_addr);
    
    members::register_member(&admin, user2_addr, 2);
    members::accept_membership(&user2, admin_addr);
    compliance::whitelist_address(&admin, user2_addr);
    
    // Create multiple requests
    timebank::create_request(&user1, 5, 1, admin_addr, bank_registry_addr);
    timebank::create_request(&user2, 10, 2, admin_addr, bank_registry_addr);
    timebank::create_request(&user1, 3, 1, admin_addr, bank_registry_addr);
    
    // Bulk approve requests
    let request_ids = vector::empty<u64>();
    vector::push_back(&mut request_ids, 0);
    vector::push_back(&mut request_ids, 1);
    vector::push_back(&mut request_ids, 2);
    
    timebank::bulk_approve_requests(&admin, request_ids, bank_registry_addr, admin_addr, admin_addr);
    
    // Verify all requests are approved
    let (_, _, _, status0, _) = timebank::get_request(0, bank_registry_addr);
    let (_, _, _, status1, _) = timebank::get_request(1, bank_registry_addr);
    let (_, _, _, status2, _) = timebank::get_request(2, bank_registry_addr);
    assert!(status0 == 1, 0); // Approved
    assert!(status1 == 1, 1); // Approved
    assert!(status2 == 1, 2); // Approved
    
    // Verify TimeTokens were minted
    let balance1 = time_token::balance(user1_addr, admin_addr);
    assert!(balance1 == 8, 3); // 5 + 3
    let balance2 = time_token::balance(user2_addr, admin_addr);
    assert!(balance2 == 10, 4);
}

#[test(admin = @0x1, user1 = @0x2, validator = @0x3)]
fun test_bulk_approve_requests_partial_failure(admin: signer, user1: signer, validator: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    compliance::initialize_for_test(&admin);
    timebank::initialize_for_test(&admin);
    let metadata = time_token::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let user1_addr = signer::address_of(&user1);
    let validator_addr = signer::address_of(&validator);
    let bank_registry_addr = admin_addr;
    
    // Register user1 and validator
    members::register_member(&admin, user1_addr, 2);
    members::accept_membership(&user1, admin_addr);
    compliance::whitelist_address(&admin, user1_addr);
    
    members::register_member(&admin, validator_addr, 3); // Validator role
    members::accept_membership(&validator, admin_addr);
    
    // Create requests
    timebank::create_request(&user1, 5, 1, admin_addr, bank_registry_addr);
    timebank::create_request(&user1, 10, 2, admin_addr, bank_registry_addr);
    
    // Approve first request individually
    timebank::approve_request(&admin, 0, admin_addr, admin_addr, bank_registry_addr, admin_addr);
    
    // Try to bulk approve both (one already approved, one pending)
    let request_ids = vector::empty<u64>();
    vector::push_back(&mut request_ids, 0); // Already approved
    vector::push_back(&mut request_ids, 1); // Pending
    
    timebank::bulk_approve_requests(&validator, request_ids, bank_registry_addr, admin_addr, admin_addr);
    
    // Verify first request still approved, second now approved
    let (_, _, _, status0, _) = timebank::get_request(0, bank_registry_addr);
    let (_, _, _, status1, _) = timebank::get_request(1, bank_registry_addr);
    assert!(status0 == 1, 0); // Approved
    assert!(status1 == 1, 1); // Approved
}

#[test(admin = @0x1)]
#[expected_failure(abort_code = 65545, location = timebank)]
fun test_bulk_approve_requests_empty_vector(admin: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    timebank::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let bank_registry_addr = admin_addr;
    
    let request_ids = vector::empty<u64>();
    timebank::bulk_approve_requests(&admin, request_ids, bank_registry_addr, admin_addr, admin_addr);
}

#[test(admin = @0x1, user1 = @0x2)]
fun test_update_request(admin: signer, user1: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    timebank::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let user1_addr = signer::address_of(&user1);
    let bank_registry_addr = admin_addr;
    
    // Register user1
    members::register_member(&admin, user1_addr, 2);
    members::accept_membership(&user1, admin_addr);
    
    // Create request
    timebank::create_request(&user1, 5, 1, admin_addr, bank_registry_addr);
    
    // Update request hours
    timebank::update_request(&user1, 0, 10, bank_registry_addr, admin_addr);
    
    // Verify hours updated
    let (_, hours, _, status, _) = timebank::get_request(0, bank_registry_addr);
    assert!(hours == 10, 0);
    assert!(status == 0, 1); // Still Pending
}

#[test(admin = @0x1, user1 = @0x2, user2 = @0x3)]
#[expected_failure(abort_code = 327688, location = timebank)]
fun test_update_request_not_owner(admin: signer, user1: signer, user2: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    timebank::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let user1_addr = signer::address_of(&user1);
    let bank_registry_addr = admin_addr;
    
    // Register users
    members::register_member(&admin, user1_addr, 2);
    members::accept_membership(&user1, admin_addr);
    members::register_member(&admin, signer::address_of(&user2), 2);
    members::accept_membership(&user2, admin_addr);
    
    // Create request by user1
    timebank::create_request(&user1, 5, 1, admin_addr, bank_registry_addr);
    
    // user2 tries to update user1's request - should fail
    timebank::update_request(&user2, 0, 10, bank_registry_addr, admin_addr);
}

#[test(admin = @0x1, user1 = @0x2)]
#[expected_failure(abort_code = 196612, location = timebank)]
fun test_update_request_not_pending(admin: signer, user1: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    compliance::initialize_for_test(&admin);
    timebank::initialize_for_test(&admin);
    let metadata = time_token::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let user1_addr = signer::address_of(&user1);
    let bank_registry_addr = admin_addr;
    
    // Register and whitelist user1
    members::register_member(&admin, user1_addr, 2);
    members::accept_membership(&user1, admin_addr);
    compliance::whitelist_address(&admin, user1_addr);
    
    // Create and approve request
    timebank::create_request(&user1, 5, 1, admin_addr, bank_registry_addr);
    timebank::approve_request(&admin, 0, admin_addr, admin_addr, bank_registry_addr, admin_addr);
    
    // Try to update approved request - should fail
    timebank::update_request(&user1, 0, 10, bank_registry_addr, admin_addr);
}

#[test(admin = @0x1, user1 = @0x2)]
#[expected_failure(abort_code = 65541, location = timebank)]
fun test_update_request_zero_hours(admin: signer, user1: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    timebank::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let user1_addr = signer::address_of(&user1);
    let bank_registry_addr = admin_addr;
    
    // Register user1
    members::register_member(&admin, user1_addr, 2);
    members::accept_membership(&user1, admin_addr);
    
    // Create request
    timebank::create_request(&user1, 5, 1, admin_addr, bank_registry_addr);
    
    // Try to update to zero hours - should fail
    timebank::update_request(&user1, 0, 0, bank_registry_addr, admin_addr);
}

#[test(admin = @0x1, user1 = @0x2)]
fun test_update_request_multiple_times(admin: signer, user1: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    timebank::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let user1_addr = signer::address_of(&user1);
    let bank_registry_addr = admin_addr;
    
    // Register user1
    members::register_member(&admin, user1_addr, 2);
    members::accept_membership(&user1, admin_addr);
    
    // Create request
    timebank::create_request(&user1, 5, 1, admin_addr, bank_registry_addr);
    
    // Update multiple times
    timebank::update_request(&user1, 0, 10, bank_registry_addr, admin_addr);
    timebank::update_request(&user1, 0, 15, bank_registry_addr, admin_addr);
    timebank::update_request(&user1, 0, 20, bank_registry_addr, admin_addr);
    
    // Verify final hours
    let (_, hours, _, _, _) = timebank::get_request(0, bank_registry_addr);
    assert!(hours == 20, 0);
}

#[test(admin = @0x1, user1 = @0x2, user2 = @0x3)]
fun test_bulk_reject_requests(admin: signer, user1: signer, user2: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    timebank::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let user1_addr = signer::address_of(&user1);
    let user2_addr = signer::address_of(&user2);
    let bank_registry_addr = admin_addr;
    
    // Register users
    members::register_member(&admin, user1_addr, 2);
    members::accept_membership(&user1, admin_addr);
    members::register_member(&admin, user2_addr, 2);
    members::accept_membership(&user2, admin_addr);
    
    // Create multiple requests
    timebank::create_request(&user1, 5, 1, admin_addr, bank_registry_addr);
    timebank::create_request(&user2, 10, 2, admin_addr, bank_registry_addr);
    timebank::create_request(&user1, 3, 1, admin_addr, bank_registry_addr);
    
    // Bulk reject requests
    let request_ids = vector::empty<u64>();
    vector::push_back(&mut request_ids, 0);
    vector::push_back(&mut request_ids, 1);
    vector::push_back(&mut request_ids, 2);
    let reason = vector::empty<u8>();
    
    timebank::bulk_reject_requests(&admin, request_ids, reason, bank_registry_addr, admin_addr);
    
    // Verify all requests are rejected
    let (_, _, _, status0, _) = timebank::get_request(0, bank_registry_addr);
    let (_, _, _, status1, _) = timebank::get_request(1, bank_registry_addr);
    let (_, _, _, status2, _) = timebank::get_request(2, bank_registry_addr);
    assert!(status0 == 2, 0); // Rejected
    assert!(status1 == 2, 1); // Rejected
    assert!(status2 == 2, 2); // Rejected
}

#[test(admin = @0x1, user1 = @0x2)]
#[expected_failure(abort_code = 327690, location = timebank)]
fun test_approve_request_not_whitelisted(admin: signer, user1: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    compliance::initialize_for_test(&admin);
    timebank::initialize_for_test(&admin);
    let metadata = time_token::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let user1_addr = signer::address_of(&user1);
    let bank_registry_addr = admin_addr;
    
    // Register user1 but DON'T whitelist
    members::register_member(&admin, user1_addr, 2);
    members::accept_membership(&user1, admin_addr);
    
    // Create request
    timebank::create_request(&user1, 5, 1, admin_addr, bank_registry_addr);
    
    // Try to approve - should fail because user1 is not whitelisted
    timebank::approve_request(&admin, 0, admin_addr, admin_addr, bank_registry_addr, admin_addr);
}

}
