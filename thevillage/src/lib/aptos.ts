/**
 * Aptos SDK Integration for Villages Finance Platform
 * 
 * Provides utilities for interacting with the deployed smart contracts
 */

import { Aptos, AptosConfig } from "@aptos-labs/ts-sdk";
import {
  CONTRACT_ADDRESS,
  MEMBERS_REGISTRY_ADDR,
  COMPLIANCE_REGISTRY_ADDR,
  TREASURY_ADDR,
  POOL_REGISTRY_ADDR,
  GOVERNANCE_ADDR,
  BANK_REGISTRY_ADDR,
  TOKEN_ADMIN_ADDR,
  MODULE_PATHS,
  getNetworkType,
} from "./config";
import { 
  Role, 
  RequestStatus, 
  PoolStatus, 
  ProposalStatus, 
  VotingMechanism,
  TimeBankRequest,
  InvestmentPool,
  Proposal,
  parseContractError,
} from "@/types/contract";
import { stringToBytes, bytesToString } from "./utils";

// Initialize Aptos client with testnet configuration
const config = new AptosConfig({ network: getNetworkType() });
export const aptos = new Aptos(config);

// ============================================================================
// View Functions - Members Module
// ============================================================================

/**
 * Check if an address is a registered member
 */
export async function isMember(address: string): Promise<boolean> {
  try {
    const result = await aptos.view({
      payload: {
        function: `${MODULE_PATHS.members}::is_member_with_registry`,
        functionArguments: [address, MEMBERS_REGISTRY_ADDR],
      },
    });
    return result[0] as boolean;
  } catch (error) {
    console.error("Error checking membership:", error);
    return false;
  }
}

/**
 * Get the role of a member
 * Returns null if not a member, or the role number
 */
export async function getMemberRole(address: string): Promise<Role | null> {
  try {
    const result = await aptos.view({
      payload: {
        function: `${MODULE_PATHS.members}::get_role_with_registry`,
        functionArguments: [address, MEMBERS_REGISTRY_ADDR],
      },
    });
    // Result is Option<u8>
    const roleOption = result[0] as { vec: number[] };
    if (roleOption.vec && roleOption.vec.length > 0) {
      return roleOption.vec[0] as Role;
    }
    return null;
  } catch (error) {
    console.error("Error getting member role:", error);
    return null;
  }
}

// ============================================================================
// View Functions - Compliance Module
// ============================================================================

/**
 * Check if an address is whitelisted (KYC verified)
 */
export async function isWhitelisted(address: string): Promise<boolean> {
  try {
    const result = await aptos.view({
      payload: {
        function: `${MODULE_PATHS.compliance}::is_whitelisted`,
        functionArguments: [address, COMPLIANCE_REGISTRY_ADDR],
      },
    });
    return result[0] as boolean;
  } catch (error) {
    console.error("Error checking whitelist status:", error);
    return false;
  }
}

// ============================================================================
// View Functions - TimeBank Module
// ============================================================================

/**
 * Get a time bank request by ID
 */
export async function getTimeBankRequest(requestId: number): Promise<TimeBankRequest | null> {
  try {
    const result = await aptos.view({
      payload: {
        function: `${MODULE_PATHS.timebank}::get_request`,
        functionArguments: [requestId, BANK_REGISTRY_ADDR],
      },
    });
    // Returns: (address, u64, u64, u8, u64)
    // [requester, hours, activity_id, status, created_at]
    const [requester, hours, activityId, status, createdAt] = result as [string, string, string, number, string];
    return {
      id: requestId,
      requester,
      hours: parseInt(hours),
      activityId: parseInt(activityId),
      status: status as RequestStatus,
      createdAt: parseInt(createdAt),
    };
  } catch (error) {
    console.error("Error getting timebank request:", error);
    return null;
  }
}

// ============================================================================
// View Functions - Time Token Module
// ============================================================================

/**
 * Get Time Token balance for an address
 */
export async function getTimeTokenBalance(address: string): Promise<number> {
  try {
    const result = await aptos.view({
      payload: {
        function: `${MODULE_PATHS.time_token}::balance`,
        functionArguments: [address, TOKEN_ADMIN_ADDR],
      },
    });
    return parseInt(result[0] as string);
  } catch (error) {
    console.error("Error getting time token balance:", error);
    return 0;
  }
}

// ============================================================================
// View Functions - Treasury Module
// ============================================================================

/**
 * Get treasury balance for an address
 */
export async function getTreasuryBalance(address: string): Promise<number> {
  try {
    const result = await aptos.view({
      payload: {
        function: `${MODULE_PATHS.treasury}::get_balance`,
        functionArguments: [address, TREASURY_ADDR],
      },
    });
    return parseInt(result[0] as string);
  } catch (error) {
    console.error("Error getting treasury balance:", error);
    return 0;
  }
}

