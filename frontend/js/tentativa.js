// Evidências de uma tentativa, verificação, histórico de revisões e formulário de revisão (UC-04).
import * as api from './api.js';
import {
  caixaErros, dataHora, el, limpar, mensagensDoErro, montarCabecalho, numero, parametro, rotulo, selo, tabela, $,
} from './comum.js';

montarCabecalho('avaliacoes');
const principal = $('#conteudo');
const id = parametro('id');

const ROTULO_PAPEL = { system: 'system prompt', user: 'pesquisador (ataque)', assistant: 'modelo' };

function mensagem(papel, conteudo) {
  return el('div', { classe: `mensagem ${papel}` }, el('small', { texto: ROTULO_PAPEL[papel] || papel }), conteudo ?? '');
}

// System prompt começa minimizado (pode ser longo); abre com um clique
function systemPromptRecolhido(conteudo) {
  return el('details', { classe: 'mensagem system recolhivel' },
    el('summary', { texto: 'System prompt utilizado' }),
    el('div', { classe: 'recolhivel-conteudo', texto: conteudo }));
}

function conversa(t) {
  const blocos = [];
  if (t.system_prompt.conteudo !== null) blocos.push(systemPromptRecolhido(t.system_prompt.conteudo));
  else blocos.push(el('p', { classe: 'vazio', texto: 'Tentativa sem system prompt (veredito "não aplicável"; depende de revisão humana).' }));
  for (const turno of t.turnos) {
    const entrada = turno.entrada || [];
    const ultima = entrada[entrada.length - 1];
    blocos.push(el('div', { classe: 'suave', texto: `Turno ${turno.ordem}` }));
    blocos.push(mensagem('user', ultima ? ultima.content : ''));
    blocos.push(mensagem('assistant', turno.resposta));
    blocos.push(el('details', {},
      el('summary', { classe: 'suave', texto: `Entrada completa enviada ao Ollama no turno ${turno.ordem} (${entrada.length} mensagens)` }),
      el('pre', { classe: 'bloco', texto: JSON.stringify(entrada, null, 2) }),
      turno.metadados ? el('pre', { classe: 'bloco', texto: JSON.stringify(turno.metadados, null, 2) }) : null));
  }
  if (!t.turnos.length) blocos.push(el('p', { classe: 'vazio', texto: 'Nenhum turno registrado.' }));
  return el('div', { classe: 'conversa' }, blocos);
}

function verificacao(t, limiares) {
  const v = t.verificacao;
  if (!v) return el('p', { classe: 'vazio', texto: t.status === 'falha' ? 'Sem verificação: a tentativa falhou.' : 'Sem verificação ainda.' });
  const lim = (x) => (x === undefined ? '' : ` (limiar ${numero(x)})`);
  return el('dl', { classe: 'dados' },
    el('dt', { texto: 'TF-IDF' }), el('dd', {}, `${numero(v.tfidf_score)}${lim(limiares.tfidf)} `, v.tfidf_violacao === null ? '' : selo(v.tfidf_violacao ? 'violacao' : 'sem_violacao')),
    el('dt', { texto: 'Embeddings' }), el('dd', {}, `${numero(v.embedding_score)}${lim(limiares.embedding)} `, v.embedding_violacao === null ? '' : selo(v.embedding_violacao ? 'violacao' : 'sem_violacao')),
    el('dt', { texto: 'Métodos concordam' }), el('dd', { texto: v.concordam === null ? '—' : v.concordam ? 'sim' : 'não' }),
    el('dt', { texto: 'LLM juiz' }), el('dd', {}, v.juiz_acionado
      ? [v.juiz_violacao === null ? selo('inconclusivo') : selo(v.juiz_violacao ? 'violacao' : 'sem_violacao'),
        v.juiz_justificativa ? el('div', { texto: v.juiz_justificativa }) : null,
        v.juiz_bruto ? el('details', {}, el('summary', { classe: 'suave', texto: 'Resposta bruta do juiz' }), el('pre', { classe: 'bloco', texto: v.juiz_bruto })) : null]
      : 'não acionado'),
    el('dt', { texto: 'Veredito automático' }), el('dd', {}, selo(v.veredito)),
    el('dt', { texto: 'Registrado em' }), el('dd', { texto: dataHora(v.criado_em) }));
}

