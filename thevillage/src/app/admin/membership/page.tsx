"use client";

import { useState } from "react";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { MainLayout } from "@/components/Navigation";
import { useMemberStatus, useWhitelistAddress, useMembershipRequests, useApproveMembershipRequest, useRejectMembershipRequest } from "@/hooks";
import { WalletConnectModal } from "@/components/WalletConnectModal";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Users,
  Wallet,
  AlertCircle,
  Shield,
  CheckCircle,
  Search,
  UserPlus,
  X,
} from "lucide-react";
import Link from "next/link";
import { formatAddress } from "@/lib/config";
import { Role, RoleLabels, RequestStatus } from "@/types/contract";

// Mock members for demonstration
const MOCK_MEMBERS = [
  {
    address: "0x1234567890abcdef1234567890abcdef12345678",
    role: Role.Depositor,
    isWhitelisted: true,
    joinedAt: Date.now() - 86400000 * 30,
  },
  {
    address: "0xabcdef1234567890abcdef1234567890abcdef12",
    role: Role.Validator,
    isWhitelisted: true,
    joinedAt: Date.now() - 86400000 * 45,
  },
  {
    address: "0x9876543210fedcba9876543210fedcba98765432",
    role: Role.Borrower,
    isWhitelisted: false,
    joinedAt: Date.now() - 86400000 * 15,
  },
];

