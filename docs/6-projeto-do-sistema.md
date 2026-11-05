# Projeto do Sistema

**Plataforma Local de Avaliação de Segurança de Modelos de Linguagem (SLMs e LLMs)**

Este documento complementa a Solicitação de Sistema, o Lean Canvas, a Elicitação de Requisitos, os Casos de Uso e o Diagrama de Processos. Ele define o escopo do sistema, a arquitetura (diagramas de contexto e de contêineres no formato C4) e os componentes de software.

---

## 1. Escopo do Sistema

### 1.1. Objetivo

Fornecer aos pesquisadores um pipeline configurável para avaliar a segurança de modelos de linguagem locais (SLMs e LLMs) diante de ataques de *prompt injection*, de forma sistemática, rastreável e reproduzível, mantendo modelos, *system prompts*, ataques, respostas e resultados no ambiente local.

### 1.2. Dentro do escopo

| Área | O que o sistema contempla | Requisitos |
|---|---|---|
| Biblioteca de ataques | Coleção predefinida organizada por estratégia de *prompt injection*; ataques personalizados em JSON, validados e reutilizáveis; ataques de turno único e multi-turno. | RF04, RF05, RF06, RNF07, RNF08 |
| Configuração da avaliação | Seleção de modelos, *system prompts* (inclusive ausência de prompt), configurações compartilhadas, ataques e repetições; cálculo de N = M × S × C × A × R. | RF01 a RF03, RF07 a RF09 |
| Execução | Execução das combinações planejadas, uma avaliação por vez, sem interrupção antecipada; preservação do contexto em ataques multi-turno; registro de cada chamada. | RF10 a RF13 |
| Verificação | Veredito por tentativa com método principal e métodos complementares, preservando as evidências. | RF14 a RF16 |
| Revisão e relatórios | Revisão humana de qualquer tentativa, histórico em CSV, relatórios e resumos por modelo, *system prompt* e tipo de ataque. | RF16 a RF22 |
| Operação local | Funcionamento integral local, sem envio de dados a serviços externos; registros e configurações preservados. | RNF01, RNF03, RNF04, RNF05 |

### 1.3. Fora do escopo

- Execução simultânea de múltiplas avaliações (RF11).
- Adaptação, ajuste fino ou correção dos modelos avaliados (RF01 exige avaliar sem adaptações).
- Uso de serviços externos de qualquer natureza, inclusive nuvem e APIs de terceiros (RNF01, RNF03).
- Uso em avaliações não autorizadas (RE01).

### 1.4. Atores e sistemas externos

| Elemento | Tipo | Descrição |
|---|---|---|
| Pesquisador (Usuário) | Pessoa | Gerencia ataques, configura e inicia avaliações e revisa resultados. |
| Modelo de Linguagem Local (SLM/LLM) | Sistema externo (local) | Modelo alvo que recebe os ataques e devolve as respostas avaliadas. Não é modificado pela plataforma. |

### 1.5. Premissas e restrições

- O ambiente local possui capacidade de processamento suficiente; o tempo de execução pode ser elevado (RNF02).
- Os resultados podem variar entre execuções, por isso são necessárias repetições e preservação das configurações usadas.
- O *system prompt* pode conter informações confidenciais, o que reforça a restrição de dados somente locais.
- A ferramenta tem natureza ofensiva e deve ser usada apenas com autorização (RE01).

---

## 2. Arquitetura

A arquitetura é uma aplicação **local e modular**: uma interface de uso, módulos de domínio com responsabilidades separadas e um armazenamento local compartilhado. Os módulos se comunicam entre si apenas dentro do ambiente local, e a única integração externa à plataforma é a chamada ao modelo alvo, também executado localmente. As tecnologias de implementação ainda não foram definidas (ver seção 5).

### 2.1. Diagrama de Contexto (C4 – nível 1)

