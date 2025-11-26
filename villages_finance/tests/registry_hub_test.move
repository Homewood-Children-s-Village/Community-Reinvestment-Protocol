#[test_only]
module villages_finance::registry_hub_test {

use villages_finance::registry_hub;
use std::signer;

#[test(admin = @0x1)]
fun test_register_and_query(admin: signer) {
    registry_hub::initialize(&admin);
    let admin_addr = signer::address_of(&admin);

    registry_hub::register_community(
        &admin,
        admin_addr,
        1,
        @0x101,
        @0x102,
        @0x103,
        @0x104,
        @0x105,
        @0x106,
        @0x107,
        @0x108,
    );

    let members_registry = registry_hub::members_registry_addr(admin_addr, 1);
    let treasury_addr = registry_hub::treasury_addr(admin_addr, 1);

    assert!(members_registry == @0x101, 0);
    assert!(treasury_addr == @0x103, 1);
}

}

