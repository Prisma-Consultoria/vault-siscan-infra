# Contribuição

## Padrão de branches e commits
- Branches: `feature/<descrição>`, `hotfix/<descrição>`.
- Commits: `<tipo>: <escopo> — <resumo>`; referenciar issues quando aplicável.
- `main` protegida; PR com revisão obrigatória para alterações em `infra/vault/**`.

## Boas práticas
- Não incluir valores sensíveis em exemplos ou scripts. Utilizar *placeholders* e variáveis de ambiente.
- Alterações em `vault.hcl`, `docker-compose.yml` e políticas devem ser descritas no PR (motivo e impacto).
- Testar localmente em DEV antes de propor mudanças em HML/PRD.
