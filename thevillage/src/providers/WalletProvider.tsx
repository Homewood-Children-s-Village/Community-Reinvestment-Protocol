"use client";

import { ReactNode, useMemo } from "react";
import {
  AptosWalletAdapterProvider,
  NetworkName,
} from "@aptos-labs/wallet-adapter-react";
import { APTOS_NETWORK } from "@/lib/config";

interface WalletProviderProps {
  children: ReactNode;
}

/**
 * Wallet Provider Component
 * 
 * Wraps the application with AptosWalletAdapterProvider to enable
 * wallet connections and blockchain interactions.
 * 
 * Supports:
 * - Petra Wallet (via AptosConnect, included by default)
 * - Aptos Connect (auto-detected)
 * 
 * Note: Petra Web is included by default in @aptos-labs/wallet-adapter-react
 * via the AptosConnect plugin. No need to explicitly add it.
 */
export function WalletProvider({ children }: WalletProviderProps) {
  // Show Petra as an option even when not already installed
  const optInWallets = ["Petra"];

  // Map network string to NetworkName
  const network = useMemo((): NetworkName => {
    switch (APTOS_NETWORK) {
      case "mainnet":
        return NetworkName.Mainnet;
      case "testnet":
        return NetworkName.Testnet;
      case "devnet":
        return NetworkName.Devnet;
      default:
        return NetworkName.Testnet;
    }
  }, []);

  // DApp configuration
  const dappInfo = useMemo(() => ({
    aptosConnect: {
      dappName: "The Village", // Defaults to document's title if not provided
      // dappImageURI: "..." // Optional: defaults to dapp's favicon
    },
  }), []);

  // DApp config with network configuration
  const dappConfig = useMemo(() => ({
    network,
    aptosConnect: {
      dappName: "The Village",
      // dappImageURI: "..." // Optional: defaults to dapp's favicon
    },
  }), [network]);

  return (
    <AptosWalletAdapterProvider
      optInWallets={optInWallets}
      autoConnect={true}
      dappInfo={dappInfo}
      dappConfig={dappConfig}
      onError={(error) => {
        console.error("Wallet adapter error:", error);
      }}
    >
      {children}
    </AptosWalletAdapterProvider>
  );
}

