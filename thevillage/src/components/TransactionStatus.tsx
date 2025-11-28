"use client";

import { useState, useEffect } from "react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Progress } from "@/components/ui/progress";
import { Loader2, CheckCircle, XCircle, ExternalLink } from "lucide-react";
import { getTransactionUrl } from "@/lib/config";

export type TransactionState = "idle" | "pending" | "confirming" | "success" | "error";

interface TransactionStatusProps {
  state: TransactionState;
  txHash?: string;
  title?: string;
  description?: string;
  errorMessage?: string;
  onClose?: () => void;
  onRetry?: () => void;
}

export function TransactionStatus({
  state,
  txHash,
  title,
  description,
  errorMessage,
  onClose,
  onRetry,
}: TransactionStatusProps) {
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    if (state === "confirming") {
      const interval = setInterval(() => {
        setProgress((prev) => Math.min(prev + 10, 90));
      }, 500);
      return () => clearInterval(interval);
    } else if (state === "success") {
      setProgress(100);
    } else {
      setProgress(0);
    }
  }, [state]);

  if (state === "idle") return null;

  const isOpen = state !== "idle";

  return (
    <Dialog open={isOpen} onOpenChange={() => state === "success" || state === "error" ? onClose?.() : null}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>
            {state === "pending" && "Confirm Transaction"}
            {state === "confirming" && "Processing Transaction"}
            {state === "success" && (title || "Transaction Successful")}
            {state === "error" && "Transaction Failed"}
          </DialogTitle>
          <DialogDescription>
            {state === "pending" && "Please confirm the transaction in your wallet"}
            {state === "confirming" && "Waiting for blockchain confirmation..."}
            {state === "success" && (description || "Your transaction has been confirmed")}
            {state === "error" && (errorMessage || "Something went wrong. Please try again.")}
          </DialogDescription>
        </DialogHeader>

        <div className="flex flex-col items-center justify-center py-6">
          {state === "pending" && (
            <div className="w-16 h-16 bg-primary/10 rounded-full flex items-center justify-center">
              <Loader2 className="h-8 w-8 text-primary animate-spin" />
            </div>
          )}

          {state === "confirming" && (
            <div className="w-full space-y-4">
              <div className="w-16 h-16 bg-secondary/10 rounded-full flex items-center justify-center mx-auto">
                <Loader2 className="h-8 w-8 text-secondary animate-spin" />
              </div>
              <Progress value={progress} className="h-2" />
              <p className="text-sm text-text-muted text-center">
                This may take a few moments...
              </p>
            </div>
          )}

          {state === "success" && (
            <div className="w-16 h-16 bg-success/10 rounded-full flex items-center justify-center">
              <CheckCircle className="h-8 w-8 text-success" />
            </div>
          )}

          {state === "error" && (
            <div className="w-16 h-16 bg-error/10 rounded-full flex items-center justify-center">
              <XCircle className="h-8 w-8 text-error" />
            </div>
          )}
        </div>

        {txHash && state === "success" && (
          <a
            href={getTransactionUrl(txHash)}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center justify-center gap-2 text-sm text-primary hover:underline"
          >
            View on Explorer
            <ExternalLink className="h-4 w-4" />
          </a>
        )}

        {(state === "success" || state === "error") && (
          <div className="flex gap-2 mt-4">
            {state === "error" && onRetry && (
              <Button onClick={onRetry} variant="outline" className="flex-1">
                Try Again
              </Button>
            )}
            <Button onClick={onClose} className="flex-1">
              {state === "success" ? "Done" : "Close"}
            </Button>
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}

/**
 * Hook to manage transaction status
 */
export function useTransactionStatus() {
  const [state, setState] = useState<TransactionState>("idle");
  const [txHash, setTxHash] = useState<string>();
  const [error, setError] = useState<string>();

  const startTransaction = () => {
    setState("pending");
    setTxHash(undefined);
    setError(undefined);
  };

  const setConfirming = (hash?: string) => {
    setState("confirming");
    if (hash) setTxHash(hash);
  };

  const setSuccess = (hash?: string) => {
    setState("success");
    if (hash) setTxHash(hash);
  };

  const setErrorState = (message: string) => {
    setState("error");
    setError(message);
  };

  const reset = () => {
    setState("idle");
    setTxHash(undefined);
    setError(undefined);
  };

  return {
    state,
    txHash,
    error,
    startTransaction,
    setConfirming,
    setSuccess,
    setError: setErrorState,
    reset,
  };
}

