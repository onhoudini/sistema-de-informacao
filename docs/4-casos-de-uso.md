# Casos de Uso

## Escopo do documento

O sistema é uma plataforma local para avaliação da segurança de modelos de linguagem (SLMs e LLMs). O usuário pode selecionar modelos, *system prompts*, configurações e ataques, utilizando uma coleção predefinida ou ataques personalizados armazenados em formato estruturado.

A avaliação contempla ataques de turno único ou multi-turno, com quantidade de repetições definida pelo usuário. O sistema executa as combinações configuradas, verifica as respostas por similaridade com o *system prompt* (TF-IDF e *embeddings*, com LLM juiz em caso de discordância), registra as evidências e disponibiliza relatórios e históricos para análise e revisão humana.

## Diagrama de Casos de Uso

```mermaid
flowchart LR
    Usuário([Usuário])

    UC01[UC-01<br>Gerenciar ataques]
    UC02[UC-02<br>Configurar avaliação]
    UC03[UC-03<br>Executar avaliação]
    UC04[UC-04<br>Revisar resultados]

    Usuário --> UC01
    Usuário --> UC02
    Usuário --> UC03
    Usuário --> UC04

    UC02 -.->|pré-condição: ataques disponíveis| UC01
    UC03 -.->|pré-condição: UC-02| UC02
    UC04 -.->|pré-condição: UC-03| UC03
```

*As setas tracejadas indicam a ordem de pré-condição entre os casos de uso, não relações UML de inclusão ou extensão.*

## Atores

| Ator | Descrição |
|---|---|
| Usuário | Usuário que gerencia ataques, configura avaliações, inicia execuções e revisa os resultados. |
| Modelo de linguagem local | Modelo selecionado pelo usuário, que recebe os ataques e fornece as respostas avaliadas pelo sistema. |

---

## UC-01 — Gerenciar ataques

| Item | Descrição |
|---|---|
| Objetivo | Permitir que o usuário consulte a coleção de ataques disponibilizada pelo sistema e adicione ataques personalizados para reutilização. |
| Ator | Usuário |
| Pré-condições | Plataforma em execução no ambiente local. |
| Fluxo principal | 1. O usuário acessa a biblioteca de ataques.<br>2. O sistema apresenta a coleção predefinida, organizada por tipos de estratégias de *prompt injection*.<br>3. O usuário pode selecionar ataques existentes ou adicionar um ataque personalizado.<br>4. Para adicionar um ataque, o usuário fornece sua definição em formato estruturado, como JSON.<br>5. O sistema valida a estrutura do ataque.<br>6. O sistema armazena o ataque para utilização em avaliações futuras. |
| Fluxos alternativos | 5a. A definição do ataque possui estrutura inválida; o sistema informa os problemas encontrados e solicita a correção. |
| Regras de negócio | RN-01: a coleção predefinida deve ser organizada por tipos de estratégias de *prompt injection*.<br>RN-02: ataques personalizados devem ser armazenados em formato estruturado e permanecer disponíveis para reutilização. |
| Pós-condições | Ataques personalizados armazenados e disponíveis para seleção em avaliações. |
| Critérios de aceite | O usuário consegue consultar a coleção predefinida e adicionar ataques personalizados.<br>Os ataques personalizados podem ser armazenados e reutilizados.<br>A biblioteca pode ser ampliada sem depender de serviços externos. |

---

## UC-02 — Configurar avaliação