export default function AdminMembershipPage() {
  const { connected } = useWallet();
  const { isMember, isAdmin, isLoading: memberLoading } = useMemberStatus();
  const { mutate: whitelistAddress, isPending: isWhitelisting } = useWhitelistAddress();
  const { data: pendingRequests = [], isLoading: requestsLoading } = useMembershipRequests(RequestStatus.Pending);
  const { mutate: approveRequest, isPending: isApproving } = useApproveMembershipRequest();
  const { mutate: rejectRequest, isPending: isRejecting } = useRejectMembershipRequest();

  const [searchQuery, setSearchQuery] = useState("");
  const [addressToWhitelist, setAddressToWhitelist] = useState("");
  const [showWhitelistDialog, setShowWhitelistDialog] = useState(false);
  const [selectedRequestId, setSelectedRequestId] = useState<number | null>(null);
  const [showRequestDialog, setShowRequestDialog] = useState(false);

  const filteredMembers = MOCK_MEMBERS.filter((member) =>
    member.address.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const handleWhitelist = () => {
    if (!addressToWhitelist) return;
    whitelistAddress(addressToWhitelist, {
      onSuccess: () => {
        setShowWhitelistDialog(false);
        setAddressToWhitelist("");
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
            Connect your wallet to access admin features.
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

  // Not an admin state
  if (!memberLoading && (!isMember || !isAdmin)) {
    return (
      <MainLayout>
        <div className="max-w-2xl mx-auto text-center py-12">
          <div className="w-16 h-16 mx-auto bg-warning/10 rounded-full flex items-center justify-center mb-6">
            <AlertCircle className="h-8 w-8 text-warning" />
          </div>
          <h1 className="text-2xl font-bold mb-4">Access Restricted</h1>
          <p className="text-text-muted mb-8">
            Only administrators can access member management.
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
              <h1 className="text-2xl font-bold">Member Management</h1>
              <Badge variant="default">Admin</Badge>
            </div>
            <p className="text-text-muted">
              Manage members and KYC verification status
            </p>
          </div>
          <Button onClick={() => setShowWhitelistDialog(true)} className="gap-2">
            <Shield className="h-5 w-5" />
            Whitelist Address
          </Button>
        </div>

        {/* Stats */}
        <div className="grid sm:grid-cols-3 gap-4">
          <Card>
            <CardContent className="flex items-center gap-4 py-4">
              <div className="w-12 h-12 bg-primary/10 rounded-full flex items-center justify-center">
                <Users className="h-6 w-6 text-primary" />
              </div>
              <div>
                <p className="text-2xl font-bold">{MOCK_MEMBERS.length}</p>
                <p className="text-sm text-text-muted">Total Members</p>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="flex items-center gap-4 py-4">
              <div className="w-12 h-12 bg-success/10 rounded-full flex items-center justify-center">
                <Shield className="h-6 w-6 text-success" />
              </div>
              <div>
                <p className="text-2xl font-bold">
                  {MOCK_MEMBERS.filter((m) => m.isWhitelisted).length}
                </p>
                <p className="text-sm text-text-muted">KYC Verified</p>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="flex items-center gap-4 py-4">
              <div className="w-12 h-12 bg-warning/10 rounded-full flex items-center justify-center">
                <UserPlus className="h-6 w-6 text-warning" />
              </div>
              <div>
                <p className="text-2xl font-bold">
                  {MOCK_MEMBERS.filter((m) => !m.isWhitelisted).length}
                </p>
                <p className="text-sm text-text-muted">Pending KYC</p>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Search */}
        <Card>
          <CardContent className="pt-6">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-muted" />
              <Input
                placeholder="Search by address..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-10"
              />
            </div>
          </CardContent>
        </Card>

        {/* Pending Membership Requests */}
        {pendingRequests.length > 0 && (
          <Card>
            <CardHeader>
              <CardTitle className="text-lg flex items-center gap-2">
                <UserPlus className="h-5 w-5" />
                Pending Membership Requests
              </CardTitle>
              <CardDescription>
                Review and approve membership applications
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                {pendingRequests.map((requestId) => (
                  <div
                    key={requestId}
                    className="flex items-center justify-between p-4 border rounded-lg hover:bg-muted/50 transition-colors"
                  >
                    <div className="flex items-center gap-4">
                      <div className="w-10 h-10 bg-primary/10 rounded-full flex items-center justify-center">
                        <UserPlus className="h-5 w-5 text-primary" />
                      </div>
                      <div>
                        <p className="font-medium">Request #{requestId}</p>
                        <p className="text-sm text-text-muted">
                          Click to view details and approve/reject
                        </p>
                      </div>
                    </div>
                    <div className="flex items-center gap-2">
                      <Button
                        size="sm"
                        variant="success"
                        onClick={() => {
                          setSelectedRequestId(requestId);
                          approveRequest(requestId);
                        }}
                        isLoading={isApproving && selectedRequestId === requestId}
                        disabled={isApproving || isRejecting}
                      >
                        <CheckCircle className="h-4 w-4 mr-1" />
                        Approve
                      </Button>
                      <Button
                        size="sm"
                        variant="destructive"
                        onClick={() => {
                          setSelectedRequestId(requestId);
                          rejectRequest(requestId);
                        }}
                        isLoading={isRejecting && selectedRequestId === requestId}
                        disabled={isApproving || isRejecting}
                      >
                        <X className="h-4 w-4 mr-1" />
                        Reject
                      </Button>
                    </div>
                  </div>
                ))}
              </div>
              <p className="text-xs text-text-muted mt-4">
                Note: Request details (requester address, role, note) are not yet available via view function.
                Approval/rejection will process the request based on the request ID.
              </p>
            </CardContent>
          </Card>
        )}

        {/* Members List */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Members</CardTitle>
            <CardDescription>
              All registered members and their verification status
            </CardDescription>
          </CardHeader>
          <CardContent>
            {filteredMembers.length === 0 ? (
              <div className="text-center py-8 text-text-muted">
                <Users className="h-12 w-12 mx-auto mb-4 opacity-30" />
                <p>No members found</p>
              </div>
            ) : (
              <div className="space-y-3">
                {filteredMembers.map((member) => (
                  <div
                    key={member.address}
                    className="flex items-center justify-between p-4 border rounded-lg"
                  >
                    <div className="flex items-center gap-4">
                      <div className="w-10 h-10 bg-primary/10 rounded-full flex items-center justify-center">
                        <Users className="h-5 w-5 text-primary" />
                      </div>
                      <div>
                        <p className="font-mono text-sm">{formatAddress(member.address)}</p>
                        <div className="flex items-center gap-2 mt-1">
                          <Badge variant="secondary">{RoleLabels[member.role]}</Badge>
                          {member.isWhitelisted ? (
                            <Badge variant="success" className="gap-1">
                              <CheckCircle className="h-3 w-3" />
                              KYC Verified
                            </Badge>
                          ) : (
                            <Badge variant="warning">Pending KYC</Badge>
                          )}
                        </div>
                      </div>
                    </div>
                    {!member.isWhitelisted && (
                      <Button
                        size="sm"
                        onClick={() => {
                          setAddressToWhitelist(member.address);
                          setShowWhitelistDialog(true);
                        }}
                      >
                        <Shield className="h-4 w-4 mr-1" />
                        Whitelist
                      </Button>
                    )}
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>

        {/* Whitelist Dialog */}
        <Dialog open={showWhitelistDialog} onOpenChange={setShowWhitelistDialog}>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Whitelist Address</DialogTitle>
              <DialogDescription>
                Add an address to the compliance whitelist (KYC verified)
              </DialogDescription>
            </DialogHeader>
            <div className="space-y-4 py-4">
              <div className="space-y-2">
                <Label htmlFor="address">Wallet Address</Label>
                <Input
                  id="address"
                  placeholder="0x..."
                  value={addressToWhitelist}
                  onChange={(e) => setAddressToWhitelist(e.target.value)}
                />
              </div>
              <p className="text-sm text-text-muted">
                This will allow the address to participate in financial operations
                like deposits and investments.
              </p>
            </div>
            <DialogFooter>
              <Button variant="outline" onClick={() => setShowWhitelistDialog(false)}>
                Cancel
              </Button>
              <Button
                onClick={handleWhitelist}
                isLoading={isWhitelisting}
                loadingText="Whitelisting..."
                disabled={!addressToWhitelist}
              >
                <Shield className="h-4 w-4 mr-2" />
                Whitelist Address
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>
    </MainLayout>
  );
}

