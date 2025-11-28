"use client";

import { useState } from "react";
import { useWallet, WalletName } from "@aptos-labs/wallet-adapter-react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Wallet, ExternalLink, Loader2 } from "lucide-react";
import { formatAddress } from "@/lib/config";

interface WalletConnectModalProps {
  trigger?: React.ReactNode;
}

export function WalletConnectModal({ trigger }: WalletConnectModalProps) {
  const { connect, disconnect, account, connected, connecting, wallets } = useWallet();
  const [open, setOpen] = useState(false);

  // Handle wallet connection
  const handleConnect = async (walletName: WalletName) => {
    try {
      await connect(walletName);
      setOpen(false);
    } catch (error) {
      console.error("Failed to connect wallet:", error);
    }
  };

  // Handle disconnect
  const handleDisconnect = async () => {
    try {
      await disconnect();
      setOpen(false);
    } catch (error) {
      console.error("Failed to disconnect wallet:", error);
    }
  };

  // Check if Petra is installed
  const isPetraInstalled = typeof window !== "undefined" && "aptos" in window;

  // If connected, show account info
  if (connected && account) {
    return (
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogTrigger asChild>
          {trigger || (
            <Button variant="outline" className="gap-2">
              <Wallet className="h-4 w-4" />
              {formatAddress(account.address)}
            </Button>
          )}
        </DialogTrigger>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Connected Wallet</DialogTitle>
            <DialogDescription>
              Manage your wallet connection
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="rounded-lg border p-4">
              <p className="text-sm text-text-muted mb-1">Address</p>
              <p className="font-mono text-sm break-all">{account.address}</p>
            </div>
            <Button
              variant="destructive"
              className="w-full"
              onClick={handleDisconnect}
            >
              Disconnect Wallet
            </Button>
          </div>
        </DialogContent>
      </Dialog>
    );
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        {trigger || (
          <Button className="gap-2">
            <Wallet className="h-4 w-4" />
            Connect Wallet
          </Button>
        )}
      </DialogTrigger>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Connect Wallet</DialogTitle>
          <DialogDescription>
            Choose a wallet to connect to The Village platform
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-3 py-4">
          {/* Petra Wallet */}
          <button
            onClick={() => handleConnect("Petra" as WalletName)}
            disabled={connecting}
            className="w-full flex items-center gap-4 p-4 rounded-lg border hover:bg-muted transition-colors disabled:opacity-50"
          >
            <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center">
              <Wallet className="h-5 w-5 text-primary" />
            </div>
            <div className="flex-1 text-left">
              <p className="font-medium">Petra Wallet</p>
              <p className="text-sm text-text-muted">
                {isPetraInstalled ? "Click to connect" : "Install required"}
              </p>
            </div>
            {connecting && <Loader2 className="h-5 w-5 animate-spin" />}
          </button>

          {/* Install Petra link if not installed */}
          {!isPetraInstalled && (
            <a
              href="https://petra.app/"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center justify-center gap-2 text-sm text-primary hover:underline"
            >
              Install Petra Wallet
              <ExternalLink className="h-3 w-3" />
            </a>
          )}

          {/* Other wallets from adapter */}
          {wallets
            .filter((w) => w.name !== "Petra")
            .map((wallet) => (
              <button
                key={wallet.name}
                onClick={() => handleConnect(wallet.name)}
                disabled={connecting}
                className="w-full flex items-center gap-4 p-4 rounded-lg border hover:bg-muted transition-colors disabled:opacity-50"
              >
                <div className="w-10 h-10 rounded-full bg-secondary/10 flex items-center justify-center">
                  <Wallet className="h-5 w-5 text-secondary" />
                </div>
                <div className="flex-1 text-left">
                  <p className="font-medium">{wallet.name}</p>
                  <p className="text-sm text-text-muted">Click to connect</p>
                </div>
                {connecting && <Loader2 className="h-5 w-5 animate-spin" />}
              </button>
            ))}
        </div>
        <div className="text-center text-xs text-text-muted">
          By connecting, you agree to our Terms of Service and Privacy Policy
        </div>
      </DialogContent>
    </Dialog>
  );
}

