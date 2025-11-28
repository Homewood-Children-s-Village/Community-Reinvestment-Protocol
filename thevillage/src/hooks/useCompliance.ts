"use client";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { isWhitelisted, buildWhitelistAddressTx } from "@/lib/aptos";
import { queryKeys } from "@/providers/QueryProvider";
import { useToast } from "@/components/ui/use-toast";

/**
 * Hook to check if the connected wallet is whitelisted (KYC verified)
 */
export function useIsWhitelisted() {
  const { account, connected } = useWallet();

  return useQuery({
    queryKey: queryKeys.user.whitelist(account?.address || ""),
    queryFn: () => isWhitelisted(account!.address),
    enabled: connected && !!account?.address,
    staleTime: 60 * 1000, // 1 minute
  });
}

/**
 * Hook to whitelist an address (admin only)
 */
export function useWhitelistAddress() {
  const { signAndSubmitTransaction } = useWallet();
  const queryClient = useQueryClient();
  const { toast } = useToast();

  return useMutation({
    mutationFn: async (addressToWhitelist: string) => {
      const payload = buildWhitelistAddressTx(addressToWhitelist);
      const response = await signAndSubmitTransaction({
        data: payload,
      });

      return response;
    },
    onSuccess: (_, addressToWhitelist) => {
      toast({
        title: "Address Whitelisted",
        description: `Successfully whitelisted ${addressToWhitelist.slice(0, 10)}...`,
      });
      // Invalidate the whitelist query for the address
      queryClient.invalidateQueries({ queryKey: queryKeys.user.whitelist(addressToWhitelist) });
    },
    onError: (error: Error) => {
      toast({
        title: "Whitelist Failed",
        description: error.message,
        variant: "destructive",
      });
    },
  });
}

/**
 * Combined compliance status hook
 */
export function useComplianceStatus() {
  const { account, connected } = useWallet();
  const { data: whitelisted, isLoading } = useIsWhitelisted();

  return {
    address: account?.address,
    connected,
    isWhitelisted: whitelisted ?? false,
    isKYCVerified: whitelisted ?? false, // Alias for clarity
    isLoading,
    canAccessFinancialFeatures: whitelisted ?? false,
  };
}

