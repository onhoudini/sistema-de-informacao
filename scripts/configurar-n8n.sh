#!/usr/bin/env bash
# Configura o n8n da Plataforma: credencial Postgres "plataforma", importação e
# ativação dos workflows de n8n/workflows/. Execute na raiz do repositório,
# com o ambiente no ar (docker compose up -d). Pode ser executado de novo.
#
# A senha vem do .env e é passada ao contêiner pela entrada padrão; nenhum
# arquivo de credencial fica no repositório.
set -euo pipefail
# Git Bash (Windows): não converter caminhos como /workflows
export MSYS_NO_PATHCONV=1
cd "$(dirname "$0")/.."

ler_env() { grep -E "^$1=" .env | tail -1 | cut -d= -f2-; }
USUARIO="$(ler_env PLATAFORMA_DB_USER)"; USUARIO="${USUARIO:-plataforma_app}"
SENHA="$(ler_env PLATAFORMA_DB_PASSWORD)"
[ -n "$SENHA" ] || { echo "PLATAFORMA_DB_PASSWORD não definida no .env" >&2; exit 1; }

echo "1/4 Credencial Postgres \"plataforma\""
printf '[{"id":"plataformaPg0001","name":"plataforma","type":"postgres","data":{"host":"postgres","port":5432,"database":"plataforma","user":"%s","password":"%s","ssl":"disable","allowUnauthorizedCerts":false,"sshTunnel":false}}]' "$USUARIO" "$SENHA" \
  | docker compose exec -T n8n sh -c 'umask 077; cat > /tmp/cred.json && n8n import:credentials --input=/tmp/cred.json; rc=$?; rm -f /tmp/cred.json; exit $rc'

echo "2/4 Importando workflows"
docker compose exec -T n8n n8n import:workflow --separate --input=/workflows

echo "3/4 Ativando workflows com webhooks"
# executar-tentativa é sub-workflow (Execute Workflow Trigger) e não precisa ser ativado
for id in PlatAtaques00001 PlatModelos00001 PlatAvaliacoes01 PlatExecAvaliac1 PlatResultados01; do
  docker compose exec -T n8n n8n update:workflow --id="$id" --active=true
done

echo "4/4 Reiniciando o n8n para registrar os webhooks"
docker compose restart n8n
echo "Pronto. API: http://127.0.0.1:8080/api  (aguarde alguns segundos o n8n subir)"