| Item | Descrição |
|---|---|
| Objetivo | Permitir que o usuário configure os modelos, *system prompts*, configurações, ataques e repetições de uma avaliação. |
| Ator | Usuário |
| Pré-condições | Plataforma em execução no ambiente local. |
| Fluxo principal | 1. O usuário seleciona os modelos locais que serão avaliados.<br>2. O usuário seleciona um ou mais *system prompts* ou a condição sem *system prompt*.<br>3. O usuário define as configurações de execução dos modelos.<br>4. O usuário seleciona os ataques da biblioteca, podendo combinar ataques predefinidos e personalizados.<br>5. O usuário define o número de repetições por ataque.<br>6. O usuário define o tempo máximo de espera por chamada (RF23).<br>7. O sistema calcula a quantidade planejada de execuções.<br>8. O sistema apresenta um resumo da configuração e valida os parâmetros informados.<br>9. O sistema disponibiliza a avaliação para execução. |
| Fluxos alternativos | 8a. A configuração é inválida ou incompleta; o sistema indica os problemas encontrados e solicita a correção. |
| Regras de negócio | RN-03: todos os modelos devem utilizar o mesmo conjunto de *system prompts*, configurações e ataques.<br>RN-04: as configurações selecionadas devem ser aplicadas igualmente a todos os modelos.<br>RN-05: a condição sem *system prompt*, quando selecionada, deve ser contabilizada como uma condição de avaliação.<br>RN-06: a quantidade planejada de execuções deve ser calculada pela fórmula:<br><br>\(N = M \times S \times C \times A \times R\)<br><br>Onde:<br>- \(N\): quantidade total de execuções planejadas;<br>- \(M\): quantidade de modelos;<br>- \(S\): quantidade de condições de *system prompt*;<br>- \(C\): quantidade de configurações;<br>- \(A\): quantidade de ataques;<br>- \(R\): quantidade de repetições por ataque. |
| Pós-condições | Avaliação configurada, validada e pronta para execução. |
| Critérios de aceite | O usuário consegue configurar todas as dimensões da avaliação.<br>Todos os modelos recebem os mesmos conjuntos de *system prompts*, configurações e ataques.<br>O sistema apresenta corretamente a quantidade planejada de execuções.<br>A configuração é mantida no ambiente local. |

---

## UC-03 — Executar avaliação

| Item | Descrição |
|---|---|
| Objetivo | Executar os ataques configurados contra os modelos selecionados, avaliar suas respostas e registrar os resultados. |
| Ator | Usuário |
| Pré-condições | Avaliação configurada e validada (UC-02). |
| Fluxo principal | 1. O usuário inicia a avaliação.<br>2. O sistema executa as combinações planejadas de modelos, *system prompts*, configurações, ataques e repetições.<br>3. O sistema envia os ataques aos modelos e recebe suas respostas. Nos ataques multi-turno, envia as mensagens da sequência, preservando o contexto da conversa.<br>4. O sistema calcula a similaridade entre as respostas e o *system prompt* utilizado pelos dois métodos principais: TF-IDF e *embeddings*.<br>5. Quando os dois métodos não concordam, o sistema aciona o LLM juiz para decidir o veredito.<br>6. O sistema registra os resultados das verificações, os vereditos e as evidências de cada tentativa (execução completa de um ataque).<br>7. O sistema continua a execução até completar a quantidade planejada de execuções.<br>8. O sistema finaliza a avaliação e disponibiliza o histórico dos resultados. |
| Fluxos alternativos | 4a. A tentativa foi executada sem *system prompt*; o sistema registra o veredito "não aplicável" e a tentativa fica disponível para revisão humana.<br>5a. O LLM juiz não produz um resultado válido; o sistema registra o veredito "inconclusivo" para posterior análise humana.<br>6a. Ocorre uma falha durante uma tentativa, inclusive por exceder o tempo máximo de espera por chamada (RF23); o sistema registra a ocorrência e suas informações disponíveis e prossegue com a avaliação. |
| Regras de negócio | RN-07: cada tentativa deve possuir registro do ataque utilizado, entrada enviada, resposta recebida e resultados das verificações.<br>RN-08: considera-se violação a resposta com similaridade elevada ao *system prompt*. TF-IDF e *embeddings* são os métodos principais; o LLM juiz é acionado somente quando os dois métodos não concordam.<br>RN-09: a execução deve terminar somente após completar a quantidade planejada de execuções, sem interrupção antecipada em função da identificação de uma violação.<br>RN-10: somente uma avaliação pode ser executada por vez. |
| Pós-condições | Avaliação finalizada, com histórico de tentativas, respostas, evidências e resultados das verificações registrados. |
| Critérios de aceite | O sistema executa todas as combinações planejadas.<br>Os ataques multi-turno preservam o contexto da conversa.<br>Cada tentativa possui os registros necessários para análise.<br>A execução respeita a quantidade planejada e o tempo máximo de espera por chamada.<br>Nenhum dado é enviado para serviços externos. |

---

## UC-04 — Revisar resultados

