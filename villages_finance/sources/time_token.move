module villages_finance::time_token {

use std::signer;
use std::error;
use std::string;
use aptos_framework::event;
use aptos_framework::fungible_asset::{Self, FungibleAsset, Metadata, MintRef, BurnRef, TransferRef};
use aptos_framework::primary_fungible_store;
use aptos_framework::object::{Self, Object, ConstructorRef};
use std::option;
use villages_finance::compliance;
use villages_finance::admin;

/// Error codes
const E_NOT_AUTHORIZED: u64 = 1;
const E_ZERO_AMOUNT: u64 = 2;
const E_INSUFFICIENT_BALANCE: u64 = 3;
const E_TRANSFER_RESTRICTED: u64 = 4;
const E_NOT_ADMIN: u64 = 5;
const E_INVALID_REGISTRY: u64 = 6;

/// Time token symbol constant
const TIME_SYMBOL: vector<u8> = b"TIME";

/// Mint capability - controlled by TimeBank module
struct MintCapability has key, store {
    metadata: Object<Metadata>,
    mint_ref: MintRef,
    burn_ref: BurnRef,
    transfer_ref: TransferRef,
}

/// Transfer configuration - controls whether transfers are restricted
struct TransferConfig has key {
    transfer_restricted: bool,
    compliance_registry_addr: option::Option<address>,
}

// Events
#[event]
struct TimeTokenMintedEvent has drop, store {
    recipient: address,
    hours: u64,
}

#[event]
struct TimeTokenBurnedEvent has drop, store {
    from: address,
    hours: u64,
}

#[event]
struct TimeTokenTransferredEvent has drop, store {
    from: address,
    to: address,
    hours: u64,
}

/// Initialize TimeToken as Fungible Asset
/// Returns only the metadata object. MintCapability is stored at admin address.
public fun initialize(
    admin: &signer,
): Object<Metadata> {
    // Create object for the fungible asset
    // Use constant for symbol since it's always "TIME" - more efficient than string conversion
    let constructor_ref = &object::create_named_object(admin, TIME_SYMBOL);
    let metadata_signer = &object::generate_signer(constructor_ref);
    
    // Create the fungible asset
    primary_fungible_store::create_primary_store_enabled_fungible_asset(
        constructor_ref,
        option::none(), // max_supply
        string::utf8(b"Time Dollar"),
        string::utf8(b"TIME"),
        0, // decimals - hours are whole numbers
        string::utf8(b""), // icon_uri
        string::utf8(b"Time Dollars representing validated volunteer hours"), // project_uri
    );
    
    let metadata = object::object_from_constructor_ref<Metadata>(constructor_ref);
    
    // Generate refs for minting, burning, and transferring
    let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
    let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
    let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);
    
    // Store mint capability struct (idempotent check)
    let admin_addr = signer::address_of(admin);
    if (!exists<MintCapability>(admin_addr)) {
        let mint_cap = MintCapability {
            metadata,
            mint_ref,
            burn_ref,
            transfer_ref,
        };
        move_to(admin, mint_cap);
    };
    
    // Initialize transfer config (transfers unrestricted by default) - idempotent
    if (!exists<TransferConfig>(admin_addr)) {
        move_to(admin, TransferConfig {
            transfer_restricted: false,
            compliance_registry_addr: option::none(),
        });
    };
    
    metadata
}

/// Get metadata object for TimeToken
public fun get_metadata(admin_addr: address): Object<Metadata> acquires MintCapability {
    let cap = borrow_global<MintCapability>(admin_addr);
    cap.metadata
}

/// Get asset type address from metadata (for backward compatibility)
public fun get_asset_type(admin_addr: address): address acquires MintCapability {
    object::object_address(&get_metadata(admin_addr))
}

/// Mint TimeTokens (called by TimeBank module on approval)
/// This function should be called only by authorized validators/admins
public fun mint(
    minter: &signer,
    recipient: address,
    hours: u64,
    admin_addr: address,
) acquires MintCapability {
    let minter_addr = signer::address_of(minter);
    assert!(exists<MintCapability>(admin_addr), error::permission_denied(E_NOT_AUTHORIZED));
    assert!(hours > 0, error::invalid_argument(E_ZERO_AMOUNT));
    
    let cap = borrow_global<MintCapability>(admin_addr);
    
    // Ensure primary store exists for recipient (mint will create it if needed)
    primary_fungible_store::ensure_primary_store_exists(recipient, cap.metadata);
    
    // Mint assets directly to the store
    primary_fungible_store::mint(&cap.mint_ref, recipient, hours);
    
    event::emit(TimeTokenMintedEvent {
        recipient,
        hours,
    });
    
    // Asset is automatically deposited, no need to return it
}

/// Burn TimeTokens (for redemption/spending)
public fun burn(
    burner: &signer,
    hours: u64,
    admin_addr: address,
) acquires MintCapability {
    assert!(hours > 0, error::invalid_argument(E_ZERO_AMOUNT));
    
    let burner_addr = signer::address_of(burner);
    let cap = borrow_global<MintCapability>(admin_addr);
    
    // Ensure primary store exists
    let store = primary_fungible_store::ensure_primary_store_exists(burner_addr, cap.metadata);
    
    // Check balance
    let balance = primary_fungible_store::balance(burner_addr, cap.metadata);
    assert!(balance >= hours, error::invalid_state(E_INSUFFICIENT_BALANCE));
    
    // Withdraw from primary store and burn
    let asset = fungible_asset::withdraw_with_ref(&cap.transfer_ref, store, hours);
    fungible_asset::burn(&cap.burn_ref, asset);
    
    event::emit(TimeTokenBurnedEvent {
        from: burner_addr,
        hours,
    });
}

