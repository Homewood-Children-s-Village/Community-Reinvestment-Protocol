/**
 * Type definitions for Villages Finance Move contracts
 * These map to the on-chain struct types and enums
 */

// ============================================================================
// Role Types
// ============================================================================

export enum Role {
  Admin = 0,
  Borrower = 1,
  Depositor = 2,
  Validator = 3,
}

export const RoleLabels: Record<Role, string> = {
  [Role.Admin]: "Admin",
  [Role.Borrower]: "Project Initiator",
  [Role.Depositor]: "Investor/Contributor",
  [Role.Validator]: "Validator/Staff",
};

export const RoleDescriptions: Record<Role, string> = {
  [Role.Admin]: "Full platform administration access",
  [Role.Borrower]: "Can initiate projects, receive loans and participate in investment pools",
  [Role.Depositor]: "Can deposit funds, invest in projects, and earn returns",
  [Role.Validator]: "Can approve volunteer hours, validate service requests, and review membership applications",
};

// ============================================================================
// Pool Status Types
// ============================================================================

export enum PoolStatus {
  Pending = 0,
  Active = 1,
  Funded = 2,
  Completed = 3,
  Defaulted = 4,
}

export const PoolStatusLabels: Record<PoolStatus, string> = {
  [PoolStatus.Pending]: "Pending",
  [PoolStatus.Active]: "Active",
  [PoolStatus.Funded]: "Funded",
  [PoolStatus.Completed]: "Completed",
  [PoolStatus.Defaulted]: "Defaulted",
};

export const PoolStatusColors: Record<PoolStatus, string> = {
  [PoolStatus.Pending]: "warning",
  [PoolStatus.Active]: "secondary",
  [PoolStatus.Funded]: "success",
  [PoolStatus.Completed]: "success",
  [PoolStatus.Defaulted]: "error",
};

// ============================================================================
// Proposal Status Types
// ============================================================================

export enum ProposalStatus {
  Pending = 0,
  Active = 1,
  Passed = 2,
  Rejected = 3,
  Executed = 4,
}

export const ProposalStatusLabels: Record<ProposalStatus, string> = {
  [ProposalStatus.Pending]: "Pending",
  [ProposalStatus.Active]: "Active",
  [ProposalStatus.Passed]: "Passed",
  [ProposalStatus.Rejected]: "Rejected",
  [ProposalStatus.Executed]: "Executed",
};

export const ProposalStatusColors: Record<ProposalStatus, string> = {
  [ProposalStatus.Pending]: "warning",
  [ProposalStatus.Active]: "secondary",
  [ProposalStatus.Passed]: "success",
  [ProposalStatus.Rejected]: "error",
  [ProposalStatus.Executed]: "primary",
};

// ============================================================================
// Request Status Types (TimeBank)
// ============================================================================

export enum RequestStatus {
  Pending = 0,
  Approved = 1,
  Rejected = 2,
}

export const RequestStatusLabels: Record<RequestStatus, string> = {
  [RequestStatus.Pending]: "Pending",
  [RequestStatus.Approved]: "Approved",
  [RequestStatus.Rejected]: "Rejected",
};

export const RequestStatusColors: Record<RequestStatus, string> = {
  [RequestStatus.Pending]: "warning",
  [RequestStatus.Approved]: "success",
  [RequestStatus.Rejected]: "error",
};

// ============================================================================
// Voting Mechanism Types
// ============================================================================

export enum VotingMechanism {
  Simple = 0,
  TokenWeighted = 1,
  Quadratic = 2,
  Conviction = 3,
}

export const VotingMechanismLabels: Record<VotingMechanism, string> = {
  [VotingMechanism.Simple]: "Simple Majority",
  [VotingMechanism.TokenWeighted]: "Token Weighted",
  [VotingMechanism.Quadratic]: "Quadratic Voting",
  [VotingMechanism.Conviction]: "Conviction Voting",
};

export const VotingMechanismDescriptions: Record<VotingMechanism, string> = {
  [VotingMechanism.Simple]: "One member, one vote. Simple majority wins.",
  [VotingMechanism.TokenWeighted]: "Votes are weighted by token balance. More tokens = more voting power.",
  [VotingMechanism.Quadratic]: "Voting power grows with square root of tokens. Reduces whale influence.",
  [VotingMechanism.Conviction]: "Votes gain strength over time. Rewards long-term commitment.",
};

// ============================================================================
// Vote Choice Types
// ============================================================================

