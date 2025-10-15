storage "raft" {
  path    = "/vault/file"
  node_id = "vault-dev-1"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1  # Somente DEV. Em HML/PRD usar TLS no proxy.
}

api_addr     = "http://vault:8200"
cluster_addr = "http://vault:8201"
ui           = true

audit {
  type = "file"
  path = "/vault/audit/audit.log"
}

disable_mlock = false
