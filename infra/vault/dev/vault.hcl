storage "raft" {
  path    = "/vault/file"
  node_id = "vault-dev-1"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

api_addr     = "http://vault:8200"
cluster_addr = "http://vault:8201"
ui           = true

# Em DEV, desabilitar mlock evita reinícios em hosts sem memlock
disable_mlock = true