```mermaid
C4Context
    title Diagrama de Contexto - Plataforma Local de Avaliação de Segurança de Modelos de Linguagem

    Person(pesq, "Pesquisador", "Gerencia ataques, configura e executa avaliações e revisa os resultados")

    Enterprise_Boundary(local, "Ambiente local do pesquisador (nenhum dado sai deste ambiente)") {
        System(plat, "Plataforma de Avaliação de Segurança", "Executa ataques de turno único e multi-turno, verifica as respostas, registra evidências e gera relatórios e CSV")
        System_Ext(llm, "Modelo de Linguagem Local (SLM/LLM)", "Modelo alvo avaliado; recebe ataques e devolve respostas")
    }

    Rel(pesq, plat, "Gerencia ataques, configura e executa avaliações, revisa resultados")
    Rel(plat, llm, "Envia ataques e recebe respostas", "Chamada local")
```

### 2.2. Diagrama de Contêineres (C4 – nível 2)

```mermaid
C4Container
    title Diagrama de Contêineres - Plataforma Local de Avaliação de Segurança

    Person(pesq, "Pesquisador", "Gerencia ataques, configura e executa avaliações e revisa resultados")

    System_Boundary(plat, "Plataforma Local de Avaliação de Segurança") {
        Container(ui, "Interface", "Tecnologia a definir", "Interface intuitiva para instalar, configurar, executar e revisar avaliações")
        Container(atq, "Gerenciador de Ataques", "Tecnologia a definir", "Biblioteca predefinida por estratégia; valida e armazena ataques personalizados em JSON")
        Container(cfg, "Configurador de Avaliação", "Tecnologia a definir", "Define modelos, system prompts, configurações, ataques e repetições; calcula N")
        Container(exe, "Executor de Avaliação", "Tecnologia a definir", "Executa as combinações planejadas, uma avaliação por vez; suporta multi-turno")
        Container(ver, "Módulo de Verificação", "Tecnologia a definir", "Método principal e complementares; emite veredito e sinaliza casos inconclusivos")
        Container(rel, "Relatórios e Revisão", "Tecnologia a definir", "Resumo, relatório e CSV; revisão humana preservando o resultado original")
        ContainerDb(db, "Armazenamento Local", "Tecnologia a definir", "Ataques, configurações, chamadas, evidências, vereditos e revisões")
    }

    System_Ext(llm, "Modelo de Linguagem Local (SLM/LLM)", "Modelo alvo avaliado")

    Rel(pesq, ui, "Usa")
    Rel(ui, atq, "Gerencia ataques")
    Rel(ui, cfg, "Configura avaliação")
    Rel(ui, exe, "Inicia avaliação")
    Rel(ui, rel, "Consulta e revisa resultados")

    Rel(cfg, atq, "Seleciona ataques")
    Rel(exe, ver, "Submete respostas para verificação")
    Rel(exe, llm, "Envia ataques e recebe respostas", "Chamada local")

    Rel(atq, db, "Lê e grava ataques")
    Rel(cfg, db, "Grava configuração")
    Rel(exe, db, "Lê configuração; grava chamadas")
    Rel(ver, db, "Grava vereditos e evidências")
    Rel(rel, db, "Lê histórico; grava revisões")
```

### 2.3. Diagrama de Componentes do Executor (C4 – nível 3)

O Executor concentra a maior parte do comportamento crítico (combinações, multi-turno e registro), por isso é detalhado.

```mermaid
C4Component
    title Diagrama de Componentes - Executor de Avaliação

    ContainerDb(db, "Armazenamento Local", "Tecnologia a definir", "Configurações, chamadas, evidências e vereditos")
    Container(ver, "Módulo de Verificação", "Tecnologia a definir", "Método principal e complementares")
    System_Ext(llm, "Modelo de Linguagem Local (SLM/LLM)", "Modelo alvo avaliado")

    Container_Boundary(exe, "Executor de Avaliação") {
        Component(pla, "Planejador de Combinações", "Componente", "Gera as combinações e garante uma avaliação por vez")
        Component(ctl, "Controlador de Conversa", "Componente", "Envia ataques de turno único ou multi-turno, preservando o contexto")
        Component(cli, "Cliente do Modelo Local", "Componente", "Aplica system prompt e configurações ao chamar o modelo")
        Component(reg, "Registrador de Tentativas", "Componente", "Registra entrada, resposta, evidências e falhas")
    }

    Rel(db, pla, "Fornece a configuração planejada")
    Rel(pla, ctl, "Fornece a próxima combinação")
    Rel(ctl, cli, "Envia mensagens do ataque")
    Rel(cli, llm, "Invoca o modelo", "Chamada local")
    Rel(ctl, reg, "Entrega as respostas da tentativa")
    Rel(reg, ver, "Submete a tentativa para verificação")
    Rel(reg, db, "Grava chamadas e evidências")
```