/// Entry function to mint TimeTokens
public entry fun mint_entry(
    minter: &signer,
    recipient: address,
    hours: u64,
    admin_addr: address,
) acquires MintCapability {
    mint(minter, recipient, hours, admin_addr);
}

/// Entry function to burn TimeTokens
public entry fun burn_entry(
    burner: &signer,
    hours: u64,
    admin_addr: address,
) acquires MintCapability {
    burn(burner, hours, admin_addr);
}

/// Transfer TimeTokens from sender to recipient
/// If transfer restrictions are enabled, both sender and recipient must be whitelisted
public entry fun transfer(
    sender: &signer,
    recipient: address,
    hours: u64,
    admin_addr: address,
) acquires MintCapability, TransferConfig {
    assert!(hours > 0, error::invalid_argument(E_ZERO_AMOUNT));
    
    let sender_addr = signer::address_of(sender);
    
    // Check if MintCapability exists
    assert!(exists<MintCapability>(admin_addr), error::permission_denied(E_NOT_AUTHORIZED));
    
    // Check transfer restrictions if enabled
    if (exists<TransferConfig>(admin_addr)) {
        let config = borrow_global<TransferConfig>(admin_addr);
        if (config.transfer_restricted) {
            // Both sender and recipient must be whitelisted
            assert!(
                option::is_some(&config.compliance_registry_addr),
                error::invalid_argument(E_INVALID_REGISTRY)
            );
            let compliance_registry_addr = *option::borrow(&config.compliance_registry_addr);
            assert!(
                compliance::is_whitelisted(sender_addr, compliance_registry_addr),
                error::permission_denied(E_TRANSFER_RESTRICTED)
            );
            assert!(
                compliance::is_whitelisted(recipient, compliance_registry_addr),
                error::permission_denied(E_TRANSFER_RESTRICTED)
            );
        };
    };
    
    let cap = borrow_global<MintCapability>(admin_addr);
    
    // Ensure primary store exists for sender
    let sender_store = primary_fungible_store::ensure_primary_store_exists(sender_addr, cap.metadata);
    
    // Check balance
    let balance = primary_fungible_store::balance(sender_addr, cap.metadata);
    assert!(balance >= hours, error::invalid_state(E_INSUFFICIENT_BALANCE));
    
    // Withdraw from sender's primary store
    let asset = fungible_asset::withdraw_with_ref(&cap.transfer_ref, sender_store, hours);
    
    // Ensure primary store exists for recipient and deposit
    let recipient_store = primary_fungible_store::ensure_primary_store_exists(recipient, cap.metadata);
    fungible_asset::deposit(recipient_store, asset);
    
    event::emit(TimeTokenTransferredEvent {
        from: sender_addr,
        to: recipient,
        hours,
    });
}

/// Enable transfer restrictions (admin only)
/// When enabled, both sender and recipient must be whitelisted in the compliance registry
public entry fun enable_transfer_restrictions(
    admin: &signer,
    compliance_registry_addr: address,
    admin_addr: address,
) acquires TransferConfig {
    let admin_addr_check = signer::address_of(admin);
    assert!(admin::has_admin_capability(admin_addr_check), error::permission_denied(E_NOT_ADMIN));
    assert!(exists<TransferConfig>(admin_addr), error::not_found(E_NOT_AUTHORIZED));
    assert!(compliance::exists_compliance_registry(compliance_registry_addr), error::invalid_argument(E_INVALID_REGISTRY));
    
    let config = borrow_global_mut<TransferConfig>(admin_addr);
    config.transfer_restricted = true;
    config.compliance_registry_addr = option::some(compliance_registry_addr);
}

/// Disable transfer restrictions (admin only)
/// When disabled, transfers are unrestricted
public entry fun disable_transfer_restrictions(
    admin: &signer,
    admin_addr: address,
) acquires TransferConfig {
    let admin_addr_check = signer::address_of(admin);
    assert!(admin::has_admin_capability(admin_addr_check), error::permission_denied(E_NOT_ADMIN));
    assert!(exists<TransferConfig>(admin_addr), error::not_found(E_NOT_AUTHORIZED));
    
    let config = borrow_global_mut<TransferConfig>(admin_addr);
    config.transfer_restricted = false;
    config.compliance_registry_addr = option::none();
}

/// Check if transfer restrictions are enabled
#[view]
public fun is_transfer_restricted(admin_addr: address): bool {
    if (!exists<TransferConfig>(admin_addr)) {
        return false
    };
    let config = borrow_global<TransferConfig>(admin_addr);
    config.transfer_restricted
}

/// Get balance of TimeTokens for an address
#[view]
public fun balance(addr: address, admin_addr: address): u64 acquires MintCapability {
    if (!exists<MintCapability>(admin_addr)) {
        return 0
    };
    let metadata = get_metadata(admin_addr);
    primary_fungible_store::balance(addr, metadata)
}

#[test_only]
public fun initialize_for_test(
    admin: &signer,
): Object<Metadata> {
    admin::initialize_for_test(admin);
    let metadata = initialize(admin);
    // TransferConfig is automatically initialized in initialize()
    metadata
}

}
