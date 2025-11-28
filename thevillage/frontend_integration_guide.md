# Frontend Integration Guide - Villages Finance Platform

## Contract Deployment Information

**Network:** Aptos Testnet  
**Contract Address:** `0x2144ec184b89cf405e430d375b3de991ae14baf26cb6ec9987ea57922c0f1c5b`  
**Module Name:** `villages_finance`  
**RPC Endpoint:** `https://fullnode.testnet.aptoslabs.com`  
**Explorer:** https://explorer.aptoslabs.com/?network=testnet

**Initialization Status:**
- ✅ Admin module initialized
- ✅ Members module initialized  
- ✅ Compliance module initialized
- ⚠️ Other modules need initialization on first use

---

## SDK Setup

### Install Dependencies

npm install @aptos-labs/ts-sdk
# or
yarn add @aptos-labs/ts-sdk### Initialize SDK
pescript
import { Aptos, AptosConfig, Network, Account } from "@aptos-labs/ts-sdk";

const config = new AptosConfig({ network: Network.TESTNET });
const aptos = new Aptos(config);

const MODULE_ADDRESS = "0x2144ec184b89cf405e430d375b3de991ae14baf26cb6ec9987ea57922c0f1c5b";---

## Module Addresses

All modules are deployed at the same address. Use these constants:

const CONTRACT_ADDRESS = "0x2144ec184b89cf405e430d375b3de991ae14baf26cb6ec9987ea57922c0f1c5b";

// Registry addresses (all point to contract address for MVP)
const ADMIN_ADDR = CONTRACT_ADDRESS;
const MEMBERS_REGISTRY_ADDR = CONTRACT_ADDRESS;
const COMPLIANCE_REGISTRY_ADDR = CONTRACT_ADDRESS;
const TREASURY_ADDR = CONTRACT_ADDRESS;
const POOL_REGISTRY_ADDR = CONTRACT_ADDRESS;
const GOVERNANCE_ADDR = CONTRACT_ADDRESS;
const BANK_REGISTRY_ADDR = CONTRACT_ADDRESS;
const PROJECT_REGISTRY_ADDR = CONTRACT_ADDRESS;
const FRACTIONAL_SHARES_ADDR = CONTRACT_ADDRESS;---

## Token Standards

### Community Token (FA Standard)
- **Type:** Fungible Asset (FA)
- **Purpose:** Governance voting, rewards
- **Admin Address:** `CONTRACT_ADDRESS`
- **Balance Check:** Requires `admin_addr` parameter

### Time Token (FA Standard)  
- **Type:** Fungible Asset (FA)
- **Purpose:** Volunteer hours (1 hour = 1 token)
- **Admin Address:** `CONTRACT_ADDRESS`
- **Balance Check:** Requires `admin_addr` parameter

### AptosCoin
- **Type:** Native Aptos coin
- **Purpose:** Deposits, investments, repayments
- **No admin address needed**

---

## Core Functions Reference

### 1. Membership Module

#### Request Membershipcript
const transaction = await aptos.transaction.build.simple({
  sender: account.address(),
  data: {
    function: `${MODULE_ADDRESS}::members::request_membership`,
    functionArguments: [
      role, // u8: 0=Admin, 1=Borrower, 2=Depositor, 3=Validator
      note, // vector<u8> (string as bytes)
      MEMBERS_REGISTRY_ADDR
    ],
  },
});#### Accept Membershipcript
const transaction = await aptos.transaction.build.simple({
  sender: account.address(),
  data: {
    function: `${MODULE_ADDRESS}::members::accept_membership`,
    functionArguments: [MEMBERS_REGISTRY_ADDR],
  },
});#### View Functions
// Check if address is member
const isMember = await aptos.view({
  function: `${MODULE_ADDRESS}::members::is_member_with_registry`,
  functionArguments: [userAddress, MEMBERS_REGISTRY_ADDR],
});

// Get user role
const role = await aptos.view({
  function: `${MODULE_ADDRESS}::members::get_role_with_registry`,
  functionArguments: [userAddress, MEMBERS_REGISTRY_ADDR],
});
// Returns: Option<u8> - null if not member, or role number---

### 2. Compliance Module (KYC)

