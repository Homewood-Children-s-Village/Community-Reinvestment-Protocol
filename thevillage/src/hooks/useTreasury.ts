"use client";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { getTreasuryBalance, buildDepositTx, buildWithdrawTx } from "@/lib/aptos";
import { queryKeys } from "@/providers/QueryProvider";
import { useToast } from "@/components/ui/use-toast";
import { octasToApt, aptToOctas } from "@/lib/config";

/**
 * Hook to get the Treasury balance for the connected wallet
 */
export function useTreasuryBalance() {
  const { account, connected } = useWallet();

  return useQuery({
    queryKey: queryKeys.user.treasuryBalance(account?.address || ""),
    queryFn: () => getTreasuryBalance(account!.address),
    enabled: connected && !!account?.address,
    staleTime: 30 * 1000, // 30 seconds
  });
}

/**
 * Hook to deposit to treasury
 */
export function useDeposit() {
  const { signAndSubmitTransaction, account } = useWallet();
  const queryClient = useQueryClient();
  const { toast } = useToast();

  return useMutation({
    mutationFn: async (amountInApt: number) => {
      if (!account) throw new Error("Wallet not connected");

      const amountInOctas = aptToOctas(amountInApt);
      const payload = buildDepositTx(amountInOctas);
      const response = await signAndSubmitTransaction({
        data: payload,
      });

      return response;
    },
    onSuccess: (_, amountInApt) => {
      toast({
        title: "Deposit Successful",
        description: `Deposited ${amountInApt} APT to your treasury account.`,
      });
      // Invalidate balance queries
      queryClient.invalidateQueries({ queryKey: queryKeys.user.treasuryBalance(account?.address || "") });
      queryClient.invalidateQueries({ queryKey: queryKeys.treasury.all });
    },
    onError: (error: Error) => {
      toast({
        title: "Deposit Failed",
        description: error.message,
        variant: "destructive",
      });
    },
  });
}

/**
 * Hook to withdraw from treasury
 */
export function useWithdraw() {
  const { signAndSubmitTransaction, account } = useWallet();
  const queryClient = useQueryClient();
  const { toast } = useToast();

  return useMutation({
    mutationFn: async (amountInApt: number) => {
      if (!account) throw new Error("Wallet not connected");

      const amountInOctas = aptToOctas(amountInApt);
      const payload = buildWithdrawTx(amountInOctas);
      const response = await signAndSubmitTransaction({
        data: payload,
      });

      return response;
    },
    onSuccess: (_, amountInApt) => {
      toast({
        title: "Withdrawal Successful",
        description: `Withdrew ${amountInApt} APT from your treasury account.`,
      });
      // Invalidate balance queries
      queryClient.invalidateQueries({ queryKey: queryKeys.user.treasuryBalance(account?.address || "") });
      queryClient.invalidateQueries({ queryKey: queryKeys.treasury.all });
    },
    onError: (error: Error) => {
      toast({
        title: "Withdrawal Failed",
        description: error.message,
        variant: "destructive",
      });
    },
  });
}

/**
 * Combined Treasury hook
 */
export function useTreasury() {
  const { account, connected } = useWallet();
  const { data: balanceInOctas, isLoading, refetch } = useTreasuryBalance();
  const deposit = useDeposit();
  const withdraw = useWithdraw();

  return {
    address: account?.address,
    connected,
    balanceInOctas: balanceInOctas ?? 0,
    balanceInApt: balanceInOctas ? octasToApt(balanceInOctas) : 0,
    isLoading,
    refetch,
    deposit: deposit.mutate,
    withdraw: withdraw.mutate,
    isDepositing: deposit.isPending,
    isWithdrawing: withdraw.isPending,
  };
}

