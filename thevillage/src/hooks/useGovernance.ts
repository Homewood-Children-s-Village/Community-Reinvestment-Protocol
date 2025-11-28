"use client";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { 
  getProposal, 
  buildCreateProposalTx, 
  buildVoteTx 
} from "@/lib/aptos";
import { queryKeys } from "@/providers/QueryProvider";
import { useToast } from "@/components/ui/use-toast";
import { VotingMechanism, VoteChoice, VoteChoiceLabels } from "@/types/contract";

/**
 * Hook to get a specific proposal
 */
export function useProposal(proposalId: number) {
  return useQuery({
    queryKey: queryKeys.governance.proposal(proposalId),
    queryFn: () => getProposal(proposalId),
    enabled: proposalId > 0,
    staleTime: 30 * 1000, // 30 seconds
  });
}

/**
 * Hook to create a new proposal
 */
export function useCreateProposal() {
  const { signAndSubmitTransaction, account } = useWallet();
  const queryClient = useQueryClient();
  const { toast } = useToast();

  return useMutation({
    mutationFn: async ({
      title,
      description,
      threshold,
      votingMechanism,
    }: {
      title: string;
      description: string;
      threshold: number;
      votingMechanism: VotingMechanism;
    }) => {
      if (!account) throw new Error("Wallet not connected");

      const payload = buildCreateProposalTx(title, description, threshold, votingMechanism);
      const response = await signAndSubmitTransaction({
        data: payload,
      });

      return response;
    },
    onSuccess: (_, variables) => {
      toast({
        title: "Proposal Created",
        description: `Your proposal "${variables.title}" has been submitted.`,
      });
      // Invalidate governance queries
      queryClient.invalidateQueries({ queryKey: queryKeys.governance.all });
    },
    onError: (error: Error) => {
      toast({
        title: "Proposal Creation Failed",
        description: error.message,
        variant: "destructive",
      });
    },
  });
}

/**
 * Hook to vote on a proposal
 */
export function useVote() {
  const { signAndSubmitTransaction, account } = useWallet();
  const queryClient = useQueryClient();
  const { toast } = useToast();

  return useMutation({
    mutationFn: async ({
      proposalId,
      choice,
    }: {
      proposalId: number;
      choice: VoteChoice;
    }) => {
      if (!account) throw new Error("Wallet not connected");

      const payload = buildVoteTx(proposalId, choice);
      const response = await signAndSubmitTransaction({
        data: payload,
      });

      return response;
    },
    onSuccess: (_, variables) => {
      toast({
        title: "Vote Cast",
        description: `You voted "${VoteChoiceLabels[variables.choice]}" on proposal #${variables.proposalId}.`,
      });
      // Invalidate governance queries
      queryClient.invalidateQueries({ queryKey: queryKeys.governance.proposal(variables.proposalId) });
      queryClient.invalidateQueries({ queryKey: queryKeys.governance.all });
    },
    onError: (error: Error) => {
      toast({
        title: "Vote Failed",
        description: error.message,
        variant: "destructive",
      });
    },
  });
}

/**
 * Combined Governance hook
 */
export function useGovernance() {
  const { account, connected } = useWallet();
  const createProposal = useCreateProposal();
  const vote = useVote();

  return {
    address: account?.address,
    connected,
    createProposal: createProposal.mutate,
    vote: vote.mutate,
    isCreatingProposal: createProposal.isPending,
    isVoting: vote.isPending,
  };
}

