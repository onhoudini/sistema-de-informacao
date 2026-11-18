# Atalho da CLI da Plataforma: executa o contêiner "cli" sob demanda.
# Caminhos são relativos à raiz do repositório; CSVs são gravados em saida/.
# Exemplo: ./plataforma.ps1 avaliacoes ver 3
Push-Location $PSScriptRoot
try {
    docker compose --profile cli run --rm cli @args
    $codigo = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $codigo
