"use client";

import { useState } from "react";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import Link from "next/link";
import { MainLayout } from "@/components/Navigation";
import { useMemberStatus } from "@/hooks";
import { WalletConnectModal } from "@/components/WalletConnectModal";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Vote,
  Plus,
  Wallet,
  AlertCircle,
  CheckCircle,
  XCircle,
  Clock,
  Users,
} from "lucide-react";
import {
  ProposalStatus,
  ProposalStatusLabels,
  ProposalStatusColors,
  VotingMechanism,
  VotingMechanismLabels,
} from "@/types/contract";
import { formatNumber, formatRelativeTime, calculatePercentage } from "@/lib/utils";
import { formatAddress } from "@/lib/config";

// Mock proposals for demonstration
const MOCK_PROPOSALS = [
  {
    id: 1,
    proposer: "0x1234567890abcdef1234567890abcdef12345678",
    title: "Fund Community Garden Project",
    description: "Allocate 5000 APT from the treasury to develop a community garden in the Homewood neighborhood.",
    status: ProposalStatus.Active,
    votesYes: 150,
    votesNo: 45,
    votesAbstain: 20,
    threshold: 200,
    votingMechanism: VotingMechanism.TokenWeighted,
    createdAt: Date.now() - 86400000 * 3,
    endsAt: Date.now() + 86400000 * 4,
  },
  {
    id: 2,
    proposer: "0xabcdef1234567890abcdef1234567890abcdef12",
    title: "Increase Time Dollar Reward Rate",
    description: "Proposal to increase the Time Dollar reward rate from 1 TD per hour to 1.5 TD per hour for tutoring activities.",
    status: ProposalStatus.Passed,
    votesYes: 280,
    votesNo: 50,
    votesAbstain: 30,
    threshold: 200,
    votingMechanism: VotingMechanism.Simple,
    createdAt: Date.now() - 86400000 * 10,
    endsAt: Date.now() - 86400000 * 3,
  },
  {
    id: 3,
    proposer: "0x9876543210fedcba9876543210fedcba98765432",
    title: "Partner with Local Business Collective",
    description: "Establish a partnership with the Homewood Business Collective for volunteer placement opportunities.",
    status: ProposalStatus.Pending,
    votesYes: 0,
    votesNo: 0,
    votesAbstain: 0,
    threshold: 100,
    votingMechanism: VotingMechanism.Quadratic,
    createdAt: Date.now() - 3600000,
    endsAt: Date.now() + 86400000 * 7,
  },
];

function getStatusBadgeVariant(status: ProposalStatus): "default" | "secondary" | "success" | "warning" | "error" {
  const map: Record<ProposalStatus, "default" | "secondary" | "success" | "warning" | "error"> = {
    [ProposalStatus.Pending]: "warning",
    [ProposalStatus.Active]: "secondary",
    [ProposalStatus.Passed]: "success",
    [ProposalStatus.Rejected]: "error",
    [ProposalStatus.Executed]: "default",
  };
  return map[status];
}

