# Disciplina de Sistemas de Informação

## Contexto

Trabalho da disciplina de Sistemas de Informação. Neste trabalho, será aplicado conhecimentos de Sistemas de Informação para projetar um sistema a ser implementado no fim do semestre.

## Sistema

**Plataforma Local de Avaliação de Segurança de Modelos de Linguagem (SLMs e LLMs).** O sistema executa, de forma totalmente local, ataques de *prompt injection* de turno único ou multi-turno contra modelos de linguagem locais, com ou sem *system prompt*. As respostas são verificadas por similaridade com o *system prompt* (TF-IDF e *embeddings*, com LLM juiz em caso de discordância), e o sistema registra as evidências e gera relatórios para revisão humana.

**Interfaces:** CLI (primeira a ser implementada) e Interface Web, ambas clientes de uma API local documentada, que também pode ser usada por scripts do pesquisador.

**Stack:** n8n (orquestração), Ollama (modelos), PostgreSQL (armazenamento), serviço Python de verificação, CLI em Python e Interface Web em HTML + JS, tudo em Docker Compose no ambiente local.

> **Uso autorizado (RE01):** a ferramenta tem natureza ofensiva e deve ser usada exclusivamente em avaliações autorizadas.

## Como executar

Pré-requisitos: Docker Desktop (WSL2) e Ollama (recomendado instalado no Windows, para usar a GPU).

```powershell
# 1. Modelos (alvo e juiz), baixados só na instalação
#    IDs testados (confira com `ollama list`): llama3.2:1b = baf6a787fdff, qwen2.5:3b = 357c53fb659c
ollama pull llama3.2:1b
ollama pull qwen2.5:3b

# 2. Configuração: copie e preencha senhas e a chave do n8n
copy .env.example .env

# 3. Subir o ambiente (o primeiro build baixa o modelo de embeddings)
docker compose up -d --build

# 4. Configurar o n8n: credencial, importação e ativação dos workflows
./scripts/configurar-n8n.ps1
```

- Interface Web: http://127.0.0.1:8080
- API da Plataforma: http://127.0.0.1:8080/api ([spec §5](spec.md))
- CLI: `./plataforma.ps1 --help` (ou `./plataforma.sh`); exemplo de avaliação em [exemplos/avaliacao-exemplo.json](exemplos/avaliacao-exemplo.json):

```powershell
./plataforma.ps1 modelos listar
./plataforma.ps1 avaliacoes validar exemplos/avaliacao-exemplo.json
./plataforma.ps1 avaliacoes criar exemplos/avaliacao-exemplo.json
./plataforma.ps1 avaliacoes executar 1
./plataforma.ps1 resultados resumo 1
./plataforma.ps1 resultados csv 1        # grava saida/avaliacao-1.csv
```

Testes: `docker compose run --rm verificador pytest` e `docker compose --profile cli run --rm --entrypoint pytest cli`. Calibração dos limiares (F8): `python verificador/calibracao.py saida/avaliacao-1.csv`.

## Documentação

| Documento | Conteúdo |
|---|---|
| [Solicitação de Sistema](docs/1-solicitacao-de-sistema.md) | Justificativa, objetivos e restrições do projeto. |
| [Lean Canvas](docs/2-lean-canvas.md) | Modelo de negócio do serviço de avaliação. |
| [Elicitação de Requisitos](docs/3-elicitacao-de-requisitos.md) | Requisitos funcionais e não funcionais. |
| [Casos de Uso](docs/4-casos-de-uso.md) | Fluxos de interação entre pesquisador e sistema. |
| [Diagrama de Processos](docs/5-diagrama-de-processos.md) | Modelagem UML dos processos de negócio onde o sistema será utilizado. |
| [Projeto do Sistema](docs/6-projeto-do-sistema.md) | Escopo, arquitetura C4, componentes e decisões de projeto. |
| [Glossário](GLOSSARY.md) | Vocabulário do domínio. |
| [Decisões de Arquitetura](docs/adr/) | ADRs com o contexto e o porquê das decisões estruturais. |
| [Especificação Técnica](spec.md) | Especificação para implementação: infraestrutura, modelo de dados, API, workflows e verificação. |
| [CLAUDE.md](CLAUDE.md) | Guia de trabalho para o Claude Code neste repositório. |

