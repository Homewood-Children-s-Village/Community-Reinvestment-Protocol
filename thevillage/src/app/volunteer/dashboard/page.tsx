"use client";

import { useWallet } from "@aptos-labs/wallet-adapter-react";
import Link from "next/link";
import { MainLayout } from "@/components/Navigation";
import { TimeTokenBalance } from "@/components/TimeTokenBalance";
import { TreasuryBalance } from "@/components/TreasuryBalance";
import { MembershipStatus } from "@/components/MembershipStatus";
import { WalletConnectModal } from "@/components/WalletConnectModal";
import { useMemberStatus } from "@/hooks";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Clock,
  Plus,
  ArrowRight,
  Wallet,
  FileText,
  CheckCircle,
  AlertCircle,
  TrendingUp,
} from "lucide-react";

export default function VolunteerDashboardPage() {
  const { connected } = useWallet();
  const { isMember, roleLabel, isLoading } = useMemberStatus();

  // Not connected state
  if (!connected) {
    return (
      <MainLayout>
        <div className="max-w-2xl mx-auto text-center py-12">
          <div className="w-16 h-16 mx-auto bg-primary/10 rounded-full flex items-center justify-center mb-6">
            <Wallet className="h-8 w-8 text-primary" />
          </div>
          <h1 className="text-2xl font-bold mb-4">Connect Your Wallet</h1>
          <p className="text-text-muted mb-8">
            Connect your wallet to access your volunteer dashboard and manage your Time Dollars.
          </p>
          <WalletConnectModal
            trigger={
              <Button size="lg" className="gap-2">
                <Wallet className="h-5 w-5" />
                Connect Wallet
              </Button>
            }
          />
        </div>
      </MainLayout>
    );
  }

  // Loading state
  if (isLoading) {
    return (
      <MainLayout>
        <div className="space-y-6">
          <Skeleton className="h-8 w-48" />
          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            <Skeleton className="h-48" />
            <Skeleton className="h-48" />
            <Skeleton className="h-48" />
          </div>
        </div>
      </MainLayout>
    );
  }

  // Not a member state
  if (!isMember) {
    return (
      <MainLayout>
        <div className="max-w-2xl mx-auto text-center py-12">
          <div className="w-16 h-16 mx-auto bg-warning/10 rounded-full flex items-center justify-center mb-6">
            <AlertCircle className="h-8 w-8 text-warning" />
          </div>
          <h1 className="text-2xl font-bold mb-4">Membership Required</h1>
          <p className="text-text-muted mb-8">
            You need to be a registered member to access the volunteer dashboard.
            Request membership to start logging hours and earning Time Dollars.
          </p>
          <Link href="/membership/request">
            <Button size="lg" className="gap-2">
              Request Membership
              <ArrowRight className="h-5 w-5" />
            </Button>
          </Link>
        </div>
      </MainLayout>
    );
  }

  return (
    <MainLayout>
      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
          <div>
            <div className="flex items-center gap-3 mb-2">
              <h1 className="text-2xl font-bold">Volunteer Dashboard</h1>
              {roleLabel && <Badge variant="secondary">{roleLabel}</Badge>}
            </div>
            <p className="text-text-muted">
              Track your service hours and manage your Time Dollars
            </p>
          </div>
          <Link href="/volunteer/log-hours">
            <Button className="gap-2">
              <Plus className="h-5 w-5" />
              Log Service Hours
            </Button>
          </Link>
        </div>

        {/* Balance Cards */}
        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
          <TimeTokenBalance />
          <TreasuryBalance />
          <MembershipStatus />
        </div>

        {/* Quick Actions */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Quick Actions</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-4">
              <Link href="/volunteer/log-hours">
                <Card hoverable className="h-full">
                  <CardContent className="flex flex-col items-center justify-center py-6 text-center">
                    <div className="w-12 h-12 bg-primary/10 rounded-full flex items-center justify-center mb-3">
                      <Clock className="h-6 w-6 text-primary" />
                    </div>
                    <p className="font-medium">Log Hours</p>
                    <p className="text-sm text-text-muted">Submit service request</p>
                  </CardContent>
                </Card>
              </Link>

              <Link href="/projects">
                <Card hoverable className="h-full">
                  <CardContent className="flex flex-col items-center justify-center py-6 text-center">
                    <div className="w-12 h-12 bg-secondary/10 rounded-full flex items-center justify-center mb-3">
                      <TrendingUp className="h-6 w-6 text-secondary" />
                    </div>
                    <p className="font-medium">Invest</p>
                    <p className="text-sm text-text-muted">Stake in projects</p>
                  </CardContent>
                </Card>
              </Link>

              <Link href="/governance">
                <Card hoverable className="h-full">
                  <CardContent className="flex flex-col items-center justify-center py-6 text-center">
                    <div className="w-12 h-12 bg-success/10 rounded-full flex items-center justify-center mb-3">
                      <FileText className="h-6 w-6 text-success" />
                    </div>
                    <p className="font-medium">Vote</p>
                    <p className="text-sm text-text-muted">Community proposals</p>
                  </CardContent>
                </Card>
              </Link>

              <Link href="/treasury">
                <Card hoverable className="h-full">
                  <CardContent className="flex flex-col items-center justify-center py-6 text-center">
                    <div className="w-12 h-12 bg-warning/10 rounded-full flex items-center justify-center mb-3">
                      <Wallet className="h-6 w-6 text-warning" />
                    </div>
                    <p className="font-medium">Deposit</p>
                    <p className="text-sm text-text-muted">Add funds</p>
                  </CardContent>
                </Card>
              </Link>
            </div>
          </CardContent>
        </Card>

        {/* Recent Activity */}
        <Card>
          <CardHeader className="flex flex-row items-center justify-between">
            <div>
              <CardTitle className="text-lg">Recent Activity</CardTitle>
              <CardDescription>Your latest service requests and transactions</CardDescription>
            </div>
            <Button variant="ghost" size="sm">
              View All
              <ArrowRight className="h-4 w-4 ml-1" />
            </Button>
          </CardHeader>
          <CardContent>
            {/* Placeholder for activity list */}
            <div className="text-center py-8 text-text-muted">
              <CheckCircle className="h-12 w-12 mx-auto mb-4 opacity-30" />
              <p>No recent activity</p>
              <p className="text-sm mt-1">
                Start by logging your first service hours
              </p>
            </div>
          </CardContent>
        </Card>
      </div>
    </MainLayout>
  );
}

