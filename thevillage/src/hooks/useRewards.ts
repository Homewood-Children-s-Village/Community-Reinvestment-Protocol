"use client";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { 
  getPendingRewards, 
  buildStakeTx, 
  buildClaimRewardsTx, 
  buildUnstakeTx 
} from "@/lib/aptos";
import { queryKeys } from "@/providers/QueryProvider";
import { useToast } from "@/components/ui/use-toast";

/**
 * Hook to get pending rewards for a specific pool
 */
export function usePendingRewards(poolId: number) {
  const { account, connected } = useWallet();

  return useQuery({
    queryKey: queryKeys.rewards.pending(account?.address || "", poolId),
    queryFn: () => getPendingRewards(account!.address, poolId),
    enabled: connected && !!account?.address && poolId > 0,
    staleTime: 30 * 1000, // 30 seconds
  });
}

/**
 * Hook to stake tokens in a pool
 */
export function useStake() {
  const { signAndSubmitTransaction, account } = useWallet();
  const queryClient = useQueryClient();
  const { toast } = useToast();

  return useMutation({
    mutationFn: async ({ poolId, amount }: { poolId: number; amount: number }) => {
      if (!account) throw new Error("Wallet not connected");

      const payload = buildStakeTx(poolId, amount);
      const response = await signAndSubmitTransaction({
        data: payload,
      });

      return response;
    },
    onSuccess: (_, variables) => {
      toast({
        title: "Stake Successful",
        description: `Staked ${variables.amount} tokens in pool #${variables.poolId}.`,
      });
      // Invalidate rewards and balance queries
      queryClient.invalidateQueries({ queryKey: queryKeys.rewards.all });
      queryClient.invalidateQueries({ queryKey: queryKeys.user.timeTokenBalance(account?.address || "") });
    },
    onError: (error: Error) => {
      toast({
        title: "Stake Failed",
        description: error.message,
        variant: "destructive",
      });
    },
  });
}

/**
 * Hook to claim rewards from a pool
 */
export function useClaimRewards() {
  const { signAndSubmitTransaction, account } = useWallet();
  const queryClient = useQueryClient();
  const { toast } = useToast();

  return useMutation({
    mutationFn: async (poolId: number) => {
      if (!account) throw new Error("Wallet not connected");

      const payload = buildClaimRewardsTx(poolId);
      const response = await signAndSubmitTransaction({
        data: payload,
      });

      return response;
    },
    onSuccess: (_, poolId) => {
      toast({
        title: "Rewards Claimed",
        description: `Successfully claimed rewards from pool #${poolId}.`,
      });
      // Invalidate rewards and balance queries
      queryClient.invalidateQueries({ queryKey: queryKeys.rewards.all });
      queryClient.invalidateQueries({ queryKey: queryKeys.user.timeTokenBalance(account?.address || "") });
    },
    onError: (error: Error) => {
      toast({
        title: "Claim Failed",
        description: error.message,
        variant: "destructive",
      });
    },
  });
}

/**
 * Hook to unstake tokens from a pool
 */
export function useUnstake() {
  const { signAndSubmitTransaction, account } = useWallet();
  const queryClient = useQueryClient();
  const { toast } = useToast();

  return useMutation({
    mutationFn: async ({ poolId, amount }: { poolId: number; amount: number }) => {
      if (!account) throw new Error("Wallet not connected");

      const payload = buildUnstakeTx(poolId, amount);
      const response = await signAndSubmitTransaction({
        data: payload,
      });

      return response;
    },
    onSuccess: (_, variables) => {
      toast({
        title: "Unstake Successful",
        description: `Unstaked ${variables.amount} tokens from pool #${variables.poolId}.`,
      });
      // Invalidate rewards and balance queries
      queryClient.invalidateQueries({ queryKey: queryKeys.rewards.all });
      queryClient.invalidateQueries({ queryKey: queryKeys.user.timeTokenBalance(account?.address || "") });
    },
    onError: (error: Error) => {
      toast({
        title: "Unstake Failed",
        description: error.message,
        variant: "destructive",
      });
    },
  });
}

/**
 * Combined Rewards hook
 */
export function useRewards() {
  const { account, connected } = useWallet();
  const stake = useStake();
  const claimRewards = useClaimRewards();
  const unstake = useUnstake();

  return {
    address: account?.address,
    connected,
    stake: stake.mutate,
    claimRewards: claimRewards.mutate,
    unstake: unstake.mutate,
    isStaking: stake.isPending,
    isClaiming: claimRewards.isPending,
    isUnstaking: unstake.isPending,
  };
}

