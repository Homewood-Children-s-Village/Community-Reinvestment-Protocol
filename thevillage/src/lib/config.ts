/**
 * Configuration for the Villages Finance Platform
 * 
 * Environment variables are loaded from .env.local
 * Create a .env.local file with the following variables:
 * 
 * NEXT_PUBLIC_APTOS_NETWORK=testnet
 * NEXT_PUBLIC_APTOS_REST_URL=https://fullnode.testnet.aptoslabs.com
 * NEXT_PUBLIC_APTOS_INDEXER_URL=https://api.testnet.aptoslabs.com/v1/graphql
 * NEXT_PUBLIC_CONTRACT_ADDRESS=0x2144ec184b89cf405e430d375b3de991ae14baf26cb6ec9987ea57922c0f1c5b
 * NEXT_PUBLIC_EXPLORER_URL=https://explorer.aptoslabs.com/?network=testnet
 */

import { Network } from "@aptos-labs/ts-sdk";

// Aptos Network Configuration
export const APTOS_NETWORK = (process.env.NEXT_PUBLIC_APTOS_NETWORK as "mainnet" | "testnet" | "devnet") || "testnet";
export const APTOS_REST_URL = process.env.NEXT_PUBLIC_APTOS_REST_URL || "https://fullnode.testnet.aptoslabs.com";
export const APTOS_INDEXER_URL = process.env.NEXT_PUBLIC_APTOS_INDEXER_URL || "https://api.testnet.aptoslabs.com/v1/graphql";
export const APTOS_FAUCET_URL = process.env.NEXT_PUBLIC_APTOS_FAUCET_URL || "https://faucet.testnet.aptoslabs.com";
export const EXPLORER_URL = process.env.NEXT_PUBLIC_EXPLORER_URL || "https://explorer.aptoslabs.com/?network=testnet";

// Contract Configuration - Villages Finance deployed contract
export const CONTRACT_ADDRESS = process.env.NEXT_PUBLIC_CONTRACT_ADDRESS || "0x2144ec184b89cf405e430d375b3de991ae14baf26cb6ec9987ea57922c0f1c5b";

// Registry addresses - all point to contract address for MVP
export const ADMIN_ADDR = CONTRACT_ADDRESS;
export const MEMBERS_REGISTRY_ADDR = CONTRACT_ADDRESS;
export const COMPLIANCE_REGISTRY_ADDR = CONTRACT_ADDRESS;
export const TREASURY_ADDR = CONTRACT_ADDRESS;
export const POOL_REGISTRY_ADDR = CONTRACT_ADDRESS;
export const GOVERNANCE_ADDR = CONTRACT_ADDRESS;
export const BANK_REGISTRY_ADDR = CONTRACT_ADDRESS;
export const PROJECT_REGISTRY_ADDR = CONTRACT_ADDRESS;
export const FRACTIONAL_SHARES_ADDR = CONTRACT_ADDRESS;
export const TOKEN_ADMIN_ADDR = CONTRACT_ADDRESS;

// Network type mapping for Aptos SDK
export const getNetworkType = (): Network => {
  switch (APTOS_NETWORK) {
    case "mainnet":
      return Network.MAINNET;
    case "testnet":
      return Network.TESTNET;
    case "devnet":
      return Network.DEVNET;
    default:
      return Network.TESTNET;
  }
};

// Module paths for contract interactions
export const MODULE_PATHS = {
  members: `${CONTRACT_ADDRESS}::members`,
  compliance: `${CONTRACT_ADDRESS}::compliance`,
  timebank: `${CONTRACT_ADDRESS}::timebank`,
  time_token: `${CONTRACT_ADDRESS}::time_token`,
  treasury: `${CONTRACT_ADDRESS}::treasury`,
  investment_pool: `${CONTRACT_ADDRESS}::investment_pool`,
  governance: `${CONTRACT_ADDRESS}::governance`,
  rewards: `${CONTRACT_ADDRESS}::rewards`,
  project_registry: `${CONTRACT_ADDRESS}::project_registry`,
  fractional_asset: `${CONTRACT_ADDRESS}::fractional_asset`,
  token: `${CONTRACT_ADDRESS}::token`,
} as const;

// APT conversion constants
export const OCTAS_PER_APT = 100_000_000;

// Convert APT to Octas
export function aptToOctas(apt: number): number {
  return Math.floor(apt * OCTAS_PER_APT);
}

// Convert Octas to APT
export function octasToApt(octas: number): number {
  return octas / OCTAS_PER_APT;
}

// Format address for display (truncate middle)
export function formatAddress(address: string, startChars = 6, endChars = 4): string {
  if (address.length <= startChars + endChars) {
    return address;
  }
  return `${address.slice(0, startChars)}...${address.slice(-endChars)}`;
}

// Get explorer URL for transaction
export function getTransactionUrl(txHash: string): string {
  return `${EXPLORER_URL}&txn=${txHash}`;
}

// Get explorer URL for account
export function getAccountUrl(address: string): string {
  return `${EXPLORER_URL}&account=${address}`;
}

