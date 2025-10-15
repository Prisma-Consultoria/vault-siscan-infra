# Infraestrutura Vault OSS para RPA SISCAN (Dev/HML/PRD)

Este repositório provê manifests Docker para o HashiCorp Vault (OSS) com **Integrated Storage (Raft)**, **Caddy** como *reverse proxy* TLS em HML/PRD, scripts de **bootstrap** (auditoria, *auth* AppRole, **mounts KV v2**), **templates de políticas** e demonstração do fluxo de **response wrapping** (para um “broker de credenciais”).

## Objetivo
Custodiar credenciais do SISCAN por profissional, permitindo que o RPA opere “em nome de” com mínimo privilégio, rastreabilidade e conformidade (LGPD).

## Estrutura
- `infra/vault/dev/`: ambiente de desenvolvimento (sem TLS no listener; porta 8200).
- `infra/vault/hml-prd/`: ambiente com Caddy (TLS), recomendado para HML/PRD.
- `infra/vault/bootstrap/`: scripts pós-subida (auditoria, auth, KV, políticas e *wrap* demo).
- `infra/vault/policies/`: políticas base e templates.
- `docs/`: documentação de arquitetura e operação.
- `.env.*.sample`: exemplos sem segredos (preencher valores reais fora do VCS).

## Requisitos
- Docker / Docker Compose
- `vault` CLI e `jq`
- DNS e portas 80/443 liberadas (HML/PRD) para ACME (Let’s Encrypt)

## Uso (DEV)
1. Subir o Vault (DEV):
   ```bash
   cd infra/vault/dev
   docker compose up -d
