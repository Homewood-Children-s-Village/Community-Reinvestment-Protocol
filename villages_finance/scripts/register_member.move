script {
    use std::signer;
    use villages_finance::members;
    
    fun register_member(
        admin: signer,
        member_addr: address,
        role: u8,
    ) {
        members::register_member(admin, member_addr, role);
    }
}

