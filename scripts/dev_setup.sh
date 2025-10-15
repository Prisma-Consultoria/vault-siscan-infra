#!/usr/bin/env bash
# dev_setup.sh — Bootstrap do ambiente DEV do Vault OSS para SISCAN (revisado)
# Uso:
#   ./scripts/dev_setup.sh [opções]
#
# Opções:
#   --auto-init                   Executa 'vault operator init' (não salva em disco).
#   --no-print-secrets            Não imprime root token e unseal keys (recomendado em ambientes compartilhados).
#   --unseal                      Solicita interativamente 3 chaves e executa o unseal (repete status).
#   --bootstrap                   Executa scripts de bootstrap (auditoria, auth, KV, policies/roles).
#   --create-demo-user ID         Cria usuário (userpass) de demonstração (apenas DEV).
#   --create-demo-secret ID       Cria segredo KV de demonstração (apenas DEV).
#   --wrap-demo ID                Executa demonstração de response wrapping (apenas DEV).
#   --diag                        Executa diagnóstico detalhado (logs, env, .env, listener duplicado).
#   --fix-port                    Ajusta listener interno para 8205 e mapeia host 8200->8205 (corrige colisões).
#   --reset                       Derruba DEV e remove volumes (APAGA estado).
#   --yes                         Não perguntar confirmação para ações destrutivas (uso com --reset).
#   --help                        Exibe esta ajuda.
#
# Pré-requisitos:
#   - Docker e Docker Compose
#   - curl e jq no host
#
# Observações:
#   - Em DEV, 'userpass' é apenas para demonstração. Em HML/PRD, preferir OIDC/LDAP.
#   - Este script não persiste segredos em disco; pode opcionalmente não imprimir em stdout.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEV_DIR="${ROOT_DIR}/infra/vault/dev"
BOOT_DIR="${ROOT_DIR}/infra/vault/bootstrap"

VAULT_HTTP="${VAULT_ADDR:-http://localhost:8200}"
VAULT_CONTAINER="vault-dev"

DO_AUTO_INIT=false
DO_UNSEAL=false
DO_BOOTSTRAP=false
DO_RESET=false
ASSUME_YES=false
CREATE_DEMO_USER=""
CREATE_DEMO_SECRET=""
RUN_WRAP_DEMO=""
DO_DIAG=false
DO_FIX_PORT=false
NO_PRINT_SECRETS=false

VAULT_TOKEN="${VAULT_TOKEN:-}"

usage() {
  cat <<'HLP'
Uso:
  ./scripts/dev_setup.sh [opções]

Opções:
  --auto-init                   Executa 'vault operator init'.
  --no-print-secrets            Evita imprimir unseal keys e root token.
  --unseal                      Executa unseal com 3 chaves (interativo).
  --bootstrap                   Habilita auditoria, auth e mounts KV v2.
  --create-demo-user ID         Cria usuário (userpass) DEV.
  --create-demo-secret ID       Cria segredo KV DEV para o ID.
  --wrap-demo ID                Demonstra response wrapping para o ID.
  --diag                        Diagnóstico (logs/env/.env/listener).
  --fix-port                    Ajusta listener interno para 8205 e Compose 8200:8205.
  --reset                       Down -v (APAGA estado DEV).
  --yes                         Confirma ações destrutivas sem prompt.
  --help                        Esta ajuda.

Exemplos:
  Subir, init, unseal e bootstrap:
    ./scripts/dev_setup.sh --auto-init --unseal --bootstrap

  Diagnosticar problemas de subida:
    ./scripts/dev_setup.sh --diag

  Corrigir colisão da porta interna:
    ./scripts/dev_setup.sh --fix-port
HLP
}

# Parse de argumentos
while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto-init) DO_AUTO_INIT=true; shift ;;
    --no-print-secrets) NO_PRINT_SECRETS=true; shift ;;
    --unseal) DO_UNSEAL=true; shift ;;
    --bootstrap) DO_BOOTSTRAP=true; shift ;;
    --create-demo-user) CREATE_DEMO_USER="${2:?informar ID}"; shift 2 ;;
    --create-demo-secret) CREATE_DEMO_SECRET="${2:?informar ID}"; shift 2 ;;
    --wrap-demo) RUN_WRAP_DEMO="${2:?informar ID}"; shift 2 ;;
    --diag) DO_DIAG=true; shift ;;
    --fix-port) DO_FIX_PORT=true; shift ;;
    --reset) DO_RESET=true; shift ;;
    --yes) ASSUME_YES=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Opção desconhecida: $1"; usage; exit 1 ;;
  esac
