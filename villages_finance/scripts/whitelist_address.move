script {
    use std::signer;
    use villages_finance::compliance;
    
    fun whitelist_address(
        admin: signer,
        addr: address,
    ) {
        compliance::whitelist_address(admin, addr);
    }
}

