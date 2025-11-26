# The Villages Community Finance Platform - Aptos Move 2 Contracts

## Table of Contents

1. [Overview](#overview)
2. [Project Goals](#project-goals)
3. [Architecture](#architecture)
4. [Core Modules](#core-modules)
5. [User Journeys](#user-journeys)
6. [API Reference](#api-reference)
7. [Deployment](#deployment)
8. [Security Considerations](#security-considerations)
9. [Architecture Decisions](#architecture-decisions)
10. [Building and Testing](#building-and-testing)

---

## Overview

The Villages Community Finance Platform is a comprehensive DeFi system built on Aptos that enables community-driven financial services including:

- **Time Dollar Banking**: Volunteer hours tracking and tokenization
- **Community Investment Pools**: Fractional ownership and lending for community projects
- **Treasury Management**: Community fund deposits and withdrawals
- **Governance**: DAO-style proposal and voting system
- **Rewards Distribution**: Proportional reward distribution to depositors
- **Project Registry**: Community project proposal and approval system

The platform uses the **Aptos Fungible Asset (FA) standard** for all custom tokens and follows Move 2 best practices for production-ready smart contracts.

---

## Project Goals

### Primary Objectives

1. **Community Empowerment**: Enable community members to pool resources and invest in local projects
2. **Volunteer Recognition**: Tokenize volunteer hours as Time Dollars to recognize community contributions
3. **Transparent Governance**: Decentralized decision-making through token-weighted voting
4. **Financial Inclusion**: Provide access to investment opportunities and lending for community members
5. **Compliance**: KYC/AML whitelist system for regulatory compliance

### Key Features

- **Role-Based Access Control**: Admin, Borrower, Depositor, and Validator roles
- **KYC Compliance**: Whitelist registry for verified members
- **Fractional Ownership**: Share-based investment tracking
- **Interest-Bearing Loans**: Configurable interest rates and repayment terms
- **Event History**: Comprehensive event tracking for all user actions
- **Bulk Operations**: Efficient batch processing for common operations

---

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                    User Interface Layer                      │
└─────────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────────┐
│                  Smart Contract Layer                        │
├─────────────────────────────────────────────────────────────┤
│  Admin │ Members │ Compliance │ Governance │ Event History  │
├─────────────────────────────────────────────────────────────┤
│  Token │ TimeToken │ Treasury │ Investment Pool │ Rewards   │
├─────────────────────────────────────────────────────────────┤
│  TimeBank │ Project Registry │ Fractional Asset              │
└─────────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────────┐
│                    Aptos Blockchain                         │
│         (Fungible Asset Standard, Coin API)                  │
└─────────────────────────────────────────────────────────────┘
```

### Registry Pattern

The platform uses a **registry pattern** where each module stores its state in a registry object at a specific address:

- **Membership Registry**: Tracks all registered members and their roles
- **Compliance Registry**: Maintains KYC whitelist
- **Pool Registry**: Manages investment pools
- **Project Registry**: Tracks community projects
- **Governance Registry**: Stores proposals and votes

### Token Standards

- **Community Token**: FA standard fungible token for governance and rewards
- **Time Token**: FA standard token representing volunteer hours (1 hour = 1 token)
- **AptosCoin**: Native Aptos coin for deposits, investments, and repayments

### Multi-Community Setup

1. **Create a Registry Hub** – call `registry_hub::initialize` under the address that will coordinate multiple communities.
2. **Instantiate per-community registries** – deploy membership, compliance, treasury, pool, rewards, and governance resources under community-specific resource accounts.
3. **Register the community** – call `registry_hub::register_community` (or use `scripts/register_community.move`) to map a `community_id` to the addresses created in step 2.
4. **Use community-aware entry points** – e.g., `members::request_membership_for_community` resolves the correct registry via the hub, while other modules accept addresses fetched from the hub’s view functions.

---

## Core Modules

### 0. Registry Hub (`registry_hub.move`)

**Purpose**: Stores per-community registry addresses so multiple communities can share the same code deployment.

**Key Functions**:
- `initialize()`: Creates a hub under the caller’s address.
- `register_community()`: Maps a `community_id` to its members, compliance, treasury, pool, fractional-share, governance, and token vault addresses.
- `update_community()`: Rotates any of the stored addresses.
- View helpers like `members_registry_addr()` let frontends resolve addresses without redeploying contracts.

### 1. Members Module (`members.move`)

**Purpose**: Manages membership roles and member registration.

**Key Functions**:
- `initialize()`: Create membership registry
- `register_member()`: Register new member with role (Admin only)
- `accept_membership()`: Member accepts membership and creates Member resource
- `update_role()`: Change member's role (Admin only)
- `revoke_membership()`: Remove member from registry (Admin only)

**Roles**:
- `0` - Admin: Full system access
- `1` - Borrower: Can create projects and borrow funds
- `2` - Depositor: Can deposit funds and invest
- `3` - Validator: Can approve volunteer hour requests

**Storage**: 
- `MembershipRegistry`: Global registry at admin address
- `Member`: Per-user resource storing role

### 2. Compliance Module (`compliance.move`)

**Purpose**: KYC whitelist registry for verified members.

**Key Functions**:
- `initialize()`: Create compliance registry
- `whitelist_address()`: Add address to whitelist (Admin only)
- `remove_from_whitelist()`: Remove address (Admin only)
- `bulk_whitelist_addresses()`: Batch whitelist operation
- `is_whitelisted()`: Check if address is whitelisted (view)

**Integration**: Called by backend after off-chain KYC verification (e.g., Privy/Persona).

### 3. Admin Module (`admin.move`)

**Purpose**: Admin-only operations and system management.

**Key Functions**:
- `initialize()`: Create admin capability
- `pause_module()`: Pause module operations
- `unpause_module()`: Resume module operations
- `has_admin_capability()`: Check admin status (view)

**Capabilities**: 
- Module pause/unpause
- Parameter updates
- Governance rights transfer

### 4. Token Module (`token.move`)

**Purpose**: Community fungible token using FA standard.

**Key Functions**:
- `initialize()`: Create token with metadata, returns `Object<Metadata>`
- `mint()`: Mint tokens to address (requires admin_addr)
- `burn()`: Burn tokens from address (requires admin_addr)
- `balance()`: Get token balance (view, requires admin_addr)
- `supply()`: Get total supply (view)

**Storage**: `MintCapability` stored at admin address with mint/burn/transfer refs.

### 5. Time Token Module (`time_token.move`)

**Purpose**: Time Dollar token representing validated volunteer hours.

**Key Functions**:
- `initialize()`: Create TimeToken with metadata
- `mint()`: Mint TimeTokens (called by TimeBank on approval)
- `burn()`: Burn TimeTokens
- `balance()`: Get TimeToken balance (view)
- `get_asset_type()`: Get asset type address (view)

**Integration**: Minted automatically when TimeBank approves volunteer hour requests.

### 6. Treasury Module (`treasury.move`)

**Purpose**: Community treasury for deposits and withdrawals.

**Key Functions**:
- `initialize()`: Create treasury
- `deposit()`: Deposit AptosCoin to treasury (requires member + KYC)
- `withdraw()`: Withdraw from treasury (self-service, membership validated)
- `transfer_to_pool()`: Transfer funds to investment pool vaults
- `get_balance()`: Get user balance (view)
- `get_total_deposited()`: Get total treasury balance (view)

**Storage**: `Treasury` object with per-user balances tracked in BigOrderedMap.

### 7. TimeBank Module (`timebank.move`)

**Purpose**: Volunteer hour requests, approvals, and TimeToken minting.

**Key Functions**:
- `initialize()`: Create TimeBank registry
- `create_request()`: Create volunteer hour request
- `approve_request()`: Approve request and mint TimeTokens (Validator/Admin only)
- `reject_request()`: Reject request (Validator/Admin only)
- `bulk_approve_requests()`: Batch approval operation
- `cancel_request()`: Cancel pending request (requester only)
- `update_request()`: Update pending request hours (requester only)
- `get_request()`: Get request details (view)
- `get_volunteer_stats()`: Get volunteer statistics (view)

**Request Status**:
- `0` - Pending: Awaiting approval
- `1` - Approved: TimeTokens minted
- `2` - Rejected: Request denied

### 8. Project Registry Module (`project_registry.move`)

**Purpose**: Community project proposal and approval system.

**Key Functions**:
- `initialize()`: Create project registry
- `propose_project()`: Propose new project (Member only)
- `approve_project()`: Approve project (Admin only)
- `update_status()`: Update project status (Admin only)
- `get_project()`: Get project details (view)
- `list_projects()`: List projects with optional status filter (view)

**Project Status**:
- `0` - Proposed: Awaiting approval
- `1` - Approved: Ready for pool creation
- `2` - Active: Project in progress
- `3` - Completed: Project finished
- `4` - Cancelled: Project cancelled

**Project Fields**:
- `metadata_cid`: IPFS CID for project metadata
- `target_usdc`: Target funding amount
- `target_hours`: Target volunteer hours
- `is_grant`: Whether project is a grant (non-repayable)

### 9. Fractional Asset Module (`fractional_asset.move`)

**Purpose**: Fractional ownership shares for investment pools.

**Key Functions**:
- `initialize()`: Initialize shares for a pool
- `mint_shares()`: Mint shares to investor (called by InvestmentPool)
- `burn_shares()`: Burn shares on redemption
- `transfer_shares()`: Transfer shares (restricted)
- `get_shares()`: Get share balance (view)
- `get_total_shares()`: Get total shares for pool (view)

**Storage**: Shared `FractionalSharesRegistry` maps each `pool_id` to its own share ledger, enabling multiple pools per deployment.

### 10. Investment Pool Module (`investment_pool.move`)

**Purpose**: Fundraising pools for community projects with interest and repayment.

**Key Functions**:
- `initialize()`: Create pool registry
- `create_pool()`: Create new investment pool (Admin only). Accepts a `token_admin_addr` parameter that references the community fungible asset created via `token.move`.
- `create_pool_from_project()`: Create pool from approved project (Admin only) using the same token configuration.
- `join_pool()`: Invest in pool (Member + KYC required)
- `finalize_funding()`: Finalize when goal met (Admin only)
- `repay_loan()`: Repay loan with interest (Borrower only)
- `claim_repayment()`: Claim repayment share (investor self-service)
- `bulk_claim_repayments()`: Batch claim operation
- `mark_defaulted()`: Mark pool as defaulted (Admin only)
- `get_pool()`: Get pool details (view)
- `get_investor_portfolio()`: Get investor's portfolio (view)
- `get_borrower_loans()`: Get borrower's loans (view)

> **Tokenization note:** Pools use dedicated resource accounts per pool to hold funds, allowing self-service withdrawals for investors without requiring admin co-signers. Each pool creates its own resource account during initialization.

**Pool Status**:
- `0` - Pending: Created but not yet active
- `1` - Active: Accepting investments
- `2` - Funded: Goal met, funds transferred to borrower
- `3` - Completed: Loan repaid, investors can claim
- `4` - Defaulted: Loan defaulted

**Pool Configuration**:
- `interest_rate`: Interest rate in basis points (e.g., 500 = 5%)
- `duration`: Loan duration in seconds
- `target_amount`: Funding goal
- `current_total`: Current amount raised

### 11. Governance Module (`governance.move`)

**Purpose**: DAO-style proposal and voting mechanism.

**Key Functions**:
- `initialize()`: Create governance registry
- `create_proposal()`: Create governance proposal (Member only)
- `vote()`: Cast vote on proposal (Member only)
- `execute_proposal()`: Execute passed proposal (Admin only)
- `get_proposal()`: Get proposal details (view)
- `get_voting_power()`: Get user's voting power (view)

**Voting Mechanisms**:
- `0` - Simple: One vote per address
- `1` - TokenWeighted: Voting power = token balance
- `2` - Quadratic: Voting power = sqrt(token balance)
- `3` - Conviction: Time-weighted (future)

**Proposal Status**:
- `0` - Pending: Created but not active
- `1` - Active: Open for voting
- `2` - Passed: Vote threshold met
- `3` - Rejected: Vote threshold not met
- `4` - Executed: Proposal executed

**Proposal Actions**:
- Upgrade module
- Update parameter
- Pause/unpause module
- Transfer admin rights

### 12. Rewards Module (`rewards.move`)

**Purpose**: Proportional reward distribution to depositors using reward debt pattern.

**Key Functions**:
- `initialize()`: Create rewards pool. Requires `token_admin_addr` pointing to the fungible asset used for staking/reward payouts.
- `stake()`: Stake tokens in rewards pool
- `unstake()`: Unstake tokens directly from the pool vault
- `distribute_rewards()`: Distribute rewards to pool
- `claim_rewards()`: Claim pending rewards (no admin co-signer)
- `bulk_stake()`: Batch stake operation
- `bulk_unstake()`: Batch unstake operation
- `get_pending_rewards()`: Get pending rewards (view)
- `get_staked_amount()`: Get staked amount (view)

**Reward Debt Pattern**: Efficient calculation of proportional rewards without iterating through all stakers.

> **Tokenization note:** Rewards staking now uses dedicated resource accounts per pool, allowing the module to move vault funds without borrowing an admin signer.

---

## User Journeys

### Journey 1: New Member Onboarding

**Goal**: Register a new member and enable platform access.

**Steps**:

1. **Off-chain KYC Verification**
   - User completes KYC through backend (Privy/Persona)
   - Backend verifies identity documents

2. **Prospective Member Submits On-Chain Request**
   ```move
   members::request_membership(
       applicant: signer,
       registry_addr: address, // or resolve via RegistryHub
       role: u8,
       note: vector<u8>,
   )
   ```
   - Returns: `request_id`

3. **Validator/Admin Reviews Request**
   ```move
   members::approve_membership(
       validator: signer,
       request_id: u64,
       registry_addr: address,
   )
   // or members::reject_membership(...)
   ```
   - Validators can approve as long as they hold the validator role.

4. **Admin Whitelists Address** (Admin)
   ```move
   compliance::whitelist_address(
       admin: signer,
       addr: address,
   )
   ```

5. **Admin Registers Member (optional direct registration)** (Admin)
   ```move
   members::register_member(
       admin: signer,
       member_addr: address,
       role: u8,  // 0=Admin, 1=Borrower, 2=Depositor, 3=Validator
   )
   ```

6. **Member Accepts Membership** (Member)
   ```move
   members::accept_membership(
       member: signer,
       registry_addr: address,
   )
   ```

**Result**: Member can now participate in platform activities based on role.

---

### Journey 2: Volunteer Hour Tracking (Time Dollar Banking)

**Goal**: Track volunteer hours and mint TimeTokens.

**Steps**:

1. **Volunteer Creates Request** (Member)
   ```move
   timebank::create_request(
       requester: signer,
       hours: u64,
       activity_id: u64,
       members_registry_addr: address,
       bank_registry_addr: address,
   )
   ```
   - Returns: `request_id`

2. **Validator Approves Request** (Validator/Admin)
   ```move
   timebank::approve_request(
       validator: signer,
       request_id: u64,
       members_registry_addr: address,
       compliance_registry_addr: address,
       bank_registry_addr: address,
       time_token_admin_addr: address,
   )
   ```
   - Automatically mints TimeTokens to requester
   - Requires requester to be whitelisted

3. **Volunteer Checks Balance** (View)
   ```move
   time_token::balance(
       addr: address,
       admin_addr: address,
   ): u64
   ```

**Alternative**: Bulk approval for multiple requests
```move
timebank::bulk_approve_requests(
    validator: signer,
    request_ids: vector<u64>,
    bank_registry_addr: address,
    members_registry_addr: address,
    time_token_admin_addr: address,
)
```

**Result**: Volunteer receives TimeTokens equal to approved hours.

---

### Journey 3: Project Proposal and Investment

**Goal**: Propose a project, get it approved, and raise funds through investment pool.

**Steps**:

1. **Member Proposes Project** (Member)
   ```move
   project_registry::propose_project(
       proposer: signer,
       metadata_cid: vector<u8>,  // IPFS CID
       target_usdc: u64,
       target_hours: u64,
       is_grant: bool,
       registry_addr: address,
       members_registry_addr: address,
   )
   ```
   - Returns: `project_id`
   - Status: `Proposed` (0)

2. **Admin Approves Project** (Admin)
   ```move
   project_registry::approve_project(
       approver: signer,
       project_id: u64,
       registry_addr: address,
   )
   ```
   - Status: `Approved` (1)

3. **Admin Creates Investment Pool** (Admin)
   ```move
   investment_pool::create_pool_from_project(
       admin: signer,
       project_id: u64,
       interest_rate: u64,  // Basis points (500 = 5%)
       duration: u64,        // Seconds
       pool_address: address,
       fractional_shares_addr: address,
       compliance_registry_addr: address,
       members_registry_addr: address,
       project_registry_addr: address,
       pool_registry_addr: address,
   )
   ```
   - Returns: `pool_id`
   - Status: `Pending` (0)

4. **Investors Join Pool** (Depositor + KYC)
   ```move
   investment_pool::join_pool(
       investor: signer,
       pool_id: u64,
       amount: u64,  // AptosCoin amount
       registry_addr: address,
   )
   ```
   - Transfers AptosCoin to pool
   - Mints fractional shares to investor
   - Pool status becomes `Active` (1)

5. **Admin Finalizes Funding** (Admin, when goal met)
   ```move
   investment_pool::finalize_funding(
       admin: signer,
       pool_id: u64,
       registry_addr: address,
   )
   ```
   - Transfers funds to borrower
   - Status: `Funded` (2)

**Result**: Project receives funding, investors hold fractional shares.

---

### Journey 4: Loan Repayment and Investor Returns

**Goal**: Borrower repays loan, investors claim their share with interest.

**Steps**:

1. **Borrower Repays Loan** (Borrower)
   ```move
   investment_pool::repay_loan(
       borrower: signer,
       pool_id: u64,
       registry_addr: address,
   )
   ```
   - Calculates principal + interest
   - Transfers repayment to pool address
   - Status: `Completed` (3)

2. **Investor Claims Repayment** (Investor + Admin)
   ```move
   investment_pool::claim_repayment(
       investor: signer,
       admin: signer,  // Required for MVP
       pool_id: u64,
       registry_addr: address,
   )
   ```
   - Calculates proportional share: `(contribution / total) * repayment`
   - Transfers share to investor
   - Marks as claimed

**Alternative**: Bulk claim for multiple pools
```move
investment_pool::bulk_claim_repayments(
    investor: signer,
    admin: signer,
    pool_ids: vector<u64>,
    registry_addr: address,
)
```

**Result**: Investors receive principal + proportional interest.

---

### Journey 5: Treasury Deposit and Withdrawal

**Goal**: Deposit funds to community treasury and withdraw when needed.

**Steps**:

1. **Deposit to Treasury** (Depositor + KYC)
   ```move
   treasury::deposit(
       depositor: signer,
       amount: u64,
       treasury_addr: address,
       members_registry_addr: address,
       compliance_registry_addr: address,
   )
   ```
   - Transfers AptosCoin to treasury address
   - Updates depositor balance

2. **Check Balance** (View)
   ```move
   treasury::get_balance(
       addr: address,
       treasury_addr: address,
   ): u64
   ```

3. **Withdraw from Treasury** (Depositor)
   ```move
   treasury::withdraw(
       withdrawer: signer,
       amount: u64,
       treasury_addr: address,
   )
   ```
   - Validates sufficient balance
   - Transfers coins back to withdrawer without needing an admin co-signer

**Result**: Funds safely stored in treasury, available for withdrawal.

---

### Journey 6: Governance Proposal and Voting

**Goal**: Create governance proposal, vote, and execute if passed.

**Steps**:

1. **Create Proposal** (Member)
   ```move
   governance::create_proposal(
       proposer: signer,
       title: vector<u8>,
       description: vector<u8>,
       threshold: u64,
       voting_mechanism: u8,  // 0=Simple, 1=TokenWeighted, 2=Quadratic
       action: option::Option<ProposalAction>,
       members_registry_addr: address,
       token_admin_addr: address,
       governance_registry_addr: address,
   )
   ```
   - Returns: `proposal_id`
   - Status: `Pending` (0)

2. **Proposal Becomes Active** (Automatic or Admin)
   - Status: `Active` (1)

3. **Members Vote** (Member)
   ```move
   governance::vote(
       voter: signer,
       proposal_id: u64,
       choice: u8,  // 0=Yes, 1=No, 2=Abstain
       governance_registry_addr: address,
       members_registry_addr: address,
       token_admin_addr: address,
   )
   ```
   - Voting power calculated based on mechanism
   - TokenWeighted: `balance = voting_power`
   - Quadratic: `sqrt(balance) = voting_power`

4. **Check Proposal Status** (View)
   ```move
   governance::get_proposal(
       proposal_id: u64,
       governance_registry_addr: address,
   ): (address, vector<u8>, vector<u8>, u8, u64, u64, u64, u8, u64)
   ```

5. **Execute Passed Proposal** (Admin)
   ```move
   governance::execute_proposal(
       admin: signer,
       proposal_id: u64,
       governance_registry_addr: address,
   )
   ```
   - Executes action (upgrade, pause, etc.)
   - Status: `Executed` (4)

**Result**: Community decision implemented on-chain.

---

### Journey 7: Rewards Staking and Claiming

**Goal**: Stake tokens in rewards pool and claim proportional rewards.

**Steps**:

1. **Stake Tokens** (Depositor)
   ```move
   rewards::stake(
       staker: signer,
       pool_id: u64,
       amount: u64,
       pool_registry_addr: address,
   )
   ```
   - Transfers AptosCoin to pool
   - Updates reward debt

2. **Rewards Distributed** (Admin/Distributor)
   ```move
   rewards::distribute_rewards(
       distributor: signer,
       pool_id: u64,
       total_amount: u64,
       pool_registry_addr: address,
   )
   ```
   - Updates cumulative reward index
   - Rewards calculated proportionally

3. **Check Pending Rewards** (View)
   ```move
   rewards::get_pending_rewards(
       addr: address,
       pool_id: u64,
       pool_addr: address,
   ): u64
   ```

4. **Claim Rewards** (Staker + Admin)
   ```move
   rewards::claim_rewards(
       claimer: signer,
       admin: signer,  // Required for MVP
       pool_id: u64,
       pool_registry_addr: address,
   )
   ```
   - Transfers pending rewards to claimer

5. **Unstake Tokens** (Staker + Admin)
   ```move
   rewards::unstake(
       unstaker: signer,
       admin: signer,  // Required for MVP
       pool_id: u64,
       amount: u64,
       pool_registry_addr: address,
   )
   ```

**Result**: Stakers earn proportional rewards based on stake amount.

---

## API Reference

### Common Parameters

- `registry_addr`: Address where module registry is stored (usually admin address)
- `members_registry_addr`: Address of membership registry
- `compliance_registry_addr`: Address of compliance registry
- `admin_addr`: Address with admin capabilities
- `admin: signer`: Admin signer (required for MVP withdrawals)

### Error Codes

Each module defines error codes. Common patterns:
- `E_NOT_ADMIN` (1): Caller lacks admin permissions
- `E_NOT_MEMBER` (2): Address not registered as member
- `E_NOT_WHITELISTED` (3): Address not in compliance whitelist
- `E_INVALID_REGISTRY` (4): Registry address invalid or not found
- `E_ZERO_AMOUNT` (5): Amount must be greater than zero
- `E_INSUFFICIENT_BALANCE` (6): Insufficient balance for operation

### View Functions

All view functions are marked with `#[view]` and can be called without a transaction:

```move
#[view]
public fun get_balance(addr: address, treasury_addr: address): u64
```

### Events

All state changes emit events. Event structure:
```move
#[event]
struct DepositEvent has drop, store {
    depositor: address,
    amount: u64,
}
```

---

## Deployment

### Prerequisites

- Aptos CLI installed (latest version)
- Move toolchain configured
- Aptos account with sufficient funds

### Build

```bash
cd villages_finance
aptos move compile
```

### Test

```bash
aptos move test
```

### Test with Coverage

```bash
aptos move test --coverage
```

### Initialize Modules

Use the initialization script to set up all core modules:

```bash
aptos move run-script --compiled-script-path scripts/initialize.move
```

**Manual Initialization** (if needed):

1. **Initialize Admin**
   ```move
   admin::initialize(admin: &signer)
   ```

2. **Initialize Members**
   ```move
   members::initialize(admin: &signer)
   ```

3. **Initialize Compliance**
   ```move
   compliance::initialize(admin: &signer)
   ```

4. **Initialize Tokens**
   ```move
   token::initialize(
       admin: &signer,
       name: string::String,
       symbol: string::String,
       decimals: u8,
       description: string::String,
       icon_uri: string::String,
   ): Object<Metadata>
   ```

5. **Initialize TimeToken**
   ```move
   time_token::initialize(
       admin: &signer,
       name: string::String,
       symbol: string::String,
       decimals: u8,
       description: string::String,
       icon_uri: string::String,
   ): Object<Metadata>
   ```

6. **Initialize Other Modules**
   - `treasury::initialize()`
   - `timebank::initialize()`
   - `project_registry::initialize()`
   - `investment_pool::initialize()`
   - `governance::initialize()`
   - `rewards::initialize()`

### Register Members

```bash
aptos move run-script --compiled-script-path scripts/register_member.move \
  --args address:<member_addr> u8:<role>
```

Roles: `0`=Admin, `1`=Borrower, `2`=Depositor, `3`=Validator

### Whitelist Address

```bash
aptos move run-script --compiled-script-path scripts/whitelist_address.move \
  --args address:<addr>
```

---

## Security Considerations

### Access Control

- **Role-Based**: All operations check member roles
- **Admin Capability**: Critical operations require admin capability resource
- **KYC Compliance**: Financial operations require whitelist check

### Self-Service Withdrawals

**Resource Account Pattern**: All withdrawals use dedicated resource accounts with stored signer capabilities:

- `investment_pool::claim_repayment()` - investor self-service via pool vault capability
- `treasury::withdraw()` - depositor self-service using treasury transfer_ref
- `rewards::claim_rewards()` - claimer self-service via rewards vault capability
- `rewards::unstake()` - staker self-service via rewards vault capability

**Security**: Each pool/treasury maintains its own resource account, enabling secure, decentralized withdrawals without requiring admin co-signers.

### Best Practices

- **Arithmetic Safety**: All calculations use overflow protection
- **Resource Management**: No `copy, drop` on tokens
- **Event Emission**: All state changes emit events
- **Input Validation**: All inputs validated (non-zero, bounds checks)
- **Registry Validation**: Registry addresses validated before use

### Security Features

- **FA Standard**: Enhanced security and composability
- **User-Specific Storage**: Avoids global loops
- **Capability Pattern**: Admin capabilities stored in resources
- **Event History**: Comprehensive audit trail

---

## Architecture Decisions

### Fungible Asset (FA) Standard Migration

**Status**: ✅ Fully migrated for custom tokens

- ✅ **TimeToken**: FA standard
- ✅ **Community Token**: FA standard
- ⚠️ **AptosCoin**: Uses legacy Coin API (ecosystem migration ongoing)

**Rationale**: Aptos is migrating all tokens to FA standard. Custom tokens fully migrated; AptosCoin operations continue using Coin API until ecosystem migration completes.

### Resource Account Pattern for Vaults

**Pattern**: Each pool/treasury creates a dedicated resource account during initialization, storing the signer capability for self-service withdrawals.

**Example**:
```move
// In investment_pool.move - pool creation
let (pool_signer, signer_cap) = account::create_resource_account(admin, seed);
aptos_framework::big_ordered_map::add(&mut registry.pool_signer_caps, pool_id, signer_cap);

// In claim_repayment - self-service withdrawal
let asset = withdraw_from_pool_vault(&mut registry.pool_signer_caps, pool_id, amount, token_admin_addr);
```

**Benefits**: Enables secure, decentralized withdrawals without requiring admin co-signers, improving user experience and reducing operational overhead.

### Registry Pattern

**Design**: Each module stores state in a registry object at a specific address (usually admin address).

**Benefits**:
- Centralized state management
- Easy cross-module access
- Simplified initialization

**Trade-offs**:
- Single point of failure (mitigated by admin capability management)
- Scalability considerations (addressed with BigOrderedMap for large datasets)

### Event History Module

**Purpose**: Comprehensive event tracking for all user actions.

**Events Tracked**:
- Deposits, withdrawals, investments
- Volunteer requests, approvals
- Governance votes, proposals
- Rewards claimed, staked

**Use Cases**:
- Audit trail
- Frontend activity feeds
- Analytics and reporting

---

## Building and Testing

### Build Commands

```bash
# Compile all modules
aptos move compile

# Compile with verbose output
aptos move compile --verbose

# Check for errors without building
aptos move check
```

### Test Commands

```bash
# Run all tests
aptos move test

# Run specific test
aptos move test --filter test_name

# Test with coverage
aptos move test --coverage

# Test with verbose output
aptos move test --verbose
```

### Test Structure

Tests are located in `tests/` directory:
- `admin_test.move`
- `members_test.move`
- `compliance_test.move`
- `token_test.move`
- `time_token_test.move`
- `treasury_test.move`
- `timebank_test.move`
- `project_registry_test.move`
- `investment_pool_test.move`
- `governance_test.move`
- `rewards_test.move`
- `integration_test.move`

### Code Quality

- **Move 2 Best Practices**: Follows Aptos Move 2 standards
- **Error Handling**: Comprehensive error codes
- **Documentation**: Inline comments for all public functions
- **Type Safety**: Strong typing throughout

---

## Production Considerations

### Recommended Enhancements

1. **Resource Accounts**: Use resource accounts for pool/treasury withdrawals
2. **Formal Verification**: Add formal verification for critical invariants
3. **Upgrade Mechanism**: Implement governance-controlled module upgrades
4. **Pagination**: Add pagination for large result sets
5. **Rate Limiting**: Consider rate limiting for bulk operations
6. **Gas Optimization**: Optimize gas costs for high-frequency operations
7. **Automatic Proposal Expiration**: Implement timestamp-based automatic finalization for governance proposals
   - **Current State**: Proposals require manual admin intervention via `finalize_proposal()` to transition from `Active` to `Passed`/`Rejected`
   - **Proposed Enhancement**: Add automatic expiration based on voting period
   - **Implementation Requirements**:
     - Add `voting_period: u64` parameter to `create_proposal()` (duration in seconds, e.g., 7 days = 604800)
     - Store `activated_at: u64` timestamp when `activate_proposal()` is called (using `timestamp::now_seconds()`)
     - Calculate `expires_at: u64 = activated_at + voting_period` in the `GovernanceProposal` struct
     - Replace `created_at: proposal_id` with real timestamp `timestamp::now_seconds()` in `create_proposal()`
     - Add expiration check in `vote()` function: if `timestamp::now_seconds() >= proposal.expires_at`, auto-finalize based on current votes
     - Default to "Rejected" status if threshold not met by expiration time
     - Optionally add a `check_expiration()` view function to check proposal expiration status
   - **Benefits**: 
     - Self-executing proposals reduce reliance on manual admin intervention
     - Clear voting deadlines improve governance transparency
     - Prevents proposals from remaining in `Active` state indefinitely

### Integration Points

- **Off-chain KYC**: Integrate with Privy/Persona for KYC verification
- **IPFS**: Store project metadata on IPFS
- **Frontend**: Build React/Next.js frontend for user interactions
- **Indexer**: Use Aptos indexer for efficient querying

### Monitoring

- **Events**: Monitor all emitted events
- **Error Rates**: Track error code frequencies
- **Gas Usage**: Monitor transaction gas costs
- **User Activity**: Track user journey completion rates

---

## License

See LICENSE file for details.

---

## Support

For questions or issues:
1. Review this documentation
2. Check test files for usage examples
3. Review API_CHANGES.md and API_FIXES_SUMMARY.md for recent updates
4. Consult MOVE_2_BEST_PRACTICES.md for coding standards

---

**Last Updated**: See git history for latest changes.