#### Whitelist Address (Admin Only)cript
const transaction = await aptos.transaction.build.simple({
  sender: adminAccount.address(),
  data: {
    function: `${MODULE_ADDRESS}::compliance::whitelist_address`,
    functionArguments: [
      addressToWhitelist,
      COMPLIANCE_REGISTRY_ADDR
    ],
  },
});#### Check Whitelist Statusipt
const isWhitelisted = await aptos.view({
  function: `${MODULE_ADDRESS}::compliance::is_whitelisted`,
  functionArguments: [userAddress, COMPLIANCE_REGISTRY_ADDR],
});---

### 3. TimeBank Module (Volunteer Hours)

#### Create Volunteer Requestcript
const transaction = await aptos.transaction.build.simple({
  sender: account.address(),
  data: {
    function: `${MODULE_ADDRESS}::timebank::create_request`,
    functionArguments: [
      hours, // u64
      activityId, // u64
      MEMBERS_REGISTRY_ADDR,
      BANK_REGISTRY_ADDR
    ],
  },
});#### Approve Request (Validator/Admin)cript
const transaction = await aptos.transaction.build.simple({
  sender: validatorAccount.address(),
  data: {
    function: `${MODULE_ADDRESS}::timebank::approve_request`,
    functionArguments: [
      requestId, // u64
      MEMBERS_REGISTRY_ADDR,
      COMPLIANCE_REGISTRY_ADDR,
      BANK_REGISTRY_ADDR,
      CONTRACT_ADDRESS // time_token_admin_addr
    ],
  },
});#### Get Request Detailsypescript
const request = await aptos.view({
  function: `${MODULE_ADDRESS}::timebank::get_request`,
  functionArguments: [requestId, BANK_REGISTRY_ADDR],
});
// Returns: (address, u64, u64, u8, u64)
// [requester, hours, activity_id, status, created_at]---

### 4. Time Token Module

#### Check Balancept
const balance = await aptos.view({
  function: `${MODULE_ADDRESS}::time_token::balance`,
  functionArguments: [userAddress, CONTRACT_ADDRESS], // admin_addr
});#### Transfer Time Tokenscript
const transaction = await aptos.transaction.build.simple({
  sender: account.address(),
  data: {
    function: `${MODULE_ADDRESS}::time_token::transfer`,
    functionArguments: [
      recipient,
      amount, // u64
      CONTRACT_ADDRESS // admin_addr
    ],
  },
});---

### 5. Treasury Module

#### Deposit AptosCoincript
const transaction = await aptos.transaction.build.simple({
  sender: account.address(),
  data: {
    function: `${MODULE_ADDRESS}::treasury::deposit`,
    functionArguments: [
      amount, // u64 (in Octas: 1 APT = 100,000,000 Octas)
      TREASURY_ADDR,
      MEMBERS_REGISTRY_ADDR,
      COMPLIANCE_REGISTRY_ADDR
    ],
  },
});#### Withdraw (Self-Service)cript
const transaction = await aptos.transaction.build.simple({
  sender: account.address(),
  data: {
    function: `${MODULE_ADDRESS}::treasury::withdraw`,
    functionArguments: [
      amount, // u64
      TREASURY_ADDR
    ],
  },
});#### Get Balance
const balance = await aptos.view({
  function: `${MODULE_ADDRESS}::treasury::get_balance`,
  functionArguments: [userAddress, TREASURY_ADDR],
});---

### 6. Investment Pool Module

