script {
    use std::signer;
    use villages_finance::timebank;
    use villages_finance::investment_pool;
    use villages_finance::project_registry;
    use villages_finance::parameters;
    
    fun initialize_missing(admin: signer) {
        // Initialize only the modules that are likely missing
        // These are idempotent, so safe to call even if already initialized
        timebank::initialize(&admin);
        investment_pool::initialize(&admin);
        project_registry::initialize(&admin);
        parameters::initialize(&admin);
    }
}