done

# Checagens básicas
command -v docker >/dev/null || { echo "Docker não encontrado."; exit 1; }
command -v curl >/dev/null || { echo "curl não encontrado."; exit 1; }
command -v jq >/dev/null || { echo "jq não encontrado."; exit 1; }
[[ -f "${DEV_DIR}/docker-compose.yml" ]] || { echo "Compose DEV não encontrado em ${DEV_DIR}."; exit 1; }
[[ -f "${DEV_DIR}/vault.hcl" ]] || { echo "vault.hcl não encontrado em ${DEV_DIR}."; exit 1; }

vault_exec() {
  # Garante HTTP dentro do contêiner (DEV): evita tentativa de HTTPS default do CLI.
  docker exec -i "${VAULT_CONTAINER}" sh -lc "export VAULT_ADDR=http://127.0.0.1:8200; $*"
}

compose_up() {
  (cd "${DEV_DIR}" && docker compose up -d)
}

ensure_up_dev() {
  echo ">> Subindo ambiente DEV..."
  compose_up
  echo ">> Aguardando container '${VAULT_CONTAINER}'..."
  for _ in {1..30}; do
    if docker ps --format '{{.Names}}' | grep -q "^${VAULT_CONTAINER}$"; then
      echo ">> Container em execução."
      return 0
    fi
    sleep 1
  done
  echo "Não foi possível confirmar a execução do container '${VAULT_CONTAINER}'."
  exit 1
}

wait_http_ready_or_diag() {
  echo ">> Aguardando endpoint HTTP ${VAULT_HTTP}..."
  # Considera atingível: 200 OK, 429 standby, 472 DR secondary, 501 not initialized, 503 sealed
  for _ in {1..30}; do
    code="$(curl -sS -o /dev/null -w '%{http_code}' "${VAULT_HTTP}/v1/sys/health" || true)"
    case "${code}" in
      200|429|472|501|503)
        echo ">> Endpoint acessível (HTTP ${code})."
        return 0
        ;;
    esac
    sleep 1
  done
  echo "Aviso: /sys/health não respondeu com códigos esperados. Iniciando diagnóstico automático..."
  run_diag
}

run_diag() {
  echo "== Diagnóstico =="
  echo "-- docker compose ps --"
  (cd "${DEV_DIR}" && docker compose ps || true)
  echo "-- docker logs (últimas 200 linhas) --"
  docker logs --tail=200 "${VAULT_CONTAINER}" 2>&1 || true
  echo "-- variáveis do contêiner (grep VAULT_) --"
  docker inspect "${VAULT_CONTAINER}" --format '{{json .Config.Env}}' 2>/dev/null \
    | jq -r '.[]' | grep -E '^VAULT_' || echo "(sem VAULT_* definidas no contêiner)"

  echo "-- .env no diretório do compose --"
  if [[ -f "${DEV_DIR}/.env" ]]; then
    echo "(ATENÇÃO) arquivo .env detectado em ${DEV_DIR} — Compose injeta variáveis automaticamente."
    nl -ba "${DEV_DIR}/.env" | sed -n '1,120p'
  else
    echo "Nenhum .env no diretório do compose."
  fi

  echo "-- checagem de duplicidade de listener no vault.hcl --"
  cnt=$(grep -c 'listener "tcp"' "${DEV_DIR}/vault.hcl" || true)
  echo "Ocorrências de listener tcp no vault.hcl: ${cnt}"

  echo "== Fim do diagnóstico =="
}

