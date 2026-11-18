# CLAUDE.md

## Projeto

Trabalho da disciplina de Sistemas de Informação: **Plataforma Local de Avaliação de Segurança de Modelos de Linguagem (SLMs e LLMs)**. A plataforma executa ataques de *prompt injection* (turno único e multi-turno) contra modelos locais servidos pelo Ollama e verifica se a resposta vazou o *system prompt*. A verificação usa TF-IDF e *embeddings* (`paraphrase-multilingual-MiniLM-L12-v2`), com um LLM juiz quando os dois discordam.

- Requisitos e modelagem: [docs/](docs/) (1 a 6). **Fonte da verdade.**
- Decisões de implementação: [spec.md](spec.md). Decisões de arquitetura: [docs/adr/](docs/adr/).
- Vocabulário do domínio: [GLOSSARY.md](GLOSSARY.md).
- Stack: n8n (orquestração; seus webhooks implementam a API da Plataforma, exposta pelo `gateway` nginx), Ollama, PostgreSQL, serviço Python `verificador` (FastAPI), CLI Python (Typer + httpx, em contêiner) e Interface Web HTML + JS puro, tudo em Docker Compose.

## Regras invioláveis

1. **Nada sai do ambiente local** (RNF01, RNF03).
   - Sem APIs externas, SaaS ou nós de serviços em nuvem no n8n.
   - Sem CDN, fontes externas ou analytics na Interface Web; bibliotecas vão para `frontend/vendor/`.
   - Telemetria do n8n desligada (variáveis na seção 2.1 do spec). Não remova essas variáveis.
   - Modelos são baixados só na instalação (`docker build` do verificador, `ollama pull`). Nunca em tempo de execução.
   - Portas publicadas sempre em `127.0.0.1`.
   - **Versões sempre fixadas** (spec §2.2): nada de `latest` nem tags flutuantes em imagens, `FROM`, pacotes ou modelos. Pacotes Python novos ou atualizados exigem regenerar o `constraints.txt` da imagem.
2. **Resultados originais são imutáveis** (RN-13). Nunca faça `UPDATE`/`DELETE` em `verificacao`. Revisão humana é sempre `INSERT` em `revisao`.
3. **Uma avaliação por vez** (RF11). O índice único parcial em `avaliacao` garante isso; não o contorne.
4. **Sem interrupção antecipada** (RF12). Falha ou *timeout* numa tentativa vira `falha`, e o loop continua.
5. **Uso autorizado** (RE01). A ferramenta é ofensiva. Os ataques predefinidos tratam de extração de *system prompt*; não acrescente conteúdo voltado a causar dano real.
6. **Clientes finos** (RNF09, [ADR 0001](docs/adr/0001-interfaces-como-clientes-finos-da-api.md)). CLI e Interface Web só falam com a API da Plataforma (`/api/...` via `gateway`). Nenhuma regra de negócio nos clientes (nem o cálculo de N) e nenhum acesso direto a Postgres, Ollama ou n8n. Se um cliente precisa de uma regra, crie ou ajuste uma rota.

## Fonte da verdade e rastreabilidade

- Se uma mudança altera comportamento, atualize primeiro o doc em `docs/` e depois o `spec.md`, mantendo as matrizes de rastreabilidade (docs/4 e docs/6) coerentes.
- Use os IDs existentes (RFxx, RNFxx, RN-xx, UC-xx) em comentários, testes e mensagens de commit quando relevante.
- Terminologia: "chamada" (RF09/RF12/RF13) e "tentativa" (RF16) são a mesma unidade (execução completa de um ataque numa combinação). "Turno" é uma requisição ao Ollama. Não renomeie isso nos docs.
- O ator é sempre **Pesquisador** (nunca "usuário" ou "operador"). Interfaces: "CLI" e "Interface Web" (não "front-end" ou "interface" sem qualificador). Ao fechar um termo novo, registre-o no `GLOSSARY.md`.
- Docs 1 (Solicitação) e 2 (Lean Canvas) só devem ser alterados a pedido do usuário.

## Convenções

