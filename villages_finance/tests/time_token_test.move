#[test_only]
module villages_finance::time_token_test {

use villages_finance::time_token;
use villages_finance::admin;
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
#[expected_failure(abort_code = 2, location = time_token)]
fun test_mint_zero_hours(admin: signer) {
    admin::initialize_for_test(&admin);
    let metadata = time_token::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    time_token::mint_entry(&admin, admin_addr, 0, admin_addr);
}

}
