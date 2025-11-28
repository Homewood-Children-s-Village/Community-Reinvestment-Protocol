import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

/**
 * Combines class names using clsx and tailwind-merge
 * This ensures Tailwind classes are properly merged without conflicts
 */
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

/**
 * Formats a number with commas for thousands separators
 */
export function formatNumber(value: number, decimals = 2): string {
  return new Intl.NumberFormat("en-US", {
    minimumFractionDigits: 0,
    maximumFractionDigits: decimals,
  }).format(value);
}

/**
 * Formats a date to a human-readable string
 */
export function formatDate(date: Date | number | string): string {
  const d = new Date(date);
  return new Intl.DateTimeFormat("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  }).format(d);
}

/**
 * Formats a date with time
 */
export function formatDateTime(date: Date | number | string): string {
  const d = new Date(date);
  return new Intl.DateTimeFormat("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(d);
}

/**
 * Formats a timestamp (in seconds or milliseconds) to relative time
 */
export function formatRelativeTime(timestamp: number): string {
  // If timestamp is in seconds, convert to milliseconds
  const ms = timestamp < 1e12 ? timestamp * 1000 : timestamp;
  const now = Date.now();
  const diff = now - ms;
  
  const seconds = Math.floor(diff / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);
  
  if (days > 0) return `${days} day${days === 1 ? "" : "s"} ago`;
  if (hours > 0) return `${hours} hour${hours === 1 ? "" : "s"} ago`;
  if (minutes > 0) return `${minutes} minute${minutes === 1 ? "" : "s"} ago`;
  return "Just now";
}

/**
 * Converts a string to bytes (Uint8Array) for Move contract arguments
 */
export function stringToBytes(str: string): Uint8Array {
  return new TextEncoder().encode(str);
}

/**
 * Converts bytes to string
 */
export function bytesToString(bytes: Uint8Array | number[]): string {
  const uint8Array = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  return new TextDecoder().decode(uint8Array);
}

/**
 * Truncates a string in the middle
 */
export function truncateMiddle(str: string, startLen = 6, endLen = 4): string {
  if (str.length <= startLen + endLen) return str;
  return `${str.slice(0, startLen)}...${str.slice(-endLen)}`;
}

/**
 * Sleep for a specified number of milliseconds
 */
export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Debounce a function
 */
export function debounce<T extends (...args: unknown[]) => unknown>(
  func: T,
  wait: number
): (...args: Parameters<T>) => void {
  let timeout: NodeJS.Timeout | null = null;
  
  return (...args: Parameters<T>) => {
    if (timeout) clearTimeout(timeout);
    timeout = setTimeout(() => func(...args), wait);
  };
}

/**
 * Check if we're running on the client side
 */
export function isClient(): boolean {
  return typeof window !== "undefined";
}

/**
 * Safely parse JSON with fallback
 */
export function safeJsonParse<T>(json: string, fallback: T): T {
  try {
    return JSON.parse(json) as T;
  } catch {
    return fallback;
  }
}

/**
 * Creates a percentage from two numbers
 */
export function calculatePercentage(current: number, total: number): number {
  if (total === 0) return 0;
  return Math.min(100, Math.max(0, (current / total) * 100));
}

/**
 * Formats a percentage for display
 */
export function formatPercentage(value: number, decimals = 1): string {
  return `${value.toFixed(decimals)}%`;
}

/**
 * Converts APT to USD (using approximate rate)
 * TODO: Replace with real-time API call for production
 */
export function aptToUsd(apt: number, aptPriceUsd = 8.5): number {
  return apt * aptPriceUsd;
}

/**
 * Formats USD currency
 */
export function formatUsd(value: number): string {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(value);
}

