# Operador: gestão de auth e policies, sem acesso a valores de segredos.
path "sys/policies/acl/*" { capabilities = ["create", "update", "read", "list"] }
path "sys/auth/*"         { capabilities = ["create", "update", "read", "list"] }
path "auth/*"             { capabilities = ["read", "list"] }
path "sys/mounts/*"       { capabilities = ["create", "update", "read", "list"] }
path "sys/health"         { capabilities = ["read"] }

# Sem acesso a kv/*
