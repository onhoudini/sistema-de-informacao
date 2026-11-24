# Melhorias Futuras

- **[X]**: não realizado
- **[V]**: realizado
- **Esforço:** P (pequeno), M (médio), G (grande)

Antes de implementar um item que muda comportamento, atualizar primeiro `docs/` e depois `spec.md`, e seguir o ADR 0001 (regras na API, clientes finos).

## Ordem de implementação

| # | Melhoria | Categoria | Prioridade | Esforço | Depende de |
|---|---|---|---|---|---|
| 1 | Valores padrão no formulário | Configuração da avaliação | alta | P | nenhum |
| 2 | Minimizar resumo dos resultados | Resultados | média | P | nenhum |
| 3 | Lista de modelos para juiz no readme | Documentação | baixa | P | nenhum |
| 4 | Ícone de ajuda | Configuração da avaliação | média | M | nenhum |
| 5 | Visualização dos ataques | Configuração da avaliação | média | P | 4 |
| 6 | Motivos de falha | Resultados | média | M | nenhum |
| 7 | Pausar, retomar e encerrar | Execução | alta | G | nenhum |
| 8 | Refazer falhas por motivo | Execução | média | G | 6 |
| 9 | Duplicar avaliação | Configuração da avaliação | média | M | nenhum |
| 10 | Rodadas | Execução | média | G | 7 e 8 (mesmo código) |
| 11 | Formulário de ataques e baixar JSON | Ataques | média | G | nenhum |
| 12 | Gráficos | Resultados | média | M | 6 |
| 13 | Estimativa de tempo | Execução | média | G | nenhum |
| 14 | Seletor de tema claro/escuro | Aparência e idioma | baixa | P | nenhum |
| 15 | Multilinguagem | Aparência e idioma | baixa (futuro distante) | G | todas as anteriores |

## Execução

### 7. [X] Pausar, retomar e encerrar avaliações

Prioridade: alta | Esforço: G | Depende de: nenhum

Permitir que o Pesquisador pare uma avaliação e continue depois, sem perder o que já foi executado.

- Criar os status `pausada` e `encerrada`.
- **Pausar:** a tentativa em andamento termina antes da pausa.
- **Retomar:** sempre manual, por botão na Interface Web e comando na CLI. Executa só as tentativas pendentes.
- **Encerrar:** disponível em execução ou pausada. Mantém as tentativas feitas e não executa as pendentes. É definitivo.
- Uma avaliação pausada bloqueia a execução de outras, até ser retomada e finalizada, ou encerrada.
- Usar a mesma retomada quando o n8n cair, no lugar do `UPDATE` manual descrito no spec. Cuidado: impedir que dois laços executem a mesma avaliação.
- Rever nos docs: RF11 (o bloqueio passa a incluir a avaliação pausada) e RF12 (exceção para o encerramento pedido pelo Pesquisador).

### 8. [X] Refazer falhas por motivo

Prioridade: média | Esforço: G | Depende de: 6

Permitir refazer as tentativas que falharam, escolhendo os motivos (ex.: conexão, tempo excedido).

- O Pesquisador escolhe um ou mais motivos e pode informar um novo tempo máximo por chamada para as tentativas refeitas.
- Só com a rodada finalizada, e dentro da mesma rodada. Enquanto o item 10 não existir, vale a própria avaliação.
- Cada falha refeita gera uma nova tentativa ligada à original, que fica preservada.
- Só a tentativa mais recente conta no resumo e no N.
- Disponível na Interface Web e na CLI.

### 10. [X] Rodadas

Prioridade: média | Esforço: G | Depende de: 7 e 8 (mesmo código)

Rodar a avaliação inteira de novo, com todas as execuções salvas dentro da mesma avaliação (Rodada 1, Rodada 2...).

