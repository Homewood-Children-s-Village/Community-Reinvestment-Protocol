"use client";

import { ReactNode } from "react";
import { WalletProvider } from "./WalletProvider";
import { QueryProvider } from "./QueryProvider";
import { Toaster } from "@/components/ui/toaster";

interface ProvidersProps {
  children: ReactNode;
}

/**
 * Combined Providers Component
 * 
 * Wraps the application with all necessary providers:
 * - React Query for data fetching
 * - Wallet adapter for blockchain interactions
 * - Toast notifications
 */
export function Providers({ children }: ProvidersProps) {
  return (
    <QueryProvider>
      <WalletProvider>
        {children}
        <Toaster />
      </WalletProvider>
    </QueryProvider>
  );
}

