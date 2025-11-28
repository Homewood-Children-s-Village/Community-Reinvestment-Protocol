"use client";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { getTimeTokenBalance, buildTransferTimeTokenTx } from "@/lib/aptos";
import { queryKeys } from "@/providers/QueryProvider";
import { useToast } from "@/components/ui/use-toast";

/**
 * Hook to get the Time Token balance for the connected wallet
 */
export function useTimeTokenBalance() {
  const { account, connected } = useWallet();

  return useQuery({
    queryKey: queryKeys.user.timeTokenBalance(account?.address || ""),
    queryFn: () => getTimeTokenBalance(account!.address),
    enabled: connected && !!account?.address,
    staleTime: 30 * 1000, // 30 seconds
  });
}

/**
 * Hook to get Time Token balance for any address
 */
export function useTimeTokenBalanceOf(address: string | undefined) {
  return useQuery({
    queryKey: queryKeys.user.timeTokenBalance(address || ""),
    queryFn: () => getTimeTokenBalance(address!),
    enabled: !!address,
    staleTime: 30 * 1000, // 30 seconds
  });
}

/**
 * Hook to transfer Time Tokens
 */
export function useTransferTimeToken() {
  const { signAndSubmitTransaction, account } = useWallet();
  const queryClient = useQueryClient();
  const { toast } = useToast();

  return useMutation({
    mutationFn: async ({ recipient, amount }: { recipient: string; amount: number }) => {
      if (!account) throw new Error("Wallet not connected");

      const payload = buildTransferTimeTokenTx(recipient, amount);
      const response = await signAndSubmitTransaction({
        data: payload,
      });

      return response;
    },
    onSuccess: (_, variables) => {
      toast({
        title: "Transfer Successful",
        description: `Transferred ${variables.amount} Time Dollars to ${variables.recipient.slice(0, 10)}...`,
      });
      // Invalidate balance queries
      queryClient.invalidateQueries({ queryKey: queryKeys.user.timeTokenBalance(account?.address || "") });
      queryClient.invalidateQueries({ queryKey: queryKeys.user.timeTokenBalance(variables.recipient) });
    },
    onError: (error: Error) => {
      toast({
        title: "Transfer Failed",
        description: error.message,
        variant: "destructive",
      });
    },
  });
}

/**
 * Combined Time Token hook
 */
export function useTimeToken() {
  const { account, connected } = useWallet();
  const { data: balance, isLoading, refetch } = useTimeTokenBalance();
  const transfer = useTransferTimeToken();

  return {
    address: account?.address,
    connected,
    balance: balance ?? 0,
    isLoading,
    refetch,
    transfer: transfer.mutate,
    isTransferring: transfer.isPending,
  };
}

