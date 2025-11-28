"use client";

import { useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { MainLayout } from "@/components/Navigation";
import { useMemberStatus, useComplianceStatus, useTreasury, useTimeToken } from "@/hooks";
import { WalletConnectModal } from "@/components/WalletConnectModal";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
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
  Building2,
  MapPin,
  Clock,
  DollarSign,
  Users,
  ArrowLeft,
  CheckCircle,
  Target,
  Calendar,
  TrendingUp,
  Wallet,
  AlertTriangle,
} from "lucide-react";
import { PoolStatus, PoolStatusLabels } from "@/types/contract";
import { formatNumber, formatDate, calculatePercentage } from "@/lib/utils";
import { octasToApt, aptToOctas } from "@/lib/config";

// Mock project data
const MOCK_PROJECT = {
  id: 1,
  name: "Homewood Family Home Restoration",
  description: `This project aims to completely restore a distressed family home in the Homewood neighborhood. The home has been vacant for several years and requires significant work to make it safe and livable again.

## Project Scope
- Complete roof replacement
- Plumbing system overhaul  
- Electrical system upgrade to code
- HVAC installation
- Interior renovation including drywall, flooring, and paint
- Exterior siding and landscaping

## Impact
This restoration will provide safe, affordable housing for a family in need while also improving the neighborhood aesthetics and property values.

## Timeline
- Month 1-2: Structural and roofing work
- Month 3-4: Plumbing and electrical
- Month 5-6: Interior finishing
- Month 7: Final inspection and family move-in`,
  location: "7543 Hamilton Ave, Homewood, PA 15208",
  targetFunding: 50000 * 100000000,
  currentFunding: 35000 * 100000000,
  targetHours: 500,
  currentHours: 320,
  status: PoolStatus.Active,
  category: "Home Repair",
  createdAt: Date.now() - 86400000 * 30,
  milestones: [
    { id: 1, description: "Roof replacement", isCompleted: true, completedAt: Date.now() - 86400000 * 20 },
    { id: 2, description: "Plumbing system", isCompleted: true, completedAt: Date.now() - 86400000 * 10 },
    { id: 3, description: "Electrical upgrade", isCompleted: false },
    { id: 4, description: "HVAC installation", isCompleted: false },
    { id: 5, description: "Interior renovation", isCompleted: false },
    { id: 6, description: "Final inspection", isCompleted: false },
  ],
  contributors: [
    { address: "0x1234...5678", amount: 10000, type: "funding" },
    { address: "0xabcd...ef12", amount: 80, type: "hours" },
    { address: "0x9876...5432", amount: 5000, type: "funding" },
  ],
};

function getStatusBadgeVariant(status: PoolStatus): "default" | "secondary" | "success" | "warning" | "error" {
  const map: Record<PoolStatus, "default" | "secondary" | "success" | "warning" | "error"> = {
    [PoolStatus.Pending]: "warning",
    [PoolStatus.Active]: "secondary",
    [PoolStatus.Funded]: "success",
    [PoolStatus.Completed]: "default",
    [PoolStatus.Defaulted]: "error",
  };
  return map[status];
}

