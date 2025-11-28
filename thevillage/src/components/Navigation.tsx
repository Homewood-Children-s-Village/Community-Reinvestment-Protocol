"use client";

import { usePathname } from "next/navigation";
import Link from "next/link";
import { cn } from "@/lib/utils";
import { useMemberStatus } from "@/hooks";
import { WalletConnectModal } from "@/components/WalletConnectModal";
import {
  Home,
  Clock,
  Wallet,
  Vote,
  Building2,
  Users,
  Settings,
  ClipboardCheck,
  Shield,
} from "lucide-react";

interface NavItem {
  href: string;
  label: string;
  icon: React.ReactNode;
  requiresAuth?: boolean;
  adminOnly?: boolean;
  validatorOnly?: boolean;
}

const navItems: NavItem[] = [
  { href: "/", label: "Home", icon: <Home className="h-5 w-5" /> },
  { href: "/volunteer/dashboard", label: "Dashboard", icon: <Clock className="h-5 w-5" />, requiresAuth: true },
  { href: "/treasury", label: "Treasury", icon: <Wallet className="h-5 w-5" />, requiresAuth: true },
  { href: "/governance", label: "Governance", icon: <Vote className="h-5 w-5" />, requiresAuth: true },
  { href: "/projects", label: "Projects", icon: <Building2 className="h-5 w-5" /> },
];

const staffItems: NavItem[] = [
  { href: "/staff/approvals", label: "Approvals", icon: <ClipboardCheck className="h-5 w-5" />, validatorOnly: true },
  { href: "/admin/membership", label: "Members", icon: <Users className="h-5 w-5" />, adminOnly: true },
  { href: "/admin/compliance", label: "Compliance", icon: <Shield className="h-5 w-5" />, adminOnly: true },
];

export function Navigation() {
  const pathname = usePathname();
  const { connected, isMember, isAdmin, isValidator } = useMemberStatus();

  // Filter nav items based on authentication and role
  const filteredNavItems = navItems.filter((item) => {
    if (item.requiresAuth && !connected) return false;
    return true;
  });

  // Filter staff items based on role
  const filteredStaffItems = staffItems.filter((item) => {
    if (item.adminOnly && !isAdmin) return false;
    if (item.validatorOnly && !isValidator) return false;
    return true;
  });

  return (
    <>
      {/* Desktop Sidebar */}
      <aside className="hidden lg:flex lg:flex-col lg:w-64 lg:fixed lg:inset-y-0 lg:border-r bg-surface">
        <div className="flex flex-col flex-1 min-h-0">
          {/* Logo */}
          <div className="flex items-center h-16 px-6 border-b">
            <Link href="/" className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-full gradient-primary flex items-center justify-center">
                <span className="text-white font-bold text-sm">V</span>
              </div>
              <span className="font-bold text-lg text-primary">The Village</span>
            </Link>
          </div>

          {/* Navigation */}
          <nav className="flex-1 px-3 py-4 space-y-1 overflow-y-auto">
            {filteredNavItems.map((item) => {
              const isActive = pathname === item.href;
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={cn(
                    "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors",
                    isActive
                      ? "bg-primary text-primary-foreground"
                      : "text-text hover:bg-muted"
                  )}
                >
                  {item.icon}
                  {item.label}
                </Link>
              );
            })}

            {/* Staff Section */}
            {filteredStaffItems.length > 0 && (
              <>
                <div className="pt-4 pb-2">
                  <p className="px-3 text-xs font-semibold text-text-muted uppercase tracking-wider">
                    Staff
                  </p>
                </div>
                {filteredStaffItems.map((item) => {
                  const isActive = pathname === item.href;
                  return (
                    <Link
                      key={item.href}
                      href={item.href}
                      className={cn(
                        "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors",
                        isActive
                          ? "bg-primary text-primary-foreground"
                          : "text-text hover:bg-muted"
                      )}
                    >
                      {item.icon}
                      {item.label}
                    </Link>
                  );
                })}
              </>
            )}
          </nav>

          {/* Wallet Section */}
          <div className="p-4 border-t">
            <WalletConnectModal />
          </div>
        </div>
      </aside>

      {/* Mobile Bottom Navigation */}
      <nav className="lg:hidden fixed bottom-0 left-0 right-0 bg-surface border-t z-50 safe-area-inset-bottom">
        <div className="flex justify-around py-2">
          {filteredNavItems.slice(0, 5).map((item) => {
            const isActive = pathname === item.href;
            return (
              <Link
                key={item.href}
                href={item.href}
                className={cn(
                  "flex flex-col items-center gap-1 px-3 py-2 min-w-[64px]",
                  isActive ? "text-primary" : "text-text-muted"
                )}
              >
                {item.icon}
                <span className="text-xs">{item.label}</span>
              </Link>
            );
          })}
        </div>
      </nav>

      {/* Mobile Header */}
      <header className="lg:hidden fixed top-0 left-0 right-0 h-14 bg-surface border-b z-50 flex items-center justify-between px-4">
        <Link href="/" className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-full gradient-primary flex items-center justify-center">
            <span className="text-white font-bold text-sm">V</span>
          </div>
          <span className="font-bold text-primary">The Village</span>
        </Link>
        <WalletConnectModal />
      </header>
    </>
  );
}

export function MainLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-background">
      <Navigation />
      {/* Main content area */}
      <main className="lg:pl-64">
        {/* Mobile header spacing */}
        <div className="h-14 lg:hidden" />
        <div className="container-app py-6 lg:py-8">
          {children}
        </div>
        {/* Mobile bottom nav spacing */}
        <div className="h-20 lg:hidden" />
      </main>
    </div>
  );
}

