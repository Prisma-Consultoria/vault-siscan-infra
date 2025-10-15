storage "raft" {
  path    = "/vault/file"
  node_id = "vault-node-1"
}

# Terminação TLS no proxy (Caddy)
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

api_addr     = "http://vault:8200"
cluster_addr = "http://vault:8201"
ui           = true

audit {
  type = "file"
  path = "/vault/audit/audit.log"
}

disable_mlock = false
