<!-- 18e0c77f-d117-4f10-975d-453ae846ade5 3fb404db-3431-4112-bb45-cd4a476ef130 -->
# Fix Failing Test and Add Missing User Journey Tests

## Problem Analysis

### Current Status

- **58/59 tests passing** (98.3% pass rate)
- **1 failing test**: `governance_enhanced_test::test_token_weighted_voting`
- **Missing test coverage** for critical user journey functions:
  - `claim_repayment` (Journey 4: Loan Repayment)
  - `unstake` (Journey 7: Rewards)
  - Bulk operations (`bulk_claim_repayments`, `bulk_unstake`)

### Root Cause Analysis

#### Failing Test: `test_token_weighted_voting`

**Error**: Proposal status check fails at line 357 in `governance.move::vote()` - proposal is not Active when vote is called.

**Possible causes**:

1. Proposal activation not persisting (OrderedMap borrow_mut issue)
2. Token balance lookup failing silently before status check
3. Test setup issue with token metadata or balances

**Investigation needed**:

- Verify `activate_proposal` successfully changes status to Active
- Check if `calculate_voting_power` for TokenWeighted is failing before status check
- Compare with working `test_create_and_vote_simple` (uses Simple voting, not TokenWeighted)

## Solution Plan

### Phase 1: Fix Failing Governance Test

**1.1 Debug and Fix `test_token_weighted_voting`**

- **File**: `villages_finance/tests/governance_enhanced_test.move`
- **Investigation steps**:

  1. Add debug assertions to verify proposal status after `activate_proposal`
  2. Verify token balances are correctly set before voting
  3. Check if `calculate_voting_power` is being called and failing before status check
  4. Compare token metadata setup with working `test_quadratic_voting`

- **Potential fixes**:
  - If token balance lookup fails: Ensure token metadata is properly initialized
  - If status not persisting: Verify OrderedMap::borrow_mut is working correctly
  - If test setup issue: Ensure voters have tokens before proposal creation

**1.2 Verify Proposal Status Persistence**

- **File**: `villages_finance/sources/governance.move`
- **Check**: Ensure `activate_proposal` correctly updates proposal status
- **Test**: Add intermediate status check in test after activation

### Phase 2: Add Missing Tests for Journey 2 (Volunteer Hour Tracking)

**2.1 Test `bulk_approve_requests` Function**

- **File**: `villages_finance/tests/timebank_test.move`
- **Test cases**:

  1. `test_bulk_approve_requests` - Approve multiple requests at once
  2. `test_bulk_approve_requests_partial_failure` - Some requests fail validation
  3. `test_bulk_approve_requests_mixed_status` - Mix of pending and already processed requests
  4. `test_bulk_approve_requests_batch_limit` - Test 50 request limit
  5. `test_bulk_approve_requests_empty_vector` - Error handling for empty input

**2.2 Test `update_request` Function**

- **File**: `villages_finance/tests/timebank_test.move`
- **Test cases**:

  1. `test_update_request` - Requester updates pending request hours
  2. `test_update_request_not_owner` - Non-owner cannot update request
  3. `test_update_request_not_pending` - Cannot update approved/rejected requests
  4. `test_update_request_zero_hours` - Error handling for zero hours
  5. `test_update_request_multiple_times` - Multiple updates to same request

**2.3 Test `bulk_reject_requests` Function**

- **File**: `villages_finance/tests/timebank_test.move`
- **Test cases**:

  1. `test_bulk_reject_requests` - Reject multiple requests at once
  2. `test_bulk_reject_requests_partial_failure` - Some requests fail validation
  3. `test_bulk_reject_requests_batch_limit` - Test 50 request limit

**2.4 Test Time Token Transfer and Spending**

- **File**: `villages_finance/tests/time_token_test.move`
- **Test cases**:

  1. `test_time_token_transfer` - Transfer TimeTokens between users
  2. `test_time_token_transfer_insufficient_balance` - Error handling
  3. `test_time_token_burn` - Burn TimeTokens (if supported)
  4. `test_time_token_spending` - Use TimeTokens for project contributions

