script {

use villages_finance::registry_hub;

/// Register a new community in the RegistryHub owned by the sender.
entry fun register_community(
    admin: signer,
    hub_addr: address,
    community_id: u64,
    members_registry_addr: address,
    compliance_registry_addr: address,
    treasury_addr: address,
    pool_registry_addr: address,
    fractional_shares_addr: address,
    governance_addr: address,
    token_admin_addr: address,
    time_token_admin_addr: address,
) {
    registry_hub::register_community(
        &admin,
        hub_addr,
        community_id,
        members_registry_addr,
        compliance_registry_addr,
        treasury_addr,
        pool_registry_addr,
        fractional_shares_addr,
        governance_addr,
        token_admin_addr,
        time_token_admin_addr,
    );
}

}

