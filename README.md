# Vault OSS para SISCAN — Infraestrutura de Cofre de Segredos (Dev/HML/PRD)

## Introdução

Este projeto disponibiliza uma base completa para implantação do **HashiCorp Vault (Open Source)** dedicada à custódia de credenciais do **SISCAN**, com separação por ambientes (desenvolvimento, homologação e produção), **governança de acesso por profissional**, **rastreamento de auditoria** e integração simplificada com **RPA**. 

A proposta visa permitir que o RPA execute ações “em nome de” profissionais do SISCAN sem expor senhas à equipe, preservando **mínimo privilégio**, **tokens efêmeros**, **não enumeração de segredos** e **aderência à LGPD**. Em HML/PRD, a exposição externa é realizada por *reverse proxy* com **TLS** (Caddy/Let’s Encrypt). Opcionalmente, um **broker de credenciais** pode emitir *tokens* de leitura de uso único (*response wrapping*), reduzindo ainda mais a superfície de risco.

---

## Objetivo e princípios

**Objetivo**  
Custodiar usuário/senha do SISCAN por profissional e permitir que o RPA consuma esses segredos **apenas em memória** e **somente quando autorizado**, com trilhas de auditoria e controles de revogação/rotação.

**Princípios**  
- Segregação por ambiente: `dev`, `hml`, `prd`.  
- Mínimo privilégio e **negação de listagem** (impede enumeração de caminhos).  
- Tokens efêmeros, TTL curto e revogação imediata.  
- Auditoria habilitada e exportável para SIEM.  
- Conformidade com a LGPD (finalidade documentada, rotação e offboarding).  

---

## Arquitetura (resumo)

- **Vault OSS** com **Integrated Storage (Raft)** e **KV v2** para versionamento de segredos.
- **Caddy (TLS)** em HML/PRD para terminação HTTPS e cabeçalhos de segurança.
- **AppRole** como método de autenticação do RPA; OIDC/LDAP como alvo para profissionais (userpass transitório).
- **Broker de credenciais** (opcional): recebe `id_tarefa` + `id_profissional`, valida autorização e emite *wrap token* de uso único.
- **Auditoria** do Vault habilitada em arquivo e passível de expedição para SIEM.

---

## Estrutura do repositório

```

infra/
vault/
dev/
docker-compose.yml
vault.hcl
hml-prd/
docker-compose.yml
vault.hcl
caddy/
Caddyfile
bootstrap/
01-enable-audit.sh
02-enable-auth-and-kv.sh
03-policies-and-roles.sh
04-broker-demo.sh
policies/
policy-profissional-template.hcl
policy-rpa-read-template.hcl
policy-operator.hcl
.env.dev.sample
.env.hml.sample
.env.prd.sample
docs/
ARQUITETURA.md
PLAYBOOKS.md
OPERACAO-SEGURANCA-LGPD.md
.github/
ISSUE_TEMPLATE/
PULL_REQUEST_TEMPLATE.md
workflows/
lint-compose.yml
scripts/
generate_policy_for_prof.sh
check_security_basics.sh

````

---

## Pré-requisitos

- Docker e Docker Compose.
- CLI do Vault (`vault`) e `jq` instalados no host de administração.
- DNS apontando para o *reverse proxy* (HML/PRD) com portas 80/443 abertas para ACME (Let’s Encrypt).
- Operadores com procedimentos de guarda de **unseal keys** e **root token** fora deste repositório.

---

## Como usar — Desenvolvimento (DEV)

1. Subir o Vault:
```bash
   cd infra/vault/dev
   docker compose up -d
````

2. Inicializar e destravar:

   ```bash
   docker exec -it vault-dev sh -lc 'vault operator init'
   docker exec -it vault-dev sh -lc 'vault operator unseal'
   # Repetir unseal até atingir o limiar configurado
   ```
3. *Bootstrap* (no host, com variáveis exportadas):

   ```bash
   export VAULT_ADDR=http://localhost:8200
   export VAULT_TOKEN=<root-token>
   bash ../../bootstrap/01-enable-audit.sh
   bash ../../bootstrap/02-enable-auth-and-kv.sh
   bash ../../bootstrap/03-policies-and-roles.sh
   ```

---

## Como usar — Homologação/Produção (HML/PRD)

