"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { MainLayout } from "@/components/Navigation";
import { useTimeBank, useMemberStatus } from "@/hooks";
import { WalletConnectModal } from "@/components/WalletConnectModal";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
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
import { Badge } from "@/components/ui/badge";
import {
  Clock,
  Wallet,
  AlertCircle,
  ArrowRight,
  CheckCircle,
  Info,
} from "lucide-react";
import Link from "next/link";

// Activity types with IDs
const ACTIVITIES = [
  { id: 1, name: "Tutoring", description: "Academic tutoring and homework help" },
  { id: 2, name: "Mentoring", description: "Youth mentorship and guidance" },
  { id: 3, name: "Community Service", description: "General volunteer work" },
  { id: 4, name: "Home Repair", description: "Helping with home maintenance" },
  { id: 5, name: "Food Distribution", description: "Food bank and meal prep" },
  { id: 6, name: "Transportation", description: "Driving community members" },
  { id: 7, name: "Administrative", description: "Office and organizational support" },
  { id: 8, name: "Event Support", description: "Helping with community events" },
  { id: 9, name: "Other", description: "Other volunteer activities" },
];

export default function LogHoursPage() {
  const router = useRouter();
  const { connected } = useWallet();
  const { isMember, isLoading: memberLoading } = useMemberStatus();
  const { createRequest, isCreating } = useTimeBank();

  const [hours, setHours] = useState("");
  const [activityId, setActivityId] = useState("");
  const [showConfirmation, setShowConfirmation] = useState(false);
  const [showSuccess, setShowSuccess] = useState(false);

  const selectedActivity = ACTIVITIES.find((a) => a.id.toString() === activityId);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!hours || !activityId) return;
    setShowConfirmation(true);
  };

  const handleConfirm = () => {
    createRequest(
      { hours: parseInt(hours), activityId: parseInt(activityId) },
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
            Connect your wallet to log service hours and earn Time Dollars.
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
            You need to be a registered member to log service hours.
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
      <div className="max-w-2xl mx-auto">
        <div className="mb-6">
          <h1 className="text-2xl font-bold">Log Service Hours</h1>
          <p className="text-text-muted">
            Submit your volunteer hours for review and approval
          </p>
        </div>

        <Card>
          <CardHeader>
            <div className="flex items-center gap-3">
              <div className="w-12 h-12 bg-primary/10 rounded-lg flex items-center justify-center">
                <Clock className="h-6 w-6 text-primary" />
              </div>
              <div>
                <CardTitle>Service Request</CardTitle>
                <CardDescription>
                  Hours will be reviewed by a validator before Time Dollars are minted
                </CardDescription>
              </div>
            </div>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-6">
              {/* Hours Input */}
              <div className="space-y-2">
                <Label htmlFor="hours" required>
                  Number of Hours
                </Label>
                <Input
                  id="hours"
                  type="number"
                  min="1"
                  max="24"
                  placeholder="Enter hours worked"
                  value={hours}
                  onChange={(e) => setHours(e.target.value)}
                />
                <p className="text-xs text-text-muted">
                  Enter a whole number between 1 and 24
                </p>
              </div>

              {/* Activity Selection */}
              <div className="space-y-2">
                <Label htmlFor="activity" required>
                  Activity Type
                </Label>
                <Select value={activityId} onValueChange={setActivityId}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select an activity..." />
                  </SelectTrigger>
                  <SelectContent>
                    {ACTIVITIES.map((activity) => (
                      <SelectItem key={activity.id} value={activity.id.toString()}>
                        {activity.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                
                {selectedActivity && (
                  <div className="flex items-start gap-2 p-3 bg-muted rounded-lg mt-2">
                    <Info className="h-4 w-4 text-primary mt-0.5 flex-shrink-0" />
                    <p className="text-sm text-text-muted">
                      {selectedActivity.description}
                    </p>
                  </div>
                )}
              </div>

              {/* Summary */}
              {hours && activityId && (
                <div className="p-4 border rounded-lg bg-muted/50">
                  <p className="text-sm font-medium mb-2">Request Summary</p>
                  <div className="flex items-center justify-between">
                    <span className="text-text-muted">Hours</span>
                    <Badge variant="secondary">{hours} hour(s)</Badge>
                  </div>
                  <div className="flex items-center justify-between mt-2">
                    <span className="text-text-muted">Activity</span>
                    <span className="font-medium">{selectedActivity?.name}</span>
                  </div>
                  <div className="flex items-center justify-between mt-2">
                    <span className="text-text-muted">Time Dollars Earned</span>
                    <span className="font-bold text-primary">{hours} TD</span>
                  </div>
                </div>
              )}

              {/* Submit Button */}
              <Button
                type="submit"
                className="w-full"
                size="lg"
                disabled={!hours || !activityId || isCreating}
              >
                Submit Request
              </Button>
            </form>
          </CardContent>
        </Card>

        {/* Confirmation Dialog */}
        <Dialog open={showConfirmation} onOpenChange={setShowConfirmation}>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Confirm Service Request</DialogTitle>
              <DialogDescription>
                Please review your request before submitting
              </DialogDescription>
            </DialogHeader>
            <div className="space-y-4 py-4">
              <div className="p-4 border rounded-lg">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-text-muted">Hours</span>
                  <span className="font-bold">{hours}</span>
                </div>
                <div className="flex items-center justify-between mb-2">
                  <span className="text-text-muted">Activity</span>
                  <span className="font-medium">{selectedActivity?.name}</span>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-text-muted">Reward</span>
                  <Badge variant="secondary">{hours} Time Dollars</Badge>
                </div>
              </div>
              <p className="text-sm text-text-muted">
                After submission, a validator will review and approve your request.
                Once approved, Time Dollars will be minted to your account.
              </p>
            </div>
            <DialogFooter>
              <Button variant="outline" onClick={() => setShowConfirmation(false)}>
                Cancel
              </Button>
              <Button onClick={handleConfirm} isLoading={isCreating} loadingText="Submitting...">
                Confirm & Submit
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
              <DialogTitle className="text-center">Request Submitted!</DialogTitle>
              <DialogDescription className="text-center">
                Your service hours have been submitted for review
              </DialogDescription>
            </DialogHeader>
            <div className="py-4 text-center">
              <p className="text-sm text-text-muted">
                A validator will review your request. Once approved, {hours} Time Dollars
                will be minted to your account.
              </p>
            </div>
            <DialogFooter className="flex-col sm:flex-row gap-2">
              <Button
                variant="outline"
                onClick={() => {
                  setShowSuccess(false);
                  setHours("");
                  setActivityId("");
                }}
              >
                Log More Hours
              </Button>
              <Button onClick={() => router.push("/volunteer/dashboard")}>
                Go to Dashboard
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>
    </MainLayout>
  );
}

