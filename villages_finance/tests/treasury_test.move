#[test_only]
module villages_finance::treasury_test {

use villages_finance::treasury;
use villages_finance::admin;
use villages_finance::members;
use villages_finance::compliance;
use aptos_framework::fungible_asset;
use std::signer;
use std::string;

#[test(admin = @0x1, user1 = @0x2)]
fun test_initialize_and_deposit(admin: signer, user1: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    compliance::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    // Initialize treasury with FA metadata (same flow as production)
    if (!treasury::exists_treasury(admin_addr)) {
        treasury::initialize(
            &admin,
            b"Test Token",
            b"TTK",
            6, // decimals
            b"Test token for treasury operations"
        );
    };
    
    // Register admin as member and whitelist
    members::accept_membership(&admin, admin_addr);
    compliance::whitelist_address(&admin, admin_addr);
    
    // Setup: Mint treasury assets for depositor (using production mint function)
    treasury::mint(&admin, signer::address_of(&admin), 10000, admin_addr);
    treasury::mint(&admin, signer::address_of(&user1), 10000, admin_addr);
    
    // Deposit 1000 fungible assets
    let amount = 1000;
    treasury::deposit(&admin, amount, admin_addr, admin_addr, admin_addr);
    
    let balance = treasury::get_balance(admin_addr, admin_addr);
    assert!(balance == amount, 0);
    
    let total = treasury::get_total_deposited(admin_addr);
    assert!(total == amount, 1);
}

#[test(admin = @0x1)]
#[expected_failure(abort_code = 65538, location = treasury)]
fun test_deposit_zero(admin: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    compliance::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    // Initialize treasury with FA metadata (same flow as production)
    if (!treasury::exists_treasury(admin_addr)) {
        treasury::initialize(
            &admin,
            b"Test Token",
            b"TTK",
            6, // decimals
            b"Test token for treasury operations"
        );
    };
    members::accept_membership(&admin, admin_addr);
    compliance::whitelist_address(&admin, admin_addr);
    treasury::deposit(&admin, 0, admin_addr, admin_addr, admin_addr);
}

#[test(admin = @0x1)]
fun test_withdraw(admin: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    compliance::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    // Initialize treasury with FA metadata (same flow as production)
    if (!treasury::exists_treasury(admin_addr)) {
        treasury::initialize(
            &admin,
            b"Test Token",
            b"TTK",
            6, // decimals
            b"Test token for treasury operations"
        );
    };
    
    members::accept_membership(&admin, admin_addr);
    compliance::whitelist_address(&admin, admin_addr);
    
    // Setup: Mint treasury assets (using production mint function)
    treasury::mint(&admin, admin_addr, 10000, admin_addr);
    
    // Deposit
    let deposit_amount = 1000;
    treasury::deposit(&admin, deposit_amount, admin_addr, admin_addr, admin_addr);
    
    // Withdraw - Updated: add admin parameter (same signer for MVP)
    let withdraw_amount = 300;
    treasury::withdraw(&admin, &admin, withdraw_amount, admin_addr);
    
    let balance = treasury::get_balance(admin_addr, admin_addr);
    assert!(balance == 700, 0);
}

#[test(admin = @0x1)]
#[expected_failure(abort_code = 196611, location = treasury)]
fun test_withdraw_insufficient(admin: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    compliance::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    // Initialize treasury with FA metadata (same flow as production)
    if (!treasury::exists_treasury(admin_addr)) {
        treasury::initialize(
            &admin,
            b"Test Token",
            b"TTK",
            6, // decimals
            b"Test token for treasury operations"
        );
    };
    members::accept_membership(&admin, admin_addr);
    compliance::whitelist_address(&admin, admin_addr);
    
    // Setup: Mint treasury assets (using production mint function)
    treasury::mint(&admin, admin_addr, 10000, admin_addr);
    
    treasury::deposit(&admin, 100, admin_addr, admin_addr, admin_addr);
    // Updated: add admin parameter
    treasury::withdraw(&admin, &admin, 200, admin_addr);
}

#[test(admin = @0x1)]
fun test_transfer_to_pool(admin: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    compliance::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    // Initialize treasury with FA metadata (same flow as production)
    if (!treasury::exists_treasury(admin_addr)) {
        treasury::initialize(
            &admin,
            b"Test Token",
            b"TTK",
            6, // decimals
            b"Test token for treasury operations"
        );
    };
    
    members::accept_membership(&admin, admin_addr);
    compliance::whitelist_address(&admin, admin_addr);
    
    // Setup: Mint treasury assets (using production mint function)
    treasury::mint(&admin, admin_addr, 10000, admin_addr);
    
    treasury::deposit(&admin, 1000, admin_addr, admin_addr, admin_addr);
    
    let pool_id = 1;
    let transfer_amount = 500;
    let pool_address = @0x999; // Mock pool address
    // Updated: add admin parameter
    treasury::transfer_to_pool(&admin, pool_id, transfer_amount, pool_address, admin_addr);
    
    let balance = treasury::get_balance(admin_addr, admin_addr);
    assert!(balance == 500, 0);
}

}