export default function GovernancePage() {
  const { connected } = useWallet();
  const { isMember, isLoading: memberLoading } = useMemberStatus();
  const [activeTab, setActiveTab] = useState("all");

  const filteredProposals = MOCK_PROPOSALS.filter((proposal) => {
    if (activeTab === "all") return true;
    if (activeTab === "active") return proposal.status === ProposalStatus.Active;
    if (activeTab === "passed") return proposal.status === ProposalStatus.Passed;
    if (activeTab === "pending") return proposal.status === ProposalStatus.Pending;
    return true;
  });

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
            Connect your wallet to participate in governance.
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
            <AlertCircle className="h-8 w-8 text-warning" />
          </div>
          <h1 className="text-2xl font-bold mb-4">Membership Required</h1>
          <p className="text-text-muted mb-8">
            You need to be a registered member to participate in governance.
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
            <h1 className="text-2xl font-bold mb-2">Governance</h1>
            <p className="text-text-muted">
              Vote on proposals to shape the community
            </p>
          </div>
          <Link href="/governance/create">
            <Button className="gap-2">
              <Plus className="h-5 w-5" />
              Create Proposal
            </Button>
          </Link>
        </div>

        {/* Stats */}
        <div className="grid sm:grid-cols-3 gap-4">
          <Card>
            <CardContent className="flex items-center gap-4 py-4">
              <div className="w-12 h-12 bg-secondary/10 rounded-full flex items-center justify-center">
                <Vote className="h-6 w-6 text-secondary" />
              </div>
              <div>
                <p className="text-2xl font-bold">{MOCK_PROPOSALS.length}</p>
                <p className="text-sm text-text-muted">Total Proposals</p>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="flex items-center gap-4 py-4">
              <div className="w-12 h-12 bg-success/10 rounded-full flex items-center justify-center">
                <CheckCircle className="h-6 w-6 text-success" />
              </div>
              <div>
                <p className="text-2xl font-bold">
                  {MOCK_PROPOSALS.filter((p) => p.status === ProposalStatus.Active).length}
                </p>
                <p className="text-sm text-text-muted">Active Votes</p>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="flex items-center gap-4 py-4">
              <div className="w-12 h-12 bg-primary/10 rounded-full flex items-center justify-center">
                <Users className="h-6 w-6 text-primary" />
              </div>
              <div>
                <p className="text-2xl font-bold">
                  {MOCK_PROPOSALS.reduce((acc, p) => acc + p.votesYes + p.votesNo + p.votesAbstain, 0)}
                </p>
                <p className="text-sm text-text-muted">Total Votes Cast</p>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Proposals List */}
        <Card>
          <CardHeader>
            <Tabs value={activeTab} onValueChange={setActiveTab}>
              <TabsList>
                <TabsTrigger value="all">All</TabsTrigger>
                <TabsTrigger value="active">Active</TabsTrigger>
                <TabsTrigger value="pending">Pending</TabsTrigger>
                <TabsTrigger value="passed">Passed</TabsTrigger>
              </TabsList>
            </Tabs>
          </CardHeader>
          <CardContent>
            {filteredProposals.length === 0 ? (
              <div className="text-center py-8 text-text-muted">
                <Vote className="h-12 w-12 mx-auto mb-4 opacity-30" />
                <p>No proposals found</p>
              </div>
            ) : (
              <div className="space-y-4">
                {filteredProposals.map((proposal) => {
                  const totalVotes = proposal.votesYes + proposal.votesNo + proposal.votesAbstain;
                  const yesPercentage = calculatePercentage(proposal.votesYes, totalVotes);
                  const noPercentage = calculatePercentage(proposal.votesNo, totalVotes);
                  
                  return (
                    <Link key={proposal.id} href={`/governance/${proposal.id}`}>
                      <Card hoverable className="overflow-hidden">
                        <CardContent className="p-4">
                          <div className="flex items-start justify-between gap-4 mb-3">
                            <div className="flex-1">
                              <div className="flex items-center gap-2 mb-1">
                                <Badge variant={getStatusBadgeVariant(proposal.status)}>
                                  {ProposalStatusLabels[proposal.status]}
                                </Badge>
                                <Badge variant="outline">
                                  {VotingMechanismLabels[proposal.votingMechanism]}
                                </Badge>
                              </div>
                              <h3 className="font-semibold text-lg">{proposal.title}</h3>
                              <p className="text-sm text-text-muted truncate-2">
                                {proposal.description}
                              </p>
                            </div>
                          </div>
                          
                          {/* Vote Progress */}
                          {totalVotes > 0 && (
                            <div className="mb-3">
                              <div className="flex justify-between text-sm mb-1">
                                <span className="text-success">Yes {yesPercentage.toFixed(1)}%</span>
                                <span className="text-error">No {noPercentage.toFixed(1)}%</span>
                              </div>
                              <div className="h-2 bg-muted rounded-full overflow-hidden flex">
                                <div
                                  className="h-full bg-success transition-all"
                                  style={{ width: `${yesPercentage}%` }}
                                />
                                <div
                                  className="h-full bg-error transition-all"
                                  style={{ width: `${noPercentage}%` }}
                                />
                              </div>
                            </div>
                          )}
                          
                          <div className="flex items-center justify-between text-sm text-text-muted">
                            <div className="flex items-center gap-4">
                              <span className="flex items-center gap-1">
                                <Users className="h-4 w-4" />
                                {totalVotes} votes
                              </span>
                              <span>Threshold: {proposal.threshold}</span>
                            </div>
                            <span className="flex items-center gap-1">
                              <Clock className="h-4 w-4" />
                              {formatRelativeTime(proposal.createdAt)}
                            </span>
                          </div>
                        </CardContent>
                      </Card>
                    </Link>
                  );
                })}
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </MainLayout>
  );
}

