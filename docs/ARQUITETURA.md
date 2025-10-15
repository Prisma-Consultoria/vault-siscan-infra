# Arquitetura — Vault OSS para SISCAN

## Visão lógica
- Vault (OSS) com Integrated Storage (Raft)
- KV v2 por ambiente: `kv-siscan-dev`, `kv-siscan-hml`, `kv-siscan-prd`
- Autenticação:
  - AppRole para RPA (`svc-rpa-siscan-<env>`)
  - OIDC/LDAP (alvo) ou userpass (transitório) para profissionais
- Proxy TLS (Caddy) em HML/PRD
- Broker (opcional, recomendado) com *response wrapping* (uso único, TTL curto)

## Princípios
Mínimo privilégio, segregação por ambiente, tokens efêmeros, auditoria e LGPD.
