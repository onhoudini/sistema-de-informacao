# Plataforma Local de Avaliação de Segurança de Modelos de Linguagem

Vocabulário do domínio da plataforma que executa ataques de *prompt injection* contra modelos de linguagem locais e verifica se as respostas vazaram o *system prompt*.

## Atores

**Pesquisador**:
Pessoa que gerencia ataques, configura e executa avaliações e revisa os resultados.
_Evitar_: Usuário, operador

## Avaliação e execução

**Avaliação**:
Conjunto configurado de modelos, *system prompts*, configurações, ataques, repetições e tempo máximo por tentativa, executado como uma unidade.

**Combinação**:
Uma tupla (modelo, *system prompt*, configuração, ataque, repetição) dentro de uma avaliação.

**Tentativa**:
Execução completa de um ataque em uma combinação; é a unidade contada em N.
_Sinônimo nos requisitos_: Chamada (RF09, RF12, RF13). Os dois termos designam a mesma unidade.

**Turno**:
Uma única troca de mensagem com o modelo alvo dentro de uma tentativa; um ataque de turno único tem um turno, um multi-turno tem um por mensagem da sequência.

**Condição "sem *system prompt*"**:
Elemento do conjunto de *system prompts* que representa a ausência de *system prompt*; conta em N como qualquer outro.

## Verificação e revisão

**Veredito automático**:
Resultado da verificação de uma tentativa: violação, sem violação, inconclusivo ou não aplicável. Nunca é sobrescrito.

**Revisão humana**:
Veredito registrado pelo pesquisador sobre uma tentativa; revisões se acumulam e a mais recente vale.

**Veredito final**:
O veredito da revisão humana mais recente, se houver; senão, o veredito automático.

**Ataque bem-sucedido**:
Tentativa cujo veredito final é violação.

## Interfaces

**API da Plataforma**:
Contrato público, local e documentado pelo qual qualquer cliente acessa todas as funcionalidades da plataforma.
_Evitar_: webhooks, back-end

**Interface Web**:
Cliente fino gráfico da API da Plataforma, usado pelo navegador.
_Evitar_: Interface (sem qualificador), front-end, GUI

**Interface de Linha de Comando (CLI)**:
Cliente fino de terminal da API da Plataforma.
_Evitar_: Interface (sem qualificador)

**Cliente**:
Qualquer consumidor da API da Plataforma: a Interface Web, a CLI ou um script do pesquisador.

**Cliente fino**:
Cliente que apenas coleta a entrada, chama a API da Plataforma e apresenta a resposta, sem regras de negócio e sem acesso direto aos dados ou aos modelos.
_Evitar_: thin client
