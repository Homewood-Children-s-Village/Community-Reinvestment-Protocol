"use client";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { 
  getTimeBankRequest, 
  buildCreateTimeBankRequestTx, 
  buildApproveTimeBankRequestTx 
} from "@/lib/aptos";
import { queryKeys } from "@/providers/QueryProvider";
import { useToast } from "@/components/ui/use-toast";
import { TimeBankRequest } from "@/types/contract";

/**
 * Hook to get a specific timebank request
 */
export function useTimeBankRequest(requestId: number) {
  return useQuery({
    queryKey: queryKeys.timebank.request(requestId),
    queryFn: () => getTimeBankRequest(requestId),
    enabled: requestId > 0,
    staleTime: 30 * 1000, // 30 seconds
  });
}

/**
 * Hook to create a new service hours request
 */
export function useCreateRequest() {
  const { signAndSubmitTransaction, account } = useWallet();
  const queryClient = useQueryClient();
  const { toast } = useToast();

  return useMutation({
    mutationFn: async ({ hours, activityId }: { hours: number; activityId: number }) => {
      if (!account) throw new Error("Wallet not connected");

      const payload = buildCreateTimeBankRequestTx(hours, activityId);
      const response = await signAndSubmitTransaction({
        data: payload,
      });

      return response;
    },
    onSuccess: (_, variables) => {
      toast({
        title: "Request Submitted",
        description: `Your request for ${variables.hours} hour(s) has been submitted for approval.`,
      });
      // Invalidate timebank queries
      queryClient.invalidateQueries({ queryKey: queryKeys.timebank.all });
    },
    onError: (error: Error) => {
      toast({
        title: "Request Failed",
        description: error.message,
        variant: "destructive",
      });
    },
  });
}

/**
 * Hook to approve a service hours request (validator/admin only)
 */
export function useApproveRequest() {
  const { signAndSubmitTransaction, account } = useWallet();
  const queryClient = useQueryClient();
  const { toast } = useToast();

  return useMutation({
    mutationFn: async (requestId: number) => {
      if (!account) throw new Error("Wallet not connected");

      const payload = buildApproveTimeBankRequestTx(requestId);
      const response = await signAndSubmitTransaction({
        data: payload,
      });

      return response;
    },
    onSuccess: (_, requestId) => {
      toast({
        title: "Request Approved",
        description: `Request #${requestId} has been approved and Time Dollars have been minted.`,
      });
      // Invalidate timebank queries
      queryClient.invalidateQueries({ queryKey: queryKeys.timebank.all });
      // Also invalidate time token balances as they may have changed
      queryClient.invalidateQueries({ queryKey: queryKeys.user.timeTokenBalance("") });
    },
    onError: (error: Error) => {
      toast({
        title: "Approval Failed",
        description: error.message,
        variant: "destructive",
      });
    },
  });
}

/**
 * Combined TimeBank hook
 */
export function useTimeBank() {
  const { account, connected } = useWallet();
  const createRequest = useCreateRequest();
  const approveRequest = useApproveRequest();

  return {
    address: account?.address,
    connected,
    createRequest: createRequest.mutate,
    approveRequest: approveRequest.mutate,
    isCreating: createRequest.isPending,
    isApproving: approveRequest.isPending,
  };
}