**2.5 Test Volunteer Statistics View Functions**

- **File**: `villages_finance/tests/timebank_test.move`
- **Test cases**:

  1. `test_get_volunteer_stats` - View volunteer statistics (if view function exists)
  2. `test_get_total_hours_volunteered` - Aggregate hours calculation
  3. `test_get_request_history` - View request history for a volunteer

**2.6 Additional TimeBank Edge Cases**

- **File**: `villages_finance/tests/timebank_test.move`
- **Test cases**:

  1. `test_cancel_request` - Requester cancels pending request (if function exists)
  2. `test_approve_request_not_whitelisted` - Approval fails if requester not whitelisted
  3. `test_approve_request_requires_validator` - Non-validator cannot approve
  4. `test_create_request_zero_hours` - Error handling for zero hours
  5. `test_create_request_max_hours` - Edge case for maximum hours value

**2.7 Integration Test for Full Journey 2**

- **File**: `villages_finance/tests/integration_test.move`
- **Test**: `test_full_volunteer_hour_journey`
  - Create request → Update request → Approve request → Verify TimeToken minted → Check balance → Transfer tokens

### Phase 3: Add Missing Tests for Journey 3 (Project Proposal and Investment)

**3.1 Test `create_pool_from_project` Function**

- **File**: `villages_finance/tests/investment_pool_test.move`
- **Test cases**:

  1. `test_create_pool_from_project` - Create pool from approved project
  2. `test_create_pool_from_project_not_approved` - Cannot create pool from unapproved project
  3. `test_create_pool_from_project_already_has_pool` - Prevent duplicate pools
  4. `test_create_pool_from_project_invalid_project` - Error handling for non-existent project

**3.2 Test `join_pool` Function with FA Assets**

- **File**: `villages_finance/tests/investment_pool_test.move`
- **Test cases**:

  1. `test_join_pool_single_investor` - Basic join pool flow with actual coin transfer
  2. `test_join_pool_multiple_investors` - Multiple investors join same pool
  3. `test_join_pool_not_whitelisted` - Join fails if investor not whitelisted
  4. `test_join_pool_exceeds_target` - Handle over-subscription scenario
  5. `test_join_pool_pool_not_active` - Cannot join inactive/completed pool
  6. `test_join_pool_insufficient_balance` - Error when investor lacks funds
  7. `test_join_pool_coin_transfer` - Verify coins are actually transferred to pool address
  8. `test_join_pool_multiple_contributions` - Same investor contributes multiple times

**3.3 Test Fractional Share Minting During Investment**

- **File**: `villages_finance/tests/investment_pool_test.move`
- **Test cases**:

  1. `test_fractional_shares_minted_on_join` - Verify shares are minted when joining pool
  2. `test_fractional_shares_proportional` - Shares proportional to contribution amount
  3. `test_fractional_shares_multiple_investors` - Each investor gets correct share amount
  4. `test_fractional_shares_cumulative` - Multiple contributions from same investor accumulate shares
  5. `test_fractional_shares_view_function` - Verify get_shares returns correct values

**3.4 Test `finalize_funding` Function**

- **File**: `villages_finance/tests/investment_pool_test.move`
- **Test cases**:

  1. `test_finalize_funding_goal_met` - Finalize when target reached
  2. `test_finalize_funding_goal_not_met` - Finalize with partial funding (under target)
  3. `test_finalize_funding_requires_admin` - Only admin can finalize
  4. `test_finalize_funding_already_finalized` - Prevent double finalization
  5. `test_finalize_funding_zero_contributions` - Edge case handling
  6. `test_finalize_funding_status_transition` - Verify pool status changes correctly

**3.5 Test Project Cancellation Flow**

- **File**: `villages_finance/tests/project_registry_test.move`
- **Test cases**:

  1. `test_cancel_project` - Admin cancels a project
  2. `test_cancel_project_with_active_pool` - Handle cancellation when pool exists
  3. `test_cancel_project_refund_investors` - Verify refunds if pool was funded (if supported)
  4. `test_cancel_project_status_transition` - Verify status changes to Cancelled