#### Create Pool (Admin Only)cript
const transaction = await aptos.transaction.build.simple({
  sender: adminAccount.address(),
  data: {
    function: `${MODULE_ADDRESS}::investment_pool::create_pool`,
    functionArguments: [
      borrowerAddress,
      targetAmount, // u64
      interestRate, // u64 (basis points: 500 = 5%)
      duration, // u64 (seconds)
      POOL_REGISTRY_ADDR,
      FRACTIONAL_SHARES_ADDR,
      COMPLIANCE_REGISTRY_ADDR,
      MEMBERS_REGISTRY_ADDR,
      CONTRACT_ADDRESS // token_admin_addr
    ],
  },
});#### Join Pool (Invest)cript
const transaction = await aptos.transaction.build.simple({
  sender: account.address(),
  data: {
    function: `${MODULE_ADDRESS}::investment_pool::join_pool`,
    functionArguments: [
      poolId, // u64
      amount, // u64 (AptosCoin)
      POOL_REGISTRY_ADDR
    ],
  },
});#### Claim Repayment (Self-Service)cript
const transaction = await aptos.transaction.build.simple({
  sender: account.address(),
  data: {
    function: `${MODULE_ADDRESS}::investment_pool::claim_repayment`,
    functionArguments: [
      poolId, // u64
      POOL_REGISTRY_ADDR
    ],
  },
});#### Get Pool Details
const pool = await aptos.view({
  function: `${MODULE_ADDRESS}::investment_pool::get_pool`,
  functionArguments: [poolId, POOL_REGISTRY_ADDR],
});
// Returns: (u64, u64, u64, u8, u64, u64, address)
// [pool_id, target_amount, current_total, status, interest_rate, duration, borrower]#### Get Investor Portfolio
const portfolio = await aptos.view({
  function: `${MODULE_ADDRESS}::investment_pool::get_investor_portfolio`,
  functionArguments: [investorAddress, POOL_REGISTRY_ADDR],
});
// Returns: vector<PortfolioEntry>---

### 7. Governance Module

#### Create Proposalcript
const transaction = await aptos.transaction.build.simple({
  sender: account.address(),
  data: {
    function: `${MODULE_ADDRESS}::governance::create_proposal`,
    functionArguments: [
      title, // vector<u8>
      description, // vector<u8>
      threshold, // u64 (votes needed)
      votingMechanism, // u8: 0=Simple, 1=TokenWeighted, 2=Quadratic
      action, // Option<ProposalAction> - can be null
      MEMBERS_REGISTRY_ADDR,
      CONTRACT_ADDRESS, // token_admin_addr
      GOVERNANCE_ADDR
    ],
  },
});#### Votecript
const transaction = await aptos.transaction.build.simple({
  sender: account.address(),
  data: {
    function: `${MODULE_ADDRESS}::governance::vote`,
    functionArguments: [
      proposalId, // u64
      choice, // u8: 0=Yes, 1=No, 2=Abstain
      GOVERNANCE_ADDR,
      MEMBERS_REGISTRY_ADDR,
      CONTRACT_ADDRESS // token_admin_addr
    ],
  },
});#### Get Proposal
const proposal = await aptos.view({
  function: `${MODULE_ADDRESS}::governance::get_proposal`,
  functionArguments: [proposalId, GOVERNANCE_ADDR],
});
// Returns: (address, vector<u8>, u8, u64, u64, u64, u64, u8)
// [proposer, title, status, votes_yes, votes_no, votes_abstain, threshold, voting_mechanism]---

### 8. Rewards Module

#### Stake Tokenscript
const transaction = await aptos.transaction.build.simple({
  sender: account.address(),
  data: {
    function: `${MODULE_ADDRESS}::rewards::stake`,
    functionArguments: [
      poolId, // u64
      amount, // u64
      POOL_REGISTRY_ADDR
    ],
  },
});#### Claim Rewards (Self-Service)cript
const transaction = await aptos.transaction.build.simple({
  sender: account.address(),
  data: {
    function: `${MODULE_ADDRESS}::rewards::claim_rewards`,
    functionArguments: [
      poolId, // u64
      POOL_REGISTRY_ADDR
    ],
  },
});#### Unstake (Self-Service)cript
const transaction = await aptos.transaction.build.simple({
  sender: account.address(),
  data: {
    function: `${MODULE_ADDRESS}::rewards::unstake`,
    functionArguments: [
      poolId, // u64
      amount, // u64
      POOL_REGISTRY_ADDR
    ],
  },
});#### Get Pending Rewardsypescript
const rewards = await aptos.view({
  function: `${MODULE_ADDRESS}::rewards::get_pending_rewards`,
  functionArguments: [userAddress, poolId, POOL_REGISTRY_ADDR],
});
---

## Status Enums

