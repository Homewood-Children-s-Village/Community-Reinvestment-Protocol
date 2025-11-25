module villages_finance::registry_config {

use std::error;

/// Error codes
const E_INVALID_REGISTRY: u64 = 1;

/// Get the shared registry address for MVP
/// In MVP, admin initializes all registries, so admin address is the registry address
/// In production, this would return an object address or package address
public fun get_registry_address(admin_addr: address): address {
    admin_addr
}

/// Validate that a members registry exists at the given address
public fun validate_members_registry(addr: address): bool {
    use villages_finance::members;
    members::exists_membership_registry(addr)
}

/// Validate that a compliance registry exists at the given address
public fun validate_compliance_registry(addr: address): bool {
    use villages_finance::compliance;
    compliance::exists_compliance_registry(addr)
}

/// Validate that governance exists at the given address
public fun validate_governance(addr: address): bool {
    use villages_finance::governance;
    governance::exists_governance(addr)
}

}
