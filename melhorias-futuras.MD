# Melhorias Futuras

X : não realizado
V: realizado

## Melhorias Mais Complexas

### de Funcionamento

1. [X] *Permitir parar e recomeçar avaliações*

2. [X] *Criação de ataques via formulário dinâmico.* Criar um formulário dentro da interface gráfica, que se modificaria caso o usuário quisesse criar um ataque de turno único ou de multi-turno. Esse formulário criaria dentro do diretório um arquivo .json com as informações do ataque.

### de Praticidade

1. [X] *Estimativa de tempo de execuções:* permitir que seja realizado um cálculo, mesmo que imperfeito, para estimar o tempo de execução. Deve utilizar o hardware da máquina e os modelos utilizados na avaliação como base para estimar o tempo. Depender somente do tempo dos primeiros não seria válido em casos onde o pesquisador escolhesse modelos grandes e pequenos na mesma avaliação.
2. [X] *Minimizar de informações:* minimizar *resumo dos resultados*, assim como as suas subáreas; *Por modelo × system prompt × estratégia* e *Por ataque (bem-sucedido = veredito final violação)*.


# Melhorias Menos Complexas

### de Funcionamento

1. [V] *System Prompt minimizado*: sempre que fosse clicar em uma das tentativas, deveria ser mostrado o System Prompt minizado, devido a casos onde o System Prompt fosse muito grande. Isso atrapalha a visualização do pesquisador, e também pode ocasionar pequenos problemas em caso do pesquisador querer mostrar resultados sem mostrar as informações internas da ferramenta. Obs: deveria continuar tendo um botão para maximizar, e ser aplicado tanto na interface gráfica quanto na interface por linha de comando.

2. [X] *Exemplos de schema.json*: colocar um modelo de exemplo para o formato esperado do json de ataque. Colocar isso dentro de um markdown no diretório do projeto.

### de Praticidade

1. [V] *Veredito final pelo juiz:* Não funciona, deveria ter uma listagem de todas as que necessitaram de um juiz.
