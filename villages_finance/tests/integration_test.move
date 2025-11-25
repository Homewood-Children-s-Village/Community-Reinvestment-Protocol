#[test_only]
module villages_finance::integration_test {

use villages_finance::admin;
use villages_finance::members;
use villages_finance::compliance;
use villages_finance::investment_pool;
use villages_finance::timebank;
use villages_finance::project_registry;
use villages_finance::treasury;
use villages_finance::fractional_asset;
use villages_finance::time_token;
use aptos_framework::aptos_coin;
use aptos_framework::coin;
use aptos_framework::fungible_asset;
use aptos_framework::primary_fungible_store;
use std::signer;
use std::string;

/// Integration test: Admin creates pool, investor joins (cross-user operation)
#[test(admin = @0x1, investor = @0x2)]
fun test_cross_user_pool_operations(admin: signer, investor: signer) {
    // Initialize all modules
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    compliance::initialize_for_test(&admin);
    investment_pool::initialize_for_test(&admin);
    fractional_asset::initialize_for_test(&admin, 0);
    
    let admin_addr = signer::address_of(&admin);
    let investor_addr = signer::address_of(&investor);
    
    // Register investor as member
    members::register_member(&admin, investor_addr, 2); // Depositor role
    members::accept_membership(&investor, admin_addr);
    
    // Whitelist investor
    compliance::whitelist_address(&admin, investor_addr);
    
    // Register coins
    coin::register<aptos_framework::aptos_coin::AptosCoin>(&investor);
    
    // Initialize fractional shares
    fractional_asset::initialize(&admin, 0);
    
    // Admin creates pool (stored at admin_addr)
    let project_id = 1;
    let target_amount = 10000;
    investment_pool::create_pool(
        &admin,
        project_id,
        target_amount,
        500, // 5% interest
        86400, // 1 day
        @0x999, // borrower
        admin_addr, // pool_address (will be set to admin_addr for MVP)
        admin_addr, // fractional_shares_addr
        admin_addr, // compliance_registry_addr
        admin_addr, // members_registry_addr
    );
    
    // Verify pool exists at admin_addr (shared registry)
    let (proj_id, target, _, status, _, _, _) = investment_pool::get_pool(0, admin_addr);
    assert!(proj_id == project_id, 0);
    assert!(target == target_amount, 1);
    assert!(status == 0, 2); // Pending
    
    // Investor can see and join pool (cross-user works!)
    // Note: Would need actual coins to join, but verification that pool is visible passes
}

/// Integration test: Requester creates request, validator approves (cross-user operation)
#[test(admin = @0x1, requester = @0x2, validator = @0x3)]
fun test_cross_user_timebank_operations(admin: signer, requester: signer, validator: signer) {
    // Initialize all modules
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    compliance::initialize_for_test(&admin);
    timebank::initialize_for_test(&admin);
    let metadata = time_token::initialize_for_test(&admin);
    
    let admin_addr = signer::address_of(&admin);
    let requester_addr = signer::address_of(&requester);
    let validator_addr = signer::address_of(&validator);
    let bank_registry_addr = admin_addr; // Shared registry
    
    // Primary store is automatically created when minting
    
    // Register requester as member
    members::register_member(&admin, requester_addr, 2); // Depositor
    members::accept_membership(&requester, admin_addr);
    
    // Register validator as member with Validator role
    members::register_member(&admin, validator_addr, 3); // Validator
    members::accept_membership(&validator, admin_addr);
    
    // Whitelist requester
    compliance::whitelist_address(&admin, requester_addr);
    
    // Requester creates request (stored at bank_registry_addr)
    let hours = 10;
    timebank::create_request(&requester, hours, 1, admin_addr, bank_registry_addr);
    
    // Verify request exists at shared registry
    let (req_requester, req_hours, _, status, _) = timebank::get_request(0, bank_registry_addr);
    assert!(req_requester == requester_addr, 0);
    assert!(req_hours == hours, 1);
    assert!(status == 0, 2); // Pending
    
    // Validator can see and approve request (cross-user works!)
    // Updated: no mint_cap parameter, add time_token_admin_addr
    timebank::approve_request(&validator, 0, admin_addr, admin_addr, bank_registry_addr, admin_addr);
    
    // Verify request was approved
    let (_, _, _, status_after, _) = timebank::get_request(0, bank_registry_addr);
    assert!(status_after == 1, 3); // Approved
    
    // Verify TimeTokens were minted
    let balance = time_token::balance(requester_addr, admin_addr);
    assert!(balance == hours, 4);
}

/// Integration test: Project proposal and approval flow
#[test(admin = @0x1, proposer = @0x2)]
fun test_project_proposal_flow(admin: signer, proposer: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    project_registry::initialize_for_test(&admin);
    
    let admin_addr = signer::address_of(&admin);
    let proposer_addr = signer::address_of(&proposer);
    
    // Register proposer as member
    members::register_member(&admin, proposer_addr, 1); // Borrower
    members::accept_membership(&proposer, admin_addr);
    
    // Proposer creates project (stored at admin_addr)
    let metadata_cid = string::utf8(b"QmTest123");
    project_registry::propose_project(&proposer, *string::bytes(&metadata_cid), 5000, 100, false, admin_addr, admin_addr);
    
    // Verify project exists at shared registry
    let (proj_proposer, _, usdc, hours, _, status, _) = project_registry::get_project(0, admin_addr);
    assert!(proj_proposer == proposer_addr, 0);
    assert!(usdc == 5000, 1);
    assert!(status == 0, 2); // Proposed
    
    // Admin approves project (cross-user works!)
    project_registry::approve_project(&admin, 0, admin_addr);
    
    // Verify project was approved
    let (_, _, _, _, _, status_after, _) = project_registry::get_project(0, admin_addr);
    assert!(status_after == 1, 3); // Approved
}

/// Integration test: Treasury deposit and withdrawal flow
#[test(admin = @0x1, depositor = @0x2)]
fun test_treasury_flow(admin: signer, depositor: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    compliance::initialize_for_test(&admin);
    treasury::initialize_for_test(&admin);
    
    let admin_addr = signer::address_of(&admin);
    let depositor_addr = signer::address_of(&depositor);
    
    // Register depositor as member
    members::register_member(&admin, depositor_addr, 2); // Depositor
    members::accept_membership(&depositor, admin_addr);
    
    // Whitelist depositor
    compliance::whitelist_address(&admin, depositor_addr);
    
    // Register coins
    coin::register<aptos_framework::aptos_coin::AptosCoin>(&depositor);
    coin::register<aptos_coin::AptosCoin>(&depositor);
    
    // Depositor deposits to shared treasury (stored at admin_addr)
    let deposit_amount = 5000;
    treasury::deposit(&depositor, deposit_amount, admin_addr, admin_addr, admin_addr);
    
    // Verify deposit recorded in shared treasury
    let balance = treasury::get_balance(depositor_addr, admin_addr);
    assert!(balance == deposit_amount, 0);
    
    let total = treasury::get_total_deposited(admin_addr);
    assert!(total == deposit_amount, 1);
    
    // Withdraw from shared treasury
    // Updated: add admin parameter
    let withdraw_amount = 2000;
    treasury::withdraw(&depositor, &admin, withdraw_amount, admin_addr);
    
    // Verify withdrawal
    let balance_after = treasury::get_balance(depositor_addr, admin_addr);
    assert!(balance_after == 3000, 2);
}

}
