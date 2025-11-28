"use client";

import { useTreasury, useComplianceStatus } from "@/hooks";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { Button } from "@/components/ui/button";
import { Wallet, ArrowDownToLine, ArrowUpFromLine, RefreshCw, AlertTriangle } from "lucide-react";
import { formatNumber } from "@/lib/utils";
import Link from "next/link";

interface TreasuryBalanceProps {
  showActions?: boolean;
  compact?: boolean;
}

export function TreasuryBalance({ showActions = true, compact = false }: TreasuryBalanceProps) {
  const { balanceInApt, isLoading, refetch, connected } = useTreasury();
  const { isWhitelisted } = useComplianceStatus();

  if (!connected) {
    return null;
  }

  if (compact) {
    return (
      <div className="flex items-center gap-2">
        <Wallet className="h-4 w-4 text-secondary" />
        {isLoading ? (
          <Skeleton className="h-5 w-16" />
        ) : (
          <span className="font-semibold">{formatNumber(balanceInApt, 4)} APT</span>
        )}
      </div>
    );
  }

  return (
    <Card>
      <CardHeader className="pb-3">
        <div className="flex items-center justify-between">
          <CardTitle className="text-lg flex items-center gap-2">
            <Wallet className="h-5 w-5 text-secondary" />
            Treasury Balance
          </CardTitle>
          <Button
            variant="ghost"
            size="icon"
            onClick={() => refetch()}
            disabled={isLoading}
          >
            <RefreshCw className={`h-4 w-4 ${isLoading ? "animate-spin" : ""}`} />
          </Button>
        </div>
      </CardHeader>
      <CardContent>
        {isLoading ? (
          <Skeleton className="h-10 w-32" />
        ) : (
          <div className="text-3xl font-bold text-secondary">
            {formatNumber(balanceInApt, 4)}
            <span className="text-lg font-normal text-text-muted ml-2">APT</span>
          </div>
        )}
        
        {!isWhitelisted && (
          <div className="flex items-center gap-2 mt-2 text-warning">
            <AlertTriangle className="h-4 w-4" />
            <span className="text-sm">KYC required for deposits</span>
          </div>
        )}

        {showActions && (
          <div className="flex gap-2 mt-4">
            <Link href="/treasury" className="flex-1">
              <Button variant="outline" className="w-full" disabled={!isWhitelisted}>
                <ArrowDownToLine className="h-4 w-4 mr-2" />
                Deposit
              </Button>
            </Link>
            <Link href="/treasury" className="flex-1">
              <Button variant="secondary" className="w-full">
                <ArrowUpFromLine className="h-4 w-4 mr-2" />
                Withdraw
              </Button>
            </Link>
          </div>
        )}
      </CardContent>
    </Card>
  );
}

