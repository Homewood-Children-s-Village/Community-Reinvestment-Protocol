"use client";

import { useState } from "react";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { MainLayout } from "@/components/Navigation";
import { useTreasury, useMemberStatus, useComplianceStatus } from "@/hooks";
import { WalletConnectModal } from "@/components/WalletConnectModal";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Wallet,
  ArrowDownToLine,
  ArrowUpFromLine,
  AlertTriangle,
  CheckCircle,
  RefreshCw,
  Shield,
  ExternalLink,
} from "lucide-react";
import Link from "next/link";
import { formatNumber } from "@/lib/utils";
import { EXPLORER_URL, aptToOctas, octasToApt } from "@/lib/config";

export default function TreasuryPage() {
  const { connected } = useWallet();
  const { isMember, isLoading: memberLoading } = useMemberStatus();
  const { isWhitelisted, isLoading: kycLoading } = useComplianceStatus();
  const { balanceInApt, isLoading: balanceLoading, deposit, withdraw, isDepositing, isWithdrawing, refetch } = useTreasury();

  const [depositAmount, setDepositAmount] = useState("");
  const [withdrawAmount, setWithdrawAmount] = useState("");
  const [showDepositSuccess, setShowDepositSuccess] = useState(false);
  const [showWithdrawSuccess, setShowWithdrawSuccess] = useState(false);

  const handleDeposit = () => {
    if (!depositAmount) return;
    deposit(parseFloat(depositAmount), {
      onSuccess: () => {
        setShowDepositSuccess(true);
        setDepositAmount("");
      },
    });
  };

  const handleWithdraw = () => {
    if (!withdrawAmount) return;
    withdraw(parseFloat(withdrawAmount), {
      onSuccess: () => {
        setShowWithdrawSuccess(true);
        setWithdrawAmount("");
      },
    });
  };

  // Not connected state
  if (!connected) {
    return (
      <MainLayout>
        <div className="max-w-2xl mx-auto text-center py-12">
          <div className="w-16 h-16 mx-auto bg-secondary/10 rounded-full flex items-center justify-center mb-6">
            <Wallet className="h-8 w-8 text-secondary" />
          </div>
          <h1 className="text-2xl font-bold mb-4">Connect Your Wallet</h1>
          <p className="text-text-muted mb-8">
            Connect your wallet to manage your treasury balance.
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

  // Not a member state
  if (!memberLoading && !isMember) {
    return (
      <MainLayout>
        <div className="max-w-2xl mx-auto text-center py-12">
          <div className="w-16 h-16 mx-auto bg-warning/10 rounded-full flex items-center justify-center mb-6">
            <AlertTriangle className="h-8 w-8 text-warning" />
          </div>
          <h1 className="text-2xl font-bold mb-4">Membership Required</h1>
          <p className="text-text-muted mb-8">
            You need to be a registered member to access the treasury.
          </p>
          <Link href="/membership/request">
            <Button size="lg">Request Membership</Button>
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
            <h1 className="text-2xl font-bold mb-2">Treasury</h1>
            <p className="text-text-muted">
              Manage your deposits and withdrawals
            </p>
          </div>
          <Button
            variant="outline"
            onClick={() => refetch()}
            disabled={balanceLoading}
          >
            <RefreshCw className={`h-4 w-4 mr-2 ${balanceLoading ? "animate-spin" : ""}`} />
            Refresh
          </Button>
        </div>

        {/* KYC Warning */}
        {!kycLoading && !isWhitelisted && (
          <Card className="border-warning bg-warning/5">
            <CardContent className="flex items-center gap-4 py-4">
              <div className="w-10 h-10 bg-warning/20 rounded-full flex items-center justify-center flex-shrink-0">
                <Shield className="h-5 w-5 text-warning" />
              </div>
              <div className="flex-1">
                <p className="font-medium text-warning">KYC Verification Required</p>
                <p className="text-sm text-text-muted">
                  Complete KYC verification to deposit funds. Contact an admin to get whitelisted.
                </p>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Balance Card */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Wallet className="h-5 w-5 text-secondary" />
              Treasury Balance
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-4xl font-bold text-secondary">
              {formatNumber(balanceInApt, 4)}
              <span className="text-lg font-normal text-text-muted ml-2">APT</span>
            </div>
            <p className="text-sm text-text-muted mt-2">
              ≈ ${formatNumber(balanceInApt * 10, 2)} USD (estimated)
            </p>
          </CardContent>
        </Card>

        {/* Deposit/Withdraw Tabs */}
        <Card>
          <Tabs defaultValue="deposit">
            <CardHeader>
              <TabsList className="grid w-full grid-cols-2">
                <TabsTrigger value="deposit" className="gap-2">
                  <ArrowDownToLine className="h-4 w-4" />
                  Deposit
                </TabsTrigger>
                <TabsTrigger value="withdraw" className="gap-2">
                  <ArrowUpFromLine className="h-4 w-4" />
                  Withdraw
                </TabsTrigger>
              </TabsList>
            </CardHeader>
            <CardContent>
              {/* Deposit Tab */}
              <TabsContent value="deposit" className="space-y-4">
                <div className="space-y-2">
                  <Label htmlFor="depositAmount">Amount (APT)</Label>
                  <Input
                    id="depositAmount"
                    type="number"
                    min="0"
                    step="0.0001"
                    placeholder="0.0000"
                    value={depositAmount}
                    onChange={(e) => setDepositAmount(e.target.value)}
                    disabled={!isWhitelisted}
                  />
                </div>
                {depositAmount && (
                  <div className="p-3 bg-muted rounded-lg text-sm">
                    <div className="flex justify-between">
                      <span className="text-text-muted">You will deposit</span>
                      <span className="font-medium">{depositAmount} APT</span>
                    </div>
                  </div>
                )}
                <Button
                  className="w-full"
                  onClick={handleDeposit}
                  disabled={!depositAmount || !isWhitelisted || isDepositing}
                  isLoading={isDepositing}
                  loadingText="Depositing..."
                >
                  <ArrowDownToLine className="h-4 w-4 mr-2" />
                  Deposit APT
                </Button>
                {!isWhitelisted && (
                  <p className="text-xs text-warning text-center">
                    KYC verification required to deposit
                  </p>
                )}
              </TabsContent>

              {/* Withdraw Tab */}
              <TabsContent value="withdraw" className="space-y-4">
                <div className="space-y-2">
                  <div className="flex justify-between">
                    <Label htmlFor="withdrawAmount">Amount (APT)</Label>
                    <button
                      className="text-xs text-primary hover:underline"
                      onClick={() => setWithdrawAmount(balanceInApt.toString())}
                    >
                      Max: {formatNumber(balanceInApt, 4)}
                    </button>
                  </div>
                  <Input
                    id="withdrawAmount"
                    type="number"
                    min="0"
                    max={balanceInApt}
                    step="0.0001"
                    placeholder="0.0000"
                    value={withdrawAmount}
                    onChange={(e) => setWithdrawAmount(e.target.value)}
                  />
                </div>
                {withdrawAmount && (
                  <div className="p-3 bg-muted rounded-lg text-sm">
                    <div className="flex justify-between">
                      <span className="text-text-muted">You will receive</span>
                      <span className="font-medium">{withdrawAmount} APT</span>
                    </div>
                  </div>
                )}
                <Button
                  className="w-full"
                  variant="secondary"
                  onClick={handleWithdraw}
                  disabled={!withdrawAmount || parseFloat(withdrawAmount) > balanceInApt || isWithdrawing}
                  isLoading={isWithdrawing}
                  loadingText="Withdrawing..."
                >
                  <ArrowUpFromLine className="h-4 w-4 mr-2" />
                  Withdraw APT
                </Button>
              </TabsContent>
            </CardContent>
          </Tabs>
        </Card>

        {/* Info Card */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">About Treasury</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3 text-sm text-text-muted">
            <p>
              • Treasury deposits are used to fund community investment pools
            </p>
            <p>
              • KYC verification is required for deposits (anti-money laundering compliance)
            </p>
            <p>
              • Withdrawals are self-service and don&apos;t require admin approval
            </p>
            <p>
              • All transactions are recorded on the Aptos blockchain
            </p>
          </CardContent>
        </Card>

        {/* Success Dialogs */}
        <Dialog open={showDepositSuccess} onOpenChange={setShowDepositSuccess}>
          <DialogContent>
            <DialogHeader>
              <div className="mx-auto w-16 h-16 bg-success/10 rounded-full flex items-center justify-center mb-4">
                <CheckCircle className="h-8 w-8 text-success" />
              </div>
              <DialogTitle className="text-center">Deposit Successful!</DialogTitle>
              <DialogDescription className="text-center">
                Your funds have been deposited to the treasury
              </DialogDescription>
            </DialogHeader>
            <DialogFooter>
              <Button onClick={() => setShowDepositSuccess(false)} className="w-full">
                Done
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>

        <Dialog open={showWithdrawSuccess} onOpenChange={setShowWithdrawSuccess}>
          <DialogContent>
            <DialogHeader>
              <div className="mx-auto w-16 h-16 bg-success/10 rounded-full flex items-center justify-center mb-4">
                <CheckCircle className="h-8 w-8 text-success" />
              </div>
              <DialogTitle className="text-center">Withdrawal Successful!</DialogTitle>
              <DialogDescription className="text-center">
                Your funds have been withdrawn from the treasury
              </DialogDescription>
            </DialogHeader>
            <DialogFooter>
              <Button onClick={() => setShowWithdrawSuccess(false)} className="w-full">
                Done
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>
    </MainLayout>
  );
}

