/**
 * Centralized hook exports for the Villages Finance Platform
 */

// Member hooks
export {
  useIsMember,
  useMemberRole,
  useIsAdmin,
  useIsValidator,
  useRequestMembership,
  useAcceptMembership,
  useMemberStatus,
  useMembershipRequests,
  useApproveMembershipRequest,
  useRejectMembershipRequest,
} from "./useMember";

// Compliance hooks
export {
  useIsWhitelisted,
  useWhitelistAddress,
  useComplianceStatus,
} from "./useCompliance";

// Time Token hooks
export {
  useTimeTokenBalance,
  useTimeTokenBalanceOf,
  useTransferTimeToken,
  useTimeToken,
} from "./useTimeToken";

// Treasury hooks
export {
  useTreasuryBalance,
  useDeposit,
  useWithdraw,
  useTreasury,
} from "./useTreasury";

// TimeBank hooks
export {
  useTimeBankRequest,
  useCreateRequest,
  useApproveRequest,
  useTimeBank,
} from "./useTimeBank";

// Governance hooks
export {
  useProposal,
  useCreateProposal,
  useVote,
  useGovernance,
} from "./useGovernance";

// Rewards hooks
export {
  usePendingRewards,
  useStake,
  useClaimRewards,
  useUnstake,
  useRewards,
} from "./useRewards";