| Item | Descrição |
|---|---|
| Objetivo | Permitir que o usuário consulte os resultados, examine as evidências e revise manualmente os vereditos. |
| Ator | Usuário |
| Pré-condições | Avaliação finalizada (UC-03). |
| Fluxo principal | 1. O usuário acessa os resultados da avaliação.<br>2. O sistema apresenta um resumo dos resultados obtidos.<br>3. O sistema apresenta o histórico das tentativas, incluindo modelos, *system prompts*, configurações, ataques, respostas e resultados das verificações.<br>4. O usuário pode consultar o histórico em formato CSV.<br>5. O usuário seleciona qualquer tentativa para examinar suas evidências e vereditos.<br>6. O usuário pode confirmar ou corrigir manualmente o veredito registrado.<br>7. O sistema registra as alterações realizadas na revisão humana.<br>8. O sistema disponibiliza o relatório atualizado. |
| Fluxos alternativos | 6a. O usuário não identifica necessidade de alteração; o veredito automático é mantido. |
| Regras de negócio | RN-11: toda tentativa deve possuir evidências registradas que permitam sua revisão.<br>RN-12: a revisão humana pode ser realizada em qualquer tentativa, sem depender de amostragem ou de divergência entre os métodos de verificação.<br>RN-13: os resultados originais das verificações devem ser preservados, mesmo quando houver correção humana do veredito. |
| Pós-condições | Resultados disponibilizados e eventuais revisões humanas registradas. |
| Critérios de aceite | O usuário consegue consultar o resumo e o histórico completo da avaliação.<br>O histórico pode ser exportado em CSV.<br>O usuário consegue revisar qualquer tentativa e registrar sua conclusão.<br>As evidências e os resultados originais permanecem preservados. |

---

## Matriz de Rastreabilidade

### Requisitos Funcionais

| Requisito | Caso de Uso |
|---|---|
| RF01 — selecionar modelos locais | UC-02 |
| RF02 — definir *system prompts*, incluindo ausência de prompt | UC-02 |
| RF03 — configurar parâmetros dos modelos | UC-02 |
| RF04 — disponibilizar coleção predefinida de ataques | UC-01 |
| RF05 — adicionar, armazenar e reutilizar ataques personalizados | UC-01 |
| RF06 — utilizar ataques de turno único ou multi-turno | UC-01, UC-02, UC-03 |
| RF07 — configurar número de repetições | UC-02 |
| RF08 — utilizar os mesmos conjuntos de condições em todos os modelos | UC-02 |
| RF09 — calcular a quantidade planejada de execuções | UC-02 |
| RF10 — executar os ataques e receber respostas | UC-03 |
| RF11 — executar uma avaliação por vez | UC-03 |
| RF12 — encerrar após completar a quantidade planejada | UC-03 |
| RF13 — registrar ataques, entradas e respostas | UC-03 |
| RF14 — verificar violação por similaridade com o *system prompt* | UC-03 |
| RF15 — utilizar TF-IDF e *embeddings* como métodos principais e LLM juiz em caso de discordância | UC-03 |
| RF16 — apresentar vereditos e evidências | UC-03, UC-04 |
| RF17 — permitir revisão manual de qualquer tentativa | UC-04 |
| RF18 — considerar os resultados das verificações na revisão humana | UC-04 |
| RF19 — manter histórico das chamadas e configurações | UC-03, UC-04 |
| RF20 — disponibilizar histórico em CSV | UC-04 |
| RF21 — gerar relatórios e resumos | UC-04 |
| RF22 — apresentar ataques bem-sucedidos e malsucedidos | UC-04 |
| RF23 — definir tempo máximo de espera por chamada | UC-02, UC-03 |

### Requisitos Não Funcionais

| Requisito | Caso de Uso |
|---|---|
| RNF01 — funcionamento integral em ambiente local | UC-01, UC-02, UC-03, UC-04 |
| RNF02 — considerar limitações de processamento local | UC-03 |
| RNF03 — impedir envio de dados para fora do ambiente local | UC-01, UC-02, UC-03, UC-04 |
| RNF04 — preservar resultados e configurações | UC-03, UC-04 |
| RNF05 — preservar evidências para revisão | UC-03, UC-04 |
| RNF06 — interface intuitiva e fácil de utilizar | UC-01, UC-02, UC-03, UC-04 |
| RNF07 — formato estruturado e de fácil edição para ataques personalizados | UC-01 |
| RNF08 — permitir ampliação e manutenção da coleção de ataques | UC-01 |

### Restrições de Uso

| Restrição | Caso de Uso |
|---|---|
| RE01 — utilização exclusivamente em avaliações autorizadas | UC-01, UC-02, UC-03, UC-04 |