// ============================================================================
// View Functions - Investment Pool Module
// ============================================================================

/**
 * Get investment pool details by ID
 */
export async function getInvestmentPool(poolId: number): Promise<InvestmentPool | null> {
  try {
    const result = await aptos.view({
      payload: {
        function: `${MODULE_PATHS.investment_pool}::get_pool`,
        functionArguments: [poolId, POOL_REGISTRY_ADDR],
      },
    });
    // Returns: (u64, u64, u64, u8, u64, u64, address)
    // [pool_id, target_amount, current_total, status, interest_rate, duration, borrower]
    const [id, targetAmount, currentTotal, status, interestRate, duration, borrower] = result as [
      string, string, string, number, string, string, string
    ];
    return {
      id: parseInt(id),
      borrower,
      targetAmount: parseInt(targetAmount),
      currentTotal: parseInt(currentTotal),
      status: status as PoolStatus,
      interestRate: parseInt(interestRate),
      duration: parseInt(duration),
      createdAt: 0, // Not returned by view function
    };
  } catch (error) {
    console.error("Error getting investment pool:", error);
    return null;
  }
}

// ============================================================================
// View Functions - Governance Module
// ============================================================================

/**
 * Get proposal details by ID
 */
export async function getProposal(proposalId: number): Promise<Proposal | null> {
  try {
    const result = await aptos.view({
      payload: {
        function: `${MODULE_PATHS.governance}::get_proposal`,
        functionArguments: [proposalId, GOVERNANCE_ADDR],
      },
    });
    // Returns: (address, vector<u8>, u8, u64, u64, u64, u64, u8)
    // [proposer, title, status, votes_yes, votes_no, votes_abstain, threshold, voting_mechanism]
    const [proposer, titleBytes, status, votesYes, votesNo, votesAbstain, threshold, votingMechanism] = result as [
      string, number[], number, string, string, string, string, number
    ];
    return {
      id: proposalId,
      proposer,
      title: bytesToString(titleBytes),
      description: "", // Not returned by view function
      status: status as ProposalStatus,
      votesYes: parseInt(votesYes),
      votesNo: parseInt(votesNo),
      votesAbstain: parseInt(votesAbstain),
      threshold: parseInt(threshold),
      votingMechanism: votingMechanism as VotingMechanism,
      createdAt: 0, // Not returned by view function
      endsAt: 0, // Not returned by view function
    };
  } catch (error) {
    console.error("Error getting proposal:", error);
    return null;
  }
}

// ============================================================================
// View Functions - Rewards Module
// ============================================================================

/**
 * Get pending rewards for a user in a pool
 */
export async function getPendingRewards(address: string, poolId: number): Promise<number> {
  try {
    const result = await aptos.view({
      payload: {
        function: `${MODULE_PATHS.rewards}::get_pending_rewards`,
        functionArguments: [address, poolId, POOL_REGISTRY_ADDR],
      },
    });
    return parseInt(result[0] as string);
  } catch (error) {
    console.error("Error getting pending rewards:", error);
    return 0;
  }
}

// ============================================================================
// Transaction Builders
// ============================================================================

/**
 * Build transaction data for requesting membership
 * Move function signature: request_membership(applicant, registry_addr, desired_role, note)
 */
export function buildRequestMembershipTx(role: Role, note: string) {
  return {
    function: `${MODULE_PATHS.members}::request_membership` as `${string}::${string}::${string}`,
    functionArguments: [
      MEMBERS_REGISTRY_ADDR, // registry_addr (first)
      role, // desired_role (second) - u8
      Array.from(stringToBytes(note)), // note (third) - vector<u8>
    ],
  };
}

/**
 * Build transaction data for accepting membership
 */
export function buildAcceptMembershipTx() {
  return {
    function: `${MODULE_PATHS.members}::accept_membership` as `${string}::${string}::${string}`,
    functionArguments: [MEMBERS_REGISTRY_ADDR],
  };
}

/**
 * Build transaction data for creating a timebank request
 */
export function buildCreateTimeBankRequestTx(hours: number, activityId: number) {
  return {
    function: `${MODULE_PATHS.timebank}::create_request` as `${string}::${string}::${string}`,
    functionArguments: [
      hours,
      activityId,
      MEMBERS_REGISTRY_ADDR,
      BANK_REGISTRY_ADDR,
    ],
  };
}

/**
 * Build transaction data for approving a timebank request
 */
export function buildApproveTimeBankRequestTx(requestId: number) {
  return {
    function: `${MODULE_PATHS.timebank}::approve_request` as `${string}::${string}::${string}`,
    functionArguments: [
      requestId,
      MEMBERS_REGISTRY_ADDR,
      COMPLIANCE_REGISTRY_ADDR,
      BANK_REGISTRY_ADDR,
      TOKEN_ADMIN_ADDR,
    ],
  };
}

