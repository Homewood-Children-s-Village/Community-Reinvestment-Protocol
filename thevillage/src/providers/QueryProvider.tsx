"use client";

import { ReactNode, useState } from "react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ReactQueryDevtools } from "@tanstack/react-query-devtools";

interface QueryProviderProps {
  children: ReactNode;
}

/**
 * React Query Provider Component
 * 
 * Provides global data fetching and caching capabilities.
 * Configured with sensible defaults for blockchain data:
 * - Stale time: 30 seconds (blockchain data can change)
 * - Retry: 2 times (handle temporary network issues)
 * - Refetch on window focus: true (keep data fresh)
 */
export function QueryProvider({ children }: QueryProviderProps) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            // Data is considered stale after 30 seconds
            staleTime: 30 * 1000,
            // Garbage collect after 5 minutes
            gcTime: 5 * 60 * 1000,
            // Retry failed requests 2 times
            retry: 2,
            // Refetch on window focus
            refetchOnWindowFocus: true,
            // Don't refetch on reconnect by default
            refetchOnReconnect: false,
          },
          mutations: {
            // Retry failed mutations once
            retry: 1,
          },
        },
      })
  );

  return (
    <QueryClientProvider client={queryClient}>
      {children}
      <ReactQueryDevtools initialIsOpen={false} />
    </QueryClientProvider>
  );
}

/**
 * Query keys factory for consistent cache management
 */
export const queryKeys = {
  // User-related queries
  user: {
    all: ["user"] as const,
    membership: (address: string) => ["user", "membership", address] as const,
    role: (address: string) => ["user", "role", address] as const,
    whitelist: (address: string) => ["user", "whitelist", address] as const,
    timeTokenBalance: (address: string) => ["user", "timeTokenBalance", address] as const,
    treasuryBalance: (address: string) => ["user", "treasuryBalance", address] as const,
  },
  
  // Membership requests queries
  membershipRequests: (status?: number) => ["membershipRequests", status] as const,
  
  // TimeBank queries
  timebank: {
    all: ["timebank"] as const,
    request: (id: number) => ["timebank", "request", id] as const,
    requests: (status?: number) => ["timebank", "requests", status] as const,
    userRequests: (address: string) => ["timebank", "userRequests", address] as const,
  },
  
  // Treasury queries
  treasury: {
    all: ["treasury"] as const,
    balance: (address: string) => ["treasury", "balance", address] as const,
    history: (address: string) => ["treasury", "history", address] as const,
  },
  
  // Investment pool queries
  pools: {
    all: ["pools"] as const,
    list: () => ["pools", "list"] as const,
    detail: (id: number) => ["pools", "detail", id] as const,
    portfolio: (address: string) => ["pools", "portfolio", address] as const,
  },
  
  // Governance queries
  governance: {
    all: ["governance"] as const,
    proposals: () => ["governance", "proposals"] as const,
    proposal: (id: number) => ["governance", "proposal", id] as const,
    userVotes: (address: string) => ["governance", "userVotes", address] as const,
  },
  
  // Projects queries
  projects: {
    all: ["projects"] as const,
    list: () => ["projects", "list"] as const,
    detail: (id: number) => ["projects", "detail", id] as const,
  },
  
  // Rewards queries
  rewards: {
    all: ["rewards"] as const,
    pending: (address: string, poolId: number) => ["rewards", "pending", address, poolId] as const,
    stakes: (address: string) => ["rewards", "stakes", address] as const,
  },
};

