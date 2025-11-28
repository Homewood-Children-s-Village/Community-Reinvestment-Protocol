# Admin Setup Guide

## Making an Address Admin Upfront

To make an address an admin before the platform is fully initialized, you can use the `register_member` function in the Move contract.

### Using the Move CLI

```bash
cd villages_finance

# Register an address as admin (requires existing admin to sign)
aptos move run \
  --function-id 0x2144ec184b89cf405e430d375b3de991ae14baf26cb6ec9987ea57922c0f1c5b::members::register_member \
  --args address:0x32b6c1f82515c22d87109105550ecd89ca6a0e8ebd043afb29154ef1806e1008 \
  --args u8:0 \
  --type-args
```

Where:
- `0x32b6c1f82515c22d87109105550ecd89ca6a0e8ebd043afb29154ef1806e1008` is the address to make admin
- `0` is the Role enum value for Admin (Role::Admin = 0)

### Role Values

- `0` = Admin
- `1` = Borrower (Project Initiator)
- `2` = Depositor (Investor/Contributor)
- `3` = Validator (Validator/Staff)

### Alternative: During Initialization

If you're initializing the contract for the first time, the `initialize` function automatically registers the signer as an admin:

```bash
aptos move run \
  --function-id 0x2144ec184b89cf405e430d375b3de991ae14baf26cb6ec9987ea57922c0f1c5b::members::initialize
```

### Frontend Integration

Currently, the frontend does not have a UI for registering members directly. This must be done via:
1. Move CLI (as shown above)
2. A custom admin script
3. Future admin UI implementation

### Notes

- Only existing admins can register new members
- The first admin is created during contract initialization
- Admins can also approve membership requests through the frontend at `/admin/membership`

