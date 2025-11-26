#[test_only]
module villages_finance::members_test {

use villages_finance::members;
use std::signer;
use std::vector;

#[test(admin = @0x1, user1 = @0x2, user2 = @0x3)]
fun test_initialize_and_register(admin: signer, user1: signer, user2: signer) {
    members::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    // Admin should be registered
    assert!(members::is_member(admin_addr), 0);
    assert!(members::is_admin_with_registry(&admin, admin_addr), 1);
    
    // Register user1 as Borrower
    members::register_member(&admin, signer::address_of(&user1), 1);
    assert!(members::is_member_with_registry(signer::address_of(&user1), admin_addr), 2);
    assert!(members::has_role_with_registry(signer::address_of(&user1), 1, admin_addr), 3);
    
    // Register user2 as Depositor
    members::register_member(&admin, signer::address_of(&user2), 2);
    assert!(members::is_member_with_registry(signer::address_of(&user2), admin_addr), 4);
    assert!(members::has_role_with_registry(signer::address_of(&user2), 2, admin_addr), 5);
}

#[test(admin = @0x1, user1 = @0x2)]
#[expected_failure(abort_code = 327681, location = members)]
fun test_register_requires_admin(admin: signer, user1: signer) {
    members::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    // user1 is not admin, so this should fail
    members::register_member(&user1, signer::address_of(&user1), 1);
}

#[test(admin = @0x1, user1 = @0x2)]
#[expected_failure(abort_code = 524291, location = members)]
fun test_duplicate_registration(admin: signer, user1: signer) {
    members::initialize_for_test(&admin);
    members::register_member(&admin, signer::address_of(&user1), 1);
    members::register_member(&admin, signer::address_of(&user1), 2);
}

#[test(admin = @0x1, user1 = @0x2)]
fun test_update_role(admin: signer, user1: signer) {
    members::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    members::register_member(&admin, signer::address_of(&user1), 1);
    
    assert!(members::has_role_with_registry(signer::address_of(&user1), 1, admin_addr), 0);
    
    members::update_role(&admin, signer::address_of(&user1), 2);
    
    assert!(members::has_role_with_registry(signer::address_of(&user1), 2, admin_addr), 1);
}

#[test(admin = @0x1, user1 = @0x2)]
fun test_revoke_membership(admin: signer, user1: signer) {
    members::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    members::register_member(&admin, signer::address_of(&user1), 1);
    
    assert!(members::is_member_with_registry(signer::address_of(&user1), admin_addr), 0);
    
    members::revoke_membership(&admin, signer::address_of(&user1));
    
    assert!(!members::is_member_with_registry(signer::address_of(&user1), admin_addr), 1);
}

#[test(admin = @0x1, user1 = @0x2)]
#[expected_failure(abort_code = 393218, location = members)]
fun test_revoke_nonexistent_member(admin: signer, user1: signer) {
    members::initialize_for_test(&admin);
    // user1 is not registered, so this should fail
    members::revoke_membership(&admin, signer::address_of(&user1));
}

#[test(admin = @0x1)]
fun test_get_role(admin: signer) {
    members::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    // Admin has Member resource, so get_role should work
    let role_opt = members::get_role(admin_addr);
    assert!(std::option::is_some(&role_opt), 0);
    assert!(*std::option::borrow(&role_opt) == 0, 1);
    
    // Test with registry lookup
    let role_opt_registry = members::get_role_with_registry(admin_addr, admin_addr);
    assert!(std::option::is_some(&role_opt_registry), 2);
    
    let role_opt_none = members::get_role(@0x999);
    assert!(std::option::is_none(&role_opt_none), 3);
}

#[test(admin = @0x1, validator = @0x2, applicant = @0x3)]
fun test_membership_request_lifecycle(admin: signer, validator: signer, applicant: signer) {
    members::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);

    // Bootstrap validator
    members::register_member(&admin, signer::address_of(&validator), members::validator_role_u8());
    members::accept_membership(&validator, admin_addr);

    // Applicant submits request
    members::request_membership(&applicant, admin_addr, 2, b"ready to help");
    
    // Get request_id from the request
    let applicant_addr = signer::address_of(&applicant);
    let request_id_opt = members::get_request_id_by_address(admin_addr, applicant_addr);
    assert!(std::option::is_some(&request_id_opt), 0);
    let request_id = *std::option::borrow(&request_id_opt);

    // Validator approves
    members::approve_membership(&validator, request_id, admin_addr);

    assert!(members::has_role_with_registry(signer::address_of(&applicant), 2, admin_addr), 0);
}

#[test(admin = @0x1, validator = @0x2, applicant = @0x3)]
#[expected_failure(abort_code = 327688, location = members)]
fun test_membership_request_approval_requires_privilege(admin: signer, validator: signer, applicant: signer) {
    members::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);

    members::request_membership(&applicant, admin_addr, 1, b"");
    
    // Get request_id from the request
    let applicant_addr = signer::address_of(&applicant);
    let request_id_opt = members::get_request_id_by_address(admin_addr, applicant_addr);
    assert!(std::option::is_some(&request_id_opt), 0);
    let request_id = *std::option::borrow(&request_id_opt);

    // validator is not registered as validator yet, so this should fail
    members::approve_membership(&validator, request_id, admin_addr);
}

#[test(admin = @0x1, validator = @0x2, applicant = @0x3)]
fun test_membership_request_rejection(admin: signer, validator: signer, applicant: signer) {
    members::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);

    members::register_member(&admin, signer::address_of(&validator), members::validator_role_u8());
    members::accept_membership(&validator, admin_addr);

    members::request_membership(&applicant, admin_addr, 1, b"");
    
    // Get request_id from the request
    let applicant_addr = signer::address_of(&applicant);
    let request_id_opt = members::get_request_id_by_address(admin_addr, applicant_addr);
    assert!(std::option::is_some(&request_id_opt), 0);
    let request_id = *std::option::borrow(&request_id_opt);
    
    members::reject_membership(&validator, request_id, admin_addr);

    let pending = members::list_membership_requests(admin_addr, 0);
    assert!(vector::length(&pending) == 0, 0);
}

}

