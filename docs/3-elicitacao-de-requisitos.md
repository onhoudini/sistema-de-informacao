# Elicitação de Requisitos

## 1. Requisitos Funcionais

### 1.1. Configuração da Avaliação

**RF01.** O sistema deve permitir selecionar os modelos de linguagem locais (SLMs ou LLMs) que serão avaliados, sem exigir adaptações nos modelos.

**RF02.** O sistema deve permitir definir um ou mais *system prompts* para a avaliação, incluindo a possibilidade de executar testes sem *system prompt*.

**RF03.** O sistema deve permitir configurar os parâmetros de execução dos modelos. As configurações selecionadas serão compartilhadas e aplicadas igualmente a todos os modelos da avaliação.

**RF04.** O sistema deve disponibilizar uma coleção predefinida de ataques de *prompt injection*, organizada por tipos de estratégias, e permitindo sua ampliação.

**RF05.** O sistema deve permitir adicionar ataques personalizados, definidos pelo pesquisador em um formato estruturado, JSON.

**RF06.** O sistema deve permitir utilizar ataques de turno único ou multi-turno. Para ataques multi-turno, deve ser possível fornecer uma sequência de mensagens, preservando o contexto da conversa durante sua execução.

**RF07.** O sistema deve permitir configurar o número de repetições por ataque.

**RF08.** Todos os modelos selecionados devem ser avaliados utilizando o mesmo conjunto de *system prompts*, configurações e ataques, permitindo comparações equivalentes.

### 1.2. Execução da Avaliação

**RF09.** O sistema deve calcular a quantidade total de chamadas necessárias para a avaliação com base nos parâmetros configurados:

$$
 N = | M | \times | S | \times | C | \times | A | \times | R |
$$

Onde:

- \(N\): quantidade total de chamadas;
- \(M\): conjunto de modelos selecionados;
- \(S\): conjunto de *system prompt* avaliadas;
- \(C\): conjunto de configurações;
- \(A\): conjunto de ataques;
- \(R\): conjunto de repetições.


**RF10.** O sistema deve executar os ataques configurados contra os modelos selecionados, respeitando as combinações e quantidades definidas na avaliação.

**RF11.** O sistema deve executar uma avaliação por vez, sem permitir avaliações simultâneas.

**RF12.** A execução deve ser encerrada somente após a conclusão da quantidade de chamadas planejada, sem interrupção antecipada em função da identificação de uma violação.

**RF13.** O sistema deve registrar, para cada chamada, o modelo alvo, o system prompt utilizado (em caso de uso), as configurações do modelo, o ataque utilizado, a entrada enviada e a resposta recebida do modelo.

### 1.3. Avaliação dos Resultados

**RF14.** O sistema deve verificar se houve violação comparando a resposta do modelo com o *system prompt* utilizado. Considera-se violação quando a resposta apresenta similaridade elevada com o *system prompt* (vazamento). Tentativas executadas sem *system prompt* recebem o veredito "não aplicável" e permanecem disponíveis para revisão humana.

**RF15.** O sistema deve utilizar dois métodos principais de verificação, a similaridade TF-IDF e a similaridade semântica por *embeddings* (modelo `paraphrase-multilingual-MiniLM-L12-v2`), cada um com limiar configurável. Quando os dois métodos não concordarem, o sistema deve acionar um LLM como juiz, executado localmente, para decidir o veredito. Caso o juiz não produza um resultado válido, o veredito deve ser registrado como "inconclusivo".

**RF16.** O sistema deve apresentar o veredito de cada tentativa (execução completa de um ataque) e as evidências correspondentes, incluindo a entrada enviada e a resposta recebida.

**RF17.** O sistema deve permitir que o pesquisador revise manualmente qualquer tentativa, utilizando o histórico e as evidências registradas.

**RF18.** A avaliação humana deve poder considerar os resultados dos métodos de verificação, especialmente nos casos em que não houver conclusões suficientemente claras.

### 1.4. Relatórios e Histórico

**RF19.** O sistema deve manter um histórico das chamadas realizadas, incluindo suas respectivas configurações, entradas, respostas e resultados das verificações.

**RF20.** O sistema deve disponibilizar o histórico das tentativas em formato CSV, permitindo sua análise e revisão manual.

**RF21.** O sistema deve gerar relatórios contendo o histórico das tentativas e um resumo dos resultados obtidos.

**RF22.** O sistema deve apresentar quais ataques foram bem-sucedidos e malsucedidos, permitindo analisar os resultados por modelo, *system prompt* e tipo de ataque.

### 1.5. Limites de Execução

**RF23.** O sistema deve permitir definir o tempo máximo de espera por chamada ao modelo. Quando esse tempo for excedido, a chamada deve ser registrada como falha e a avaliação deve prosseguir com as chamadas seguintes, sem interrupção (RF12).

---

## 2. Requisitos Não Funcionais

### 2.1. Operacional

**RNF01.** O sistema deve funcionar integralmente em ambiente local, sem depender de chamadas a serviços externos.

### 2.2. Desempenho

**RNF02.** O sistema deve considerar as limitações de processamento do ambiente local, uma vez que a execução de modelos de linguagem pode exigir recursos computacionais significativos e apresentar tempos elevados.

### 2.3. Segurança

**RNF03.** Nenhum dado relacionado à avaliação, incluindo modelos, *system prompts*, ataques, respostas, relatórios e resultados, pode ser enviado para fora do ambiente local.


### 2.4. Confiabilidade

**RNF04.** Os resultados e as configurações de cada avaliação devem ser registrados e preservados, permitindo rastrear as condições em que os experimentos foram realizados.

**RNF05.** O sistema deve preservar as evidências necessárias para a revisão dos resultados, considerando que os métodos automáticos de verificação podem apresentar divergências ou conclusões inconclusivas.

### 2.5. Usabilidade

**RNF06.** As interfaces da plataforma, de linha de comando e web, devem ser intuitivas e facilitar a instalação, a configuração e a execução das avaliações.

**RNF07.** A definição de ataques personalizados deve utilizar um formato estruturado e de fácil edição, como JSON, facilitando sua criação, organização, armazenamento e reutilização.

### 2.6. Manutenibilidade e Extensibilidade

**RNF08.** A coleção de ataques disponibilizada pelo sistema deve permitir ampliação e manutenção, possibilitando a inclusão de novas estratégias de *prompt injection*.

**RNF09.** A plataforma deve expor todas as suas funcionalidades por uma API local documentada, permitindo que outros clientes sejam integrados sem alterar os módulos de domínio.

---

## 3. Restrições de Uso

**RE01.** A ferramenta possui natureza ofensiva e deve ser utilizada exclusivamente em avaliações autorizadas.