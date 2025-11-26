#[test_only]
module villages_finance::time_token_test {

use villages_finance::time_token;
use villages_finance::admin;
use villages_finance::compliance;
use aptos_framework::fungible_asset;
use aptos_framework::primary_fungible_store;
use std::signer;

#[test(admin = @0x1, user1 = @0x2)]
fun test_initialize_and_mint(admin: signer, user1: signer) {
    admin::initialize_for_test(&admin);
    let metadata = time_token::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let user1_addr = signer::address_of(&user1);
    
    // Primary store is automatically created when minting
    // Mint 10 hours to user1
    let hours = 10;
    time_token::mint_entry(&admin, user1_addr, hours, admin_addr);
    
    // Check balance
    let balance = time_token::balance(user1_addr, admin_addr);
    assert!(balance == hours, 0);
}

#[test(admin = @0x1, user1 = @0x2)]
fun test_burn(admin: signer, user1: signer) {
    admin::initialize_for_test(&admin);
    let _metadata = time_token::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let user1_addr = signer::address_of(&user1);
    
    // Primary store is automatically created when minting
    // Mint 20 hours
    let mint_hours = 20;
    time_token::mint_entry(&admin, user1_addr, mint_hours, admin_addr);
    
    // Burn 5 hours
    let burn_hours = 5;
    time_token::burn_entry(&user1, burn_hours, admin_addr);
    
    // Check balance
    let balance = time_token::balance(user1_addr, admin_addr);
    assert!(balance == 15, 0);
}

#[test(admin = @0x1)]
#[expected_failure(abort_code = 65538, location = time_token)]
fun test_mint_zero_hours(admin: signer) {
    admin::initialize_for_test(&admin);
    let metadata = time_token::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    time_token::mint_entry(&admin, admin_addr, 0, admin_addr);
}

#[test(admin = @0x1, user1 = @0x2)]
#[expected_failure(abort_code = 65539, location = time_token)]
fun test_burn_insufficient_balance(admin: signer, user1: signer) {
    admin::initialize_for_test(&admin);
    let _metadata = time_token::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let user1_addr = signer::address_of(&user1);
    
    // Mint 10 hours
    time_token::mint_entry(&admin, user1_addr, 10, admin_addr);
    
    // Try to burn more than balance - should fail
    time_token::burn_entry(&user1, 20, admin_addr);
}

#[test(admin = @0x1, user1 = @0x2)]
fun test_time_token_spending(admin: signer, user1: signer) {
    admin::initialize_for_test(&admin);
    let _metadata = time_token::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let user1_addr = signer::address_of(&user1);
    
    // Mint 100 hours
    time_token::mint_entry(&admin, user1_addr, 100, admin_addr);
    
    // Spend (burn) 30 hours
    time_token::burn_entry(&user1, 30, admin_addr);
    
    // Verify remaining balance
    let balance = time_token::balance(user1_addr, admin_addr);
    assert!(balance == 70, 0);
    
    // Spend more
    time_token::burn_entry(&user1, 20, admin_addr);
    
    // Verify final balance
    let final_balance = time_token::balance(user1_addr, admin_addr);
    assert!(final_balance == 50, 1);
}

#[test(admin = @0x1, user1 = @0x2, user2 = @0x3)]
fun test_time_token_transfer(admin: signer, user1: signer, user2: signer) {
    admin::initialize_for_test(&admin);
    let _metadata = time_token::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let user1_addr = signer::address_of(&user1);
    let user2_addr = signer::address_of(&user2);
    
    // Mint 100 hours to user1
    time_token::mint_entry(&admin, user1_addr, 100, admin_addr);
    
    // Transfer 30 hours from user1 to user2 (unrestricted by default)
    time_token::transfer(&user1, user2_addr, 30, admin_addr);
    
    // Verify balances
    let balance1 = time_token::balance(user1_addr, admin_addr);
    let balance2 = time_token::balance(user2_addr, admin_addr);
    assert!(balance1 == 70, 0);
    assert!(balance2 == 30, 1);
    
    // Transfer more
    time_token::transfer(&user1, user2_addr, 20, admin_addr);
    
    // Verify final balances
    let final_balance1 = time_token::balance(user1_addr, admin_addr);
    let final_balance2 = time_token::balance(user2_addr, admin_addr);
    assert!(final_balance1 == 50, 2);
    assert!(final_balance2 == 50, 3);
}

#[test(admin = @0x1, user1 = @0x2, user2 = @0x3)]
#[expected_failure(abort_code = 65539, location = time_token)]
fun test_time_token_transfer_insufficient_balance(admin: signer, user1: signer, user2: signer) {
    admin::initialize_for_test(&admin);
    let _metadata = time_token::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let user1_addr = signer::address_of(&user1);
    let user2_addr = signer::address_of(&user2);
    
    // Mint 50 hours to user1
    time_token::mint_entry(&admin, user1_addr, 50, admin_addr);
    
    // Try to transfer more than balance - should fail
    time_token::transfer(&user1, user2_addr, 100, admin_addr);
}

#[test(admin = @0x1, user1 = @0x2, user2 = @0x3)]
#[expected_failure(abort_code = 65538, location = time_token)]
fun test_time_token_transfer_zero_amount(admin: signer, user1: signer, user2: signer) {
    admin::initialize_for_test(&admin);
    let _metadata = time_token::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let user1_addr = signer::address_of(&user1);
    let user2_addr = signer::address_of(&user2);
    
    // Mint hours to user1
    time_token::mint_entry(&admin, user1_addr, 50, admin_addr);
    
    // Try to transfer zero - should fail
    time_token::transfer(&user1, user2_addr, 0, admin_addr);
}

#[test(admin = @0x1, user1 = @0x2, user2 = @0x3, user3 = @0x4)]
fun test_time_token_transfer_with_restrictions(admin: signer, user1: signer, user2: signer, user3: signer) {
    admin::initialize_for_test(&admin);
    compliance::initialize_for_test(&admin);
    let _metadata = time_token::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let user1_addr = signer::address_of(&user1);
    let user2_addr = signer::address_of(&user2);
    let user3_addr = signer::address_of(&user3);
    
    // Mint hours to user1
    time_token::mint_entry(&admin, user1_addr, 100, admin_addr);
    
    // Whitelist user1 and user2, but NOT user3
    compliance::whitelist_address(&admin, user1_addr);
    compliance::whitelist_address(&admin, user2_addr);
    
    // Enable transfer restrictions
    time_token::enable_transfer_restrictions(&admin, admin_addr, admin_addr);
    
    // Transfer from user1 (whitelisted) to user2 (whitelisted) - should succeed
    time_token::transfer(&user1, user2_addr, 30, admin_addr);
    
    // Verify transfer succeeded
    let balance1 = time_token::balance(user1_addr, admin_addr);
    let balance2 = time_token::balance(user2_addr, admin_addr);
    assert!(balance1 == 70, 0);
    assert!(balance2 == 30, 1);
    
    // Verify restrictions are enabled
    let restricted = time_token::is_transfer_restricted(admin_addr);
    assert!(restricted == true, 2);
}

#[test(admin = @0x1, user1 = @0x2, user2 = @0x3)]
#[expected_failure(abort_code = 65540, location = time_token)]
fun test_time_token_transfer_restricted_sender_not_whitelisted(admin: signer, user1: signer, user2: signer) {
    admin::initialize_for_test(&admin);
    compliance::initialize_for_test(&admin);
    let _metadata = time_token::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let user1_addr = signer::address_of(&user1);
    let user2_addr = signer::address_of(&user2);
    
    // Mint hours to user1
    time_token::mint_entry(&admin, user1_addr, 100, admin_addr);
    
    // Whitelist user2 but NOT user1
    compliance::whitelist_address(&admin, user2_addr);
    
    // Enable transfer restrictions
    time_token::enable_transfer_restrictions(&admin, admin_addr, admin_addr);
    
    // Try to transfer from user1 (not whitelisted) to user2 (whitelisted) - should fail
    time_token::transfer(&user1, user2_addr, 30, admin_addr);
}

#[test(admin = @0x1, user1 = @0x2, user2 = @0x3)]
#[expected_failure(abort_code = 65540, location = time_token)]
fun test_time_token_transfer_restricted_recipient_not_whitelisted(admin: signer, user1: signer, user2: signer) {
    admin::initialize_for_test(&admin);
    compliance::initialize_for_test(&admin);
    let _metadata = time_token::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let user1_addr = signer::address_of(&user1);
    let user2_addr = signer::address_of(&user2);
    
    // Mint hours to user1
    time_token::mint_entry(&admin, user1_addr, 100, admin_addr);
    
    // Whitelist user1 but NOT user2
    compliance::whitelist_address(&admin, user1_addr);
    
    // Enable transfer restrictions
    time_token::enable_transfer_restrictions(&admin, admin_addr, admin_addr);
    
    // Try to transfer from user1 (whitelisted) to user2 (not whitelisted) - should fail
    time_token::transfer(&user1, user2_addr, 30, admin_addr);
}

#[test(admin = @0x1, user1 = @0x2, user2 = @0x3)]
fun test_enable_disable_transfer_restrictions(admin: signer, user1: signer, user2: signer) {
    admin::initialize_for_test(&admin);
    compliance::initialize_for_test(&admin);
    let _metadata = time_token::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let user1_addr = signer::address_of(&user1);
    let user2_addr = signer::address_of(&user2);
    
    // Mint hours to user1
    time_token::mint_entry(&admin, user1_addr, 100, admin_addr);
    
    // Initially unrestricted - verify
    let restricted1 = time_token::is_transfer_restricted(admin_addr);
    assert!(restricted1 == false, 0);
    
    // Transfer should work (unrestricted)
    time_token::transfer(&user1, user2_addr, 30, admin_addr);
    
    // Enable restrictions
    time_token::enable_transfer_restrictions(&admin, admin_addr, admin_addr);
    let restricted2 = time_token::is_transfer_restricted(admin_addr);
    assert!(restricted2 == true, 1);
    
    // Whitelist both users
    compliance::whitelist_address(&admin, user1_addr);
    compliance::whitelist_address(&admin, user2_addr);
    
    // Transfer should still work (both whitelisted)
    time_token::transfer(&user1, user2_addr, 20, admin_addr);
    
    // Disable restrictions
    time_token::disable_transfer_restrictions(&admin, admin_addr);
    let restricted3 = time_token::is_transfer_restricted(admin_addr);
    assert!(restricted3 == false, 2);
    
    // Transfer should work again (unrestricted)
    time_token::transfer(&user1, user2_addr, 10, admin_addr);
}

#[test(admin = @0x1, user1 = @0x2)]
#[expected_failure(abort_code = 327687, location = time_token)]
fun test_enable_transfer_restrictions_requires_admin(admin: signer, user1: signer) {
    admin::initialize_for_test(&admin);
    compliance::initialize_for_test(&admin);
    let _metadata = time_token::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    // user1 (not admin) tries to enable restrictions - should fail
    time_token::enable_transfer_restrictions(&user1, admin_addr, admin_addr);
}

}