fix_port_collision() {
  echo ">> Ajustando porta interna para 8205 e mapeando host 8200:8205..."
  local ts
  ts="$(date +%Y%m%d%H%M%S)"

  # Backups
  cp -a "${DEV_DIR}/vault.hcl" "${DEV_DIR}/vault.hcl.bak.${ts}"
  cp -a "${DEV_DIR}/docker-compose.yml" "${DEV_DIR}/docker-compose.yml.bak.${ts}"

  # Ajuste do vault.hcl
  sed -i '' -e 's/address[[:space:]]*=[[:space:]]*"0\.0\.0\.0:8200"/address = "0.0.0.0:8205"/' "${DEV_DIR}/vault.hcl" 2>/dev/null || \
  sed -i -e 's/address[[:space:]]*=[[:space:]]*"0\.0\.0\.0:8200"/address = "0.0.0.0:8205"/' "${DEV_DIR}/vault.hcl"

  sed -i '' -e 's|api_addr[[:space:]]*=[[:space:]]*"http://vault:8200"|api_addr = "http://vault:8205"|' "${DEV_DIR}/vault.hcl" 2>/dev/null || \
  sed -i -e 's|api_addr[[:space:]]*=[[:space:]]*"http://vault:8200"|api_addr = "http://vault:8205"|' "${DEV_DIR}/vault.hcl"

  # Ajuste do docker-compose.yml: mapear 8200:8205 e garantir comando explícito do Vault
  if ! grep -q 'command: \["vault", "server"' "${DEV_DIR}/docker-compose.yml"; then
    awk '
      /container_name: vault-dev/ { print; print "    command: [\"vault\", \"server\", \"-config=/vault/config/vault.hcl\", \"-log-level=debug\"]"; next }
      { print }
    ' "${DEV_DIR}/docker-compose.yml" > "${DEV_DIR}/docker-compose.yml.tmp" && mv "${DEV_DIR}/docker-compose.yml.tmp" "${DEV_DIR}/docker-compose.yml"
  fi

  # Ajusta porta
  if grep -q '"8200:8200"' "${DEV_DIR}/docker-compose.yml"; then
    sed -i '' -e 's/"8200:8200"/"8200:8205"/' "${DEV_DIR}/docker-compose.yml" 2>/dev/null || \
    sed -i -e 's/"8200:8200"/"8200:8205"/' "${DEV_DIR}/docker-compose.yml"
  fi

  echo ">> Reiniciando DEV com nova configuração..."
  (cd "${DEV_DIR}" && docker compose down -v && docker compose up -d)
  docker logs --tail=120 -f "${VAULT_CONTAINER}"
}

status_info() {
  echo ">> Status do Vault (pode falhar se selado ou não inicializado):"
  vault_exec 'vault status || true'
}

do_init() {
  echo ">> Executando 'vault operator init'..."
  local out_json
  out_json="$(vault_exec 'vault operator init -format=json')"

  local root_token
  root_token="$(echo "${out_json}" | jq -r '.root_token')"

  if ${NO_PRINT_SECRETS}; then
    echo ">> Init concluído. Segredos NÃO foram impressos (--no-print-secrets)."
    if command -v pbcopy >/dev/null 2>&1; then
      echo "${out_json}" | pbcopy
      echo ">> JSON de init copiado para a área de transferência (macOS)."
    fi
  else
    echo
    echo "===== ATENÇÃO — ANOTAR E GUARDAR COM SEGURANÇA ====="
    echo "Shares (unseal keys):"
    echo "${out_json}" | jq -r '.unseal_keys_hex[]' | nl -w1 -s': '
    echo
    echo "Root Token:"
    echo "${root_token}"
    echo "===== FIM ====="
    echo
  fi

  VAULT_TOKEN="${root_token}"
  export VAULT_TOKEN
}

do_unseal() {
  echo ">> Execução do UNSEAL (serão solicitadas 3 chaves)."
  read -rsp "Inserir Unseal Key #1: " K1; echo
  read -rsp "Inserir Unseal Key #2: " K2; echo
  read -rsp "Inserir Unseal Key #3: " K3; echo

  vault_exec "vault operator unseal '${K1}'"
  vault_exec "vault operator unseal '${K2}'"
  vault_exec "vault operator unseal '${K3}'"

  echo ">> UNSEAL executado. Status:"
  status_info
}

do_bootstrap() {
  echo ">> Executando bootstrap (auditoria, auth, KV, policies/roles)..."
  export VAULT_ADDR="${VAULT_HTTP}"
  if [[ -z "${VAULT_TOKEN:-}" ]]; then
    read -rsp "Inserir VAULT_TOKEN (root/operador): " VAULT_TOKEN; echo
    export VAULT_TOKEN
  fi
  bash "${BOOT_DIR}/01-enable-audit.sh"
  bash "${BOOT_DIR}/02-enable-auth-and-kv.sh"
  bash "${BOOT_DIR}/03-policies-and-roles.sh"
  echo ">> Bootstrap concluído."
}

