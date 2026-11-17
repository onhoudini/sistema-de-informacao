# Interfaces como clientes finos da API da Plataforma

A plataforma tem duas interfaces oficiais (CLI, implementada primeiro, e Interface Web) e deve permitir que o pesquisador integre scripts próprios. Decidimos que todas são **clientes finos** de uma única API da Plataforma (`127.0.0.1:8080/api`, *gateway* nginx → *webhooks* do n8n). Elas só coletam a entrada, chamam a API e apresentam a resposta. Regras de negócio (cálculo de N, RN-03 a RN-06, uma avaliação por vez, vereditos) ficam exclusivamente nos módulos atrás da API.

## Opções consideradas

- **CLI acessando PostgreSQL e Ollama diretamente**: descartada. Duplicaria em Python as validações, o cálculo de N (RF09) e o bloqueio de execução simultânea (RF11) que já estão nos workflows, e as duas interfaces poderiam divergir.
- **Clientes chamando o n8n diretamente (`:5678/webhook`)**: descartada. Prenderia os clientes ao n8n; com o *gateway*, o n8n é detalhe de implementação.

## Consequências

- Toda validação que um cliente queira mostrar antes de gravar precisa de uma rota própria na API (por exemplo, `POST /avaliacoes/validar` para N, erros e avisos), em vez de ser reimplementada no cliente.
- A API é um contrato público e sem versão: uma mudança incompatível exige atualizar o spec e os dois clientes juntos.
