# Configura o n8n da Plataforma (equivalente a scripts/configurar-n8n.sh, para PowerShell).
# Execute na raiz do repositório com o ambiente no ar: ./scripts/configurar-n8n.ps1
# Sem 'Stop' global: o docker escreve progresso no stderr; os passos críticos conferem $LASTEXITCODE
Set-Location (Join-Path $PSScriptRoot '..')

function Read-EnvValue([string]$nome) {
    $linha = Get-Content .env | Where-Object { $_ -match "^$nome=" } | Select-Object -Last 1
    if ($linha) { return $linha.Substring($nome.Length + 1) } else { return '' }
}
$usuario = Read-EnvValue 'PLATAFORMA_DB_USER'; if (-not $usuario) { $usuario = 'plataforma_app' }
$senha = Read-EnvValue 'PLATAFORMA_DB_PASSWORD'
if (-not $senha) { throw 'PLATAFORMA_DB_PASSWORD não definida no .env' }

Write-Host '1/4 Credencial Postgres "plataforma"'
$cred = @(@{ id = 'plataformaPg0001'; name = 'plataforma'; type = 'postgres'; data = @{
    host = 'postgres'; port = 5432; database = 'plataforma'; user = $usuario; password = $senha
    ssl = 'disable'; allowUnauthorizedCerts = $false; sshTunnel = $false } })
# Enviada em base64 (só ASCII): o contêiner descarta qualquer outro byte (inclusive BOM) antes de decodificar
$json = ConvertTo-Json -InputObject $cred -Depth 5 -Compress
[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($json)) |
    docker compose exec -T n8n sh -c 'umask 077; tr -cd A-Za-z0-9+/= | base64 -d > /tmp/cred.json && n8n import:credentials --input=/tmp/cred.json; rc=$?; rm -f /tmp/cred.json; exit $rc'
if ($LASTEXITCODE -ne 0) { throw 'Falha ao importar a credencial' }

Write-Host '2/4 Importando workflows'
docker compose exec -T n8n n8n import:workflow --separate --input=/workflows
if ($LASTEXITCODE -ne 0) { throw 'Falha ao importar os workflows' }

Write-Host '3/4 Ativando workflows com webhooks'
foreach ($id in 'PlatAtaques00001', 'PlatModelos00001', 'PlatAvaliacoes01', 'PlatExecAvaliac1', 'PlatResultados01') {
    docker compose exec -T n8n n8n update:workflow --id=$id --active=true
}

Write-Host '4/4 Reiniciando o n8n para registrar os webhooks'
docker compose restart n8n
if ($LASTEXITCODE -ne 0) { throw 'Falha ao reiniciar o n8n' }
Write-Host 'Pronto. API: http://127.0.0.1:8080/api  (aguarde alguns segundos o n8n subir)'
