#[test_only]
module villages_finance::token_test {

use villages_finance::token;
use villages_finance::admin;
use aptos_framework::fungible_asset;
use aptos_framework::primary_fungible_store;
use std::signer;
use std::string;

#[test(admin = @0x1, user1 = @0x2)]
fun test_initialize_and_mint(admin: signer, user1: signer) {
    admin::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let user1_addr = signer::address_of(&user1);
    
    let name = string::utf8(b"Villages Token");
    let symbol = string::utf8(b"VIL");
    let metadata = token::initialize_for_test(&admin, name, symbol);
    
    // Mint tokens to user1
    let amount = 1000;
    token::mint_entry(&admin, user1_addr, amount, admin_addr);
    
    // Check balance - metadata is now Object<Metadata>
    let balance = primary_fungible_store::balance(user1_addr, metadata);
    assert!(balance == amount, 0);
}

#[test(admin = @0x1)]
fun test_burn(admin: signer) {
    admin::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    let name = string::utf8(b"Villages Token");
    let symbol = string::utf8(b"VIL");
    let metadata = token::initialize_for_test(&admin, name, symbol);
    
    // Mint tokens
    let mint_amount = 1000;
    token::mint_entry(&admin, admin_addr, mint_amount, admin_addr);
    
    // Withdraw asset and burn some - metadata is now Object<Metadata>
    let asset = token::withdraw(&admin, 300, admin_addr);
    token::burn(&admin, asset, admin_addr);
    
    // Check balance
    let balance = primary_fungible_store::balance(admin_addr, metadata);
    assert!(balance == 700, 0);
}

#[test(admin = @0x1)]
#[expected_failure(abort_code = 65538, location = token)]
fun test_mint_zero_amount(admin: signer) {
    admin::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    let name = string::utf8(b"Villages Token");
    let symbol = string::utf8(b"VIL");
    let metadata = token::initialize_for_test(&admin, name, symbol);
    
    token::mint_entry(&admin, admin_addr, 0, admin_addr);
}

}

