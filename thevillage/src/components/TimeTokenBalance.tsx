"use client";

import { useTimeToken } from "@/hooks";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { Button } from "@/components/ui/button";
import { Clock, ArrowRight, RefreshCw } from "lucide-react";
import { formatNumber } from "@/lib/utils";
import Link from "next/link";

interface TimeTokenBalanceProps {
  showActions?: boolean;
  compact?: boolean;
}

export function TimeTokenBalance({ showActions = true, compact = false }: TimeTokenBalanceProps) {
  const { balance, isLoading, refetch, connected } = useTimeToken();

  if (!connected) {
    return null;
  }

  if (compact) {
    return (
      <div className="flex items-center gap-2">
        <Clock className="h-4 w-4 text-primary" />
        {isLoading ? (
          <Skeleton className="h-5 w-16" />
        ) : (
          <span className="font-semibold">{formatNumber(balance)} TD</span>
        )}
      </div>
    );
  }

  return (
    <Card>
      <CardHeader className="pb-3">
        <div className="flex items-center justify-between">
          <CardTitle className="text-lg flex items-center gap-2">
            <Clock className="h-5 w-5 text-primary" />
            Time Dollars
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
          <div className="text-3xl font-bold text-primary">
            {formatNumber(balance)}
            <span className="text-lg font-normal text-text-muted ml-2">TD</span>
          </div>
        )}
        
        <p className="text-sm text-text-muted mt-2">
          1 Time Dollar = 1 hour of volunteer service
        </p>

        {showActions && (
          <div className="flex gap-2 mt-4">
            <Link href="/volunteer/log-hours" className="flex-1">
              <Button variant="outline" className="w-full">
                Log Hours
              </Button>
            </Link>
            <Link href="/volunteer/dashboard" className="flex-1">
              <Button className="w-full">
                View History
                <ArrowRight className="h-4 w-4 ml-2" />
              </Button>
            </Link>
          </div>
        )}
      </CardContent>
    </Card>
  );
}

export function TimeTokenBalanceInline() {
  const { balance, isLoading, connected } = useTimeToken();

  if (!connected) {
    return <span className="text-text-muted">-</span>;
  }

  if (isLoading) {
    return <Skeleton className="h-5 w-16 inline-block" />;
  }

  return (
    <span className="font-semibold text-primary">
      {formatNumber(balance)} TD
    </span>
  );
}

