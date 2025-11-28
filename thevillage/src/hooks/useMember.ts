"use client";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { isMember, getMemberRole, buildRequestMembershipTx, buildAcceptMembershipTx, buildApproveMembershipTx, buildRejectMembershipTx, listMembershipRequests } from "@/lib/aptos";
import { queryKeys } from "@/providers/QueryProvider";
import { Role, RoleLabels, RequestStatus } from "@/types/contract";
import { useToast } from "@/components/ui/use-toast";

/**
 * Hook to check if the connected wallet is a registered member
 */
export function useIsMember() {
  const { account, connected } = useWallet();

  return useQuery({
    queryKey: queryKeys.user.membership(account?.address || ""),
    queryFn: () => isMember(account!.address),
    enabled: connected && !!account?.address,
    staleTime: 60 * 1000, // 1 minute
  });
}

/**
 * Hook to get the role of the connected wallet
 */
export function useMemberRole() {
  const { account, connected } = useWallet();

  return useQuery({
    queryKey: queryKeys.user.role(account?.address || ""),
    queryFn: () => getMemberRole(account!.address),
    enabled: connected && !!account?.address,
    staleTime: 60 * 1000, // 1 minute
  });
}

/**
 * Hook to check if user is an admin
 */
export function useIsAdmin() {
  const { data: role, isLoading } = useMemberRole();
  return {
    isAdmin: role === Role.Admin,
    isLoading,
  };
}

/**
 * Hook to check if user is a validator
 */
export function useIsValidator() {
  const { data: role, isLoading } = useMemberRole();
  return {
    isValidator: role === Role.Validator || role === Role.Admin,
    isLoading,
  };
}

/**
 * Hook to request membership
 */
export function useRequestMembership() {
  const { signAndSubmitTransaction, account } = useWallet();
  const queryClient = useQueryClient();
  const { toast } = useToast();

  return useMutation({
    mutationFn: async ({ role, note }: { role: Role; note: string }) => {
      if (!account) throw new Error("Wallet not connected");

      const payload = buildRequestMembershipTx(role, note);
      const response = await signAndSubmitTransaction({
        data: payload,
      });

      return response;
    },
    onSuccess: (data, variables) => {
      toast({
        title: "Membership Requested",
        description: `Your request to become a ${RoleLabels[variables.role]} has been submitted.`,
      });
      // Invalidate membership queries
      queryClient.invalidateQueries({ queryKey: queryKeys.user.membership(account?.address || "") });
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
 * Hook to accept membership
 */
export function useAcceptMembership() {
  const { signAndSubmitTransaction, account } = useWallet();
  const queryClient = useQueryClient();
  const { toast } = useToast();

  return useMutation({
    mutationFn: async () => {
      if (!account) throw new Error("Wallet not connected");

      const payload = buildAcceptMembershipTx();
      const response = await signAndSubmitTransaction({
        data: payload,
      });

      return response;
    },
    onSuccess: () => {
      toast({
        title: "Membership Accepted",
        description: "You are now a registered member of The Village.",
      });
      // Invalidate membership queries
      queryClient.invalidateQueries({ queryKey: queryKeys.user.all });
    },
    onError: (error: Error) => {
      toast({
        title: "Acceptance Failed",
        description: error.message,
        variant: "destructive",
      });
    },
  });
}

/**
 * Combined hook for member status
 */
export function useMemberStatus() {
  const { account, connected } = useWallet();
  const { data: isMemberData, isLoading: isMemberLoading } = useIsMember();
  const { data: roleData, isLoading: isRoleLoading } = useMemberRole();

  return {
    address: account?.address,
    connected,
    isMember: isMemberData ?? false,
    role: roleData ?? null,
    roleLabel: roleData !== null ? RoleLabels[roleData] : null,
    isAdmin: roleData === Role.Admin,
    isValidator: roleData === Role.Validator || roleData === Role.Admin,
    isBorrower: roleData === Role.Borrower,
    isDepositor: roleData === Role.Depositor,
    isLoading: isMemberLoading || isRoleLoading,
  };
}

/**
 * Hook to list pending membership requests
 */
export function useMembershipRequests(statusFilter: RequestStatus = RequestStatus.Pending) {
  return useQuery({
    queryKey: queryKeys.membershipRequests(statusFilter),
    queryFn: () => listMembershipRequests(statusFilter),
    staleTime: 30 * 1000, // 30 seconds
    refetchInterval: 60 * 1000, // Refetch every minute
  });
}

/**
 * Hook to approve a membership request (admin or validator)
 */
export function useApproveMembershipRequest() {
  const { signAndSubmitTransaction, account } = useWallet();
  const queryClient = useQueryClient();
  const { toast } = useToast();

  return useMutation({
    mutationFn: async (requestId: number) => {
      if (!account) throw new Error("Wallet not connected");

      const payload = buildApproveMembershipTx(requestId);
      const response = await signAndSubmitTransaction({
        data: payload,
      });

      return response;
    },
    onSuccess: (_, requestId) => {
      toast({
        title: "Request Approved",
        description: `Membership request #${requestId} has been approved.`,
      });
      // Invalidate membership requests queries
      queryClient.invalidateQueries({ queryKey: ["membershipRequests"] });
      queryClient.invalidateQueries({ queryKey: queryKeys.user.all });
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
 * Hook to reject a membership request (admin or validator)
 */
export function useRejectMembershipRequest() {
  const { signAndSubmitTransaction, account } = useWallet();
  const queryClient = useQueryClient();
  const { toast } = useToast();

  return useMutation({
    mutationFn: async (requestId: number) => {
      if (!account) throw new Error("Wallet not connected");

      const payload = buildRejectMembershipTx(requestId);
      const response = await signAndSubmitTransaction({
        data: payload,
      });

      return response;
    },
    onSuccess: (_, requestId) => {
      toast({
        title: "Request Rejected",
        description: `Membership request #${requestId} has been rejected.`,
      });
      // Invalidate membership requests queries
      queryClient.invalidateQueries({ queryKey: ["membershipRequests"] });
    },
    onError: (error: Error) => {
      toast({
        title: "Rejection Failed",
        description: error.message,
        variant: "destructive",
      });
    },
  });
}

