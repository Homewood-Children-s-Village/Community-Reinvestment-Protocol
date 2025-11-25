#[test_only]
module villages_finance::compliance_test {

use villages_finance::compliance;
use std::signer;

#[test(admin = @0x1, user1 = @0x2, user2 = @0x3)]
fun test_initialize_and_whitelist(admin: signer, user1: signer, user2: signer) {
    compliance::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    // Initially no addresses whitelisted
    assert!(!compliance::is_whitelisted(signer::address_of(&user1), admin_addr), 0);
    
    // Whitelist user1
    compliance::whitelist_address(&admin, signer::address_of(&user1));
    assert!(compliance::is_whitelisted(signer::address_of(&user1), admin_addr), 1);
    
    // Whitelist user2
    compliance::whitelist_address(&admin, signer::address_of(&user2));
    assert!(compliance::is_whitelisted(signer::address_of(&user2), admin_addr), 2);
    
    // Check count
    assert!(compliance::get_whitelist_count(admin_addr) == 2, 3);
}

#[test(admin = @0x1, user1 = @0x2)]
#[expected_failure(abort_code = 3, location = compliance)]
fun test_duplicate_whitelist(admin: signer, user1: signer) {
    compliance::initialize_for_test(&admin);
    compliance::whitelist_address(&admin, signer::address_of(&user1));
    // Try to whitelist again - should fail
    compliance::whitelist_address(&admin, signer::address_of(&user1));
}

#[test(admin = @0x1, user1 = @0x2)]
fun test_remove_from_whitelist(admin: signer, user1: signer) {
    compliance::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    compliance::whitelist_address(&admin, signer::address_of(&user1));
    assert!(compliance::is_whitelisted(signer::address_of(&user1), admin_addr), 0);
    
    compliance::remove_from_whitelist(&admin, signer::address_of(&user1));
    assert!(!compliance::is_whitelisted(signer::address_of(&user1), admin_addr), 1);
}

#[test(admin = @0x1, user1 = @0x2)]
#[expected_failure(abort_code = 2, location = compliance)]
fun test_remove_nonexistent(admin: signer, user1: signer) {
    compliance::initialize_for_test(&admin);
    // Try to remove address that was never whitelisted
    compliance::remove_from_whitelist(&admin, signer::address_of(&user1));
}

#[test(admin = @0x1)]
fun test_get_whitelist_count(admin: signer) {
    compliance::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    assert!(compliance::get_whitelist_count(admin_addr) == 0, 0);
    
    compliance::whitelist_address(&admin, @0x100);
    assert!(compliance::get_whitelist_count(admin_addr) == 1, 1);
    
    compliance::whitelist_address(&admin, @0x200);
    assert!(compliance::get_whitelist_count(admin_addr) == 2, 2);
    
    compliance::remove_from_whitelist(&admin, @0x100);
    // Count doesn't decrease on removal (as per current implementation)
    // This could be changed if needed
}

}

