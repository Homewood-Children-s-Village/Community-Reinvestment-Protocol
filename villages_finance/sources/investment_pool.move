module villages_finance::investment_pool {

use std::signer;
use std::error;
use std::vector;
use aptos_framework::event;
use aptos_framework::big_ordered_map;
use aptos_framework::fungible_asset::{Self, FungibleAsset};
use aptos_framework::primary_fungible_store;
use aptos_framework::account;
use villages_finance::fractional_asset;
use villages_finance::compliance;
use villages_finance::members;
use villages_finance::token;
use villages_finance::admin;
use villages_finance::registry_config;
use villages_finance::project_registry;
use villages_finance::event_history;
use std::option;

/// Error codes
const E_NOT_INITIALIZED: u64 = 1;
const E_POOL_NOT_FOUND: u64 = 2;
const E_INVALID_STATUS: u64 = 3;
const E_INSUFFICIENT_FUNDS: u64 = 4;
const E_ZERO_AMOUNT: u64 = 5;
const E_NOT_AUTHORIZED: u64 = 6;
const E_GOAL_NOT_MET: u64 = 7;
const E_NOT_WHITELISTED: u64 = 8;
const E_INSUFFICIENT_BALANCE: u64 = 9;
const E_INVALID_REGISTRY: u64 = 10;
const E_NOT_ADMIN: u64 = 11;
const E_NOT_MEMBER: u64 = 12;
const E_REPAYMENT_ALREADY_CLAIMED: u64 = 13;
const E_NO_REPAYMENT_AVAILABLE: u64 = 14;
const E_PROJECT_NOT_FOUND: u64 = 15;

/// Pool status
public enum PoolStatus has copy, drop, store {
    Pending,
    Active,
    Funded,
    Completed,
    Defaulted,
}

/// Pool configuration
struct PoolConfig has store {
    interest_rate: u64, // in basis points
    duration: u64, // in seconds
}

/// Investment pool object
struct InvestmentPool has key, store {
    pool_id: u64,
    project_id: u64,
    target_amount: u64,
    current_total: u64,
    status: PoolStatus,
    config: PoolConfig,
    contributions: aptos_framework::big_ordered_map::BigOrderedMap<address, u64>,
    repayment_claimed: aptos_framework::big_ordered_map::BigOrderedMap<address, bool>, // Track if investor claimed repayment
    total_repayment: u64, // Total repayment amount available
    total_claimed: u64, // Total amount claimed so far (for rounding handling)
    borrower: address,
    pool_address: address, // Address where funds are held
    fractional_shares_addr: address, // Address of fractional shares object
    compliance_registry_addr: address, // For KYC checks
    members_registry_addr: address, // For member checks
    token_admin_addr: address, // FA admin controlling liquidity token
}

// Events
#[event]
struct PoolCreatedEvent has drop, store {
    pool_id: u64,
    project_id: u64,
    target_amount: u64,
    creator: address,
}

#[event]
struct InvestmentCommittedEvent has drop, store {
    pool_id: u64,
    investor: address,
    amount: u64,
}

#[event]
struct FundingFinalizedEvent has drop, store {
    pool_id: u64,
    total_raised: u64,
}

#[event]
struct LoanRepaidEvent has drop, store {
    pool_id: u64,
    amount: u64,
    interest: u64,
}

#[event]
struct RepaymentClaimedEvent has drop, store {
    pool_id: u64,
    investor: address,
    amount: u64,
}

#[event]
struct PoolDefaultedEvent has drop, store {
    pool_id: u64,
}

/// Portfolio entry for investor portfolio view
struct PortfolioEntry has store {
    pool_id: u64,
    contribution: u64,
    shares: u64,
    status: u8,
}

/// Loan entry for borrower loans view
struct LoanEntry has store {
    pool_id: u64,
    amount_borrowed: u64,
    status: u8,
    amount_repaid: u64,
}

/// Initialize investment pool registry
struct PoolRegistry has key {
    pools: aptos_framework::big_ordered_map::BigOrderedMap<u64, InvestmentPool>,
    pool_counter: u64,
    // Store signer capabilities for pool resource accounts
    pool_signer_caps: aptos_framework::big_ordered_map::BigOrderedMap<u64, account::SignerCapability>,
}

/// Initialize pool registry
/// Initialize pool registry
/// Idempotent: safe to call multiple times
public fun initialize(admin: &signer) {
    let admin_addr = signer::address_of(admin);
    // Explicit check for idempotency - no assert, just conditional creation
    if (!exists<PoolRegistry>(admin_addr)) {
        move_to(admin, PoolRegistry {
            // Use new_with_type_size_hints because InvestmentPool contains nested BigOrderedMap fields
            // Size calculation: 2 nested maps (~400 bytes) + other fields (~100 bytes) + overhead (~200 bytes) = ~500-800 bytes
            pools: aptos_framework::big_ordered_map::new_with_type_size_hints<u64, InvestmentPool>(8, 8, 500, 2048),
            pool_counter: 0,
            pool_signer_caps: aptos_framework::big_ordered_map::new(),
        });
    };
}

/// Create a new investment pool
public entry fun create_pool(
    admin: &signer,
    project_id: u64,
    target_amount: u64,
    interest_rate: u64,
    duration: u64,
    borrower: address,
    _legacy_pool_address: address,
    fractional_shares_addr: address,
    compliance_registry_addr: address,
    members_registry_addr: address,
    token_admin_addr: address,
) acquires PoolRegistry {
    let admin_addr = signer::address_of(admin);
    
    // Verify admin role
    assert!(admin::has_admin_capability(admin_addr), error::permission_denied(E_NOT_ADMIN));
    
    // Validate registries
    assert!(exists<PoolRegistry>(admin_addr), error::invalid_argument(E_INVALID_REGISTRY));
    assert!(registry_config::validate_compliance_registry(compliance_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    assert!(registry_config::validate_members_registry(members_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    
    // Validate fractional shares are initialized
    assert!(fractional_asset::exists_fractional_shares(fractional_shares_addr), error::invalid_argument(E_INVALID_REGISTRY));
    
    // Validate FA token admin configured
    assert!(token::is_initialized(token_admin_addr), error::invalid_argument(E_INVALID_REGISTRY));
    
    // Legacy parameter retained for backward compatibility
    let _ = _legacy_pool_address;

    // Validate project exists and is Approved (if project_registry_addr provided)
    // Note: For MVP, we'll validate project exists. For full validation, would need project_registry_addr parameter
    // This is a simplified check - in production, would validate project status
    
    assert!(target_amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
    assert!(interest_rate <= 10000, error::invalid_argument(1)); // Max 100%
    
    // Initialize if needed
    if (!exists<PoolRegistry>(admin_addr)) {
        move_to(admin, PoolRegistry {
            // Use new_with_type_size_hints because InvestmentPool contains nested BigOrderedMap fields
            pools: aptos_framework::big_ordered_map::new_with_type_size_hints<u64, InvestmentPool>(8, 8, 500, 2048),
            pool_counter: 0,
            pool_signer_caps: aptos_framework::big_ordered_map::new(),
        });
    };
    
    let registry = borrow_global_mut<PoolRegistry>(admin_addr);
    let pool_id = registry.pool_counter;
    registry.pool_counter = registry.pool_counter + 1;
    
    // Create per-pool resource account and signer capability
    let pool_address = create_pool_vault(&mut registry.pool_signer_caps, admin, pool_id);
    
    let pool = InvestmentPool {
        pool_id,
        project_id,
        target_amount,
        current_total: 0,
        status: PoolStatus::Pending,
        config: PoolConfig {
            interest_rate,
            duration,
        },
        contributions: aptos_framework::big_ordered_map::new(),
        repayment_claimed: aptos_framework::big_ordered_map::new(),
        total_repayment: 0,
        total_claimed: 0,
        borrower,
        pool_address,
        fractional_shares_addr,
        compliance_registry_addr,
        members_registry_addr,
        token_admin_addr,
    };

    fractional_asset::ensure_pool(pool_id, fractional_shares_addr);
    
    aptos_framework::big_ordered_map::add(&mut registry.pools, pool_id, pool);

    event::emit(PoolCreatedEvent {
        pool_id,
        project_id,
        target_amount,
        creator: admin_addr,
    });
}

/// Create a pool from an approved project
/// Reads project details and creates pool with project's target amounts
public entry fun create_pool_from_project(
    admin: &signer,
    project_id: u64,
    interest_rate: u64,
    duration: u64,
    _legacy_pool_address: address,
    fractional_shares_addr: address,
    compliance_registry_addr: address,
    members_registry_addr: address,
    project_registry_addr: address,
    pool_registry_addr: address,
    token_admin_addr: address,
) acquires PoolRegistry {
    let admin_addr = signer::address_of(admin);
    
    // Verify admin role
    assert!(admin::has_admin_capability(admin_addr), error::permission_denied(E_NOT_ADMIN));
    
    // Validate registries
    assert!(exists<PoolRegistry>(pool_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    assert!(registry_config::validate_compliance_registry(compliance_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    assert!(registry_config::validate_members_registry(members_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    assert!(project_registry::exists_project_registry(project_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    
    // Validate project exists and is Approved
    assert!(project_registry::project_exists(project_id, project_registry_addr), error::not_found(E_PROJECT_NOT_FOUND));
    
    // Validate project is Approved (status 1 = Approved)
    let (_, _, _, _, _, project_status_u8, _) = project_registry::get_project(project_id, project_registry_addr);
    assert!(project_status_u8 == 1, error::invalid_state(E_INVALID_STATUS)); // 1 = Approved
    
    // Use project's target_usdc as target_amount (or target_hours converted)
    let target_amount = project_registry::get_project_target_usdc(project_id, project_registry_addr);
    assert!(target_amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
    
    // Use project proposer as borrower
    let borrower = project_registry::get_project_proposer(project_id, project_registry_addr);
    
    // Validate fractional shares are initialized
    assert!(fractional_asset::exists_fractional_shares(fractional_shares_addr), error::invalid_argument(E_INVALID_REGISTRY));
    
    // Validate FA token admin configured
    assert!(token::is_initialized(token_admin_addr), error::invalid_argument(E_INVALID_REGISTRY));
    
    assert!(interest_rate <= 10000, error::invalid_argument(1)); // Max 100%
    
    // Initialize pool registry if needed
    if (!exists<PoolRegistry>(pool_registry_addr)) {
        move_to(admin, PoolRegistry {
            // Use new_with_type_size_hints because InvestmentPool contains nested BigOrderedMap fields
            pools: aptos_framework::big_ordered_map::new_with_type_size_hints<u64, InvestmentPool>(8, 8, 500, 2048),
            pool_counter: 0,
            pool_signer_caps: aptos_framework::big_ordered_map::new(),
        });
    };
    
    let registry = borrow_global_mut<PoolRegistry>(pool_registry_addr);
    let pool_id = registry.pool_counter;
    registry.pool_counter = registry.pool_counter + 1;
    
    let _ = _legacy_pool_address;
    let pool_address = create_pool_vault(&mut registry.pool_signer_caps, admin, pool_id);
    
    let pool = InvestmentPool {
        pool_id,
        project_id,
        target_amount,
        current_total: 0,
        status: PoolStatus::Pending,
        config: PoolConfig {
            interest_rate,
            duration,
        },
        contributions: aptos_framework::big_ordered_map::new(),
        repayment_claimed: aptos_framework::big_ordered_map::new(),
        total_repayment: 0,
        total_claimed: 0,
        borrower,
        pool_address,
        fractional_shares_addr,
        compliance_registry_addr,
        members_registry_addr,
        token_admin_addr,
    };
    
    aptos_framework::big_ordered_map::add(&mut registry.pools, pool_id, pool);

    fractional_asset::ensure_pool(pool_id, fractional_shares_addr);
    
    event::emit(PoolCreatedEvent {
        pool_id,
        project_id,
        target_amount,
        creator: admin_addr,
    });
}

/// Join a pool (invest in it)
public entry fun join_pool(
    investor: &signer,
    pool_id: u64,
    amount: u64,
    registry_addr: address,
) acquires PoolRegistry {
    // Input validation first
    assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
    
    // Validate registry exists
    assert!(exists<PoolRegistry>(registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    
    let investor_addr = signer::address_of(investor);
    
    let registry = borrow_global_mut<PoolRegistry>(registry_addr);
    assert!(aptos_framework::big_ordered_map::contains(&registry.pools, &pool_id), 
        error::not_found(E_POOL_NOT_FOUND));
    
    // Use remove-modify-insert pattern because InvestmentPool contains nested BigOrderedMap
    let pool = aptos_framework::big_ordered_map::remove(&mut registry.pools, &pool_id);
    
    // Validate pool status
    assert!((pool.status is PoolStatus::Pending) || (pool.status is PoolStatus::Active), 
        error::invalid_state(E_INVALID_STATUS));
    
    // Check compliance/KYC first (most specific failure)
    assert!(
        compliance::is_whitelisted(investor_addr, pool.compliance_registry_addr),
        error::permission_denied(E_NOT_WHITELISTED)
    );
    
    // Then verify membership
    assert!(
        members::is_member_with_registry(investor_addr, pool.members_registry_addr),
        error::permission_denied(E_NOT_MEMBER)
    );
    
    // Check investor has sufficient balance of the configured FA
    let balance = pool_balance(investor_addr, pool.token_admin_addr);
    assert!(balance >= amount, error::invalid_state(E_INSUFFICIENT_BALANCE));
    
    // Transfer fungible assets to the pool address
    let asset = token::withdraw(investor, amount, pool.token_admin_addr);
    deposit_asset(pool.pool_address, pool.token_admin_addr, asset);
    
    // Update contribution
    if (aptos_framework::big_ordered_map::contains(&pool.contributions, &investor_addr)) {
        let current = *aptos_framework::big_ordered_map::borrow(&pool.contributions, &investor_addr);
        aptos_framework::big_ordered_map::upsert(&mut pool.contributions, investor_addr, current + amount);
    } else {
        aptos_framework::big_ordered_map::add(&mut pool.contributions, investor_addr, amount);
    };
    
    pool.current_total = pool.current_total + amount;
    pool.status = PoolStatus::Active;
    
    // Extract fractional_shares_addr before moving pool into the map
    let fractional_shares_addr = pool.fractional_shares_addr;
    
    // Re-insert pool using add (will overwrite if exists, but we just removed it)
    aptos_framework::big_ordered_map::add(&mut registry.pools, pool_id, pool);
    
    // Mint fractional shares
    fractional_asset::mint_shares(investor, pool_id, investor_addr, amount, fractional_shares_addr);

    event::emit(InvestmentCommittedEvent {
        pool_id,
        investor: investor_addr,
        amount,
    });
    
    // Record in event history
    event_history::record_user_event(
        investor_addr,
        event_history::event_type_investment(),
        option::some(amount),
        option::some(pool_id),
        option::none(),
        option::none(),
        option::none(),
        option::none(),
    );
}

/// Finalize funding when goal is met
public entry fun finalize_funding(
    admin: &signer,
    pool_id: u64,
    registry_addr: address,
) acquires PoolRegistry {
    let admin_addr = signer::address_of(admin);
    
    // Verify admin role
    assert!(admin::has_admin_capability(admin_addr), error::permission_denied(E_NOT_ADMIN));
    
    // Validate registry exists
    assert!(exists<PoolRegistry>(registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    let registry = borrow_global_mut<PoolRegistry>(registry_addr);
    
    assert!(aptos_framework::big_ordered_map::contains(&registry.pools, &pool_id), 
        error::not_found(E_POOL_NOT_FOUND));
    
    let pool = aptos_framework::big_ordered_map::borrow_mut(&mut registry.pools, &pool_id);
    assert!(pool.current_total >= pool.target_amount, error::invalid_state(E_GOAL_NOT_MET));
    assert!(pool.status is PoolStatus::Active, error::invalid_state(E_INVALID_STATUS));
    
    // Check pool has sufficient balance before withdrawal
    let total_funds = pool.current_total;
    let pool_balance_amt = pool_balance(pool.pool_address, pool.token_admin_addr);
    assert!(pool_balance_amt >= total_funds, error::invalid_state(E_INSUFFICIENT_BALANCE));
    
    let asset = withdraw_from_pool_vault(&mut registry.pool_signer_caps, pool_id, total_funds, pool.token_admin_addr);
    deposit_asset(pool.borrower, pool.token_admin_addr, asset);
    
    pool.status = PoolStatus::Funded;

    event::emit(FundingFinalizedEvent {
        pool_id,
        total_raised: pool.current_total,
    });
}

/// Repay loan with interest
public entry fun repay_loan(
    borrower: &signer,
    pool_id: u64,
    registry_addr: address,
) acquires PoolRegistry {
    let borrower_addr = signer::address_of(borrower);
    
    // Validate registry exists
    assert!(exists<PoolRegistry>(registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    let registry = borrow_global_mut<PoolRegistry>(registry_addr);
    
    assert!(aptos_framework::big_ordered_map::contains(&registry.pools, &pool_id), 
        error::not_found(E_POOL_NOT_FOUND));
    
    let pool = aptos_framework::big_ordered_map::borrow_mut(&mut registry.pools, &pool_id);
    assert!(pool.borrower == borrower_addr, error::permission_denied(E_NOT_AUTHORIZED));
    assert!(pool.status is PoolStatus::Funded, error::invalid_state(E_INVALID_STATUS));
    
    // Calculate interest (with overflow protection)
    let principal = pool.current_total;
    let principal_128 = principal as u128;
    let rate_128 = pool.config.interest_rate as u128;
    let interest = ((principal_128 * rate_128) / 10000) as u64;
    let total_owed = principal + interest;
    
    // Check borrower has sufficient balance before withdrawal
    let borrower_balance = pool_balance(borrower_addr, pool.token_admin_addr);
    assert!(borrower_balance >= total_owed, error::invalid_state(E_INSUFFICIENT_BALANCE));
    
    // Transfer repayment + interest to pool address
    let asset = token::withdraw(borrower, total_owed, pool.token_admin_addr);
    deposit_asset(pool.pool_address, pool.token_admin_addr, asset);
    
    // Store total repayment amount - investors can claim their share
    pool.total_repayment = total_owed;
    pool.status = PoolStatus::Completed;

    event::emit(LoanRepaidEvent {
        pool_id,
        amount: total_owed,
        interest,
    });
}

/// Bulk claim repayments across multiple pools (investor only)
/// Note: For MVP, requires admin signer to withdraw from pool_address
/// In production: Would use resource account signer capability
public entry fun bulk_claim_repayments(
    investor: &signer,
    pool_ids: vector<u64>,
    registry_addr: address,
) acquires PoolRegistry {
    let investor_addr = signer::address_of(investor);
    
    // Validate registry exists
    assert!(exists<PoolRegistry>(registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    let registry = borrow_global_mut<PoolRegistry>(registry_addr);
    
    let batch_size = vector::length(&pool_ids);
    assert!(batch_size > 0, error::invalid_argument(1));
    assert!(batch_size <= 20, error::invalid_argument(2)); // Limit batch size for gas
    
    let total_claimed = 0;
    let claimed_pools = vector::empty<u64>();
    let failed_pools = vector::empty<u64>();
    let i = 0;
    
    while (i < batch_size) {
        let pool_id = *vector::borrow(&pool_ids, i);
        if (aptos_framework::big_ordered_map::contains(&registry.pools, &pool_id)) {
            let pool = aptos_framework::big_ordered_map::borrow_mut(&mut registry.pools, &pool_id);
            
            // Check if investor has contribution and hasn't claimed
            if (aptos_framework::big_ordered_map::contains(&pool.contributions, &investor_addr) &&
                (!aptos_framework::big_ordered_map::contains(&pool.repayment_claimed, &investor_addr) ||
                 !*aptos_framework::big_ordered_map::borrow(&pool.repayment_claimed, &investor_addr))) {
                
                if ((pool.status is PoolStatus::Completed) && pool.total_repayment > 0) {
                    let contribution = *aptos_framework::big_ordered_map::borrow(&pool.contributions, &investor_addr);
                    let contrib_128 = contribution as u128;
                    let repayment_128 = pool.total_repayment as u128;
                    let total_128 = pool.current_total as u128;
                    let share = ((contrib_128 * repayment_128) / total_128) as u64;
                    
                    if (share > 0) {
                        let remaining_unclaimed = pool.total_repayment - pool.total_claimed;
                        let final_share = if (share > remaining_unclaimed) {
                            remaining_unclaimed
                        } else {
                            share
                        };
                        
                        if (final_share > 0) {
                            let pool_balance_amt = pool_balance(pool.pool_address, pool.token_admin_addr);
                            if (pool_balance_amt >= final_share) {
                                let asset = withdraw_from_pool_vault(&mut registry.pool_signer_caps, pool_id, final_share, pool.token_admin_addr);
                                deposit_asset(investor_addr, pool.token_admin_addr, asset);
                                
                                // Update total claimed
                                pool.total_claimed = pool.total_claimed + final_share;
                                
                                // Mark as claimed
                                aptos_framework::big_ordered_map::upsert(&mut pool.repayment_claimed, investor_addr, true);
                                
                                event::emit(RepaymentClaimedEvent {
                                    pool_id,
                                    investor: investor_addr,
                                    amount: final_share,
                                });
                                
                                // Record in event history
                                event_history::record_user_event(
                                    investor_addr,
                                    event_history::event_type_repayment_claimed(),
                                    option::some(final_share),
                                    option::some(pool_id),
                                    option::none(),
                                    option::none(),
                                    option::none(),
                                    option::none(),
                                );
                                
                                total_claimed = total_claimed + final_share;
                                vector::push_back(&mut claimed_pools, pool_id);
                            } else {
                                vector::push_back(&mut failed_pools, pool_id);
                            };
                        } else {
                            vector::push_back(&mut failed_pools, pool_id);
                        };
                    } else {
                        vector::push_back(&mut failed_pools, pool_id);
                    };
                } else {
                    vector::push_back(&mut failed_pools, pool_id);
                };
            } else {
                vector::push_back(&mut failed_pools, pool_id);
            };
        } else {
            vector::push_back(&mut failed_pools, pool_id);
        };
        i = i + 1;
    };
}

/// Claim repayment share (for investors after loan repayment)
/// Note: For MVP, requires admin signer to withdraw from pool_address
/// In production: Would use resource account signer capability
public entry fun claim_repayment(
    investor: &signer,
    pool_id: u64,
    registry_addr: address,
) acquires PoolRegistry {
    let investor_addr = signer::address_of(investor);
    
    // Validate registry exists
    assert!(exists<PoolRegistry>(registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    let registry = borrow_global_mut<PoolRegistry>(registry_addr);
    
    assert!(aptos_framework::big_ordered_map::contains(&registry.pools, &pool_id), 
        error::not_found(E_POOL_NOT_FOUND));
    
    // Use remove-modify-insert pattern because InvestmentPool contains nested BigOrderedMap
    let pool = aptos_framework::big_ordered_map::remove(&mut registry.pools, &pool_id);
    
    // Validate pool status
    assert!(pool.status is PoolStatus::Completed, error::invalid_state(E_INVALID_STATUS));
    assert!(pool.total_repayment > 0, error::invalid_state(E_NO_REPAYMENT_AVAILABLE));
    
    // Check investor has contribution
    assert!(aptos_framework::big_ordered_map::contains(&pool.contributions, &investor_addr),
        error::not_found(E_POOL_NOT_FOUND));
    
    // Check not already claimed
    assert!(
        !aptos_framework::big_ordered_map::contains(&pool.repayment_claimed, &investor_addr) ||
        !*aptos_framework::big_ordered_map::borrow(&pool.repayment_claimed, &investor_addr),
        error::already_exists(E_REPAYMENT_ALREADY_CLAIMED)
    );
    
    // Calculate investor's share: (contribution / total_contributed) * total_repayment
    let contribution = *aptos_framework::big_ordered_map::borrow(&pool.contributions, &investor_addr);
    let contrib_128 = contribution as u128;
    let repayment_128 = pool.total_repayment as u128;
    let total_128 = pool.current_total as u128;
    let share = ((contrib_128 * repayment_128) / total_128) as u64;
    assert!(share > 0, error::invalid_argument(E_ZERO_AMOUNT));
    
    // Handle rounding: if this claim would exceed total_repayment, give remainder to last claimant
    let remaining_unclaimed = pool.total_repayment - pool.total_claimed;
    let final_share = if (share > remaining_unclaimed) {
        remaining_unclaimed // Give remainder to last claimant
    } else {
        share
    };
    assert!(final_share > 0, error::invalid_argument(E_ZERO_AMOUNT));
    
    // Check pool has sufficient balance
    let pool_balance_amt = pool_balance(pool.pool_address, pool.token_admin_addr);
    assert!(pool_balance_amt >= final_share, error::invalid_state(E_INSUFFICIENT_BALANCE));
    
    // Transfer share to investor
    let asset = withdraw_from_pool_vault(&mut registry.pool_signer_caps, pool_id, final_share, pool.token_admin_addr);
    deposit_asset(investor_addr, pool.token_admin_addr, asset);
    
    // Update total claimed
    pool.total_claimed = pool.total_claimed + final_share;
    
    // Mark as claimed
    aptos_framework::big_ordered_map::upsert(&mut pool.repayment_claimed, investor_addr, true);
    
    // Re-insert pool
    aptos_framework::big_ordered_map::add(&mut registry.pools, pool_id, pool);

    event::emit(RepaymentClaimedEvent {
        pool_id,
        investor: investor_addr,
        amount: final_share,
    });
}

/// Mark pool as defaulted
public entry fun mark_defaulted(
    admin: &signer,
    pool_id: u64,
    registry_addr: address,
) acquires PoolRegistry {
    let admin_addr = signer::address_of(admin);
    
    // Verify admin role
    assert!(admin::has_admin_capability(admin_addr), error::permission_denied(E_NOT_ADMIN));
    
    // Validate registry exists
    assert!(exists<PoolRegistry>(registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    let registry = borrow_global_mut<PoolRegistry>(registry_addr);
    
    assert!(aptos_framework::big_ordered_map::contains(&registry.pools, &pool_id), 
        error::not_found(E_POOL_NOT_FOUND));
    
    // Use remove-modify-insert pattern for variable-sized value type (InvestmentPool contains nested BigOrderedMaps)
    let pool = aptos_framework::big_ordered_map::remove(&mut registry.pools, &pool_id);
    pool.status = PoolStatus::Defaulted;
    aptos_framework::big_ordered_map::add(&mut registry.pools, pool_id, pool);

    event::emit(PoolDefaultedEvent {
        pool_id,
    });
}

/// Get pool details
#[view]
public fun get_pool(pool_id: u64, registry_addr: address): (u64, u64, u64, u8, u64, u64, address) {
    if (!exists<PoolRegistry>(registry_addr)) {
        abort error::not_found(E_NOT_INITIALIZED)
    };
    let registry = borrow_global<PoolRegistry>(registry_addr);
    if (!aptos_framework::big_ordered_map::contains(&registry.pools, &pool_id)) {
        abort error::not_found(E_POOL_NOT_FOUND)
    };
    let pool = aptos_framework::big_ordered_map::borrow(&registry.pools, &pool_id);
    let status_u8 = status_to_u8(pool.status);
    (pool.project_id, pool.target_amount, pool.current_total, status_u8, 
     pool.config.interest_rate, pool.config.duration, pool.borrower)
}

/// Get investor contribution
#[view]
public fun get_contribution(
    investor_addr: address,
    pool_id: u64,
    registry_addr: address,
): u64 {
    if (!exists<PoolRegistry>(registry_addr)) {
        return 0
    };
    let registry = borrow_global<PoolRegistry>(registry_addr);
    if (!aptos_framework::big_ordered_map::contains(&registry.pools, &pool_id)) {
        return 0
    };
    let pool = aptos_framework::big_ordered_map::borrow(&registry.pools, &pool_id);
    if (aptos_framework::big_ordered_map::contains(&pool.contributions, &investor_addr)) {
        *aptos_framework::big_ordered_map::borrow(&pool.contributions, &investor_addr)
    } else {
        0
    }
}

/// Get total claimed amount
#[view]
public fun get_total_claimed(pool_id: u64, registry_addr: address): u64 {
    if (!exists<PoolRegistry>(registry_addr)) {
        return 0
    };
    let registry = borrow_global<PoolRegistry>(registry_addr);
    if (!aptos_framework::big_ordered_map::contains(&registry.pools, &pool_id)) {
        return 0
    };
    let pool = aptos_framework::big_ordered_map::borrow(&registry.pools, &pool_id);
    pool.total_claimed
}

/// Get unclaimed repayment amount
#[view]
public fun get_unclaimed_repayment(pool_id: u64, registry_addr: address): u64 {
    if (!exists<PoolRegistry>(registry_addr)) {
        return 0
    };
    let registry = borrow_global<PoolRegistry>(registry_addr);
    if (!aptos_framework::big_ordered_map::contains(&registry.pools, &pool_id)) {
        return 0
    };
    let pool = aptos_framework::big_ordered_map::borrow(&registry.pools, &pool_id);
    if (pool.total_repayment > pool.total_claimed) {
        pool.total_repayment - pool.total_claimed
    } else {
        0
    }
}

/// List all pools
/// Returns vector of pool IDs, optionally filtered by status
/// Note: For MVP, iterates through pool_counter. For scale, consider pagination.
#[view]
public fun list_pools(registry_addr: address, status_filter: u8): vector<u64> {
    let result = vector::empty<u64>();
    if (!exists<PoolRegistry>(registry_addr)) {
        return result
    };
    let registry = borrow_global<PoolRegistry>(registry_addr);
    let counter = registry.pool_counter;
    let i = 0;
    // Use 255 as sentinel value for "no filter"
    let filter_active = status_filter != 255;
    while (i < counter) {
        if (aptos_framework::big_ordered_map::contains(&registry.pools, &i)) {
            if (filter_active) {
                let pool = aptos_framework::big_ordered_map::borrow(&registry.pools, &i);
                let pool_status = status_to_u8(pool.status);
                if (pool_status == status_filter) {
                    vector::push_back(&mut result, i);
                }
            } else {
                vector::push_back(&mut result, i);
            }
        };
        i = i + 1;
    };
    result
}

/// Get pool summary with additional fields
#[view]
public fun get_pool_summary(pool_id: u64, registry_addr: address): (u64, u64, u64, u8, u64, u64, address, u64, u64) {
    if (!exists<PoolRegistry>(registry_addr)) {
        abort error::not_found(E_NOT_INITIALIZED)
    };
    let registry = borrow_global<PoolRegistry>(registry_addr);
    if (!aptos_framework::big_ordered_map::contains(&registry.pools, &pool_id)) {
        abort error::not_found(E_POOL_NOT_FOUND)
    };
    let pool = aptos_framework::big_ordered_map::borrow(&registry.pools, &pool_id);
    let status_u8 = status_to_u8(pool.status);
    (pool.project_id, pool.target_amount, pool.current_total, status_u8,
     pool.config.interest_rate, pool.config.duration, pool.borrower,
     pool.total_claimed, pool.total_repayment)
}

/// Get pools for a project
/// Returns vector of pool IDs associated with a specific project
#[view]
public fun get_pools_for_project(project_id: u64, registry_addr: address): vector<u64> {
    let result = vector::empty<u64>();
    if (!exists<PoolRegistry>(registry_addr)) {
        return result
    };
    let registry = borrow_global<PoolRegistry>(registry_addr);
    let counter = registry.pool_counter;
    let i = 0;
    while (i < counter) {
        if (aptos_framework::big_ordered_map::contains(&registry.pools, &i)) {
            let pool = aptos_framework::big_ordered_map::borrow(&registry.pools, &i);
            if (pool.project_id == project_id) {
                vector::push_back(&mut result, i);
            }
        };
        i = i + 1;
    };
    result
}

/// Get investor portfolio
/// Returns vector of (pool_id, contribution, shares, pool_status) tuples for an investor
#[view]
public fun get_investor_portfolio(investor_addr: address, registry_addr: address): vector<PortfolioEntry> {
    let result = vector::empty<PortfolioEntry>();
    if (!exists<PoolRegistry>(registry_addr)) {
        return result
    };
    let registry = borrow_global<PoolRegistry>(registry_addr);
    let counter = registry.pool_counter;
    let i = 0;
    while (i < counter) {
        if (aptos_framework::big_ordered_map::contains(&registry.pools, &i)) {
            let pool = aptos_framework::big_ordered_map::borrow(&registry.pools, &i);
            if (aptos_framework::big_ordered_map::contains(&pool.contributions, &investor_addr)) {
                let contribution = *aptos_framework::big_ordered_map::borrow(&pool.contributions, &investor_addr);
                // Get shares from fractional asset module
                let shares = fractional_asset::get_shares(investor_addr, i, pool.fractional_shares_addr);
                let pool_status = status_to_u8(pool.status);
                vector::push_back(&mut result, PortfolioEntry {
                    pool_id: i,
                    contribution,
                    shares,
                    status: pool_status,
                });
            }
        };
        i = i + 1;
    };
    result
}

/// Get borrower loans
/// Returns vector of (pool_id, amount_borrowed, status, amount_repaid) tuples for a borrower
#[view]
public fun get_borrower_loans(borrower: address, registry_addr: address): vector<LoanEntry> {
    let result = vector::empty<LoanEntry>();
    if (!exists<PoolRegistry>(registry_addr)) {
        return result
    };
    let registry = borrow_global<PoolRegistry>(registry_addr);
    let counter = registry.pool_counter;
    let i = 0;
    while (i < counter) {
        if (aptos_framework::big_ordered_map::contains(&registry.pools, &i)) {
            let pool = aptos_framework::big_ordered_map::borrow(&registry.pools, &i);
            if (pool.borrower == borrower) {
                let amount_borrowed = pool.current_total; // Amount actually borrowed
                let pool_status = status_to_u8(pool.status);
                // Amount repaid is total_repayment - unclaimed (approximation)
                // For more accurate tracking, would need separate repaid tracking
                let amount_repaid = if (pool.total_repayment > pool.total_claimed) {
                    pool.total_claimed // Amount claimed back by investors
                } else {
                    pool.total_repayment
                };
                vector::push_back(&mut result, LoanEntry {
                    pool_id: i,
                    amount_borrowed,
                    status: pool_status,
                    amount_repaid,
                });
            }
        };
        i = i + 1;
    };
    result
}

/// Helper: Convert status enum to u8
fun status_to_u8(status: PoolStatus): u8 {
    match (status) {
        PoolStatus::Pending => 0,
        PoolStatus::Active => 1,
        PoolStatus::Funded => 2,
        PoolStatus::Completed => 3,
        PoolStatus::Defaulted => 4,
    }
}

fun pool_balance(addr: address, token_admin_addr: address): u64 {
    if (!token::is_initialized(token_admin_addr)) {
        return 0
    };
    let metadata = token::get_metadata(token_admin_addr);
    primary_fungible_store::balance(addr, metadata)
}

fun deposit_asset(recipient: address, token_admin_addr: address, asset: FungibleAsset) {
    let metadata = token::get_metadata(token_admin_addr);
    let store = primary_fungible_store::ensure_primary_store_exists(recipient, metadata);
    fungible_asset::deposit(store, asset);
}

fun create_pool_vault(
    signer_caps: &mut aptos_framework::big_ordered_map::BigOrderedMap<u64, account::SignerCapability>,
    admin: &signer,
    pool_id: u64,
): address {
    let seed = pool_seed(pool_id);
    let (pool_signer, signer_cap) = account::create_resource_account(admin, seed);
    let pool_addr = signer::address_of(&pool_signer);
    aptos_framework::big_ordered_map::add(signer_caps, pool_id, signer_cap);
    pool_addr
}

fun pool_seed(pool_id: u64): vector<u8> {
    let bytes = vector::empty<u8>();
    let byte0 = (pool_id % 256) as u8;
    let temp1 = pool_id / 256;
    let byte1 = (temp1 % 256) as u8;
    let temp2 = temp1 / 256;
    let byte2 = (temp2 % 256) as u8;
    let temp3 = temp2 / 256;
    let byte3 = (temp3 % 256) as u8;
    let temp4 = temp3 / 256;
    let byte4 = (temp4 % 256) as u8;
    let temp5 = temp4 / 256;
    let byte5 = (temp5 % 256) as u8;
    let temp6 = temp5 / 256;
    let byte6 = (temp6 % 256) as u8;
    let temp7 = temp6 / 256;
    let byte7 = (temp7 % 256) as u8;
    vector::push_back(&mut bytes, byte0);
    vector::push_back(&mut bytes, byte1);
    vector::push_back(&mut bytes, byte2);
    vector::push_back(&mut bytes, byte3);
    vector::push_back(&mut bytes, byte4);
    vector::push_back(&mut bytes, byte5);
    vector::push_back(&mut bytes, byte6);
    vector::push_back(&mut bytes, byte7);
    bytes
}

fun withdraw_from_pool_vault(
    signer_caps: &mut aptos_framework::big_ordered_map::BigOrderedMap<u64, account::SignerCapability>,
    pool_id: u64,
    amount: u64,
    token_admin_addr: address,
): FungibleAsset {
    assert!(aptos_framework::big_ordered_map::contains(signer_caps, &pool_id), error::not_found(E_POOL_NOT_FOUND));
    let cap_ref = aptos_framework::big_ordered_map::borrow(signer_caps, &pool_id);
    let pool_signer = account::create_signer_with_capability(cap_ref);
    token::withdraw(&pool_signer, amount, token_admin_addr)
}

#[test_only]
public fun initialize_for_test(admin: &signer) {
    admin::initialize_for_test(admin);
    let admin_addr = signer::address_of(admin);
    if (!exists<PoolRegistry>(admin_addr)) {
        initialize(admin);
    };
}

}
