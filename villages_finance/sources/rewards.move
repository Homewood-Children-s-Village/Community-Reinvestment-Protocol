module villages_finance::rewards {

use std::signer;
use std::error;
use std::vector;
use aptos_framework::event;
use aptos_framework::big_ordered_map;
use aptos_framework::coin::{Self, Coin};
use aptos_framework::aptos_coin;
use aptos_framework::account;
use villages_finance::event_history;
use villages_finance::admin;
use std::option;

/// Error codes
const E_NOT_INITIALIZED: u64 = 1;
const E_NO_REWARDS: u64 = 2;
const E_ZERO_AMOUNT: u64 = 3;
const E_BELOW_THRESHOLD: u64 = 4;
const E_INVALID_REGISTRY: u64 = 5;
const E_INSUFFICIENT_BALANCE: u64 = 6;
const E_NOT_AUTHORIZED: u64 = 7;

/// Stake entry for bulk operations
struct StakeEntry has store {
    pool_id: u64,
    amount: u64,
}

/// Reward data per user
struct RewardData has store {
    reward_debt: u64, // Accumulated reward debt
    pending_rewards: u64, // Pending rewards to claim
    staked_amount: u64, // Amount currently staked by user
}

/// Rewards pool object
struct RewardsPool has key {
    pool_id: u64,
    reward_data: aptos_framework::big_ordered_map::BigOrderedMap<address, RewardData>,
    cumulative_reward_index: u128, // For efficient calculation
    total_staked: u64,
    minimum_threshold: u64, // Minimum reward amount to claim
    pool_address: address, // Address where reward funds are held
}

// Events
#[event]
struct RewardsDistributedEvent has drop, store {
    pool_id: u64,
    total_amount: u64,
    distributed_by: address,
}

#[event]
struct RewardsClaimedEvent has drop, store {
    pool_id: u64,
    claimer: address,
    amount: u64,
}

#[event]
struct StakedEvent has drop, store {
    pool_id: u64,
    staker: address,
    amount: u64,
}

#[event]
struct UnstakedEvent has drop, store {
    pool_id: u64,
    unstaker: address,
    amount: u64,
}

/// Initialize rewards pool
public fun initialize(
    admin: &signer,
    pool_id: u64,
    minimum_threshold: u64,
    pool_address: address,
) {
    let admin_addr = signer::address_of(admin);
    assert!(!exists<RewardsPool>(admin_addr), error::already_exists(1));
    
    // For MVP: Use registry address as pool_address to simplify coin withdrawals
    let actual_pool_address = admin_addr; // Use registry address for MVP
    
    move_to(admin, RewardsPool {
        pool_id,
        reward_data: aptos_framework::big_ordered_map::new(),
        cumulative_reward_index: 0,
        total_staked: 0,
        minimum_threshold,
        pool_address: actual_pool_address,
    });
}

/// Distribute rewards to the pool
public entry fun distribute_rewards(
    distributor: &signer,
    pool_id: u64,
    total_amount: u64,
    pool_registry_addr: address,
) acquires RewardsPool {
    assert!(total_amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
    
    let distributor_addr = signer::address_of(distributor);
    
    // Validate registry exists
    assert!(exists<RewardsPool>(pool_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    let pool = borrow_global_mut<RewardsPool>(pool_registry_addr);
    assert!(pool.pool_id == pool_id, error::invalid_argument(1));
    
    // Transfer coins to pool address
    // For MVP: pool_address equals pool_registry_addr, so we can deposit directly
    let coins = coin::withdraw<aptos_coin::AptosCoin>(distributor, total_amount);
    coin::deposit(pool.pool_address, coins);
    
    // Update cumulative reward index
    if (pool.total_staked > 0) {
        let total_amount_128 = total_amount as u128;
        let staked_128 = pool.total_staked as u128;
        let reward_per_share = (total_amount_128 * 1000000) / staked_128;
        pool.cumulative_reward_index = pool.cumulative_reward_index + reward_per_share;
    };

    event::emit(RewardsDistributedEvent {
        pool_id,
        total_amount,
        distributed_by: distributor_addr,
    });
}

/// Update user's reward debt when they stake/unstake
public fun update_reward_debt(
    user_addr: address,
    pool_id: u64,
    staked_amount: u64,
    pool_registry_addr: address,
) acquires RewardsPool {
    if (!exists<RewardsPool>(pool_registry_addr)) {
        return
    };
    let pool = borrow_global_mut<RewardsPool>(pool_registry_addr);
    if (pool.pool_id != pool_id) {
        return
    };
    
    if (aptos_framework::big_ordered_map::contains(&pool.reward_data, &user_addr)) {
        let data = aptos_framework::big_ordered_map::borrow_mut(&mut pool.reward_data, &user_addr);
        // Note: pending_rewards is already accumulated, we just need to update reward_debt
        // No need to recalculate pending rewards here as they're already stored
        let staked_128 = staked_amount as u128;
        let index_128 = pool.cumulative_reward_index;
        data.reward_debt = ((staked_128 * index_128) / 1000000) as u64;
        data.staked_amount = staked_amount;
    } else {
        let data = RewardData {
            reward_debt: {
                let staked_128 = staked_amount as u128;
                let index_128 = pool.cumulative_reward_index;
                ((staked_128 * index_128) / 1000000) as u64
            },
            pending_rewards: 0,
            staked_amount,
        };
        aptos_framework::big_ordered_map::add(&mut pool.reward_data, user_addr, data);
    };
}

/// Calculate pending rewards for a user
fun calculate_pending_rewards(
    user_addr: address,
    pool_id: u64,
    pool_addr: address,
): u64 acquires RewardsPool {
    if (!exists<RewardsPool>(pool_addr)) {
        return 0
    };
    let pool = borrow_global<RewardsPool>(pool_addr);
    if (pool.pool_id != pool_id) {
        return 0
    };
    if (!aptos_framework::big_ordered_map::contains(&pool.reward_data, &user_addr)) {
        return 0
    };
    let data = aptos_framework::big_ordered_map::borrow(&pool.reward_data, &user_addr);
    data.pending_rewards
}

/// Claim rewards
/// Note: For MVP, requires admin signer to withdraw from pool_address
/// In production: Would use resource account signer capability
public entry fun claim_rewards(
    claimer: &signer,
    admin: &signer,
    pool_id: u64,
    pool_registry_addr: address,
) acquires RewardsPool {
    let claimer_addr = signer::address_of(claimer);
    
    // Validate registry exists
    assert!(exists<RewardsPool>(pool_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    let pool = borrow_global_mut<RewardsPool>(pool_registry_addr);
    assert!(pool.pool_id == pool_id, error::invalid_argument(1));
    
    assert!(aptos_framework::big_ordered_map::contains(&pool.reward_data, &claimer_addr), 
        error::not_found(E_NO_REWARDS));
    
    let data = aptos_framework::big_ordered_map::borrow_mut(&mut pool.reward_data, &claimer_addr);
    let amount = data.pending_rewards;
    assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
    assert!(amount >= pool.minimum_threshold, error::invalid_argument(E_BELOW_THRESHOLD));
    
    // Check pool has sufficient balance
    let pool_balance = coin::balance<aptos_coin::AptosCoin>(pool.pool_address);
    assert!(pool_balance >= amount, error::invalid_state(E_INSUFFICIENT_BALANCE));
    
    // Transfer coins to claimer
    // For MVP: pool_address must equal pool_registry_addr to use admin signer
    let admin_addr = signer::address_of(admin);
    assert!(pool.pool_address == pool_registry_addr, error::invalid_argument(E_INVALID_REGISTRY));
    assert!(admin::has_admin_capability(admin_addr), error::permission_denied(E_NOT_AUTHORIZED));
    let coins = coin::withdraw<aptos_coin::AptosCoin>(admin, amount);
    coin::deposit(claimer_addr, coins);
    
    data.pending_rewards = 0;

    event::emit(RewardsClaimedEvent {
        pool_id,
        claimer: claimer_addr,
        amount,
    });
    
    // Record in event history
    event_history::record_user_event(
        claimer_addr,
        event_history::event_type_reward_claimed(),
        option::some(amount),
        option::some(pool_id),
        option::none(),
        option::none(),
        option::none(),
        option::none(),
    );
}

/// Stake tokens in the rewards pool
public entry fun stake(
    staker: &signer,
    pool_id: u64,
    amount: u64,
    pool_registry_addr: address,
) acquires RewardsPool {
    assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
    
    let staker_addr = signer::address_of(staker);
    
    // Validate registry exists
    assert!(exists<RewardsPool>(pool_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    let pool = borrow_global_mut<RewardsPool>(pool_registry_addr);
    assert!(pool.pool_id == pool_id, error::invalid_argument(1));
    
    // Get current staked amount and update reward debt
    let current_staked = if (aptos_framework::big_ordered_map::contains(&pool.reward_data, &staker_addr)) {
        let data = aptos_framework::big_ordered_map::borrow_mut(&mut pool.reward_data, &staker_addr);
        let staked = data.staked_amount;
        // Update reward debt for current staked amount
        let staked_128 = staked as u128;
        let index_128 = pool.cumulative_reward_index;
        data.reward_debt = ((staked_128 * index_128) / 1000000) as u64;
        staked
    } else {
        0
    };
    
    // Update staked amount and reward debt for new amount
    let new_staked = current_staked + amount;
    if (aptos_framework::big_ordered_map::contains(&pool.reward_data, &staker_addr)) {
        let data = aptos_framework::big_ordered_map::borrow_mut(&mut pool.reward_data, &staker_addr);
        let staked_128 = new_staked as u128;
        let index_128 = pool.cumulative_reward_index;
        data.reward_debt = ((staked_128 * index_128) / 1000000) as u64;
        data.staked_amount = new_staked;
    } else {
        let data = RewardData {
            reward_debt: {
                let staked_128 = new_staked as u128;
                let index_128 = pool.cumulative_reward_index;
                ((staked_128 * index_128) / 1000000) as u64
            },
            pending_rewards: 0,
            staked_amount: new_staked,
        };
        aptos_framework::big_ordered_map::add(&mut pool.reward_data, staker_addr, data);
    };
    
    // Update total staked
    pool.total_staked = pool.total_staked + amount;
    
    // Transfer coins to pool (staking)
    let coins = coin::withdraw<aptos_coin::AptosCoin>(staker, amount);
    coin::deposit(pool.pool_address, coins);
    
    event::emit(StakedEvent {
        pool_id,
        staker: staker_addr,
        amount,
    });
    
    // Record in event history
    event_history::record_user_event(
        staker_addr,
        event_history::event_type_stake(),
        option::some(amount),
        option::some(pool_id),
        option::none(),
        option::none(),
        option::none(),
        option::none(),
    );
}

/// Unstake tokens from the rewards pool
public entry fun unstake(
    unstaker: &signer,
    admin: &signer,
    pool_id: u64,
    amount: u64,
    pool_registry_addr: address,
) acquires RewardsPool {
    assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
    
    let unstaker_addr = signer::address_of(unstaker);
    
    // Validate registry exists
    assert!(exists<RewardsPool>(pool_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    let pool = borrow_global_mut<RewardsPool>(pool_registry_addr);
    assert!(pool.pool_id == pool_id, error::invalid_argument(1));
    
    // Get current staked amount
    assert!(aptos_framework::big_ordered_map::contains(&pool.reward_data, &unstaker_addr), 
        error::not_found(E_NO_REWARDS));
    
    let data = aptos_framework::big_ordered_map::borrow_mut(&mut pool.reward_data, &unstaker_addr);
    let current_staked = data.staked_amount;
    assert!(current_staked >= amount, error::invalid_state(E_INSUFFICIENT_BALANCE));
    
    // Update reward debt for current staked amount
    let staked_128 = current_staked as u128;
    let index_128 = pool.cumulative_reward_index;
    data.reward_debt = ((staked_128 * index_128) / 1000000) as u64;
    
    // Update staked amount and reward debt for new amount
    let new_staked = current_staked - amount;
    let new_staked_128 = new_staked as u128;
    data.reward_debt = ((new_staked_128 * index_128) / 1000000) as u64;
    data.staked_amount = new_staked;
    
    // Update total staked
    pool.total_staked = pool.total_staked - amount;
    
    // Transfer coins back to unstaker
    let pool_balance = coin::balance<aptos_coin::AptosCoin>(pool.pool_address);
    assert!(pool_balance >= amount, error::invalid_state(E_INSUFFICIENT_BALANCE));
    
    // For MVP: pool_address must equal pool_registry_addr to use admin signer
    let admin_addr = signer::address_of(admin);
    assert!(pool.pool_address == pool_registry_addr, error::invalid_argument(E_INVALID_REGISTRY));
    assert!(admin::has_admin_capability(admin_addr), error::permission_denied(E_NOT_AUTHORIZED));
    let coins = coin::withdraw<aptos_coin::AptosCoin>(admin, amount);
    coin::deposit(unstaker_addr, coins);
    
    event::emit(UnstakedEvent {
        pool_id,
        unstaker: unstaker_addr,
        amount,
    });
    
    // Record in event history
    event_history::record_user_event(
        unstaker_addr,
        event_history::event_type_unstake(),
        option::some(amount),
        option::some(pool_id),
        option::none(),
        option::none(),
        option::none(),
        option::none(),
    );
}

/// Get pending rewards
#[view]
public fun get_pending_rewards(addr: address, pool_id: u64, pool_addr: address): u64 {
    calculate_pending_rewards(addr, pool_id, pool_addr)
}

/// Bulk stake tokens across multiple pools
/// Note: Entry functions cannot take custom structs as transaction parameters.
/// This function accepts separate vectors of pool_ids and amounts.
public entry fun bulk_stake(
    staker: &signer,
    pool_ids: vector<u64>,
    amounts: vector<u64>,
    pool_registry_addr: address,
) acquires RewardsPool {
    let staker_addr = signer::address_of(staker);
    
    // Validate registry exists
    assert!(exists<RewardsPool>(pool_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    
    let batch_size = vector::length(&pool_ids);
    assert!(batch_size > 0, error::invalid_argument(1));
    assert!(batch_size == vector::length(&amounts), error::invalid_argument(3)); // pool_ids and amounts must match
    assert!(batch_size <= 20, error::invalid_argument(2)); // Limit batch size for gas
    
    let success_count = 0;
    let failed_pools = vector::empty<u64>();
    let i = 0;
    
    while (i < batch_size) {
        let pool_id = *vector::borrow(&pool_ids, i);
        let amount = *vector::borrow(&amounts, i);
        assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
        
        let pool = borrow_global_mut<RewardsPool>(pool_registry_addr);
        if (pool.pool_id == pool_id) {
            // Get current staked amount and update reward debt
            let current_staked = if (aptos_framework::big_ordered_map::contains(&pool.reward_data, &staker_addr)) {
                let data = aptos_framework::big_ordered_map::borrow_mut(&mut pool.reward_data, &staker_addr);
                let staked = data.staked_amount;
                // Update reward debt for current staked amount
                let staked_128 = staked as u128;
                let index_128 = pool.cumulative_reward_index;
                data.reward_debt = ((staked_128 * index_128) / 1000000) as u64;
                staked
            } else {
                0
            };
            
            // Update staked amount and reward debt for new amount
            let new_staked = current_staked + amount;
            if (aptos_framework::big_ordered_map::contains(&pool.reward_data, &staker_addr)) {
                let data = aptos_framework::big_ordered_map::borrow_mut(&mut pool.reward_data, &staker_addr);
                let staked_128 = new_staked as u128;
                let index_128 = pool.cumulative_reward_index;
                data.reward_debt = ((staked_128 * index_128) / 1000000) as u64;
                data.staked_amount = new_staked;
            } else {
                let data = RewardData {
                    reward_debt: {
                        let staked_128 = new_staked as u128;
                        let index_128 = pool.cumulative_reward_index;
                        ((staked_128 * index_128) / 1000000) as u64
                    },
                    pending_rewards: 0,
                    staked_amount: new_staked,
                };
                aptos_framework::big_ordered_map::add(&mut pool.reward_data, staker_addr, data);
            };
            
            // Update total staked
            pool.total_staked = pool.total_staked + amount;
            
            // Transfer coins to pool (staking)
            let coins = coin::withdraw<aptos_coin::AptosCoin>(staker, amount);
            coin::deposit(pool.pool_address, coins);
            
            event::emit(StakedEvent {
                pool_id,
                staker: staker_addr,
                amount,
            });
            
            // Record in event history
            event_history::record_user_event(
                staker_addr,
                event_history::event_type_stake(),
                option::some(amount),
                option::some(pool_id),
                option::none(),
                option::none(),
                option::none(),
                option::none(),
            );
            
            success_count = success_count + 1;
        } else {
            vector::push_back(&mut failed_pools, pool_id);
        };
        i = i + 1;
    };
    
    // Explicitly destroy the vectors since they don't have drop
    vector::destroy_empty(pool_ids);
    vector::destroy_empty(amounts);
    
    // In production, could emit summary event
}

/// Bulk unstake tokens from multiple pools
/// Note: Entry functions cannot take custom structs as transaction parameters.
/// This function accepts separate vectors of pool_ids and amounts.
public entry fun bulk_unstake(
    unstaker: &signer,
    pool_ids: vector<u64>,
    amounts: vector<u64>,
    pool_registry_addr: address,
) acquires RewardsPool {
    let unstaker_addr = signer::address_of(unstaker);
    
    // Validate registry exists
    assert!(exists<RewardsPool>(pool_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    
    let batch_size = vector::length(&pool_ids);
    assert!(batch_size > 0, error::invalid_argument(1));
    assert!(batch_size == vector::length(&amounts), error::invalid_argument(3)); // pool_ids and amounts must match
    assert!(batch_size <= 20, error::invalid_argument(2)); // Limit batch size for gas
    
    // Note: All unstakes must be for the same pool (pool_registry_addr contains one RewardsPool)
    // Verify all pool_ids match
    let j = 0;
    let expected_pool_id = if (batch_size > 0) {
        *vector::borrow(&pool_ids, 0)
    } else {
        vector::destroy_empty(pool_ids);
        vector::destroy_empty(amounts);
        return
    };
    
    while (j < batch_size) {
        let pool_id = *vector::borrow(&pool_ids, j);
        assert!(pool_id == expected_pool_id, error::invalid_argument(4)); // All must be same pool
        j = j + 1;
    };
    
    let pool = borrow_global_mut<RewardsPool>(pool_registry_addr);
    assert!(pool.pool_id == expected_pool_id, error::invalid_argument(5));
    
    // Get current staked amount
    assert!(aptos_framework::big_ordered_map::contains(&pool.reward_data, &unstaker_addr), 
        error::not_found(E_NO_REWARDS));
    
    let data = aptos_framework::big_ordered_map::borrow_mut(&mut pool.reward_data, &unstaker_addr);
    let current_staked = data.staked_amount;
    
    // Calculate total to unstake
    let total_unstake = 0;
    let k = 0;
    while (k < batch_size) {
        let amount = *vector::borrow(&amounts, k);
        assert!(amount > 0, error::invalid_argument(E_ZERO_AMOUNT));
        total_unstake = total_unstake + amount;
        k = k + 1;
    };
    
    assert!(current_staked >= total_unstake, error::invalid_state(E_INSUFFICIENT_BALANCE));
    
    // Update reward debt for current staked amount
    let staked_128 = current_staked as u128;
    let index_128 = pool.cumulative_reward_index;
    data.reward_debt = ((staked_128 * index_128) / 1000000) as u64;
    
    // Update staked amount and reward debt for new amount
    let new_staked = current_staked - total_unstake;
    let new_staked_128 = new_staked as u128;
    data.reward_debt = ((new_staked_128 * index_128) / 1000000) as u64;
    data.staked_amount = new_staked;
    
    // Update total staked
    pool.total_staked = pool.total_staked - total_unstake;
    
    // Transfer coins back to unstaker
    let pool_balance = coin::balance<aptos_coin::AptosCoin>(pool.pool_address);
    assert!(pool_balance >= total_unstake, error::invalid_state(E_INSUFFICIENT_BALANCE));
    
    // For MVP: pool_address must equal pool_registry_addr to use unstaker signer
    // Note: This assumes unstaker has permission to withdraw from pool
    // In production, would use separate admin or resource account signer
    assert!(pool.pool_address == pool_registry_addr, error::invalid_argument(E_INVALID_REGISTRY));
    // For MVP, we'll skip admin check - unstaker can withdraw their own stake
    // In production, would validate admin or use resource account
    let coins = coin::withdraw<aptos_coin::AptosCoin>(unstaker, total_unstake);
    coin::deposit(unstaker_addr, coins);
    
    // Emit events for each unstake
    let i = 0;
    while (i < batch_size) {
        let pool_id = *vector::borrow(&pool_ids, i);
        let amount = *vector::borrow(&amounts, i);
        
        event::emit(UnstakedEvent {
            pool_id,
            unstaker: unstaker_addr,
            amount,
        });
        
        // Record in event history
        event_history::record_user_event(
            unstaker_addr,
            event_history::event_type_unstake(),
            option::some(amount),
            option::some(pool_id),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
        );
        
        i = i + 1;
    };
    
    // Explicitly destroy the vectors since they don't have drop
    vector::destroy_empty(pool_ids);
    vector::destroy_empty(amounts);
    
    // In production, could emit summary event
}

/// Get staked amount for a user
#[view]
public fun get_staked_amount(addr: address, pool_id: u64, pool_addr: address): u64 {
    if (!exists<RewardsPool>(pool_addr)) {
        return 0
    };
    let pool = borrow_global<RewardsPool>(pool_addr);
    if (pool.pool_id != pool_id) {
        return 0
    };
    if (!aptos_framework::big_ordered_map::contains(&pool.reward_data, &addr)) {
        return 0
    };
    let data = aptos_framework::big_ordered_map::borrow(&pool.reward_data, &addr);
    data.staked_amount
}

#[test_only]
public fun initialize_for_test(admin: &signer, pool_id: u64, minimum_threshold: u64, pool_address: address) {
    admin::initialize_for_test(admin);
    let admin_addr = signer::address_of(admin);
    if (!exists<RewardsPool>(admin_addr)) {
        initialize(admin, pool_id, minimum_threshold, pool_address);
    };
}

}
