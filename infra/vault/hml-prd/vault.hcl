storage "raft" {
  path    = "/vault/file"
  node_id = "vault-dev-1"
}

listener "tcp" {
  address     = "0.0.0.0:8205"   # <— trocado para 8205
  tls_disable = 1
}

api_addr     = "http://vault:8205"  # <— alinhar com a porta interna
cluster_addr = "http://vault:8201"
ui           = true

disable_mlock = true
