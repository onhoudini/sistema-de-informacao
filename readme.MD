# Disciplina de Sistemas de Informação

## Contexto

Trabalho da disciplina de Sistemas de Informação. Neste trabalho, será aplicado conhecimentos de Sistemas de Informação para projetar um sistema a ser implementado no fim do semestre.

## Sistema

**Plataforma Local de Avaliação de Segurança de Modelos de Linguagem (SLMs e LLMs).** O sistema executa, de forma totalmente local, ataques de *prompt injection* de turno único ou multi-turno contra modelos de linguagem locais, com ou sem *system prompt*. As respostas são verificadas por similaridade com o *system prompt* (TF-IDF e *embeddings*, com LLM juiz em caso de discordância), e o sistema registra as evidências e gera relatórios para revisão humana.

**Stack:** n8n (orquestração), Ollama (modelos), PostgreSQL (armazenamento), serviço Python de verificação e front-end em HTML + JS, tudo em Docker Compose no ambiente local.

## Documentação

| Documento | Conteúdo |
|---|---|
| [Solicitação de Sistema](docs/1-solicitacao-de-sistema.md) | Justificativa, objetivos e restrições do projeto. |
| [Lean Canvas](docs/2-lean-canvas.md) | Modelo de negócio do serviço de avaliação. |
| [Elicitação de Requisitos](docs/3-elicitacao-de-requisitos.md) | Requisitos funcionais e não funcionais. |
| [Casos de Uso](docs/4-casos-de-uso.md) | Fluxos de interação entre operador e sistema. |
| [Diagrama de Processos](docs/5-diagrama-de-processos.md) | Modelagem UML dos processos de negócio onde o sistema será utilizado. |
| [Projeto do Sistema](docs/6-projeto-do-sistema.md) | Escopo, arquitetura C4, componentes e decisões de projeto. |
| [Especificação Técnica](spec.md) | Especificação para implementação: infraestrutura, modelo de dados, API, workflows e verificação. |
| [CLAUDE.md](CLAUDE.md) | Guia de trabalho para o Claude Code neste repositório. |