**3.6 Test Time Dollar Contribution to Projects**

- **File**: `villages_finance/tests/investment_pool_test.move`
- **Test cases**:

  1. `test_join_pool_with_time_dollars` - Contribute TimeTokens to project pool (if supported)
  2. `test_mixed_contribution_types` - Mix of APT and TimeTokens in same pool (if supported)
  3. `test_time_dollar_conversion_rate` - Verify conversion rate handling (if applicable)

**3.7 Integration Test for Full Journey 3**

- **File**: `villages_finance/tests/integration_test.move`
- **Test**: `test_full_project_investment_journey`
  - Propose project → Approve project → Create pool → Multiple investors join pool → Verify fractional shares → Finalize funding → Verify status

### Phase 4: Add Missing Tests for Journey 6 (Governance)

**4.1 Fix Failing `test_token_weighted_voting`**

- **File**: `villages_finance/tests/governance_enhanced_test.move`
- **Investigation and fix**:

  1. Debug proposal activation persistence
  2. Verify token balance lookup for TokenWeighted mechanism
  3. Compare with working Simple voting test
  4. Add intermediate status checks after activation
  5. Verify token metadata initialization before voting

**4.2 Test Proposal Rejection Flow**

- **File**: `villages_finance/tests/governance_test.move`
- **Test cases**:

  1. `test_proposal_rejection` - Proposal rejected when votes_no > votes_yes
  2. `test_proposal_rejection_threshold` - Rejection with threshold consideration
  3. `test_proposal_rejection_status_transition` - Verify status changes to Rejected
  4. `test_proposal_rejection_cannot_execute` - Cannot execute rejected proposal

**4.3 Test Proposal Expiration/Timeout**

- **File**: `villages_finance/tests/governance_test.move`
- **Test cases**:

  1. `test_proposal_expiration` - Proposal expires after timeout period (if supported)
  2. `test_proposal_expiration_status` - Expired proposals cannot be voted on
  3. `test_proposal_expiration_execution` - Cannot execute expired proposals

**4.4 Test Conviction Voting Mechanism**

- **File**: `villages_finance/tests/governance_enhanced_test.move`
- **Test cases**:

  1. `test_conviction_voting` - Verify time-weighted voting power calculation
  2. `test_conviction_voting_time_factor` - Voting power increases with time held
  3. `test_conviction_voting_multiple_voters` - Multiple voters with different conviction periods

**4.5 Test Proposal Execution with Actual Actions**

- **File**: `villages_finance/tests/governance_test.move`
- **Test cases**:

  1. `test_execute_proposal_pause_module` - Execute proposal to pause a module
  2. `test_execute_proposal_unpause_module` - Execute proposal to unpause a module
  3. `test_execute_proposal_update_parameter` - Execute proposal to update system parameter
  4. `test_execute_proposal_transfer_admin` - Execute proposal to transfer admin rights
  5. `test_execute_proposal_verify_action_executed` - Verify action actually executes

**4.6 Test Governance with Multiple Proposals**

- **File**: `villages_finance/tests/governance_test.move`
- **Test cases**:

  1. `test_multiple_proposals_simultaneous` - Multiple active proposals at same time
  2. `test_multiple_proposals_different_statuses` - Proposals in different statuses
  3. `test_multiple_proposals_voting` - Vote on multiple proposals independently
  4. `test_multiple_proposals_execution_order` - Execute multiple passed proposals

**4.7 Test Proposal Status Transitions**

- **File**: `villages_finance/tests/governance_test.move`
- **Test cases**:

  1. `test_proposal_status_pending_to_active` - Status transition via activate_proposal
  2. `test_proposal_status_active_to_passed` - Status transition when threshold met
  3. `test_proposal_status_active_to_rejected` - Status transition when votes_no > votes_yes
  4. `test_proposal_status_passed_to_executed` - Status transition via execute_proposal
  5. `test_proposal_status_not_meeting_threshold` - Proposal stays Active if threshold not met
  6. `test_proposal_status_invalid_transitions` - Prevent invalid status transitions

