#[test_only]
module villages_finance::project_registry_test {

use villages_finance::project_registry;
use villages_finance::admin;
use villages_finance::members;
use villages_finance::investment_pool;
use villages_finance::compliance;
use villages_finance::fractional_asset;
use std::signer;
use std::string;

#[test(admin = @0x1, user1 = @0x2)]
fun test_propose_project(admin: signer, user1: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    project_registry::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    let user1_addr = signer::address_of(&user1);
    
    // Register user1 as member
    members::register_member(&admin, user1_addr, 1); // Borrower
    members::accept_membership(&user1, admin_addr);
    
    let metadata_cid = string::utf8(b"QmTest123");
    let target_usdc = 5000;
    let target_hours = 100;
    let is_grant = false;
    
    project_registry::propose_project(&user1, *string::bytes(&metadata_cid), target_usdc, target_hours, is_grant, admin_addr, admin_addr);
    
    // Check project was created
    let (proposer, cid, usdc, hours, grant, status, _) = project_registry::get_project(0, admin_addr);
    assert!(proposer == user1_addr, 0);
    assert!(usdc == target_usdc, 1);
    assert!(hours == target_hours, 2);
    assert!(grant == is_grant, 3);
    assert!(status == 0, 4); // Proposed
}

#[test(admin = @0x1)]
fun test_approve_project(admin: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    project_registry::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    let metadata_cid = string::utf8(b"QmTest123");
    project_registry::propose_project(&admin, *string::bytes(&metadata_cid), 5000, 100, false, admin_addr, admin_addr);
    
    project_registry::approve_project(&admin, 0, admin_addr);
    
    let (_, _, _, _, _, status, _) = project_registry::get_project(0, admin_addr);
    assert!(status == 1, 0); // Approved
}

#[test(admin = @0x1)]
fun test_update_status(admin: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    project_registry::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    let metadata_cid = string::utf8(b"QmTest123");
    project_registry::propose_project(&admin, *string::bytes(&metadata_cid), 5000, 100, false, admin_addr, admin_addr);
    
    project_registry::update_status(&admin, 0, 2, admin_addr); // Set to Active
    let (_, _, _, _, _, status, _) = project_registry::get_project(0, admin_addr);
    assert!(status == 2, 0);
    
    project_registry::update_status(&admin, 0, 3, admin_addr); // Set to Completed
    let (_, _, _, _, _, status, _) = project_registry::get_project(0, admin_addr);
    assert!(status == 3, 1);
}

#[test(admin = @0x1)]
fun test_cancel_project(admin: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    project_registry::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    let metadata_cid = string::utf8(b"QmTest123");
    project_registry::propose_project(&admin, *string::bytes(&metadata_cid), 5000, 100, false, admin_addr, admin_addr);
    
    // Cancel project (status 4 = Cancelled)
    project_registry::update_status(&admin, 0, 4, admin_addr);
    
    let (_, _, _, _, _, status, _) = project_registry::get_project(0, admin_addr);
    assert!(status == 4, 0); // Cancelled
}

#[test(admin = @0x1)]
fun test_cancel_project_status_transition(admin: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    project_registry::initialize_for_test(&admin);
    let admin_addr = signer::address_of(&admin);
    
    let metadata_cid = string::utf8(b"QmTest123");
    project_registry::propose_project(&admin, *string::bytes(&metadata_cid), 5000, 100, false, admin_addr, admin_addr);
    
    // Verify initial status is Proposed (0)
    let (_, _, _, _, _, status0, _) = project_registry::get_project(0, admin_addr);
    assert!(status0 == 0, 0); // Proposed
    
    // Approve project
    project_registry::approve_project(&admin, 0, admin_addr);
    let (_, _, _, _, _, status1, _) = project_registry::get_project(0, admin_addr);
    assert!(status1 == 1, 1); // Approved
    
    // Cancel from Approved status
    project_registry::update_status(&admin, 0, 4, admin_addr);
    let (_, _, _, _, _, status2, _) = project_registry::get_project(0, admin_addr);
    assert!(status2 == 4, 2); // Cancelled
}

#[test(admin = @0x1, user1 = @0x2)]
fun test_cancel_project_with_active_pool(admin: signer, user1: signer) {
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    project_registry::initialize_for_test(&admin);
    investment_pool::initialize_for_test(&admin);
    compliance::initialize_for_test(&admin);
    fractional_asset::initialize_for_test(&admin, 0);
    
    let admin_addr = signer::address_of(&admin);
    let user1_addr = signer::address_of(&user1);
    
    // Propose and approve project
    let metadata_cid = string::utf8(b"QmTest123");
    project_registry::propose_project(&user1, *string::bytes(&metadata_cid), 5000, 100, false, admin_addr, admin_addr);
    project_registry::approve_project(&admin, 0, admin_addr);
    
    // Create pool for project
    investment_pool::create_pool(&admin, 0, 5000, 500, 86400, user1_addr, admin_addr, admin_addr, admin_addr, admin_addr);
    
    // Cancel project - pool should still exist but project is cancelled
    project_registry::update_status(&admin, 0, 4, admin_addr);
    
    let (_, _, _, _, _, status, _) = project_registry::get_project(0, admin_addr);
    assert!(status == 4, 0); // Cancelled
    
    // Verify pool still exists
    let (proj_id, _, _, pool_status, _, _, _) = investment_pool::get_pool(0, admin_addr);
    assert!(proj_id == 0, 1);
    assert!(pool_status == 0, 2); // Pool still Pending
}

}

