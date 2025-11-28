script {
    use std::signer;
    use villages_finance::members;
    use villages_finance::compliance;
    use villages_finance::admin;
    use villages_finance::timebank;
    use villages_finance::investment_pool;
    use villages_finance::project_registry;
    use villages_finance::parameters;
    
    fun initialize(admin: signer) {
        // Initialize all core modules
        admin::initialize(&admin);
        members::initialize(&admin);
        compliance::initialize(&admin);
        timebank::initialize(&admin);
        investment_pool::initialize(&admin);
        project_registry::initialize(&admin);
        parameters::initialize(&admin);
    }
}

