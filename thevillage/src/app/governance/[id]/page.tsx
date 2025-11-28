"use client";

import { useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { MainLayout } from "@/components/Navigation";
import { useProposal, useVote, useMemberStatus, useTimeToken } from "@/hooks";
import { WalletConnectModal } from "@/components/WalletConnectModal";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Vote,
  Wallet,
  AlertCircle,
  CheckCircle,
  XCircle,
  MinusCircle,
  ArrowLeft,
  Clock,
  Users,
  Info,
} from "lucide-react";
import Link from "next/link";
import {
  ProposalStatus,
  ProposalStatusLabels,
  VotingMechanism,
  VotingMechanismLabels,
  VotingMechanismDescriptions,
  VoteChoice,
  VoteChoiceLabels,
} from "@/types/contract";
import { formatNumber, formatRelativeTime, calculatePercentage } from "@/lib/utils";
import { formatAddress } from "@/lib/config";

// Mock proposal data (in real app, this would come from the useProposal hook)
const MOCK_PROPOSAL = {
  id: 1,
  proposer: "0x1234567890abcdef1234567890abcdef12345678",
  title: "Fund Community Garden Project",
  description: `This proposal seeks to allocate 5000 APT from the treasury to develop a community garden in the Homewood neighborhood.

## Background
The Homewood neighborhood has limited access to fresh, locally-grown produce. A community garden would provide:
- Fresh vegetables and fruits for residents
- Educational opportunities for youth
- Community gathering space
- Job training in urban agriculture

## Budget Breakdown
- Land preparation: 1000 APT
- Seeds and plants: 500 APT
- Tools and equipment: 800 APT
- Water system installation: 1200 APT
- Fencing and structures: 1000 APT
- Reserve fund: 500 APT

## Timeline
- Month 1-2: Site preparation
- Month 3-4: Planting and initial cultivation
- Month 5+: Community programming and harvest

## Success Metrics
- 50+ families served in Year 1
- 10+ volunteer gardeners trained
- Monthly community events`,
  status: ProposalStatus.Active,
  votesYes: 150,
  votesNo: 45,
  votesAbstain: 20,
  threshold: 200,
  votingMechanism: VotingMechanism.TokenWeighted,
  createdAt: Date.now() - 86400000 * 3,
  endsAt: Date.now() + 86400000 * 4,
};

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

