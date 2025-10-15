# Substituir <ENV> e <ID_PROF>.
path "kv-siscan-<ENV>/data/credenciais/<ID_PROF>"     { capabilities = ["read"] }
path "kv-siscan-<ENV>/metadata/credenciais/<ID_PROF>" { capabilities = ["read"] }

# Bloquear enumeração
path "kv-siscan-<ENV>/data/credenciais"     { capabilities = [] }
path "kv-siscan-<ENV>/metadata/credenciais" { capabilities = [] }