### Pool Statust
enum PoolStatus {
  Pending = 0,
  Active = 1,
  Funded = 2,
  Completed = 3,
  Defaulted = 4
}### Proposal Status
enum ProposalStatus {
  Pending = 0,
  Active = 1,
  Passed = 2,
  Rejected = 3,
  Executed = 4
}### Request Status
enum RequestStatus {
  Pending = 0,
  Approved = 1,
  Rejected = 2
}### Voting Mechanismript
enum VotingMechanism {
  Simple = 0,
  TokenWeighted = 1,
  Quadratic = 2,
  Conviction = 3
}---

## Error Handling

Common error codes:
- `E_NOT_ADMIN` (1): Caller lacks admin permissions
- `E_NOT_MEMBER` (2): Address not registered as member
- `E_NOT_WHITELISTED` (3): Address not in compliance whitelist
- `E_INVALID_REGISTRY` (4): Registry address invalid
- `E_ZERO_AMOUNT` (5): Amount must be greater than zero
- `E_INSUFFICIENT_BALANCE` (6): Insufficient balance
ypescript
try {
  const transaction = await aptos.transaction.build.simple({...});
  const pendingTxn = await aptos.signAndSubmitTransaction({...});
  await aptos.waitForTransaction({ transactionHash: pendingTxn.hash });
} catch (error) {
  // Check for Move abort errors
  if (error.message.includes("Move abort")) {
    const errorCode = extractErrorCode(error.message);
    // Handle specific error codes
  }
}---

## Events

All modules emit events. Listen using:
ipt
// Using Aptos Indexer or GraphQL
const events = await aptos.getEventsByEventHandle({
  eventHandleStruct: `${MODULE_ADDRESS}::treasury::Treasury`,
  fieldName: "deposit_events",
  limit: 10,
});Key event types:
- `DepositEvent`, `WithdrawalEvent` (Treasury)
- `RequestCreatedEvent`, `RequestApprovedEvent` (TimeBank)
- `ProposalCreatedEvent`, `VoteCastEvent` (Governance)
- `PoolCreatedEvent`, `InvestmentEvent` (Investment Pool)

---

## Important Notes

1. **Self-Service Withdrawals**: `withdraw()`, `claim_repayment()`, `claim_rewards()`, and `unstake()` are self-service - no admin signer needed.

2. **FA Token Balances**: Always pass `admin_addr` when checking FA token balances (TimeToken, Community Token).

3. **KYC Required**: Financial operations (deposits, investments) require whitelisted addresses.

4. **Role-Based Access**: Check user role before allowing operations.

5. **Gas Estimation**: Use `simulateTransaction` before submitting:
const simulation = await aptos.transaction.simulate.simple({
  signerPublicKey: account.publicKey,
  transaction: transaction,
});6. **Primary Store**: FA tokens require users to have a primary fungible store. The SDK handles this automatically, but ensure users have initialized their account.

---

## Example: Complete User Flow

// 1. Check if user is member
const isMember = await aptos.view({
  function: `${MODULE_ADDRESS}::members::is_member_with_registry`,
  functionArguments: [userAddress, MEMBERS_REGISTRY_ADDR],
});

// 2. Check KYC status
const isKYC = await aptos.view({
  function: `${MODULE_ADDRESS}::compliance::is_whitelisted`,
  functionArguments: [userAddress, COMPLIANCE_REGISTRY_ADDR],
});

// 3. Deposit to treasury (if member + KYC)
if (isMember && isKYC) {
  const transaction = await aptos.transaction.build.simple({
    sender: account.address(),
    data: {
      function: `${MODULE_ADDRESS}::treasury::deposit`,
      functionArguments: [
        amount,
        TREASURY_ADDR,
        MEMBERS_REGISTRY_ADDR,
        COMPLIANCE_REGISTRY_ADDR
      ],
    },
  });
  
  const pendingTxn = await aptos.signAndSubmitTransaction({
    signer: account,
    transaction,
  });
  
  await aptos.waitForTransaction({ 
    transactionHash: pendingTxn.hash 
  });
}

// 4. Check balance
const balance = await aptos.view({
  function: `${MODULE_ADDRESS}::treasury::get_balance`,
  functionArguments: [userAddress, TREASURY_ADDR],
});---

## Testing

Use Aptos Testnet faucet: https://faucet.testnet.aptoslabs.com/

Always test with small amounts first and verify transactions on the explorer before production use.