export default function ProjectDetailPage() {
  const params = useParams();
  const router = useRouter();
  const projectId = parseInt(params.id as string);

  const { connected } = useWallet();
  const { isMember } = useMemberStatus();
  const { isWhitelisted } = useComplianceStatus();
  const { balanceInApt } = useTreasury();
  const { balance: timeTokenBalance } = useTimeToken();

  const [contributionType, setContributionType] = useState<"funding" | "hours">("funding");
  const [fundingAmount, setFundingAmount] = useState("");
  const [hoursAmount, setHoursAmount] = useState("");
  const [showContributeDialog, setShowContributeDialog] = useState(false);
  const [showSuccessDialog, setShowSuccessDialog] = useState(false);
  const [isContributing, setIsContributing] = useState(false);

  const project = MOCK_PROJECT;
  const fundingProgress = calculatePercentage(project.currentFunding, project.targetFunding);
  const hoursProgress = calculatePercentage(project.currentHours, project.targetHours);
  const completedMilestones = project.milestones.filter((m) => m.isCompleted).length;

  const handleContribute = () => {
    setIsContributing(true);
    // Simulate contribution
    setTimeout(() => {
      setIsContributing(false);
      setShowContributeDialog(false);
      setShowSuccessDialog(true);
      setFundingAmount("");
      setHoursAmount("");
    }, 2000);
  };

  return (
    <MainLayout>
      <div className="space-y-6">
        {/* Back Button */}
        <Button variant="ghost" onClick={() => router.push("/projects")} className="gap-2">
          <ArrowLeft className="h-4 w-4" />
          Back to Projects
        </Button>

        {/* Project Header */}
        <Card>
          {/* Project Image/Placeholder */}
          <div className="h-64 bg-gradient-to-br from-primary/20 to-secondary/20 flex items-center justify-center rounded-t-lg">
            <Building2 className="h-24 w-24 text-primary/40" />
          </div>
          
          <CardHeader>
            <div className="flex flex-wrap items-center gap-2 mb-2">
              <Badge variant={getStatusBadgeVariant(project.status)}>
                {PoolStatusLabels[project.status]}
              </Badge>
              <Badge variant="outline">{project.category}</Badge>
              <Badge variant="outline">#{project.id}</Badge>
            </div>
            <CardTitle className="text-2xl">{project.name}</CardTitle>
            <CardDescription className="flex flex-wrap items-center gap-4 mt-2">
              <span className="flex items-center gap-1">
                <MapPin className="h-4 w-4" />
                {project.location}
              </span>
              <span className="flex items-center gap-1">
                <Calendar className="h-4 w-4" />
                Started {formatDate(project.createdAt)}
              </span>
            </CardDescription>
          </CardHeader>
        </Card>

        {/* Progress Cards */}
        <div className="grid md:grid-cols-2 gap-6">
          <Card>
            <CardHeader>
              <CardTitle className="text-lg flex items-center gap-2">
                <DollarSign className="h-5 w-5 text-secondary" />
                Funding Progress
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="text-3xl font-bold text-secondary">
                {formatNumber(octasToApt(project.currentFunding), 0)}
                <span className="text-lg font-normal text-text-muted">
                  {" "}/ {formatNumber(octasToApt(project.targetFunding), 0)} APT
                </span>
              </div>
              <Progress value={fundingProgress} className="h-3" />
              <p className="text-sm text-text-muted">
                {fundingProgress.toFixed(1)}% funded
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle className="text-lg flex items-center gap-2">
                <Clock className="h-5 w-5 text-primary" />
                Service Hours
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="text-3xl font-bold text-primary">
                {project.currentHours}
                <span className="text-lg font-normal text-text-muted">
                  {" "}/ {project.targetHours} hours
                </span>
              </div>
              <Progress value={hoursProgress} className="h-3" indicatorClassName="bg-primary" />
              <p className="text-sm text-text-muted">
                {hoursProgress.toFixed(1)}% complete
              </p>
            </CardContent>
          </Card>
        </div>

        {/* Contribute CTA */}
        {project.status === PoolStatus.Active && (
          <Card className="border-primary">
            <CardContent className="flex flex-col md:flex-row items-center justify-between gap-4 py-6">
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 bg-primary/10 rounded-full flex items-center justify-center">
                  <TrendingUp className="h-6 w-6 text-primary" />
                </div>
                <div>
                  <p className="font-semibold">Ready to make an impact?</p>
                  <p className="text-sm text-text-muted">
                    Contribute funds or service hours to this project
                  </p>
                </div>
              </div>
              {connected ? (
                <Button size="lg" onClick={() => setShowContributeDialog(true)}>
                  Contribute Now
                </Button>
              ) : (
                <WalletConnectModal
                  trigger={
                    <Button size="lg" className="gap-2">
                      <Wallet className="h-5 w-5" />
                      Connect to Contribute
                    </Button>
                  }
                />
              )}
            </CardContent>
          </Card>
        )}

        {/* Tabs for Details */}
        <Card>
          <Tabs defaultValue="about">
            <CardHeader>
              <TabsList>
                <TabsTrigger value="about">About</TabsTrigger>
                <TabsTrigger value="milestones">Milestones</TabsTrigger>
                <TabsTrigger value="contributors">Contributors</TabsTrigger>
              </TabsList>
            </CardHeader>
            <CardContent>
              {/* About Tab */}
              <TabsContent value="about">
                <div className="prose prose-sm max-w-none">
                  <pre className="whitespace-pre-wrap font-sans text-sm text-text-muted">
                    {project.description}
                  </pre>
                </div>
              </TabsContent>

              {/* Milestones Tab */}
              <TabsContent value="milestones">
                <div className="space-y-4">
                  <div className="flex items-center justify-between mb-4">
                    <p className="text-text-muted">
                      {completedMilestones} of {project.milestones.length} milestones completed
                    </p>
                    <Badge variant="secondary">
                      {calculatePercentage(completedMilestones, project.milestones.length).toFixed(0)}%
                    </Badge>
                  </div>
                  {project.milestones.map((milestone, index) => (
                    <div
                      key={milestone.id}
                      className={`flex items-start gap-4 p-4 rounded-lg ${
                        milestone.isCompleted ? "bg-success/5" : "bg-muted"
                      }`}
                    >
                      <div
                        className={`w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 ${
                          milestone.isCompleted
                            ? "bg-success text-white"
                            : "bg-muted-foreground/20"
                        }`}
                      >
                        {milestone.isCompleted ? (
                          <CheckCircle className="h-5 w-5" />
                        ) : (
                          <span className="text-sm font-medium">{index + 1}</span>
                        )}
                      </div>
                      <div className="flex-1">
                        <p className="font-medium">{milestone.description}</p>
                        {milestone.isCompleted && milestone.completedAt && (
                          <p className="text-sm text-success">
                            Completed {formatDate(milestone.completedAt)}
                          </p>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              </TabsContent>

              {/* Contributors Tab */}
              <TabsContent value="contributors">
                <div className="space-y-3">
                  {project.contributors.length === 0 ? (
                    <p className="text-center text-text-muted py-8">
                      No contributors yet. Be the first!
                    </p>
                  ) : (
                    project.contributors.map((contributor, index) => (
                      <div
                        key={index}
                        className="flex items-center justify-between p-4 border rounded-lg"
                      >
                        <div className="flex items-center gap-3">
                          <div className="w-10 h-10 bg-primary/10 rounded-full flex items-center justify-center">
                            <Users className="h-5 w-5 text-primary" />
                          </div>
                          <span className="font-mono text-sm">{contributor.address}</span>
                        </div>
                        <Badge variant={contributor.type === "funding" ? "secondary" : "default"}>
                          {contributor.type === "funding"
                            ? `${formatNumber(contributor.amount, 0)} APT`
                            : `${contributor.amount} hours`}
                        </Badge>
                      </div>
                    ))
                  )}
                </div>
              </TabsContent>
            </CardContent>
          </Tabs>
        </Card>

        {/* Contribute Dialog */}
        <Dialog open={showContributeDialog} onOpenChange={setShowContributeDialog}>
          <DialogContent className="max-w-md">
            <DialogHeader>
              <DialogTitle>Contribute to Project</DialogTitle>
              <DialogDescription>
                Choose how you&apos;d like to support this project
              </DialogDescription>
            </DialogHeader>
            
            <Tabs value={contributionType} onValueChange={(v) => setContributionType(v as "funding" | "hours")}>
              <TabsList className="grid w-full grid-cols-2">
                <TabsTrigger value="funding" className="gap-2">
                  <DollarSign className="h-4 w-4" />
                  Funding
                </TabsTrigger>
                <TabsTrigger value="hours" className="gap-2">
                  <Clock className="h-4 w-4" />
                  Time Dollars
                </TabsTrigger>
              </TabsList>

              <TabsContent value="funding" className="space-y-4 mt-4">
                {!isWhitelisted && (
                  <div className="flex items-start gap-2 p-3 bg-warning/10 rounded-lg">
                    <AlertTriangle className="h-4 w-4 text-warning mt-0.5" />
                    <p className="text-sm text-warning">
                      KYC verification required to contribute funds
                    </p>
                  </div>
                )}
                <div className="space-y-2">
                  <div className="flex justify-between">
                    <Label>Amount (APT)</Label>
                    <span className="text-sm text-text-muted">
                      Available: {formatNumber(balanceInApt, 4)} APT
                    </span>
                  </div>
                  <Input
                    type="number"
                    min="0"
                    step="0.01"
                    placeholder="0.00"
                    value={fundingAmount}
                    onChange={(e) => setFundingAmount(e.target.value)}
                    disabled={!isWhitelisted}
                  />
                </div>
              </TabsContent>

              <TabsContent value="hours" className="space-y-4 mt-4">
                <div className="space-y-2">
                  <div className="flex justify-between">
                    <Label>Time Dollars</Label>
                    <span className="text-sm text-text-muted">
                      Available: {formatNumber(timeTokenBalance, 0)} TD
                    </span>
                  </div>
                  <Input
                    type="number"
                    min="0"
                    placeholder="0"
                    value={hoursAmount}
                    onChange={(e) => setHoursAmount(e.target.value)}
                  />
                </div>
              </TabsContent>
            </Tabs>

            <DialogFooter className="mt-4">
              <Button variant="outline" onClick={() => setShowContributeDialog(false)}>
                Cancel
              </Button>
              <Button
                onClick={handleContribute}
                isLoading={isContributing}
                loadingText="Contributing..."
                disabled={
                  (contributionType === "funding" && (!fundingAmount || !isWhitelisted)) ||
                  (contributionType === "hours" && !hoursAmount)
                }
              >
                Contribute
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
              <DialogTitle className="text-center">Contribution Successful!</DialogTitle>
              <DialogDescription className="text-center">
                Thank you for supporting this community project
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

