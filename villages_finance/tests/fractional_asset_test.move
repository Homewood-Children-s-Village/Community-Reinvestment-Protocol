#[test_only]
module villages_finance::fractional_asset_test {

use villages_finance::fractional_asset;
use villages_finance::admin;
use std::signer;

#[test(admin = @0x1, user1 = @0x2)]
fun test_mint_shares(admin: signer, user1: signer) {
    fractional_asset::initialize_for_test(&admin, 1);
    let admin_addr = signer::address_of(&admin);
    let user1_addr = signer::address_of(&user1);
    
    let pool_id = 1;
    let share_amount = 100;
    let shares_addr = admin_addr;
    fractional_asset::mint_shares(&admin, pool_id, user1_addr, share_amount, shares_addr);
    
    let shares = fractional_asset::get_shares(user1_addr, pool_id, shares_addr);
    assert!(shares == share_amount, 0);
    
    let total = fractional_asset::get_total_shares(pool_id, shares_addr);
    assert!(total == share_amount, 1);
}

#[test(admin = @0x1)]
#[expected_failure(abort_code = 65540, location = fractional_asset)]
fun test_mint_zero_shares(admin: signer) {
    fractional_asset::initialize_for_test(&admin, 1);
    let admin_addr = signer::address_of(&admin);
    fractional_asset::mint_shares(&admin, 1, @0x100, 0, admin_addr);
}

#[test(admin = @0x1)]
fun test_burn_shares(admin: signer) {
    fractional_asset::initialize_for_test(&admin, 1);
    let admin_addr = signer::address_of(&admin);
    
    let pool_id = 1;
    let shares_addr = admin_addr;
    fractional_asset::mint_shares(&admin, pool_id, admin_addr, 100, shares_addr);
    
    fractional_asset::burn_shares(&admin, pool_id, 30, shares_addr);
    
    let shares = fractional_asset::get_shares(admin_addr, pool_id, shares_addr);
    assert!(shares == 70, 0);
}

#[test(admin = @0x1, user1 = @0x2)]
fun test_transfer_shares(admin: signer, user1: signer) {
    fractional_asset::initialize_for_test(&admin, 1);
    let admin_addr = signer::address_of(&admin);
    let user1_addr = signer::address_of(&user1);
    
    let pool_id = 1;
    let shares_addr = admin_addr;
    fractional_asset::mint_shares(&admin, pool_id, admin_addr, 100, shares_addr);
    
    fractional_asset::transfer_shares(&admin, pool_id, user1_addr, 40, shares_addr);
    
    let admin_shares = fractional_asset::get_shares(admin_addr, pool_id, shares_addr);
    assert!(admin_shares == 60, 0);
    
    let user1_shares = fractional_asset::get_shares(user1_addr, pool_id, shares_addr);
    assert!(user1_shares == 40, 1);
}

}

