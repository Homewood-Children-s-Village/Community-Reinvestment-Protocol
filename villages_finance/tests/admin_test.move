#[test_only]
module villages_finance::admin_test {

use villages_finance::admin;
use std::signer;

#[test(admin = @0x1, user1 = @0x2)]
fun test_initialize(admin: signer, user1: signer) {
    admin::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    assert!(admin::has_admin_capability(admin_addr), 0);
    assert!(!admin::has_admin_capability(signer::address_of(&user1)), 1);
}

#[test(admin = @0x1)]
fun test_pause_unpause_module(admin: signer) {
    admin::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    let module_name = b"treasury";
    assert!(!admin::is_module_paused(module_name, admin_addr), 0);
    
    admin::pause_module(&admin, module_name);
    assert!(admin::is_module_paused(module_name, admin_addr), 1);
    
    admin::unpause_module(&admin, module_name);
    assert!(!admin::is_module_paused(module_name, admin_addr), 2);
}

#[test(admin = @0x1)]
#[expected_failure(abort_code = 3, location = admin)]
fun test_pause_already_paused(admin: signer) {
    admin::initialize_for_test(&admin);
    let module_name = b"treasury";
    admin::pause_module(&admin, module_name);
    admin::pause_module(&admin, module_name);
}

#[test(admin = @0x1)]
#[expected_failure(abort_code = 4, location = admin)]
fun test_unpause_not_paused(admin: signer) {
    admin::initialize_for_test(&admin);
    let module_name = b"treasury";
    admin::unpause_module(&admin, module_name);
}

#[test(admin = @0x1, user1 = @0x2)]
#[expected_failure(abort_code = 1, location = admin)]
fun test_pause_requires_admin(admin: signer, user1: signer) {
    admin::initialize_for_test(&admin);
    admin::pause_module(&user1, b"treasury");
}

#[test(admin = @0x1)]
fun test_update_interest_rate(admin: signer) {
    admin::initialize_for_test(&admin);
    // Should not abort with valid rate
    admin::update_interest_rate(&admin, 1, 500); // 5% in basis points
}

#[test(admin = @0x1)]
#[expected_failure(abort_code = 5, location = admin)]
fun test_update_interest_rate_invalid(admin: signer) {
    admin::initialize_for_test(&admin);
    // Rate > 10000 (100%) should fail
    admin::update_interest_rate(&admin, 1, 10001);
}

#[test(admin = @0x1)]
fun test_transfer_governance_rights(admin: signer) {
    admin::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let new_admin = @0x999;
    
    assert!(admin::has_admin_capability(admin_addr), 0);
    
    admin::transfer_governance_rights(&admin, new_admin);
    
    // Old admin should no longer have capability
    assert!(!admin::has_admin_capability(admin_addr), 1);
}

}