- Documentação, interface e mensagens de erro em **português (PT-BR)**.
- Banco: tabelas e colunas em `snake_case` português (`avaliacao`, `tentativa`, `timeout_chamada_s`).
- Python (`verificador/`): tipagem, FastAPI + Pydantic, testes com `pytest`. Nos testes, o Ollama é simulado; os testes não dependem de rede.
- CLI (`cli/`): mesmas convenções de Python; comandos e mensagens em PT-BR; `--json` em todos os comandos; códigos de saída do spec §8.1. Nos testes, a API é simulada (`httpx.MockTransport`).
- Interface Web: HTML + ES modules, sem etapa de build. Todas as chamadas passam por `frontend/js/api.js` e usam caminhos relativos `/api/...`.
- **Workflows n8n:** editados na interface do n8n e **exportados para `n8n/workflows/` antes de cada commit**. O JSON no repositório é a versão oficial.
- Nunca versione `.env`, credenciais do n8n ou `N8N_ENCRYPTION_KEY`. Novos parâmetros vão para `.env.example` com valor de exemplo.
- Commits só quando o usuário pedir.

## Comandos

```bash
# subir o ambiente (com Ollama em contêiner)
docker compose --profile ollama up -d
# subir usando o Ollama instalado no host (OLLAMA_BASE_URL=http://host.docker.internal:11434 no .env)
docker compose up -d

# baixar modelos (contêiner) — no host: ollama pull <modelo>
docker compose exec ollama ollama pull llama3.2:3b

# primeiro uso / após mudar workflows: credencial "plataforma" (do .env), importar, ativar e reiniciar o n8n
./scripts/configurar-n8n.ps1            # PowerShell
bash scripts/configurar-n8n.sh          # bash

# exportar / importar workflows do n8n (arquivos n8n/workflows/<id>.json)
docker compose exec n8n n8n export:workflow --all --separate --output=/workflows
docker compose exec n8n n8n import:workflow --separate --input=/workflows
#   (/workflows = volume montado de ./n8n/workflows; no Git Bash use MSYS_NO_PATHCONV=1)
#   ativação pela CLI do n8n só vale após `docker compose restart n8n`

# CLI (contêiner sob demanda; caminhos relativos à raiz, CSV em saida/)
./plataforma.ps1 avaliacoes listar      # PowerShell
./plataforma.sh avaliacoes listar       # bash

# testes da CLI
docker compose --profile cli run --rm --entrypoint pytest cli

# testes do verificador
docker compose run --rm verificador pytest
#   ou localmente: cd verificador && pytest

# inspecionar o banco da aplicação
docker compose exec postgres psql -U plataforma_app -d plataforma
```

Endereços locais: Interface Web `http://127.0.0.1:8080`, API da Plataforma `http://127.0.0.1:8080/api` (dentro do Compose: `http://gateway/api`), editor do n8n `http://127.0.0.1:5678`, Ollama `http://127.0.0.1:11434`.

## Ambiente

- Windows 11 + Docker Desktop (backend WSL2). Use caminhos com `/` em scripts e arquivos do Compose.
- GPU: o jeito mais simples é rodar o Ollama nativo no Windows e apontar `OLLAMA_BASE_URL` para `host.docker.internal`. O Ollama em contêiner com GPU NVIDIA exige suporte a GPU no WSL2.
- Primeiro uso do n8n: `scripts/configurar-n8n` cria a credencial Postgres `plataforma` (ID `plataformaPg0001`, host `postgres`, database `plataforma`, usuário `plataforma_app`), importa e ativa os workflows. A conta de proprietário local é criada no editor, só se for editar workflows.
- Se a porta 5678 estiver ocupada, defina `N8N_EDITOR_PORT` no `.env`.
- O gateway reescreve rotas com `:id` para webhooks estáticos `plataforma/...?id=` (spec §5.2); não use parâmetros de caminho nos webhooks.
- Nos workflows, laços leem dados de nós anteriores com `$('Nome').first()`, nunca `$json` (na volta do laço, `$json` é a saída do último nó).