export enum VoteChoice {
  Yes = 0,
  No = 1,
  Abstain = 2,
}

export const VoteChoiceLabels: Record<VoteChoice, string> = {
  [VoteChoice.Yes]: "Yes",
  [VoteChoice.No]: "No",
  [VoteChoice.Abstain]: "Abstain",
};

// ============================================================================
// Data Types
// ============================================================================

export interface Member {
  address: string;
  role: Role;
  joinedAt: number;
  isActive: boolean;
}

export interface MembershipRequest {
  requester: string;
  role: Role;
  note: string;
  createdAt: number;
  status: RequestStatus;
}

export interface TimeBankRequest {
  id: number;
  requester: string;
  hours: number;
  activityId: number;
  status: RequestStatus;
  createdAt: number;
}

export interface InvestmentPool {
  id: number;
  borrower: string;
  targetAmount: number;
  currentTotal: number;
  status: PoolStatus;
  interestRate: number; // basis points (500 = 5%)
  duration: number; // seconds
  createdAt: number;
}

export interface PortfolioEntry {
  poolId: number;
  amount: number;
  shares: number;
}

export interface Proposal {
  id: number;
  proposer: string;
  title: string;
  description: string;
  status: ProposalStatus;
  votesYes: number;
  votesNo: number;
  votesAbstain: number;
  threshold: number;
  votingMechanism: VotingMechanism;
  createdAt: number;
  endsAt: number;
}

export interface Project {
  id: number;
  name: string;
  description: string;
  targetFunding: number;
  currentFunding: number;
  targetHours: number;
  currentHours: number;
  status: PoolStatus;
  createdAt: number;
  milestones: Milestone[];
}

export interface Milestone {
  id: number;
  description: string;
  isCompleted: boolean;
  completedAt?: number;
}

export interface StakeInfo {
  poolId: number;
  amount: number;
  pendingRewards: number;
  stakedAt: number;
}

// ============================================================================
// Error Types
// ============================================================================

export enum ContractError {
  E_NOT_ADMIN = 1,
  E_NOT_MEMBER = 2,
  E_NOT_WHITELISTED = 3,
  E_INVALID_REGISTRY = 4,
  E_ZERO_AMOUNT = 5,
  E_INSUFFICIENT_BALANCE = 6,
  E_ALREADY_MEMBER = 7,
  E_NOT_VALIDATOR = 8,
  E_ALREADY_VOTED = 9,
  E_PROPOSAL_NOT_ACTIVE = 10,
  E_POOL_NOT_ACTIVE = 11,
  E_POOL_FULL = 12,
}

export const ContractErrorMessages: Record<ContractError, string> = {
  [ContractError.E_NOT_ADMIN]: "You don't have admin permissions to perform this action.",
  [ContractError.E_NOT_MEMBER]: "You must be a registered member to perform this action.",
  [ContractError.E_NOT_WHITELISTED]: "Your address must be whitelisted (KYC verified) to perform this action.",
  [ContractError.E_INVALID_REGISTRY]: "The registry address is invalid.",
  [ContractError.E_ZERO_AMOUNT]: "The amount must be greater than zero.",
  [ContractError.E_INSUFFICIENT_BALANCE]: "You don't have enough balance to complete this transaction.",
  [ContractError.E_ALREADY_MEMBER]: "This address is already a registered member.",
  [ContractError.E_NOT_VALIDATOR]: "You must be a validator to approve requests.",
  [ContractError.E_ALREADY_VOTED]: "You have already voted on this proposal.",
  [ContractError.E_PROPOSAL_NOT_ACTIVE]: "This proposal is no longer active.",
  [ContractError.E_POOL_NOT_ACTIVE]: "This investment pool is not currently active.",
  [ContractError.E_POOL_FULL]: "This investment pool has reached its funding target.",
};

/**
 * Parses a Move abort error message and returns a user-friendly message
 */
export function parseContractError(errorMessage: string): string {
  const match = errorMessage.match(/Move abort.*?(\d+)/);
  if (match) {
    const errorCode = parseInt(match[1], 10) as ContractError;
    return ContractErrorMessages[errorCode] || `Transaction failed with error code ${errorCode}`;
  }
  
  if (errorMessage.includes("INSUFFICIENT_BALANCE")) {
    return ContractErrorMessages[ContractError.E_INSUFFICIENT_BALANCE];
  }
  
  if (errorMessage.includes("rejected")) {
    return "Transaction was rejected by the wallet.";
  }
  
  return "An unexpected error occurred. Please try again.";
}