1. Configurar `.env` a partir dos samples:

   ```bash
   cp infra/vault/.env.hml.sample infra/vault/.env.hml
   # Editar DOMAIN e ACME_EMAIL
   ```
2. Subir a stack com Caddy (TLS):

   ```bash
   cd infra/vault/hml-prd
   docker compose --env-file ../.env.hml up -d   # ou ../.env.prd em produção
   ```
3. Inicializar o cluster:

   ```bash
   docker exec -it vault sh -lc 'vault operator init'
   docker exec -it vault sh -lc 'vault operator unseal'
   ```
4. *Bootstrap*:

   ```bash
   export VAULT_ADDR=https://<DOMAIN>
   export VAULT_TOKEN=<root-token ou token de operador>
   bash ../../bootstrap/01-enable-audit.sh
   bash ../../bootstrap/02-enable-auth-and-kv.sh
   bash ../../bootstrap/03-policies-and-roles.sh
   ```

---

## Montagens KV v2 e caminhos por profissional

* Mounts por ambiente: `kv-siscan-dev`, `kv-siscan-hml`, `kv-siscan-prd`.
* Caminho por profissional (ex. produção):
  `kv-siscan-prd/credenciais/<id_profissional>`
  Chaves: `usuario`, `senha`, `cnes`, `perfil`, `metadados` (não sensíveis).

**Observação:** KV v2 é versionado; a rotação de senhas no SISCAN deve ser seguida pela atualização do valor no Vault pelo próprio profissional.

---

## Políticas e acessos

* **Operador**: `policy-operator.hcl` (gestão de auth e policies; sem acesso a valores).
* **Profissional**: `policy-profissional-template.hcl` (create/update do próprio caminho; sem list no prefixo).
* **RPA**: `policy-rpa-read-template.hcl` (read estrito no caminho do profissional; sem list).

O script `scripts/generate_policy_for_prof.sh` gera políticas substituindo `<ENV>` e `<ID_PROF>` e as aplica automaticamente no Vault.

---

## Fluxo com broker (response wrapping)

O broker valida `id_tarefa` + `id_profissional` e emite um **wrap token** com TTL curto e política de leitura **apenas** para o caminho requerido. O RPA executa:

1. `unwrap` do *wrap token* para obter o **token efetivo** (vida curta).
2. Leitura KV em memória e autenticação no SISCAN.
3. Descarte do token ao fim da execução.

Para demonstração local, utilizar:

```bash
export VAULT_ADDR=...
export VAULT_TOKEN=<token de operador>
bash infra/vault/bootstrap/04-broker-demo.sh prd diego.123
# Saída: wrap_token: <valor>
# No robô:
# VAULT_TOKEN=$(vault unwrap -field=token <wrap_token>)
# vault kv get kv-siscan-prd/credenciais/diego.123
```

---

## Segurança e LGPD (boas práticas)

* Nunca versionar **unseal keys**, **root token**, **secret_id** (AppRole), **tokens**, **snapshots Raft** ou arquivos `.env` reais.
* Habilitar auditoria e enviar logs para SIEM, com cuidado para não registrar campos sensíveis.
* Usar tokens com **TTL curto**, revogação imediata e **deny-by-default** para listagem.
* Desabilitar *debug* em clientes; garantir que nenhuma exceção/log exponha `usuario`/`senha`.
* Formalizar rotação periódica (30–60 dias) e **offboarding** com revogação e evidências de auditoria.

---

## Alta disponibilidade e backup

* Em produção, recomenda-se **3 nós** Vault (Raft) com `retry_join` e *quorum*.
* Realizar **snapshots** periódicos e **testes de restauração**.
* Manter runbooks de **DR** e de **unseal** em local seguro.

---

## Troubleshooting básico

* `vault status` para verificar *sealed/unsealed*, *HA* e *storage*.
* Erros de TLS em HML/PRD: conferir DNS, portas 80/443 e emissão ACME.
* Acesso negado em KV: checar política aplicada ao token e se o prefixo não permite `list`.

---

## Roadmap sugerido

* Migração de autenticação de profissionais para **OIDC/LDAP**.
* Implementação do **broker** oficial (FastAPI/Go) com trilhas e cache negativos.
* Expansão para **cluster de 3 nós** no PRD com *health checks* e *snapshot jobs* automatizados.

---

## Licença

MIT. Ver arquivo `LICENSE`.