**4.8 Test Additional Voting Mechanisms**

- **File**: `villages_finance/tests/governance_enhanced_test.move`
- **Test cases**:

  1. `test_quadratic_voting` - Verify sqrt(balance) voting power calculation (already passing)
  2. `test_mixed_voting_mechanisms` - Different proposals with different mechanisms
  3. `test_voting_power_calculation_edge_cases` - Zero balance, very large balance, etc.

**4.9 Test Governance Edge Cases**

- **File**: `villages_finance/tests/governance_test.move`
- **Test cases**:

  1. `test_activate_proposal_requires_admin` - Permission check for activation
  2. `test_vote_after_proposal_passed` - Cannot vote after proposal passed
  3. `test_vote_after_proposal_rejected` - Cannot vote after proposal rejected
  4. `test_execute_proposal_not_passed` - Cannot execute non-passed proposal
  5. `test_execute_proposal_already_executed` - Prevent double execution
  6. `test_vote_with_zero_power` - Error when voting power is zero

**4.10 Integration Test for Full Journey 6**

- **File**: `villages_finance/tests/integration_test.move`
- **Test**: `test_full_governance_journey`
  - Create proposal → Activate proposal → Vote (multiple voters) → Check status → Execute if passed → Verify action executed

### Phase 5: Add Missing Tests for Journey 4 (Loan Repayment)

**5.1 Test `claim_repayment` Function**

- **File**: `villages_finance/tests/investment_pool_test.move`
- **Test cases**:

  1. `test_claim_repayment_single_investor` - Basic repayment claim flow
  2. `test_claim_repayment_multiple_investors` - Multiple investors claiming from same pool
  3. `test_claim_repayment_rounding` - Verify rounding edge cases
  4. `test_claim_repayment_already_claimed` - Prevent double claiming
  5. `test_claim_repayment_insufficient_balance` - Error handling
  6. `test_claim_repayment_pool_not_completed` - Status validation
  7. `test_claim_repayment_proportional` - Repayment proportional to contribution
  8. `test_claim_repayment_with_interest` - Verify interest calculation

**5.2 Test `bulk_claim_repayments` Function**

- **File**: `villages_finance/tests/investment_pool_test.move`
- **Test cases**:

  1. `test_bulk_claim_repayments` - Claim from multiple pools
  2. `test_bulk_claim_repayments_partial_failure` - Some pools fail, others succeed
  3. `test_bulk_claim_repayments_batch_limit` - Test batch size limits

**5.3 Integration Test for Full Journey 4**

- **File**: `villages_finance/tests/integration_test.move`
- **Test**: `test_full_loan_repayment_journey`
  - Create pool → Join pool → Finalize funding → Repay loan → Claim repayment → Verify balances

### Phase 6: Add Missing Tests for Journey 7 (Rewards)

**6.1 Test `unstake` Function**

- **File**: `villages_finance/tests/rewards_test.move`
- **Test cases**:

  1. `test_unstake_partial` - Unstake partial amount
  2. `test_unstake_full` - Unstake all staked tokens
  3. `test_unstake_insufficient_balance` - Error handling
  4. `test_unstake_updates_reward_debt` - Verify reward debt calculation
  5. `test_unstake_multiple_users` - Multiple users unstaking from same pool
  6. `test_unstake_after_claiming` - Unstake after claiming rewards
  7. `test_unstake_before_claiming` - Unstake before claiming (verify reward debt handling)

**6.2 Test `bulk_unstake` Function**

- **File**: `villages_finance/tests/rewards_test.move`
- **Test cases**:

  1. `test_bulk_unstake` - Unstake from multiple pools
  2. `test_bulk_unstake_partial_amounts` - Different amounts per pool
  3. `test_bulk_unstake_partial_failure` - Some pools fail, others succeed

**6.3 Test Reward Distribution to Multiple Stakers**

- **File**: `villages_finance/tests/rewards_test.move`
- **Test cases**:

  1. `test_reward_distribution_multiple_stakers` - Distribute rewards to multiple stakers
  2. `test_reward_distribution_proportional` - Rewards proportional to stake amount
  3. `test_reward_distribution_accuracy` - Verify reward calculation accuracy
  4. `test_reward_distribution_after_unstake` - Rewards after partial unstaking