- O que já foi executado vira a Rodada 1.
- Configuração e seed idênticas em todas as rodadas. Para mudar algo, usar Duplicar (item 9).
- Nova rodada só depois que a anterior terminar.
- Tela da avaliação: seletor de rodada e comparação da taxa de violação entre rodadas. Os resultados não são somados.
- CSV com a coluna `rodada`, e CLI com a opção de escolher a rodada.
- Registrar o termo "rodada" no `GLOSSARY.md`, diferenciando-o de "repetição" (R).

### 13. [X] Estimativa de tempo

Prioridade: média | Esforço: G | Depende de: nenhum

Estimar o tempo da avaliação antes de executar, medindo o hardware real, sem usar a velocidade de um modelo para prever outro.

- Ao executar, um teste curto **obrigatório** mede cada modelo, inclusive o juiz: tempo de carga, leitura do prompt e tokens por segundo.
- Tempo de cada modelo = carga + (tokens esperados por chamada ÷ velocidade dele) × chamadas dele. Depois, somar todos. Para o juiz, considerar só as discordâncias esperadas.
- Mostrar como faixa (ex.: "entre 40 min e 1h10") e pedir confirmação para começar. Na CLI, `--sim` dispensa a confirmação.
- Durante a execução, o modelo em andamento usa os tempos reais, e os que não começaram usam a medida do teste.
- Guardar as medidas **por máquina e modelo**: o mesmo modelo em outro computador precisa ser medido de novo. O teste só mede o que ainda não tem medida na máquina atual.
- Botão "Medir de novo", para quando o hardware ou o modelo mudar.
- Se o teste de um modelo falhar, mostrar "indisponível" para ele, com aviso, sem bloquear a execução.
- Retomar e refazer falhas usam as medidas guardadas, sem repetir o teste.
- A definir: como identificar a máquina. Os contêineres não veem a GPU, e o endereço do Ollama (`OLLAMA_BASE_URL`) pode ser igual em computadores diferentes.

## Ataques

### 11. [X] Formulário de ataques e baixar JSON

Prioridade: média | Esforço: G | Depende de: nenhum

Criar ataques pela Interface Web, com um formulário que se adapta a turno único ou multi-turno.

- Turno único: uma mensagem. Multi-turno: adicionar, remover e reordenar mensagens.
- Gravar no banco por `POST /ataques` (rota já existente), porque o navegador não grava arquivos no diretório do projeto.
- Baixar qualquer ataque, inclusive predefinido, em JSON no formato de `ataques/schema.json`. Disponível também na CLI.
- Fora do escopo: editar e excluir ataques.

## Configuração da avaliação

### 1. [X] Valores padrão no formulário

Prioridade: alta | Esforço: P | Depende de: nenhum

Mostrar o valor padrão no lugar de "Vazio = padrão da API".

- Tempo máximo por chamada (120 s) e limiares (TF-IDF 0,6 e *embeddings* 0,8).
- Os valores vêm de uma rota da API, e não fixados na Interface Web (RNF09).

### 4. [X] Ícone de ajuda

Prioridade: média | Esforço: M | Depende de: nenhum

Ícone "?" com explicação ao passar o mouse, em todas as configurações da criação da avaliação e nos resultados.

- Criar um componente único, reutilizado no item 5.
- Abrir também por clique e teclado.
- Nos resultados: TF-IDF, *embeddings*, juiz, vereditos, taxa de violação e colunas das tabelas.

### 5. [X] Visualização dos ataques

Prioridade: média | Esforço: P | Depende de: 4

Na criação da avaliação só aparece o nome do ataque. Mostrar de qual ataque se trata em uma janela flutuante.

- Mostrar descrição, estratégia, tipo e mensagens, com o mesmo ícone "?".
- Aplicar também onde os ataques aparecem nos resultados da avaliação.

### 9. [X] Duplicar avaliação

Prioridade: média | Esforço: M | Depende de: nenhum

Abrir a tela Nova avaliação preenchida com os dados de outra, para editar e salvar como avaliação nova.