do_create_demo_user() {
  local id="${CREATE_DEMO_USER}"
  [[ -n "${id}" ]] || return 0
  export VAULT_ADDR="${VAULT_HTTP}"
  if [[ -z "${VAULT_TOKEN:-}" ]]; then
    read -rsp "Inserir VAULT_TOKEN (root/operador): " VAULT_TOKEN; echo
    export VAULT_TOKEN
  fi
  echo ">> Criando usuário DEV (userpass) '${id}'..."
  vault_exec "vault write auth/userpass/users/${id} password='SenhaForte!2025' policies=default"
  echo ">> Usuário '${id}' criado (apenas DEV)."
}

do_create_demo_secret() {
  local id="${CREATE_DEMO_SECRET}"
  [[ -n "${id}" ]] || return 0
  export VAULT_ADDR="${VAULT_HTTP}"
  if [[ -z "${VAULT_TOKEN:-}" ]]; then
    read -rsp "Inserir VAULT_TOKEN (root/operador): " VAULT_TOKEN; echo
    export VAULT_TOKEN
  fi
  echo ">> Gravando segredo KV para '${id}' em kv-siscan-dev..."
  vault_exec "vault kv put kv-siscan-dev/credenciais/${id} usuario='${id}.usuario' senha='SenhaForte!2025' cnes='1234567' perfil='profissional' metadados='{\"observacao\":\"apenas DEV\"}'"
  echo ">> Leitura de validação:"
  vault_exec "vault kv get kv-siscan-dev/credenciais/${id} || true"
}

do_wrap_demo() {
  local id="${RUN_WRAP_DEMO}"
  [[ -n "${id}" ]] || return 0
  export VAULT_ADDR="${VAULT_HTTP}"
  if [[ -z "${VAULT_TOKEN:-}" ]]; then
    read -rsp "Inserir VAULT_TOKEN (root/operador): " VAULT_TOKEN; echo
    export VAULT_TOKEN
  fi
  echo ">> Executando wrap demo para '${id}' (ENV=dev)..."
  bash "${BOOT_DIR}/04-broker-demo.sh" dev "${id}" | sed 's/^/   /'
  echo ">> Para consumir no robô (exemplo):"
  cat <<'EOF'
VAULT_TOKEN=$(vault unwrap -field=token <wrap_token>)
vault kv get kv-siscan-dev/credenciais/<id_profissional>
EOF
}

do_reset() {
  if ! ${ASSUME_YES}; then
    read -rp "Confirma remover contêineres e VOLUMES do DEV (APAGA estado)? [y/N] " ans
    [[ "${ans:-N}" =~ ^[Yy]$ ]] || { echo "Cancelado."; exit 0; }
  fi
  (cd "${DEV_DIR}" && docker compose down -v)
  echo ">> Ambiente DEV removido e volumes apagados."
}

post_info() {
  echo
  echo ">> UI do Vault (DEV): ${VAULT_HTTP}"
  echo "   Login com método 'Token'."
  echo ">> Próximos passos:"
  echo "   - Integrar o RPA para leitura KV somente em memória."
  echo "   - Evoluir autenticação de profissionais para OIDC/LDAP em HML/PRD."
}

# Fluxo principal
if ${DO_RESET}; then
  do_reset
  exit 0
fi

if ${DO_FIX_PORT}; then
  fix_port_collision
  exit 0
fi

ensure_up_dev

if ${DO_DIAG}; then
  run_diag
fi

wait_http_ready_or_diag
status_info

if ${DO_AUTO_INIT}; then
  do_init
fi

if ${DO_UNSEAL}; then
  do_unseal
fi

if ${DO_BOOTSTRAP}; then
  do_bootstrap
fi

if [[ -n "${CREATE_DEMO_USER}" ]]; then
  do_create_demo_user
fi

if [[ -n "${CREATE_DEMO_SECRET}" ]]; then
  do_create_demo_secret
fi

if [[ -n "${RUN_WRAP_DEMO}" ]]; then
  do_wrap_demo
fi

post_info

# Higiene: reduzir exposição do token no ambiente da shell chamadora
unset VAULT_TOKEN || true
