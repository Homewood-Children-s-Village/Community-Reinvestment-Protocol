"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { MainLayout } from "@/components/Navigation";
import { useCreateProposal, useMemberStatus } from "@/hooks";
import { WalletConnectModal } from "@/components/WalletConnectModal";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import {
  Vote,
  Wallet,
  AlertCircle,
  Info,
  CheckCircle,
} from "lucide-react";
import Link from "next/link";
import { VotingMechanism, VotingMechanismLabels, VotingMechanismDescriptions } from "@/types/contract";

export default function CreateProposalPage() {
  const router = useRouter();
  const { connected } = useWallet();
  const { isMember, isLoading: memberLoading } = useMemberStatus();
  const { mutate: createProposal, isPending } = useCreateProposal();

  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [threshold, setThreshold] = useState("");
  const [votingMechanism, setVotingMechanism] = useState("");
  const [showConfirmation, setShowConfirmation] = useState(false);
  const [showSuccess, setShowSuccess] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title || !description || !threshold || !votingMechanism) return;
    setShowConfirmation(true);
  };

  const handleConfirm = () => {
    createProposal(
      {
        title,
        description,
        threshold: parseInt(threshold),
        votingMechanism: parseInt(votingMechanism) as VotingMechanism,
      },
      {
        onSuccess: () => {
          setShowConfirmation(false);
          setShowSuccess(true);
        },
        onError: () => {
          setShowConfirmation(false);
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
            Connect your wallet to create a governance proposal.
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
            You need to be a registered member to create proposals.
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
      <div className="max-w-2xl mx-auto">
        <div className="mb-6">
          <h1 className="text-2xl font-bold">Create Proposal</h1>
          <p className="text-text-muted">
            Submit a new proposal for community voting
          </p>
        </div>

        <Card>
          <CardHeader>
            <div className="flex items-center gap-3">
              <div className="w-12 h-12 bg-primary/10 rounded-lg flex items-center justify-center">
                <Vote className="h-6 w-6 text-primary" />
              </div>
              <div>
                <CardTitle>New Proposal</CardTitle>
                <CardDescription>
                  Fill in the details for your governance proposal
                </CardDescription>
              </div>
            </div>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-6">
              {/* Title */}
              <div className="space-y-2">
                <Label htmlFor="title" required>
                  Proposal Title
                </Label>
                <Input
                  id="title"
                  placeholder="Enter a clear, concise title"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  maxLength={100}
                />
                <p className="text-xs text-text-muted">
                  {title.length}/100 characters
                </p>
              </div>

              {/* Description */}
              <div className="space-y-2">
                <Label htmlFor="description" required>
                  Description
                </Label>
                <Textarea
                  id="description"
                  placeholder="Describe your proposal in detail. Include the problem, proposed solution, and expected outcomes."
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  rows={6}
                />
              </div>

              {/* Voting Mechanism */}
              <div className="space-y-2">
                <div className="flex items-center gap-2">
                  <Label htmlFor="votingMechanism" required>
                    Voting Mechanism
                  </Label>
                  <TooltipProvider>
                    <Tooltip>
                      <TooltipTrigger asChild>
                        <Info className="h-4 w-4 text-text-muted cursor-help" />
                      </TooltipTrigger>
                      <TooltipContent className="max-w-xs">
                        <p>Choose how votes will be counted for this proposal</p>
                      </TooltipContent>
                    </Tooltip>
                  </TooltipProvider>
                </div>
                <Select value={votingMechanism} onValueChange={setVotingMechanism}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select a voting mechanism..." />
                  </SelectTrigger>
                  <SelectContent>
                    {Object.entries(VotingMechanismLabels).map(([key, label]) => (
                      <SelectItem key={key} value={key}>
                        {label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                
                {votingMechanism && (
                  <div className="flex items-start gap-2 p-3 bg-muted rounded-lg mt-2">
                    <Info className="h-4 w-4 text-primary mt-0.5 flex-shrink-0" />
                    <p className="text-sm text-text-muted">
                      {VotingMechanismDescriptions[parseInt(votingMechanism) as VotingMechanism]}
                    </p>
                  </div>
                )}
              </div>

              {/* Threshold */}
              <div className="space-y-2">
                <div className="flex items-center gap-2">
                  <Label htmlFor="threshold" required>
                    Vote Threshold
                  </Label>
                  <TooltipProvider>
                    <Tooltip>
                      <TooltipTrigger asChild>
                        <Info className="h-4 w-4 text-text-muted cursor-help" />
                      </TooltipTrigger>
                      <TooltipContent className="max-w-xs">
                        <p>Minimum number of votes required for the proposal to pass</p>
                      </TooltipContent>
                    </Tooltip>
                  </TooltipProvider>
                </div>
                <Input
                  id="threshold"
                  type="number"
                  min="1"
                  placeholder="Enter minimum votes required"
                  value={threshold}
                  onChange={(e) => setThreshold(e.target.value)}
                />
              </div>

              {/* Submit Button */}
              <Button
                type="submit"
                className="w-full"
                size="lg"
                disabled={!title || !description || !threshold || !votingMechanism || isPending}
              >
                Preview Proposal
              </Button>
            </form>
          </CardContent>
        </Card>

        {/* Confirmation Dialog */}
        <Dialog open={showConfirmation} onOpenChange={setShowConfirmation}>
          <DialogContent className="max-w-lg">
            <DialogHeader>
              <DialogTitle>Confirm Proposal</DialogTitle>
              <DialogDescription>
                Review your proposal before submitting to the blockchain
              </DialogDescription>
            </DialogHeader>
            <div className="space-y-4 py-4">
              <div className="space-y-2">
                <p className="text-sm text-text-muted">Title</p>
                <p className="font-medium">{title}</p>
              </div>
              <div className="space-y-2">
                <p className="text-sm text-text-muted">Description</p>
                <p className="text-sm">{description}</p>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <p className="text-sm text-text-muted">Voting Mechanism</p>
                  <p className="font-medium">
                    {votingMechanism && VotingMechanismLabels[parseInt(votingMechanism) as VotingMechanism]}
                  </p>
                </div>
                <div>
                  <p className="text-sm text-text-muted">Threshold</p>
                  <p className="font-medium">{threshold} votes</p>
                </div>
              </div>
            </div>
            <DialogFooter>
              <Button variant="outline" onClick={() => setShowConfirmation(false)}>
                Edit
              </Button>
              <Button onClick={handleConfirm} isLoading={isPending} loadingText="Submitting...">
                Submit Proposal
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>

        {/* Success Dialog */}
        <Dialog open={showSuccess} onOpenChange={setShowSuccess}>
          <DialogContent>
            <DialogHeader>
              <div className="mx-auto w-16 h-16 bg-success/10 rounded-full flex items-center justify-center mb-4">
                <CheckCircle className="h-8 w-8 text-success" />
              </div>
              <DialogTitle className="text-center">Proposal Created!</DialogTitle>
              <DialogDescription className="text-center">
                Your proposal has been submitted for community voting
              </DialogDescription>
            </DialogHeader>
            <DialogFooter className="flex-col sm:flex-row gap-2">
              <Button
                variant="outline"
                onClick={() => {
                  setShowSuccess(false);
                  setTitle("");
                  setDescription("");
                  setThreshold("");
                  setVotingMechanism("");
                }}
              >
                Create Another
              </Button>
              <Button onClick={() => router.push("/governance")}>
                View All Proposals
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>
    </MainLayout>
  );
}

