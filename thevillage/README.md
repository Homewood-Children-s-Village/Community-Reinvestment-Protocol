# The Village - Community Reinvestment Platform

A modern, production-ready Next.js frontend for the Villages Finance Platform, built on Aptos blockchain.

## Features

- **Time Banking**: Log volunteer hours, earn Time Dollars, and track service history
- **Treasury Management**: Deposit and withdraw APT tokens
- **Governance**: Create and vote on community proposals
- **Project Funding**: Contribute to community projects and earn impact shares
- **Membership System**: Role-based access with KYC verification

## Tech Stack

- **Framework**: Next.js 14+ with App Router
- **Language**: TypeScript
- **Styling**: Tailwind CSS with shadcn/ui components
- **Blockchain**: Aptos SDK with Wallet Adapter
- **State Management**: React Query (TanStack Query)

## Getting Started

### Prerequisites

- Node.js 18+ 
- npm or yarn
- A web3 wallet (Petra recommended)

### Installation

1. Clone the repository:
```bash
cd thevillage/thevillage-frontend
```

2. Install dependencies:
```bash
npm install
```

3. Create a `.env.local` file with the following variables:
```env
# Aptos Network Configuration
NEXT_PUBLIC_APTOS_NETWORK=testnet
NEXT_PUBLIC_APTOS_REST_URL=https://fullnode.testnet.aptoslabs.com
NEXT_PUBLIC_APTOS_INDEXER_URL=https://api.testnet.aptoslabs.com/v1/graphql
NEXT_PUBLIC_APTOS_FAUCET_URL=https://faucet.testnet.aptoslabs.com

# Contract Configuration
NEXT_PUBLIC_CONTRACT_ADDRESS=0x2144ec184b89cf405e430d375b3de991ae14baf26cb6ec9987ea57922c0f1c5b

# Explorer URL
NEXT_PUBLIC_EXPLORER_URL=https://explorer.aptoslabs.com/?network=testnet
```

4. Copy assets from parent directory:
```bash
cp ../handshake.png public/
cp ../timedollarlogo.png public/
```

5. Start the development server:
```bash
npm run dev
```

5. Open [http://localhost:3000](http://localhost:3000) in your browser.

## Project Structure

```
src/
├── app/                    # Next.js App Router pages
│   ├── membership/         # Membership request flow
│   ├── volunteer/          # Volunteer dashboard and hour logging
│   ├── staff/              # Staff approval queue
│   ├── treasury/           # Deposit/withdraw interface
│   ├── governance/         # Proposals and voting
│   ├── projects/           # Project catalog
│   └── admin/              # Admin management
├── components/
│   ├── ui/                 # shadcn/ui components
│   ├── WalletConnectModal.tsx
│   ├── MembershipStatus.tsx
│   ├── TimeTokenBalance.tsx
│   ├── TreasuryBalance.tsx
│   ├── Navigation.tsx
│   └── ...
├── hooks/                  # Custom React hooks
│   ├── useMember.ts
│   ├── useTimeToken.ts
│   ├── useTreasury.ts
│   ├── useGovernance.ts
│   └── ...
├── lib/                    # Utility functions
│   ├── aptos.ts           # Aptos SDK integration
│   ├── config.ts          # Configuration constants
│   └── utils.ts           # Helper functions
├── providers/              # React context providers
│   ├── WalletProvider.tsx
│   └── QueryProvider.tsx
└── types/                  # TypeScript type definitions
    └── contract.ts
```

## Contract Integration

The frontend integrates with the Villages Finance smart contracts deployed on Aptos testnet:

- **Contract Address**: `0x2144ec184b89cf405e430d375b3de991ae14baf26cb6ec9987ea57922c0f1c5b`
- **Network**: Aptos Testnet

### Available Modules

| Module | Description |
|--------|-------------|
| `members` | Membership registration and role management |
| `compliance` | KYC/whitelist verification |
| `timebank` | Volunteer hour logging and approval |
| `time_token` | Time Dollar token operations |
| `treasury` | Deposit and withdrawal |
| `governance` | Proposal creation and voting |
| `investment_pool` | Investment pool management |
| `rewards` | Staking and rewards |
| `project_registry` | Community project management |

## User Roles

| Role | Access |
|------|--------|
| **Admin** | Full platform access, member management, compliance controls |
| **Validator** | Approve volunteer hours, validate service requests |
| **Depositor** | Deposit funds, earn returns, invest in projects |
| **Borrower** | Apply for loans, receive investment pool funding |

## Design System

The UI follows the Villages Community design specifications:

- **Primary Color**: `#5E3FA3` (Deep Purple)
- **Secondary Color**: `#00A0A6` (Teal)
- **Typography**: Inter font family
- **Spacing**: 8px grid system
- **Breakpoints**: sm (480px), md (768px), lg (1024px), xl (1280px)

## Scripts

```bash
npm run dev      # Start development server
npm run build    # Build for production
npm run start    # Start production server
npm run lint     # Run ESLint
```

## Deployment

### Vercel (Recommended)

1. Push your code to GitHub
2. Import the project in Vercel
3. Add environment variables
4. Deploy

### Manual Deployment

```bash
npm run build
npm run start
```

## Testing

### Manual Testing Checklist

- [ ] Connect wallet (Petra)
- [ ] Request membership
- [ ] Log service hours
- [ ] Approve hours (as validator)
- [ ] Deposit to treasury
- [ ] Create governance proposal
- [ ] Vote on proposal
- [ ] View and contribute to projects

## Resources

- [Frontend Integration Guide](../frontend_integration_guide.md)
- [Villages Frontend Specifications](../Villages%20Frontend%20Specifications.txt)
- [Aptos Testnet Faucet](https://faucet.testnet.aptoslabs.com/)
- [Aptos Explorer](https://explorer.aptoslabs.com/?network=testnet)

## License

Copyright © 2025 Homewood Children's Village. All rights reserved.

