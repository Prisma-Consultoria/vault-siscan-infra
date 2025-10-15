# Playbooks Operacionais

## Init/Unseal (primeira vez)
1. `vault operator init` → distribuir *unseal keys*, guardar *root token*
2. `vault operator unseal` até atingir limiar
3. Executar scripts de bootstrap (auditoria, auth, KV)

## Backup/Restore (Raft snapshots)
- Agendar snapshots periódicos
- Testar restauração em ambiente isolado

## Auditoria
- Audit device habilitado (arquivo) e expedição para SIEM
- Cuidado com redigir campos sensíveis na camada de observabilidade

## DR (Recuperação de Desastre)
- Procedimentos documentados para restauração de snapshots
- Verificação de *unseal* e de integridade de políticas
