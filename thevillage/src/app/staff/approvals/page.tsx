"use client";

import { useState } from "react";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { MainLayout } from "@/components/Navigation";
import { useMemberStatus, useApproveRequest } from "@/hooks";
import { WalletConnectModal } from "@/components/WalletConnectModal";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  ClipboardCheck,
  Wallet,
  AlertCircle,
  CheckCircle,
  Search,
  Clock,
  User,
} from "lucide-react";
import Link from "next/link";
import { formatAddress } from "@/lib/config";
import { formatRelativeTime } from "@/lib/utils";
import { RequestStatus, RequestStatusLabels } from "@/types/contract";

// Mock pending requests for demonstration
const MOCK_REQUESTS = [
  {
    id: 1,
    requester: "0x1234567890abcdef1234567890abcdef12345678",
    hours: 4,
    activityId: 1,
    activityName: "Tutoring",
    status: RequestStatus.Pending,
    createdAt: Date.now() - 3600000, // 1 hour ago
  },
  {
    id: 2,
    requester: "0xabcdef1234567890abcdef1234567890abcdef12",
    hours: 2,
    activityId: 3,
    activityName: "Community Service",
    status: RequestStatus.Pending,
    createdAt: Date.now() - 7200000, // 2 hours ago
  },
  {
    id: 3,
    requester: "0x9876543210fedcba9876543210fedcba98765432",
    hours: 6,
    activityId: 4,
    activityName: "Home Repair",
    status: RequestStatus.Pending,
    createdAt: Date.now() - 86400000, // 1 day ago
  },
];

export default function StaffApprovalsPage() {
  const { connected } = useWallet();
  const { isMember, isValidator, isLoading: memberLoading } = useMemberStatus();
  const { mutate: approveRequest, isPending: isApproving } = useApproveRequest();

  const [searchQuery, setSearchQuery] = useState("");
  const [selectedRequest, setSelectedRequest] = useState<typeof MOCK_REQUESTS[0] | null>(null);
  const [showApprovalDialog, setShowApprovalDialog] = useState(false);

  const filteredRequests = MOCK_REQUESTS.filter(
    (req) =>
      req.requester.toLowerCase().includes(searchQuery.toLowerCase()) ||
      req.activityName.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const handleApprove = () => {
    if (!selectedRequest) return;
    approveRequest(selectedRequest.id, {
      onSuccess: () => {
        setShowApprovalDialog(false);
        setSelectedRequest(null);
      },
    });
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
            Connect your wallet to access the approval queue.
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

  // Not a validator state
  if (!memberLoading && (!isMember || !isValidator)) {
    return (
      <MainLayout>
        <div className="max-w-2xl mx-auto text-center py-12">
          <div className="w-16 h-16 mx-auto bg-warning/10 rounded-full flex items-center justify-center mb-6">
            <AlertCircle className="h-8 w-8 text-warning" />
          </div>
          <h1 className="text-2xl font-bold mb-4">Access Restricted</h1>
          <p className="text-text-muted mb-8">
            Only validators and admins can access the approval queue.
          </p>
          <Link href="/volunteer/dashboard">
            <Button>Go to Dashboard</Button>
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
              <h1 className="text-2xl font-bold">Approval Queue</h1>
              <Badge variant="secondary">Validator</Badge>
            </div>
            <p className="text-text-muted">
              Review and approve volunteer service hour requests
            </p>
          </div>
          <div className="flex items-center gap-2">
            <Badge variant="warning" className="text-lg px-3 py-1">
              {filteredRequests.length} Pending
            </Badge>
          </div>
        </div>

        {/* Search */}
        <Card>
          <CardContent className="pt-6">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-muted" />
              <Input
                placeholder="Search by address or activity..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-10"
              />
            </div>
          </CardContent>
        </Card>

        {/* Requests List */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg flex items-center gap-2">
              <ClipboardCheck className="h-5 w-5" />
              Pending Requests
            </CardTitle>
            <CardDescription>
              Click on a request to review and approve
            </CardDescription>
          </CardHeader>
          <CardContent>
            {filteredRequests.length === 0 ? (
              <div className="text-center py-8 text-text-muted">
                <CheckCircle className="h-12 w-12 mx-auto mb-4 opacity-30" />
                <p>No pending requests</p>
                <p className="text-sm mt-1">All caught up!</p>
              </div>
            ) : (
              <div className="space-y-3">
                {filteredRequests.map((request) => (
                  <div
                    key={request.id}
                    className="p-4 border rounded-lg hover:bg-muted/50 transition-colors cursor-pointer"
                    onClick={() => {
                      setSelectedRequest(request);
                      setShowApprovalDialog(true);
                    }}
                  >
                    <div className="flex items-center justify-between mb-2">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 bg-primary/10 rounded-full flex items-center justify-center">
                          <User className="h-5 w-5 text-primary" />
                        </div>
                        <div>
                          <p className="font-mono text-sm">
                            {formatAddress(request.requester)}
                          </p>
                          <p className="text-sm text-text-muted">
                            {request.activityName}
                          </p>
                        </div>
                      </div>
                      <Badge variant="warning">
                        {RequestStatusLabels[request.status]}
                      </Badge>
                    </div>
                    <div className="flex items-center justify-between text-sm text-text-muted">
                      <div className="flex items-center gap-4">
                        <span className="flex items-center gap-1">
                          <Clock className="h-4 w-4" />
                          {request.hours} hour(s)
                        </span>
                        <span>{formatRelativeTime(request.createdAt)}</span>
                      </div>
                      <span className="text-primary font-medium">
                        +{request.hours} TD
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>

        {/* Approval Dialog */}
        <Dialog open={showApprovalDialog} onOpenChange={setShowApprovalDialog}>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Approve Service Request</DialogTitle>
              <DialogDescription>
                Review the request details before approving
              </DialogDescription>
            </DialogHeader>
            {selectedRequest && (
              <div className="space-y-4 py-4">
                <div className="p-4 border rounded-lg space-y-3">
                  <div className="flex items-center justify-between">
                    <span className="text-text-muted">Request ID</span>
                    <span className="font-mono">#{selectedRequest.id}</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-text-muted">Requester</span>
                    <span className="font-mono text-sm">
                      {formatAddress(selectedRequest.requester, 8, 6)}
                    </span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-text-muted">Activity</span>
                    <span className="font-medium">{selectedRequest.activityName}</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-text-muted">Hours</span>
                    <Badge variant="secondary">{selectedRequest.hours}</Badge>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-text-muted">Time Dollars to Mint</span>
                    <span className="font-bold text-primary">
                      {selectedRequest.hours} TD
                    </span>
                  </div>
                </div>
                <p className="text-sm text-text-muted">
                  Approving this request will mint {selectedRequest.hours} Time Dollars
                  to the requester&apos;s account.
                </p>
              </div>
            )}
            <DialogFooter>
              <Button variant="outline" onClick={() => setShowApprovalDialog(false)}>
                Cancel
              </Button>
              <Button
                variant="success"
                onClick={handleApprove}
                isLoading={isApproving}
                loadingText="Approving..."
              >
                <CheckCircle className="h-4 w-4 mr-2" />
                Approve Request
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>
    </MainLayout>
  );
}

