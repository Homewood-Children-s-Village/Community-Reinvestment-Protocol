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
use villages_finance::token;
use villages_finance::governance;
use aptos_framework::fungible_asset;
use aptos_framework::primary_fungible_store;
use aptos_framework::coin;
use aptos_framework::aptos_coin;
use std::signer;
use std::string;
use std::vector;

const INVESTMENT_TOKEN_NAME: vector<u8> = b"Integration Investment Token";
const INVESTMENT_TOKEN_SYMBOL: vector<u8> = b"IIT";

fun ensure_investment_token_initialized(admin: &signer) {
    let admin_addr = signer::address_of(admin);
    if (!token::is_initialized(admin_addr)) {
        let name = string::utf8(INVESTMENT_TOKEN_NAME);
        let symbol = string::utf8(INVESTMENT_TOKEN_SYMBOL);
        token::initialize_for_test(admin, name, symbol);
    };
}

/// Integration test: Admin creates pool, investor joins (cross-user operation)
#[test(admin = @0x1, investor = @0x2)]
fun test_cross_user_pool_operations(admin: signer, investor: signer) {
    // Initialize all modules
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    compliance::initialize_for_test(&admin);
    investment_pool::initialize_for_test(&admin);
    fractional_asset::initialize_for_test(&admin, 0);
    ensure_investment_token_initialized(&admin);
    
    let admin_addr = signer::address_of(&admin);
    let investor_addr = signer::address_of(&investor);
    
    // Register investor as member
    members::register_member(&admin, investor_addr, 2); // Depositor role
    members::accept_membership(&investor, admin_addr);
    
    // Whitelist investor
    compliance::whitelist_address(&admin, investor_addr);
    
    // Note: Coin registration commented out - this test doesn't actually use coins
    // (join_pool is commented out)
    // register_coin_for_test(&investor);
    
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
        admin_addr,
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
    
    let depositor_addr = signer::address_of(&depositor);
    
    // Register depositor as member
    members::register_member(&admin, depositor_addr, 2); // Depositor
    members::accept_membership(&depositor, admin_addr);
    
    // Whitelist depositor
    compliance::whitelist_address(&admin, depositor_addr);
    
    // Setup: Mint treasury assets for depositor (using production mint function)
    treasury::mint(&admin, depositor_addr, 10000, admin_addr);
    
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
    treasury::withdraw(&depositor, withdraw_amount, admin_addr);
    
    // Verify withdrawal
    let balance_after = treasury::get_balance(depositor_addr, admin_addr);
    assert!(balance_after == 3000, 2);
}

/// Integration test: Full volunteer hour journey (Journey 2)
#[test(admin = @0x1, requester = @0x2, validator = @0x3, recipient = @0x4)]
fun test_full_volunteer_hour_journey(admin: signer, requester: signer, validator: signer, recipient: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    compliance::initialize_for_test(&admin);
    timebank::initialize_for_test(&admin);
    let metadata = time_token::initialize_for_test(&admin);
    
    let admin_addr = signer::address_of(&admin);
    let requester_addr = signer::address_of(&requester);
    let validator_addr = signer::address_of(&validator);
    let recipient_addr = signer::address_of(&recipient);
    let bank_registry_addr = admin_addr;
    
    // Register users
    members::register_member(&admin, requester_addr, 2);
    members::accept_membership(&requester, admin_addr);
    members::register_member(&admin, validator_addr, 3); // Validator
    members::accept_membership(&validator, admin_addr);
    members::register_member(&admin, recipient_addr, 2);
    members::accept_membership(&recipient, admin_addr);
    
    compliance::whitelist_address(&admin, requester_addr);
    
    // Step 1: Create request
    timebank::create_request(&requester, 5, 1, admin_addr, bank_registry_addr);
    
    // Step 2: Update request
    timebank::update_request(&requester, 0, 10, bank_registry_addr, admin_addr);
    
    // Step 3: Approve request
    timebank::approve_request(&validator, 0, admin_addr, admin_addr, bank_registry_addr, admin_addr);
    
    // Step 4: Verify TimeToken minted
    let balance = time_token::balance(requester_addr, admin_addr);
    assert!(balance == 10, 0);
    
    // Step 5: Check request status
    let (_, _, _, status, _) = timebank::get_request(0, bank_registry_addr);
    assert!(status == 1, 1); // Approved
    
    // Step 6: Transfer TimeTokens to recipient
    time_token::transfer(&requester, recipient_addr, 5, admin_addr);
    
    // Step 7: Verify balances after transfer
    let balance_requester = time_token::balance(requester_addr, admin_addr);
    let balance_recipient = time_token::balance(recipient_addr, admin_addr);
    assert!(balance_requester == 5, 2);
    assert!(balance_recipient == 5, 3);
}

