script {
    use std::signer;
    use villages_finance::members;
    use villages_finance::compliance;
    use villages_finance::admin;
    
    fun initialize(admin: signer) {
        // Initialize all core modules
        members::initialize(&admin);
        compliance::initialize(&admin);
        admin::initialize(&admin);
    }
}