> Os três diagramas também estão disponíveis em `c4-plataforma-avaliacao-seguranca.drawio` (páginas 1 a 3), para edição no draw.io.

---

## 3. Componentes de Software

### 3.1. Visão geral

| Componente | Responsabilidade | Casos de uso |
|---|---|---|
| **Interface** | Ponto único de interação do pesquisador; guia instalação, configuração, execução e revisão. | UC-01 a UC-04 |
| **Gerenciador de Ataques** | Mantém a biblioteca predefinida por estratégia; valida e armazena ataques personalizados em JSON; permite ampliação da coleção. | UC-01 |
| **Configurador de Avaliação** | Reúne modelos, *system prompts* (ou ausência), configurações compartilhadas, ataques, repetições e limites; valida a configuração e calcula N. | UC-02 |
| **Executor de Avaliação** | Executa as combinações planejadas, uma avaliação por vez, até completar N; trata ataques multi-turno; registra falhas sem interromper o conjunto. | UC-03 |
| **Módulo de Verificação** | Aplica o método principal e os complementares, produz o veredito por tentativa e sinaliza resultados inconclusivos ou divergentes. | UC-03 |
| **Relatórios e Revisão** | Apresenta resumo e histórico; exporta CSV; gera relatórios por modelo, *system prompt* e tipo de ataque; registra a revisão humana preservando o resultado original. | UC-04 |
| **Armazenamento Local** | Persiste ataques, configurações, chamadas, evidências, vereditos e revisões, sem uso de serviços externos. | UC-01 a UC-04 |

### 3.2. Detalhamento

**Interface**
- Entradas: ações do pesquisador. Saídas: telas de biblioteca, configuração, execução e resultados.
- Não contém regras de negócio; delega aos módulos.

**Gerenciador de Ataques**
- Entradas: definições de ataque em JSON (turno único ou sequência de mensagens). Saídas: ataques validados e disponíveis para seleção.
- Regras: RN-01 (organização por estratégia), RN-02 (formato estruturado e reutilização). Em caso de estrutura inválida, informa os problemas e solicita correção.

**Configurador de Avaliação**
- Entradas: seleção de modelos, *system prompts*, configurações, ataques e repetições. Saídas: avaliação validada, com resumo e N planejado.
- Regras: RN-03 e RN-04 (mesmos conjuntos e configurações para todos os modelos), RN-05 (ausência de *system prompt* conta como condição), RN-06 (fórmula de N).

**Executor de Avaliação**
- Entradas: avaliação configurada. Saídas: registros de cada chamada e tentativas encaminhadas à verificação.
- Regras: RN-07, RN-09 (sem interrupção antecipada) e RN-10 (uma avaliação por vez). Consome recursos computacionais significativos (RNF02).
- Subcomponentes (seção 2.3): Planejador de Combinações, Controlador de Conversa, Cliente do Modelo Local e Registrador de Tentativas.

**Módulo de Verificação**
- Entradas: respostas das tentativas. Saídas: resultado de cada método, veredito e indicação de divergência ou inconclusão.
- Regras: RN-08 (método principal mais confiável; complementares auxiliam). Os resultados originais nunca são sobrescritos (RN-13).

**Relatórios e Revisão**
- Entradas: histórico e vereditos. Saídas: resumo, relatório, CSV e revisões humanas.
- Regras: RN-11 (evidências para toda tentativa), RN-12 (revisão de qualquer tentativa), RN-13 (preservar resultado original).