export default function ProposalDetailPage() {
  const params = useParams();
  const router = useRouter();
  const proposalId = parseInt(params.id as string);

  const { connected } = useWallet();
  const { isMember, isLoading: memberLoading } = useMemberStatus();
  const { balance: tokenBalance } = useTimeToken();
  const { mutate: vote, isPending: isVoting } = useVote();

  const [selectedVote, setSelectedVote] = useState<VoteChoice | null>(null);
  const [showVoteDialog, setShowVoteDialog] = useState(false);
  const [showSuccessDialog, setShowSuccessDialog] = useState(false);

  // In real app, use the useProposal hook
  const proposal = MOCK_PROPOSAL;
  const isLoading = false;

  const totalVotes = proposal.votesYes + proposal.votesNo + proposal.votesAbstain;
  const yesPercentage = calculatePercentage(proposal.votesYes, totalVotes);
  const noPercentage = calculatePercentage(proposal.votesNo, totalVotes);
  const abstainPercentage = calculatePercentage(proposal.votesAbstain, totalVotes);
  const thresholdProgress = calculatePercentage(proposal.votesYes, proposal.threshold);

  const handleVoteClick = (choice: VoteChoice) => {
    setSelectedVote(choice);
    setShowVoteDialog(true);
  };

  const handleConfirmVote = () => {
    if (selectedVote === null) return;
    vote(
      { proposalId, choice: selectedVote },
      {
        onSuccess: () => {
          setShowVoteDialog(false);
          setShowSuccessDialog(true);
        },
      }
    );
  };

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
            Connect your wallet to view and vote on proposals.
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
          <Skeleton className="h-64" />
          <Skeleton className="h-48" />
        </div>
      </MainLayout>
    );
  }

  return (
    <MainLayout>
      <div className="space-y-6">
        {/* Back Button */}
        <Button variant="ghost" onClick={() => router.push("/governance")} className="gap-2">
          <ArrowLeft className="h-4 w-4" />
          Back to Proposals
        </Button>

        {/* Proposal Header */}
        <Card>
          <CardHeader>
            <div className="flex flex-wrap items-center gap-2 mb-2">
              <Badge variant={getStatusBadgeVariant(proposal.status)}>
                {ProposalStatusLabels[proposal.status]}
              </Badge>
              <Badge variant="outline">
                {VotingMechanismLabels[proposal.votingMechanism]}
              </Badge>
              <Badge variant="outline">#{proposal.id}</Badge>
            </div>
            <CardTitle className="text-2xl">{proposal.title}</CardTitle>
            <CardDescription className="flex items-center gap-4 mt-2">
              <span>By {formatAddress(proposal.proposer)}</span>
              <span className="flex items-center gap-1">
                <Clock className="h-4 w-4" />
                {formatRelativeTime(proposal.createdAt)}
              </span>
            </CardDescription>
          </CardHeader>
          <CardContent>
            {/* Description */}
            <div className="prose prose-sm max-w-none mb-6">
              <pre className="whitespace-pre-wrap font-sans text-sm text-text-muted">
                {proposal.description}
              </pre>
            </div>

            {/* Voting Mechanism Info */}
            <div className="flex items-start gap-2 p-4 bg-muted rounded-lg mb-6">
              <Info className="h-5 w-5 text-primary mt-0.5 flex-shrink-0" />
              <div>
                <p className="font-medium">{VotingMechanismLabels[proposal.votingMechanism]}</p>
                <p className="text-sm text-text-muted">
                  {VotingMechanismDescriptions[proposal.votingMechanism]}
                </p>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Vote Results */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg flex items-center gap-2">
              <Users className="h-5 w-5" />
              Vote Results
            </CardTitle>
            <CardDescription>
              {totalVotes} total votes • Threshold: {proposal.threshold}
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            {/* Threshold Progress */}
            <div>
              <div className="flex justify-between text-sm mb-2">
                <span className="font-medium">Threshold Progress</span>
                <span>
                  {proposal.votesYes} / {proposal.threshold} ({thresholdProgress.toFixed(1)}%)
                </span>
              </div>
              <Progress value={Math.min(thresholdProgress, 100)} className="h-3" />
            </div>

            {/* Vote Breakdown */}
            <div className="grid sm:grid-cols-3 gap-4">
              <div className="p-4 border rounded-lg text-center">
                <CheckCircle className="h-8 w-8 text-success mx-auto mb-2" />
                <p className="text-2xl font-bold text-success">{proposal.votesYes}</p>
                <p className="text-sm text-text-muted">Yes ({yesPercentage.toFixed(1)}%)</p>
              </div>
              <div className="p-4 border rounded-lg text-center">
                <XCircle className="h-8 w-8 text-error mx-auto mb-2" />
                <p className="text-2xl font-bold text-error">{proposal.votesNo}</p>
                <p className="text-sm text-text-muted">No ({noPercentage.toFixed(1)}%)</p>
              </div>
              <div className="p-4 border rounded-lg text-center">
                <MinusCircle className="h-8 w-8 text-text-muted mx-auto mb-2" />
                <p className="text-2xl font-bold">{proposal.votesAbstain}</p>
                <p className="text-sm text-text-muted">Abstain ({abstainPercentage.toFixed(1)}%)</p>
              </div>
            </div>

            {/* Vote Bar */}
            {totalVotes > 0 && (
              <div className="h-4 bg-muted rounded-full overflow-hidden flex">
                <div
                  className="h-full bg-success transition-all"
                  style={{ width: `${yesPercentage}%` }}
                />
                <div
                  className="h-full bg-error transition-all"
                  style={{ width: `${noPercentage}%` }}
                />
                <div
                  className="h-full bg-gray-400 transition-all"
                  style={{ width: `${abstainPercentage}%` }}
                />
              </div>
            )}
          </CardContent>
        </Card>

        {/* Vote Actions */}
        {proposal.status === ProposalStatus.Active && isMember && (
          <Card>
            <CardHeader>
              <CardTitle className="text-lg">Cast Your Vote</CardTitle>
              <CardDescription>
                Your voting power: {formatNumber(tokenBalance)} TD
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="grid sm:grid-cols-3 gap-4">
                <Button
                  variant="outline"
                  size="lg"
                  className="h-20 flex-col gap-2 border-success hover:bg-success hover:text-white"
                  onClick={() => handleVoteClick(VoteChoice.Yes)}
                >
                  <CheckCircle className="h-6 w-6" />
                  Vote Yes
                </Button>
                <Button
                  variant="outline"
                  size="lg"
                  className="h-20 flex-col gap-2 border-error hover:bg-error hover:text-white"
                  onClick={() => handleVoteClick(VoteChoice.No)}
                >
                  <XCircle className="h-6 w-6" />
                  Vote No
                </Button>
                <Button
                  variant="outline"
                  size="lg"
                  className="h-20 flex-col gap-2"
                  onClick={() => handleVoteClick(VoteChoice.Abstain)}
                >
                  <MinusCircle className="h-6 w-6" />
                  Abstain
                </Button>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Vote Confirmation Dialog */}
        <Dialog open={showVoteDialog} onOpenChange={setShowVoteDialog}>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Confirm Your Vote</DialogTitle>
              <DialogDescription>
                You are about to cast your vote on this proposal
              </DialogDescription>
            </DialogHeader>
            <div className="py-4">
              <div className="p-4 border rounded-lg space-y-3">
                <div className="flex justify-between">
                  <span className="text-text-muted">Your Vote</span>
                  <Badge
                    variant={
                      selectedVote === VoteChoice.Yes
                        ? "success"
                        : selectedVote === VoteChoice.No
                        ? "error"
                        : "default"
                    }
                  >
                    {selectedVote !== null && VoteChoiceLabels[selectedVote]}
                  </Badge>
                </div>
                <div className="flex justify-between">
                  <span className="text-text-muted">Voting Power</span>
                  <span className="font-medium">{formatNumber(tokenBalance)} TD</span>
                </div>
              </div>
              <p className="text-sm text-text-muted mt-4">
                Your vote will be recorded on the blockchain and cannot be changed.
              </p>
            </div>
            <DialogFooter>
              <Button variant="outline" onClick={() => setShowVoteDialog(false)}>
                Cancel
              </Button>
              <Button onClick={handleConfirmVote} isLoading={isVoting} loadingText="Voting...">
                Confirm Vote
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>

        {/* Success Dialog */}
        <Dialog open={showSuccessDialog} onOpenChange={setShowSuccessDialog}>
          <DialogContent>
            <DialogHeader>
              <div className="mx-auto w-16 h-16 bg-success/10 rounded-full flex items-center justify-center mb-4">
                <CheckCircle className="h-8 w-8 text-success" />
              </div>
              <DialogTitle className="text-center">Vote Cast Successfully!</DialogTitle>
              <DialogDescription className="text-center">
                Your vote has been recorded on the blockchain
              </DialogDescription>
            </DialogHeader>
            <DialogFooter>
              <Button onClick={() => setShowSuccessDialog(false)} className="w-full">
                Done
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>
    </MainLayout>
  );
}