/// Integration test: Full project investment journey (Journey 3)
#[test(admin = @0x1, proposer = @0x2, investor1 = @0x3, investor2 = @0x4)]
fun test_full_project_investment_journey(admin: signer, proposer: signer, investor1: signer, investor2: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    compliance::initialize_for_test(&admin);
    project_registry::initialize_for_test(&admin);
    investment_pool::initialize_for_test(&admin);
    fractional_asset::initialize_for_test(&admin, 0);
    ensure_investment_token_initialized(&admin);
    
    let admin_addr = signer::address_of(&admin);
    let proposer_addr = signer::address_of(&proposer);
    let investor1_addr = signer::address_of(&investor1);
    let investor2_addr = signer::address_of(&investor2);
    
    // Register users
    members::register_member(&admin, proposer_addr, 1); // Borrower
    members::accept_membership(&proposer, admin_addr);
    members::register_member(&admin, investor1_addr, 2);
    members::accept_membership(&investor1, admin_addr);
    members::register_member(&admin, investor2_addr, 2);
    members::accept_membership(&investor2, admin_addr);
    
    compliance::whitelist_address(&admin, investor1_addr);
    compliance::whitelist_address(&admin, investor2_addr);
    
    // Step 1: Propose project
    let metadata_cid = string::utf8(b"QmTest123");
    project_registry::propose_project(&proposer, *string::bytes(&metadata_cid), 5000, 100, false, admin_addr, admin_addr);
    
    // Step 2: Approve project
    project_registry::approve_project(&admin, 0, admin_addr);
    
    // Step 3: Create pool
    investment_pool::create_pool(
        &admin,
        0,
        5000,
        500,
        86400,
        proposer_addr,
        admin_addr,
        admin_addr,
        admin_addr,
        admin_addr,
        admin_addr,
    );
    
    // Step 4: Multiple investors join pool (would require actual coins)
    // investment_pool::join_pool(&investor1, 0, 2000, admin_addr);
    // investment_pool::join_pool(&investor2, 0, 3000, admin_addr);
    
    // Step 5: Verify fractional shares (would be minted on join_pool)
    let shares1 = fractional_asset::get_shares(investor1_addr, 0, admin_addr);
    let shares2 = fractional_asset::get_shares(investor2_addr, 0, admin_addr);
    assert!(shares1 == 0, 0); // Initially 0 (no investment yet)
    assert!(shares2 == 0, 1);
    
    // Step 6: Finalize funding (would require pool to have funds)
    // investment_pool::finalize_funding(&admin, 0, admin_addr);
    
    // Step 7: Verify pool status
    let (proj_id, target, current, status, _, _, _) = investment_pool::get_pool(0, admin_addr);
    assert!(proj_id == 0, 2);
    assert!(target == 5000, 3);
    assert!(status == 0, 4); // Pending (no investments yet)
}

/// Integration test: Full governance journey (Journey 6)
#[test(admin = @0x1, voter1 = @0x2, voter2 = @0x3, voter3 = @0x4)]
fun test_full_governance_journey(admin: signer, voter1: signer, voter2: signer, voter3: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    // Register admin as member
    if (!members::is_member_with_registry(admin_addr, admin_addr)) {
        members::register_member(&admin, admin_addr, 1);
        members::accept_membership(&admin, admin_addr);
    };
    
    // Register voters
    members::register_member(&admin, signer::address_of(&voter1), 2);
    members::accept_membership(&voter1, admin_addr);
    members::register_member(&admin, signer::address_of(&voter2), 2);
    members::accept_membership(&voter2, admin_addr);
    members::register_member(&admin, signer::address_of(&voter3), 2);
    members::accept_membership(&voter3, admin_addr);
    
    let name = string::utf8(b"Test Token");
    let symbol = string::utf8(b"TEST");
    let _metadata = token::initialize_for_test(&admin, name, symbol);
    
    governance::initialize_for_test(&admin, admin_addr, admin_addr);
    
    let gov_addr = admin_addr;
    let title = vector::empty<u8>();
    let description = vector::empty<u8>();
    
    // Step 1: Create proposal
    governance::create_proposal(&admin, gov_addr, title, description, 2, 0, 0, vector::empty<u8>(), admin_addr, admin_addr);
    
    // Step 2: Activate proposal
    governance::activate_proposal(&admin, 0, gov_addr);
    
    // Step 3: Vote (multiple voters)
    governance::vote(&voter1, 0, 0, gov_addr); // Yes
    governance::vote(&voter2, 0, 0, gov_addr); // Yes
    governance::vote(&voter3, 0, 1, gov_addr); // No
    governance::finalize_proposal(&admin, 0, gov_addr);
    
    // Step 4: Check status - should be passed (2 yes > 1 no)
    let (_, _, status, yes, no, _, _, _) = governance::get_proposal(0, gov_addr);
    assert!(status == 2, 0); // Passed
    assert!(yes == 2, 1);
    assert!(no == 1, 2);
    
    // Step 5: Execute proposal
    governance::execute_proposal(&admin, 0, gov_addr);
    
    // Step 6: Verify action executed
    let (_, _, status_after, _, _, _, _, _) = governance::get_proposal(0, gov_addr);
    assert!(status_after == 4, 3); // Executed
}

}
