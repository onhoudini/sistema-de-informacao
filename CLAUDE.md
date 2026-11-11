# CLAUDE.md

## Projeto

Trabalho da disciplina de Sistemas de Informação: **Plataforma Local de Avaliação de Segurança de Modelos de Linguagem (SLMs e LLMs)**. A plataforma executa ataques de *prompt injection* (turno único e multi-turno) contra modelos locais servidos pelo Ollama e verifica se a resposta vazou o *system prompt*. A verificação usa TF-IDF e *embeddings* (`paraphrase-multilingual-MiniLM-L12-v2`), com um LLM juiz quando os dois discordam.

- Requisitos e modelagem: [docs/](docs/) (1 a 6). **Fonte da verdade.**
- Decisões de implementação: [spec.md](spec.md).
- Stack: n8n (orquestração e API via webhooks), Ollama, PostgreSQL, serviço Python `verificador` (FastAPI), front-end HTML + JS puro servido por nginx, tudo em Docker Compose.

## Regras invioláveis

1. **Nada sai do ambiente local** (RNF01, RNF03).
   - Sem APIs externas, SaaS ou nós de serviços em nuvem no n8n.
   - Sem CDN, fontes externas ou analytics no front-end; bibliotecas vão para `frontend/vendor/`.
   - Telemetria do n8n desligada (variáveis na seção 2.1 do spec). Não remova essas variáveis.
   - Modelos são baixados só na instalação (`docker build` do verificador, `ollama pull`). Nunca em tempo de execução.
   - Portas publicadas sempre em `127.0.0.1`.
2. **Resultados originais são imutáveis** (RN-13). Nunca faça `UPDATE`/`DELETE` em `verificacao`. Revisão humana é sempre `INSERT` em `revisao`.
3. **Uma avaliação por vez** (RF11). O índice único parcial em `avaliacao` garante isso; não o contorne.
4. **Sem interrupção antecipada** (RF12). Falha ou *timeout* numa tentativa vira `falha`, e o loop continua.
5. **Uso autorizado** (RE01). A ferramenta é ofensiva. Os ataques predefinidos tratam de extração de *system prompt*; não acrescente conteúdo voltado a causar dano real.

## Fonte da verdade e rastreabilidade

- Se uma mudança altera comportamento, atualize primeiro o doc em `docs/` e depois o `spec.md`, mantendo as matrizes de rastreabilidade (docs/4 e docs/6) coerentes.
- Use os IDs existentes (RFxx, RNFxx, RN-xx, UC-xx) em comentários, testes e mensagens de commit quando relevante.
- Terminologia: "chamada" (RF09/RF12/RF13) e "tentativa" (RF16) são a mesma unidade (execução completa de um ataque numa combinação). "Turno" é uma requisição ao Ollama. Não renomeie isso nos docs.
- Docs 1 (Solicitação) e 2 (Lean Canvas) só devem ser alterados a pedido do usuário.

## Convenções

- Documentação, interface e mensagens de erro em **português (PT-BR)**.
- Banco: tabelas e colunas em `snake_case` português (`avaliacao`, `tentativa`, `timeout_chamada_s`).
- Python (`verificador/`): tipagem, FastAPI + Pydantic, testes com `pytest`. Nos testes, o Ollama é simulado; os testes não dependem de rede.
- Front-end: HTML + ES modules, sem etapa de build. Todas as chamadas passam por `frontend/js/api.js` e usam caminhos relativos `/api/...`.
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

# exportar / importar workflows do n8n
docker compose exec n8n n8n export:workflow --all --separate --output=/workflows
docker compose exec n8n n8n import:workflow --separate --input=/workflows
#   (/workflows = volume montado de ./n8n/workflows)

# testes do verificador
docker compose run --rm verificador pytest
#   ou localmente: cd verificador && pytest

# inspecionar o banco da aplicação
docker compose exec postgres psql -U plataforma_app -d plataforma
```

Endereços locais: front-end `http://127.0.0.1:8080`, editor do n8n `http://127.0.0.1:5678`, Ollama `http://127.0.0.1:11434`.

## Ambiente

- Windows 11 + Docker Desktop (backend WSL2). Use caminhos com `/` em scripts e arquivos do Compose.
- GPU: o jeito mais simples é rodar o Ollama nativo no Windows e apontar `OLLAMA_BASE_URL` para `host.docker.internal`. O Ollama em contêiner com GPU NVIDIA exige suporte a GPU no WSL2.
- Primeiro uso do n8n: criar a conta de proprietário local e a credencial Postgres `plataforma` (host `postgres`, database `plataforma`, usuário `plataforma_app`). Depois, importar e ativar os workflows.
