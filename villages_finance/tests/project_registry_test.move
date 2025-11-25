#[test_only]
module villages_finance::project_registry_test;

use villages_finance::project_registry;
use villages_finance::admin;
use villages_finance::members;
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
    
    project_registry::propose_project(&user1, metadata_cid, target_usdc, target_hours, is_grant, admin_addr, admin_addr);
    
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
    project_registry::propose_project(&admin, metadata_cid, 5000, 100, false, admin_addr, admin_addr);
    
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
    project_registry::propose_project(&admin, metadata_cid, 5000, 100, false, admin_addr, admin_addr);
    
    project_registry::update_status(&admin, 0, 2, admin_addr); // Set to Active
    let (_, _, _, _, _, status, _) = project_registry::get_project(0, admin_addr);
    assert!(status == 2, 0);
    
    project_registry::update_status(&admin, 0, 3, admin_addr); // Set to Completed
    let (_, _, _, _, _, status, _) = project_registry::get_project(0, admin_addr);
    assert!(status == 3, 1);
}

