#!/usr/bin/env bash
# Atalho da CLI da Plataforma: executa o contêiner "cli" sob demanda.
# Caminhos são relativos à raiz do repositório; CSVs são gravados em saida/.
# Exemplo: ./plataforma.sh avaliacoes ver 3
cd "$(dirname "$0")"
export MSYS_NO_PATHCONV=1
exec docker compose --profile cli run --rm cli "$@"
