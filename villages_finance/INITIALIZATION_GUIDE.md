# Initialization Guide

## Error: E_INVALID_REGISTRY

If you're seeing `E_INVALID_REGISTRY` errors when trying to use features like creating timebank requests, it means the required modules haven't been initialized yet.

## Quick Fix: Initialize All Modules

You have two options:

### Option 1: Use the Initialization Script (Recommended)

```bash
cd villages_finance
aptos move compile
aptos move run-script --compiled-script-path build/villages_finance/bytecode_scripts/initialize.mv --profile testnet
```

This will initialize all modules in one transaction:
- ✅ Admin module
- ✅ Members module
- ✅ Compliance module
- ✅ TimeBank module (required for volunteer hour requests)
- ✅ Investment Pool module
- ✅ Project Registry module
- ✅ Parameters module

### Option 2: Initialize Modules Individually

Now that the initialize functions are entry functions, you can call them directly:

```bash
cd villages_finance

# Initialize TimeBank (fixes the current error)
aptos move run \
  --function-id 0x2144ec184b89cf405e430d375b3de991ae14baf26cb6ec9987ea57922c0f1c5b::timebank::initialize \
  --profile testnet

# Initialize Investment Pool
aptos move run \
  --function-id 0x2144ec184b89cf405e430d375b3de991ae14baf26cb6ec9987ea57922c0f1c5b::investment_pool::initialize \
  --profile testnet

# Initialize Project Registry
aptos move run \
  --function-id 0x2144ec184b89cf405e430d375b3de991ae14baf26cb6ec9987ea57922c0f1c5b::project_registry::initialize \
  --profile testnet

# Initialize Parameters
aptos move run \
  --function-id 0x2144ec184b89cf405e430d375b3de991ae14baf26cb6ec9987ea57922c0f1c5b::parameters::initialize \
  --profile testnet
```

## Verify Initialization

You can check if a module is initialized by viewing the account resources:

```bash
aptos account list --account 0x2144ec184b89cf405e430d375b3de991ae14baf26cb6ec9987ea57922c0f1c5b --profile testnet
```

Look for resources like:
- `TimeBank` (for timebank module)
- `InvestmentPoolRegistry` (for investment pool module)
- `ProjectRegistry` (for project registry module)

## What Each Module Does

- **Admin**: Manages admin capabilities and module pausing
- **Members**: Tracks registered members and their roles
- **Compliance**: KYC whitelist registry
- **TimeBank**: Volunteer hour requests and TimeToken minting
- **Investment Pool**: Community investment pools
- **Project Registry**: Community project proposals
- **Parameters**: System-wide parameters and configuration

## Notes

- All modules are initialized at the contract address (`0x2144ec184b89cf405e430d375b3de991ae14baf26cb6ec9987ea57922c0f1c5b`)
- Initialization is idempotent - safe to run multiple times
- You must be the admin (contract deployer) to initialize modules

