"use client";

import { useMemberStatus, useComplianceStatus } from "@/hooks";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { Shield, ShieldCheck, UserCheck, UserX } from "lucide-react";

export function MembershipStatus() {
  const { isMember, roleLabel, isLoading: isMemberLoading } = useMemberStatus();
  const { isWhitelisted, isLoading: isKYCLoading } = useComplianceStatus();

  const isLoading = isMemberLoading || isKYCLoading;

  if (isLoading) {
    return (
      <Card>
        <CardHeader className="pb-3">
          <CardTitle className="text-lg">Account Status</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <Skeleton className="h-6 w-32" />
          <Skeleton className="h-6 w-24" />
        </CardContent>
      </Card>
    );
  }

  return (
    <Card>
      <CardHeader className="pb-3">
        <CardTitle className="text-lg">Account Status</CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        <div className="flex items-center gap-2">
          {isMember ? (
            <>
              <UserCheck className="h-5 w-5 text-success" />
              <span>Member</span>
              {roleLabel && (
                <Badge variant="secondary">{roleLabel}</Badge>
              )}
            </>
          ) : (
            <>
              <UserX className="h-5 w-5 text-text-muted" />
              <span className="text-text-muted">Not a member</span>
            </>
          )}
        </div>
        
        <div className="flex items-center gap-2">
          {isWhitelisted ? (
            <>
              <ShieldCheck className="h-5 w-5 text-success" />
              <span>KYC Verified</span>
              <Badge variant="success">Approved</Badge>
            </>
          ) : (
            <>
              <Shield className="h-5 w-5 text-text-muted" />
              <span className="text-text-muted">KYC Pending</span>
            </>
          )}
        </div>
      </CardContent>
    </Card>
  );
}

export function RoleBadge({ role }: { role: string | null }) {
  if (!role) return null;

  const variantMap: Record<string, "default" | "secondary" | "success" | "warning"> = {
    Admin: "default",
    Validator: "secondary",
    Borrower: "warning",
    Depositor: "success",
  };

  return (
    <Badge variant={variantMap[role] || "default"}>
      {role}
    </Badge>
  );
}

