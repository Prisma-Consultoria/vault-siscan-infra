# Substituir <ENV> e <ID_PROF> no onboarding.
path "kv-siscan-<ENV>/data/credenciais/<ID_PROF>"     { capabilities = ["create", "read", "update"] }
path "kv-siscan-<ENV>/metadata/credenciais/<ID_PROF>" { capabilities = ["read", "update"] }

# Negar list no prefixo
path "kv-siscan-<ENV>/data/credenciais"     { capabilities = [] }
path "kv-siscan-<ENV>/metadata/credenciais" { capabilities = [] }