/**
 * Build transaction data for depositing to treasury
 */
export function buildDepositTx(amount: number) {
  return {
    function: `${MODULE_PATHS.treasury}::deposit` as `${string}::${string}::${string}`,
    functionArguments: [
      amount,
      TREASURY_ADDR,
      MEMBERS_REGISTRY_ADDR,
      COMPLIANCE_REGISTRY_ADDR,
    ],
  };
}

/**
 * Build transaction data for withdrawing from treasury
 */
export function buildWithdrawTx(amount: number) {
  return {
    function: `${MODULE_PATHS.treasury}::withdraw` as `${string}::${string}::${string}`,
    functionArguments: [amount, TREASURY_ADDR],
  };
}

/**
 * Build transaction data for creating a governance proposal
 */
export function buildCreateProposalTx(
  title: string,
  description: string,
  threshold: number,
  votingMechanism: VotingMechanism
) {
  return {
    function: `${MODULE_PATHS.governance}::create_proposal` as `${string}::${string}::${string}`,
    functionArguments: [
      Array.from(stringToBytes(title)),
      Array.from(stringToBytes(description)),
      threshold,
      votingMechanism,
      null, // action - optional
      MEMBERS_REGISTRY_ADDR,
      TOKEN_ADMIN_ADDR,
      GOVERNANCE_ADDR,
    ],
  };
}

/**
 * Build transaction data for voting on a proposal
 */
export function buildVoteTx(proposalId: number, choice: number) {
  return {
    function: `${MODULE_PATHS.governance}::vote` as `${string}::${string}::${string}`,
    functionArguments: [
      proposalId,
      choice,
      GOVERNANCE_ADDR,
      MEMBERS_REGISTRY_ADDR,
      TOKEN_ADMIN_ADDR,
    ],
  };
}

/**
 * Build transaction data for staking tokens
 */
export function buildStakeTx(poolId: number, amount: number) {
  return {
    function: `${MODULE_PATHS.rewards}::stake` as `${string}::${string}::${string}`,
    functionArguments: [poolId, amount, POOL_REGISTRY_ADDR],
  };
}

/**
 * Build transaction data for claiming rewards
 */
export function buildClaimRewardsTx(poolId: number) {
  return {
    function: `${MODULE_PATHS.rewards}::claim_rewards` as `${string}::${string}::${string}`,
    functionArguments: [poolId, POOL_REGISTRY_ADDR],
  };
}

/**
 * Build transaction data for unstaking tokens
 */
export function buildUnstakeTx(poolId: number, amount: number) {
  return {
    function: `${MODULE_PATHS.rewards}::unstake` as `${string}::${string}::${string}`,
    functionArguments: [poolId, amount, POOL_REGISTRY_ADDR],
  };
}

/**
 * Build transaction data for transferring time tokens
 */
export function buildTransferTimeTokenTx(recipient: string, amount: number) {
  return {
    function: `${MODULE_PATHS.time_token}::transfer` as `${string}::${string}::${string}`,
    functionArguments: [recipient, amount, TOKEN_ADMIN_ADDR],
  };
}

/**
 * Build transaction data for whitelisting an address (admin only)
 */
export function buildWhitelistAddressTx(addressToWhitelist: string) {
  return {
    function: `${MODULE_PATHS.compliance}::whitelist_address` as `${string}::${string}::${string}`,
    functionArguments: [addressToWhitelist, COMPLIANCE_REGISTRY_ADDR],
  };
}

/**
 * Build transaction data for approving a membership request (admin or validator)
 */
export function buildApproveMembershipTx(requestId: number) {
  return {
    function: `${MODULE_PATHS.members}::approve_membership` as `${string}::${string}::${string}`,
    functionArguments: [requestId, MEMBERS_REGISTRY_ADDR],
  };
}

/**
 * Build transaction data for rejecting a membership request (admin or validator)
 */
export function buildRejectMembershipTx(requestId: number) {
  return {
    function: `${MODULE_PATHS.members}::reject_membership` as `${string}::${string}::${string}`,
    functionArguments: [requestId, MEMBERS_REGISTRY_ADDR],
  };
}

/**
 * List pending membership requests
 */
export async function listMembershipRequests(statusFilter: number = 0): Promise<number[]> {
  try {
    const result = await aptos.view({
      payload: {
        function: `${MODULE_PATHS.members}::list_membership_requests`,
        functionArguments: [MEMBERS_REGISTRY_ADDR, statusFilter], // 0 = Pending, 255 = All
      },
    });
    return (result[0] as number[]) || [];
  } catch (error) {
    console.error("Error listing membership requests:", error);
    return [];
  }
}

// Export error parser for use in components
export { parseContractError };

