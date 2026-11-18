#!/bin/bash
# Permissões do usuário da aplicação no database "plataforma".
# RN-13: sem UPDATE/DELETE em verificacao e revisao (além dos triggers).
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname plataforma \
  -v app_user="$PLATAFORMA_DB_USER" <<'SQL'
GRANT USAGE ON SCHEMA public TO :"app_user";
GRANT SELECT, INSERT, UPDATE ON ataque, avaliacao, avaliacao_system_prompt,
  avaliacao_ataque, tentativa, turno TO :"app_user";
GRANT SELECT, INSERT ON verificacao, revisao TO :"app_user";
GRANT SELECT ON v_resultado TO :"app_user";
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO :"app_user";
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO :"app_user";
SQL