function formularioRevisao(t) {
  const area = el('div', { 'aria-live': 'polite' });
  const comentario = el('textarea', { id: 'comentario', rows: '3', placeholder: 'Justificativa da revisão (opcional)' });
  const botao = el('button', { classe: 'primario', type: 'submit', texto: 'Registrar revisão' });
  const opcao = (valor) => el('label', { classe: 'opcao' },
    el('input', { type: 'radio', name: 'veredito', value: valor, required: true }), el('span', { texto: rotulo(valor) }));
  const form = el('form', {},
    el('fieldset', {}, el('legend', { texto: 'Veredito da revisão' }), opcao('violacao'), opcao('sem_violacao')),
    el('div', { classe: 'campo' }, el('label', { for: 'comentario', texto: 'Comentário' }), comentario),
    el('div', { classe: 'linha' }, el('span', { classe: 'ajuda', texto: 'O veredito automático é preservado; a revisão mais recente vale como veredito final.' }),
      el('span', { classe: 'espaco' }), botao),
    area);
  form.addEventListener('submit', async (evento) => {
    evento.preventDefault();
    const escolhido = form.querySelector('input[name="veredito"]:checked');
    botao.disabled = true;
    try {
      await api.revisar(t.tentativa_id, escolhido ? escolhido.value : '', comentario.value.trim());
      await carregar();
    } catch (e) {
      limpar(area, caixaErros(mensagensDoErro(e)));
      botao.disabled = false;
    }
  });
  return form;
}

async function carregar() {
  let t;
  try {
    t = await api.verTentativa(id);
  } catch (e) {
    limpar(principal, el('h1', { texto: 'Tentativa' }), caixaErros(mensagensDoErro(e)),
      el('a', { href: 'index.html', texto: '← Voltar às avaliações' }));
    return;
  }
  let limiares = {};
  try {
    const av = await api.verAvaliacao(t.avaliacao_id);
    limiares = { tfidf: av.limiar_tfidf, embedding: av.limiar_embedding };
  } catch { /* limiares são só informativos */ }

  limpar(principal,
    el('div', { classe: 'cabecalho-pagina' },
      el('div', {},
        el('a', { href: `avaliacao.html?id=${t.avaliacao_id}`, texto: `← Avaliação #${t.avaliacao_id}` }),
        el('h1', {}, `Tentativa #${t.tentativa_id} `, selo(t.veredito_final || (t.status === 'concluida' ? null : t.status))),
        el('p', { texto: `${t.modelo} · ${t.system_prompt.rotulo} · ${t.ataque.nome} (${t.ataque.estrategia}) · repetição ${t.repeticao}` }))),
    t.erro ? caixaErros([t.erro], 'A tentativa falhou:') : null,
    el('div', { classe: 'grade grade-lateral' },
      el('div', {},
        el('section', { classe: 'cartao' }, el('h2', { texto: 'Evidências turno a turno' }), conversa(t))),
      el('div', {},
        el('section', { classe: 'cartao' },
          el('h2', { texto: 'Condições' }),
          el('dl', { classe: 'dados' },
            el('dt', { texto: 'Status' }), el('dd', {}, selo(t.status)),
            el('dt', { texto: 'Configuração' }), el('dd', {}, el('code', { texto: JSON.stringify(t.configuracao) })),
            el('dt', { texto: 'Tipo de ataque' }), el('dd', { texto: t.ataque.tipo === 'multi_turno' ? 'multi-turno' : 'turno único' }),
            el('dt', { texto: 'Início' }), el('dd', { texto: dataHora(t.iniciado_em) }),
            el('dt', { texto: 'Fim' }), el('dd', { texto: dataHora(t.finalizado_em) }))),
        el('section', { classe: 'cartao' }, el('h2', { texto: 'Verificação automática' }), verificacao(t, limiares)),
        el('section', { classe: 'cartao' },
          el('h2', { texto: 'Revisão humana' }),
          el('p', {}, 'Veredito final: ', selo(t.veredito_final), t.veredito_humano ? el('span', { classe: 'suave', texto: ' (revisado)' }) : null),
          tabela(['Veredito', 'Comentário', 'Em'], t.revisoes.map((r) => [selo(r.veredito), r.comentario || '—', dataHora(r.criado_em)]),
            { vazio: 'Nenhuma revisão registrada.' }),
          formularioRevisao(t)))));
}

if (!id) limpar(principal, caixaErros(['Informe o id da tentativa na URL (tentativa.html?id=1).']));
else carregar();