**Armazenamento Local**
- Garante rastreabilidade das condições dos experimentos (RNF04) e preservação das evidências (RNF05). Nenhum dado sai do ambiente local (RNF03).

### 3.3. Rastreabilidade entre componentes e requisitos

| Componente | Requisitos funcionais | Requisitos não funcionais |
|---|---|---|
| Interface | — | RNF01, RNF06 |
| Gerenciador de Ataques | RF04, RF05, RF06 | RNF07, RNF08 |
| Configurador de Avaliação | RF01, RF02, RF03, RF06, RF07, RF08, RF09 | RNF06 |
| Executor de Avaliação | RF06, RF10, RF11, RF12, RF13 | RNF02 |
| Módulo de Verificação | RF14, RF15, RF16 | RNF05 |
| Relatórios e Revisão | RF16, RF17, RF18, RF20, RF21, RF22 | RNF05 |
| Armazenamento Local | RF13, RF19 | RNF01, RNF03, RNF04, RNF05 |

*RE01 (uso exclusivamente autorizado) é uma restrição de uso e não se atribui a um componente específico.*

### 3.4. Correspondência com o Diagrama de Processos

| Etapa do processo | Componente responsável |
|---|---|
| Acessar biblioteca e fornecer ataques personalizados | Gerenciador de Ataques |
| Selecionar modelos, *system prompts*, ataques, configurações e repetições; validar e calcular N | Configurador de Avaliação |
| Enviar ataque ao modelo e tratar mensagens multi-turno | Executor de Avaliação (Controlador de Conversa e Cliente do Modelo Local) |
| Verificação principal e complementar | Módulo de Verificação |
| Registrar respostas, evidências e resultados | Executor (Registrador de Tentativas) e Armazenamento Local |
| Gerar resumo, relatório e CSV; revisar e corrigir veredito | Relatórios e Revisão |

---

## 4. Decisões de Projeto

| Decisão | Justificativa |
|---|---|
| Aplicação local com módulos separados e armazenamento compartilhado | Atende RNF01 e RNF03 e facilita a evolução independente da biblioteca, da verificação e dos relatórios. |
| Verificação isolada em módulo próprio | Permite incluir novos métodos complementares sem alterar o Executor (RF14 e RF15). |
| Ataques personalizados em JSON | Formato estruturado e de fácil edição (RNF07), com reutilização (RN-02). |
| Resultados originais preservados separadamente da revisão humana | Garante rastreabilidade e reprodutibilidade (RN-13, RNF04). |
| Execução sequencial de uma avaliação por vez | Respeita RF11 e as limitações de processamento local (RNF02). |

---

## 5. Pendências e Inconsistências a Resolver

1. **Tecnologias:** linguagem, interface, armazenamento, forma de chamada ao modelo local e métodos de verificação ainda não foram definidos (campos "Tecnologia a definir").
2. **Autenticação:** os casos de uso exigem "usuário autenticado e autorizado" e citam acesso restrito aos relatórios, mas não há requisito correspondente na elicitação. Definir se a plataforma terá controle de acesso próprio.
3. **Numeração dos RNF:** a matriz dos Casos de Uso cita RNF01 a RNF09 (incluindo "restringir acesso"), enquanto a Elicitação termina em RNF08 e não tem requisito de acesso. A numeração precisa ser alinhada.
4. **Revisão humana:** a Solicitação de Sistema fala em revisão "por amostragem", mas RF17 e RN-12 permitem revisar qualquer tentativa. Confirmar qual vale.
5. **Limites de execução:** a Solicitação (item 5) e o UC-02 (passo 6) preveem limites de execução, mas não há RF correspondente. Definir quais limites existem (por exemplo, tempo ou número de chamadas) e registrá-los nos requisitos.
6. **Métodos de verificação:** o UC-03 cita um método "complementar" (singular), enquanto RF15 prevê "um ou mais". Padronizar.