- Só grava ao salvar, e a avaliação original não muda.
- Modelos ou ataques que não existem mais ficam desmarcados, com aviso.
- Comando equivalente na CLI.

## Resultados

### 2. [X] Minimizar resumo dos resultados

Prioridade: média | Esforço: P | Depende de: nenhum

Permitir recolher áreas da tela da avaliação (só na Interface Web).

- Recolher o *Resumo dos resultados* inteiro e as subáreas *Por modelo × system prompt × estratégia* e *Por ataque (bem-sucedido = veredito final violação)*.
- Abertas por padrão, com o estado lembrado no navegador.
- Não reabrir a cada atualização de 5 s.

### 6. [X] Motivos de falha

Prioridade: média | Esforço: M | Depende de: nenhum

Hoje o erro é um texto livre, que na Interface Web só aparece no detalhe da tentativa. Categorizar e mostrar os motivos.

- Categorias: tempo excedido, conexão, modelo indisponível, verificador, interrompida e outro.
- Gravar a categoria em coluna própria e manter o texto do erro.
- Mostrar e filtrar na lista de tentativas, e mostrar no resumo, no CSV e na CLI.
- Criar uma migração em `db/migracoes/` que classifique as falhas antigas, ou as marque como "outro".

### 12. [X] Gráficos

Prioridade: média | Esforço: M | Depende de: 6

Visão geral das estatísticas, por avaliação, na tela que já existe.

- Taxa de violação por modelo.
- Situações por modelo (violação, sem violação, inconclusiva, falha etc.), em barras empilhadas.
- Mapa de calor modelo × estratégia.
- Ataques mais bem-sucedidos.
- Falhas por motivo.
- Acompanhar a atualização de 5 s, com o aviso "parcial" enquanto estiver em execução.
- SVG puro, sem biblioteca externa. Com o item 10 pronto, respeitar a rodada selecionada.

## Aparência e idioma

### 14. [X] Seletor de tema claro/escuro

Prioridade: baixa | Esforço: P | Depende de: nenhum

O tema escuro já existe e segue o sistema. Falta o seletor.

- Opções: automático (padrão), claro e escuro, com a escolha lembrada no navegador.

### 15. [X] Multilinguagem

Prioridade: baixa (futuro distante) | Esforço: G | Depende de: todas as anteriores

Português (PT-BR) e inglês em toda a plataforma. Deixar por último, para não traduzir telas que ainda vão mudar.

- Traduzir: Interface Web, CLI, erros e avisos da API, `readme.MD` e `GUIA-CLI.md`.
- Não traduzir: docs 1 a 6, nomes do banco e valores gravados (`violacao` etc.).
- Rever a convenção de PT-BR no `CLAUDE.md`.

## Documentação

### 3. [X] Lista de modelos para juiz no readme

Prioridade: baixa | Esforço: P | Depende de: nenhum

Indicações simples de modelos locais para LLM juiz, a partir de pesquisas rápidas.

- Tabela curta: modelo com tag fixa, tamanho, VRAM aproximada e observação.
- Avisar que são sugestões, sem comprovação de qualidade.

## Melhorias Já Realizadas

- [V] *System Prompt minimizado*: sempre que fosse clicar em uma das tentativas, deveria ser mostrado o System Prompt minizado, devido a casos onde o System Prompt fosse muito grande. Isso atrapalha a visualização do pesquisador, e também pode ocasionar pequenos problemas em caso do pesquisador querer mostrar resultados sem mostrar as informações internas da ferramenta. Obs: deveria continuar tendo um botão para maximizar, e ser aplicado tanto na interface gráfica quanto na interface por linha de comando.
- [V] *Veredito final pelo juiz:* Não funciona, deveria ter uma listagem de todas as que necessitaram de um juiz.
- [V] *Exemplos de schema.json*: colocar um modelo de exemplo para o formato esperado do json de ataque. Colocar isso dentro de um markdown no diretório do projeto.
