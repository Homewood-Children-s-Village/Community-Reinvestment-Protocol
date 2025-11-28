# Contract Upgrade Guide

## Current Situation

You've already published the contracts at address `0x2144ec184b89cf405e430d375b3de991ae14baf26cb6ec9987ea57922c0f1c5b`. 

The changes I made were:
- Changed `public fun initialize` → `public entry fun initialize` for:
  - `timebank::initialize`
  - `investment_pool::initialize`
  - `project_registry::initialize`
  - `parameters::initialize`

## Important: You Have Options

### Option 1: Use the Script (Works with Current Published Contracts) ✅

**This is the easiest solution and doesn't require republishing!**

The initialization script can call `public fun` (non-entry) functions. Since your published contracts have `public fun initialize`, you can use the script:

```bash
cd villages_finance
aptos move compile
aptos move run-script \
  --compiled-script-path build/villages_finance/bytecode_scripts/initialize.mv \
  --profile testnet
```

**This works because:**
- Scripts can call any `public` function (entry or not)
- The script doesn't need the functions to be `entry` functions
- No contract upgrade needed

### Option 2: Publish a New Version (If You Want Entry Functions)

If you want the convenience of calling `initialize` directly via CLI, you need to publish a new version:

#### Step 1: Check Upgrade Policy

Your `Move.toml` doesn't specify an `upgrade_policy`. In Aptos, this means:
- **Default behavior**: Packages are **immutable** by default
- You'll need to publish a **new package** (new address) OR
- Set `upgrade_policy = "compatible"` for future upgrades

#### Step 2: Update Move.toml for Upgrades (Optional)

If you want to enable upgrades in the future:

```toml
[package]
name = "villages_finance"
version = "1.0.1"  # Increment version
upgrade_policy = "compatible"  # Allows compatible upgrades
```

**Note:** You can only set `upgrade_policy` when **first publishing**. If your package is already published without it, you cannot add it later.

#### Step 3: Publish New Version

```bash
cd villages_finance
aptos move publish --profile testnet
```

**Important Considerations:**
- This will create a **new package** at a **new address**
- You'll need to update your frontend config with the new address
- Existing data stays at the old address
- You may need to migrate data or use both addresses

### Option 3: Check If Already Entry Functions

Check your published contracts to see if they're already entry functions:

```bash
aptos account list \
  --account 0x2144ec184b89cf405e430d375b3de991ae14baf26cb6ec9987ea57922c0f1c5b \
  --profile testnet
```

Or view the module on Aptos Explorer to see the actual function signatures.

## Recommendation

**Use Option 1 (Script Approach)** because:
1. ✅ No contract republishing needed
2. ✅ Works with your current published contracts
3. ✅ Safer (no risk of breaking existing functionality)
4. ✅ Can initialize all modules in one transaction
5. ✅ Scripts are the standard way to initialize in Move

The only downside is you can't call `initialize` directly via CLI, but the script works perfectly.

## What About Future Upgrades?

If you need to upgrade contracts in the future:

1. **For immutable packages**: Publish a new package and migrate
2. **For compatible upgrades**: Use `aptos move publish --upgrade-policy compatible` (only works if set at first publish)
3. **For governance upgrades**: Use the governance module's `upgrade_module` function (requires governance setup)

## Summary

- ✅ **Current contracts work fine** - use the script to initialize
- ✅ **No immediate need to republish** - script approach is standard
- ⚠️ **If you want entry functions**: You'll need to publish a new version (new address)
- 📝 **For production**: Consider setting `upgrade_policy = "compatible"` in Move.toml before first publish