**6.4 Integration Test for Full Journey 7**

- **File**: `villages_finance/tests/integration_test.move`
- **Test**: `test_full_rewards_journey`
  - Stake → Distribute rewards → Claim rewards → Unstake → Verify final balances

### Phase 7: Additional Test Coverage

**7.1 Investment Pool Edge Cases**

- **File**: `villages_finance/tests/investment_pool_test.move`
- **Test cases**:

  1. `test_claim_repayment_zero_contribution` - Edge case handling
  2. `test_claim_repayment_all_funds_claimed` - Verify no double claiming
  3. `test_join_pool_zero_amount` - Error handling for zero amount
  4. `test_finalize_funding_over_target` - Handle over-subscription finalization

**7.2 Time Bank Bulk Operations**

- **File**: `villages_finance/tests/timebank_test.move`
- **Test cases**:

  1. `test_bulk_approve_requests` - Approve multiple requests (already in Phase 2)
  2. `test_bulk_reject_requests` - Reject multiple requests (already in Phase 2)

## Implementation Details

### Test Structure Pattern

All new tests should follow existing patterns:

```move
#[test(admin = @0x1, user1 = @0x2, user2 = @0x3)]
fun test_functionality(admin: signer, user1: signer, user2: signer) {
    // Initialize modules
    admin::initialize_for_test(&admin);
    members::initialize_for_test(&admin);
    // ... setup ...
    
    // Execute functionality
    // ... test logic ...
    
    // Verify results
    // ... assertions ...
}
```

### Key Testing Principles

1. **Idempotent Setup**: Use `initialize_for_test` which handles idempotency
2. **Cross-User Operations**: Test interactions between different users
3. **Error Handling**: Test all error paths and edge cases
4. **State Verification**: Verify state changes after operations
5. **Integration**: Test full user journeys end-to-end
6. **FA Asset Transfers**: Test actual coin transfers, not just state changes
7. **Fractional Shares**: Verify share minting and tracking
8. **Status Transitions**: Verify all valid and invalid state transitions

### Files to Modify

1. `villages_finance/tests/governance_enhanced_test.move` - Fix failing test, add conviction voting tests
2. `villages_finance/tests/governance_test.move` - Add proposal rejection, expiration, execution, status transition tests
3. `villages_finance/tests/investment_pool_test.move` - Add claim_repayment, join_pool with FA assets, fractional shares tests
4. `villages_finance/tests/rewards_test.move` - Add unstake tests
5. `villages_finance/tests/integration_test.move` - Add full journey tests
6. `villages_finance/tests/timebank_test.move` - Add bulk operations, update_request, time token transfer tests
7. `villages_finance/tests/time_token_test.move` - Add transfer and spending tests
8. `villages_finance/tests/project_registry_test.move` - Add cancellation tests

### Verification Steps

After implementation:

1. Run `aptos move test` - All 59+ tests should pass
2. Verify test coverage for all user journeys
3. Check that all production functions have corresponding tests
4. Ensure no `#[test_only]` functions are used in production code paths
5. Verify FA asset transfers are tested with actual coin operations
6. Verify fractional share minting is tested and verified
7. Verify all status transitions are tested

## Success Criteria

- ✅ All tests passing (100% pass rate)
- ✅ Journey 2 (Volunteer Hour Tracking) fully tested including bulk operations, updates, and token transfers
- ✅ Journey 3 (Project Proposal and Investment) fully tested including FA assets, fractional shares, and multiple investors
- ✅ Journey 4 (Loan Repayment) fully tested
- ✅ Journey 6 (Governance) fully tested including all voting mechanisms, status transitions, and proposal execution
- ✅ Journey 7 (Rewards) fully tested
- ✅ Bulk operations tested
- ✅ Edge cases and error paths covered
- ✅ Integration tests for full user journeys
- ✅ FA asset transfers verified with actual coin operations
- ✅ Fractional share minting verified and tested

