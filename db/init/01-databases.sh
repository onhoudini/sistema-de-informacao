#!/bin/bash
# Cria os databases "n8n" (interno do n8n) e "plataforma" (dados da aplicação)
# e os usuários correspondentes. Executado só na primeira inicialização do volume.
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres \
  -v n8n_user="$N8N_DB_USER" -v n8n_pass="$N8N_DB_PASSWORD" \
  -v app_user="$PLATAFORMA_DB_USER" -v app_pass="$PLATAFORMA_DB_PASSWORD" <<'SQL'
CREATE ROLE :"n8n_user" LOGIN PASSWORD :'n8n_pass';
CREATE ROLE :"app_user" LOGIN PASSWORD :'app_pass';
CREATE DATABASE n8n OWNER :"n8n_user";
CREATE DATABASE plataforma;
-- plataforma_app só acessa o database "plataforma"
REVOKE CONNECT ON DATABASE n8n FROM PUBLIC;
REVOKE CONNECT ON DATABASE plataforma FROM PUBLIC;
GRANT CONNECT ON DATABASE plataforma TO :"app_user";
REVOKE CONNECT ON DATABASE postgres FROM PUBLIC;
SQL
