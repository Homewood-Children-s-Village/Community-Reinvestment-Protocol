"use client";

import Link from "next/link";
import Image from "next/image";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { WalletConnectModal } from "@/components/WalletConnectModal";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import {
  Clock,
  Building2,
  Vote,
  Wallet,
  ArrowRight,
  Shield,
  Users,
  TrendingUp,
  Heart,
} from "lucide-react";

export default function HomePage() {
  const { connected } = useWallet();

  return (
    <div className="min-h-screen bg-background">
      {/* Hero Section */}
      <section className="relative overflow-hidden">
        {/* Background gradient */}
        <div className="absolute inset-0 gradient-hero opacity-10" />
        
        <div className="relative container-app py-16 lg:py-24">
          <div className="grid lg:grid-cols-2 gap-12 items-center">
            {/* Left content */}
            <div className="space-y-6">
              <Badge variant="secondary" className="mb-4">
                Built on Aptos Blockchain
              </Badge>
              <h1 className="text-4xl lg:text-5xl font-bold text-text leading-tight">
                Transform Community{" "}
                <span className="text-primary">Participation</span> Into{" "}
                <span className="text-secondary">Real Impact</span>
              </h1>
              <p className="text-lg text-text-muted max-w-lg">
                Log volunteer hours, earn Time Dollars, and invest in neighborhood
                projects. The Village connects communities through transparent,
                blockchain-verified contributions.
              </p>
              <div className="flex flex-wrap gap-4">
                {connected ? (
                  <Link href="/volunteer/dashboard">
                    <Button size="lg" className="gap-2">
                      Go to Dashboard
                      <ArrowRight className="h-5 w-5" />
                    </Button>
                  </Link>
                ) : (
                  <WalletConnectModal
                    trigger={
                      <Button size="lg" className="gap-2">
                        <Wallet className="h-5 w-5" />
                        Connect Wallet to Start
                      </Button>
                    }
                  />
                )}
                <Link href="/projects">
                  <Button variant="outline" size="lg">
                    Explore Projects
                  </Button>
                </Link>
              </div>
            </div>

            {/* Right content - Hero image */}
            <div className="relative h-[400px] lg:h-[500px] flex items-center justify-center">
              <div className="relative w-64 h-64 lg:w-80 lg:h-80">
                <div className="absolute inset-0 rounded-full gradient-primary opacity-20 blur-3xl" />
                <div className="relative w-full h-full rounded-full bg-surface shadow-xl flex items-center justify-center overflow-hidden border-4 border-primary/20">
                  <Image
                    src="/handshake.png"
                    alt="Community Handshake"
                    width={280}
                    height={280}
                    className="object-contain p-4"
                    priority
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* How It Works */}
      <section className="py-16 bg-surface">
        <div className="container-app">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold text-text mb-4">How It Works</h2>
            <p className="text-text-muted max-w-2xl mx-auto">
              A simple process to convert your community service into tangible value
            </p>
          </div>

          <div className="grid md:grid-cols-4 gap-6">
            {[
              {
                step: 1,
                icon: <Users className="h-8 w-8" />,
                title: "Join the Community",
                description: "Connect your wallet and register as a volunteer, homeowner, or supporter.",
              },
              {
                step: 2,
                icon: <Clock className="h-8 w-8" />,
                title: "Log Service Hours",
                description: "Record your volunteer activities. Staff validates and approves hours.",
              },
              {
                step: 3,
                icon: <Heart className="h-8 w-8" />,
                title: "Earn Time Dollars",
                description: "Receive Time Dollar tokens for every approved hour of service.",
              },
              {
                step: 4,
                icon: <Building2 className="h-8 w-8" />,
                title: "Invest in Projects",
                description: "Stake Time Dollars in community projects and earn impact shares.",
              },
            ].map((item) => (
              <Card key={item.step} className="relative overflow-hidden">
                <div className="absolute top-0 left-0 w-12 h-12 bg-primary/10 flex items-center justify-center">
                  <span className="text-xl font-bold text-primary">{item.step}</span>
                </div>
                <CardHeader className="pt-14">
                  <div className="text-primary mb-2">{item.icon}</div>
                  <CardTitle className="text-lg">{item.title}</CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-sm text-text-muted">{item.description}</p>
                </CardContent>
              </Card>
            ))}
          </div>
        </div>
      </section>

      {/* Features Grid */}
      <section className="py-16">
        <div className="container-app">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold text-text mb-4">Platform Features</h2>
            <p className="text-text-muted max-w-2xl mx-auto">
              Everything you need to participate in community reinvestment
            </p>
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            <Card hoverable className="group">
              <CardHeader>
                <div className="w-12 h-12 rounded-lg bg-primary/10 flex items-center justify-center mb-4 group-hover:bg-primary/20 transition-colors">
                  <Clock className="h-6 w-6 text-primary" />
                </div>
                <CardTitle>Time Banking</CardTitle>
                <CardDescription>
                  Log volunteer hours and receive Time Dollar tokens. 1 hour = 1 Time Dollar.
                </CardDescription>
              </CardHeader>
              <CardContent>
                <Link href="/volunteer/dashboard" className="text-primary hover:underline text-sm font-medium">
                  Start Volunteering →
                </Link>
              </CardContent>
            </Card>

            <Card hoverable className="group">
              <CardHeader>
                <div className="w-12 h-12 rounded-lg bg-secondary/10 flex items-center justify-center mb-4 group-hover:bg-secondary/20 transition-colors">
                  <Wallet className="h-6 w-6 text-secondary" />
                </div>
                <CardTitle>Treasury</CardTitle>
                <CardDescription>
                  Deposit APT tokens to support community initiatives. Earn returns on investments.
                </CardDescription>
              </CardHeader>
              <CardContent>
                <Link href="/treasury" className="text-secondary hover:underline text-sm font-medium">
                  View Treasury →
                </Link>
              </CardContent>
            </Card>

            <Card hoverable className="group">
              <CardHeader>
                <div className="w-12 h-12 rounded-lg bg-primary/10 flex items-center justify-center mb-4 group-hover:bg-primary/20 transition-colors">
                  <Building2 className="h-6 w-6 text-primary" />
                </div>
                <CardTitle>Project Funding</CardTitle>
                <CardDescription>
                  Contribute to community projects like home repairs. Track progress with impact shares.
                </CardDescription>
              </CardHeader>
              <CardContent>
                <Link href="/projects" className="text-primary hover:underline text-sm font-medium">
                  Browse Projects →
                </Link>
              </CardContent>
            </Card>

            <Card hoverable className="group">
              <CardHeader>
                <div className="w-12 h-12 rounded-lg bg-secondary/10 flex items-center justify-center mb-4 group-hover:bg-secondary/20 transition-colors">
                  <Vote className="h-6 w-6 text-secondary" />
                </div>
                <CardTitle>Governance</CardTitle>
                <CardDescription>
                  Vote on community proposals. Multiple voting mechanisms including quadratic voting.
                </CardDescription>
              </CardHeader>
              <CardContent>
                <Link href="/governance" className="text-secondary hover:underline text-sm font-medium">
                  View Proposals →
                </Link>
              </CardContent>
            </Card>

            <Card hoverable className="group">
              <CardHeader>
                <div className="w-12 h-12 rounded-lg bg-success/10 flex items-center justify-center mb-4 group-hover:bg-success/20 transition-colors">
                  <TrendingUp className="h-6 w-6 text-success" />
                </div>
                <CardTitle>Rewards & Staking</CardTitle>
                <CardDescription>
                  Stake Time Dollars in investment pools. Earn rewards based on your contribution.
                </CardDescription>
              </CardHeader>
              <CardContent>
                <Link href="/volunteer/dashboard" className="text-success hover:underline text-sm font-medium">
                  Start Earning →
                </Link>
              </CardContent>
            </Card>

            <Card hoverable className="group">
              <CardHeader>
                <div className="w-12 h-12 rounded-lg bg-warning/10 flex items-center justify-center mb-4 group-hover:bg-warning/20 transition-colors">
                  <Shield className="h-6 w-6 text-warning" />
                </div>
                <CardTitle>Secure & Transparent</CardTitle>
                <CardDescription>
                  Built on Aptos blockchain. All transactions are verifiable and immutable.
                </CardDescription>
              </CardHeader>
              <CardContent>
                <a 
                  href="https://explorer.aptoslabs.com/?network=testnet" 
                  target="_blank" 
                  rel="noopener noreferrer"
                  className="text-warning hover:underline text-sm font-medium"
                >
                  View on Explorer →
                </a>
              </CardContent>
            </Card>
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-16 bg-surface">
        <div className="container-app">
          <div className="max-w-3xl mx-auto text-center">
            <h2 className="text-3xl font-bold text-text mb-4">
              Ready to Make an Impact?
            </h2>
            <p className="text-lg text-text-muted mb-8">
              Join The Village community and start transforming your time into tangible
              community value. Every hour counts.
            </p>
            <div className="flex flex-wrap justify-center gap-4">
              {connected ? (
                <>
                  <Link href="/membership/request">
                    <Button size="lg" className="gap-2">
                      <Users className="h-5 w-5" />
                      Request Membership
                    </Button>
                  </Link>
                  <Link href="/volunteer/log-hours">
                    <Button size="lg" variant="secondary" className="gap-2">
                      <Clock className="h-5 w-5" />
                      Log Service Hours
                    </Button>
                  </Link>
                </>
              ) : (
                <WalletConnectModal
                  trigger={
                    <Button size="lg" className="gap-2">
                      <Wallet className="h-5 w-5" />
                      Get Started Now
                    </Button>
                  }
                />
              )}
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="py-8 border-t">
        <div className="container-app">
          <div className="flex flex-col md:flex-row justify-between items-center gap-4">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-full gradient-primary flex items-center justify-center">
                <span className="text-white font-bold text-sm">V</span>
              </div>
              <span className="font-bold text-primary">The Village</span>
            </div>
            <p className="text-sm text-text-muted">
              © 2025 Homewood Children&apos;s Village. Built on Aptos.
            </p>
            <div className="flex gap-6">
              <a
                href="https://explorer.aptoslabs.com/?network=testnet"
                target="_blank"
                rel="noopener noreferrer"
                className="text-sm text-text-muted hover:text-primary transition-colors"
              >
                Explorer
              </a>
              <a
                href="https://faucet.testnet.aptoslabs.com/"
                target="_blank"
                rel="noopener noreferrer"
                className="text-sm text-text-muted hover:text-primary transition-colors"
              >
                Faucet
              </a>
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
}

