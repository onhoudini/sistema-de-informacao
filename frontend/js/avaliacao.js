// Avaliação: executar, acompanhar (polling 5 s), resumo, tentativas e CSV (UC-03, UC-04).
import * as api from './api.js';
import {
  barra, caixaErros, dataHora, el, limpar, mensagensDoErro, montarCabecalho, numero, parametro, percentual,
  rotulo, selo, tabela, $,
} from './comum.js';

montarCabecalho('avaliacoes');
const principal = $('#conteudo');
const id = parametro('id');

const VEREDITOS = ['', 'violacao', 'sem_violacao', 'inconclusivo', 'nao_aplicavel', 'falha', 'pendente'];
const JUIZ = 'decididas_juiz';
let filtro = { veredito: '', pagina: 1, juiz: false };

// Marcador "decidida pelo juiz": os métodos discordaram e o LLM juiz foi acionado
function seloJuiz(t) {
  if (!t.juiz_acionado) return '—';
  return t.juiz_violacao === null
    ? el('span', { classe: 'selo selo-inconclusivo', title: 'Juiz acionado sem resultado válido', texto: 'juiz falhou' })
    : el('span', { classe: 'selo selo-juiz', title: 'Os métodos discordaram e o juiz desempatou', texto: 'juiz decidiu' });
}
let temporizador = null;
let avaliacao = null;

const areaCabecalho = el('div');
const areaMensagens = el('div', { 'aria-live': 'polite' });
const areaProgresso = el('section', { classe: 'cartao' });
const areaConfig = el('section', { classe: 'cartao' });
const areaResumo = el('section', { classe: 'cartao' });
const areaTentativas = el('section', { classe: 'cartao' });

// ---------- cabeçalho e execução ----------

async function executar(botao) {
  botao.disabled = true;
  limpar(areaMensagens);
  try {
    await api.executarAvaliacao(id);
    await carregar();
  } catch (e) {
    limpar(areaMensagens, caixaErros(mensagensDoErro(e), 'Não foi possível iniciar a execução:'));
    botao.disabled = false;
  }
}

function desenharCabecalho(av) {
  const acoes = el('div', { classe: 'linha' });
  if (av.status === 'configurada') {
    const botao = el('button', { classe: 'primario', texto: 'Executar avaliação' });
    botao.addEventListener('click', () => executar(botao));
    acoes.append(botao);
  }
  if (av.concluidas + av.falhas > 0) {
    acoes.append(
      el('a', { classe: 'botao', href: api.urlCsv(id), download: '', texto: 'Baixar CSV' }),
      el('a', { classe: 'botao', href: api.urlCsv(id, ';'), download: '', title: 'Separador ponto e vírgula, que o Excel em português abre direto', texto: 'CSV (Excel pt-BR)' }));
  }
  limpar(areaCabecalho, el('div', { classe: 'cabecalho-pagina' },
    el('div', {},
      el('h1', {}, av.nome, ' ', el('span', { classe: 'suave', texto: `#${av.id}` })),
      el('p', {}, selo(av.status), ` · criada em ${dataHora(av.criado_em)}`)),
    acoes));
}

function desenharProgresso(av) {
  const feitas = av.concluidas + av.falhas;
  limpar(areaProgresso,
    el('h2', { texto: 'Progresso' }),
    barra(feitas, av.n_planejado, 'Progresso da avaliação'),
    el('div', { classe: 'metricas' },
      [['Planejadas (N)', av.n_planejado], ['Concluídas', av.concluidas], ['Falhas', av.falhas], ['Pendentes', av.pendentes]]
        .map(([r, v]) => el('div', { classe: 'metrica' }, el('span', { texto: r }), el('strong', { texto: String(v) })))),
    av.status === 'em_execucao'
      ? el('p', { classe: 'ajuda', texto: 'Atualiza a cada 5 segundos. Fechar esta página não interrompe a avaliação.' })
      : null,
    el('p', { classe: 'ajuda', texto: `Iniciada: ${dataHora(av.iniciado_em)} · Finalizada: ${dataHora(av.finalizado_em)}` }));
}

function desenharConfig(av) {
  limpar(areaConfig,
    el('details', {},
      el('summary', {}, el('strong', { texto: 'Configuração da avaliação' })),
      el('dl', { classe: 'dados' },
        el('dt', { texto: 'Modelos' }), el('dd', { texto: av.modelos.join(', ') }),
        el('dt', { texto: 'Repetições' }), el('dd', { texto: String(av.repeticoes) }),
        el('dt', { texto: 'Tempo máximo por chamada' }), el('dd', { texto: `${av.timeout_chamada_s} s` }),
        el('dt', { texto: 'Limiares' }), el('dd', { texto: `TF-IDF ${numero(av.limiar_tfidf)} · embeddings ${numero(av.limiar_embedding)}` }),
        el('dt', { texto: 'Modelo juiz' }), el('dd', { texto: av.modelo_juiz })),
      el('h3', { texto: 'System prompts' }),
      tabela(['Rótulo', 'Conteúdo'], av.system_prompts.map((s) => [s.rotulo, s.conteudo ?? el('em', { texto: '(sem system prompt)' })])),
      el('h3', { texto: 'Configurações' }),
      tabela(['#', 'Parâmetros'], av.configuracoes.map((c, i) => [String(i), el('code', { texto: JSON.stringify(c) })])),
      el('h3', { texto: 'Ataques' }),
      tabela(['ID', 'Nome', 'Estratégia', 'Tipo'], av.ataques.map((a) => [String(a.id), a.nome, a.estrategia, a.tipo]))));
}

// ---------- resumo (RF21, RF22) ----------

function celulasContagem(c) {
  return [
    String(c.tentativas), String(c.violacoes), String(c.sem_violacao), String(c.inconclusivas),
    String(c.nao_aplicaveis), String(c.falhas), String(c.decididas_juiz ?? 0),
    el('div', {}, el('strong', { texto: percentual(c.taxa_violacao) }),
      c.taxa_violacao !== null ? (() => { const b = barra(c.violacoes, c.violacoes + c.sem_violacao, 'Taxa de violação'); b.classList.add('violacao'); return b; })() : null),
  ];
}
const COLUNAS = ['Tent.', 'Violação', 'Sem violação', 'Inconcl.', 'N/A', 'Falhas', 'Juiz', 'Taxa de violação'];

async function desenharResumo() {
  try {
    const r = await api.resumo(id);
    const t = r.total || {};
    limpar(areaResumo,
      el('h2', { texto: 'Resumo dos resultados' }),
      el('p', { classe: 'ajuda', texto: 'Taxa de violação = violações / (violações + sem violação), sobre o veredito final (inclui revisões humanas). Decididas pelo juiz: TF-IDF e embeddings discordaram e o LLM juiz desempatou; inconclusivo = o juiz não conseguiu decidir.' }),
      el('div', { classe: 'metricas' },
        [['Violações', t.violacoes], ['Sem violação', t.sem_violacao], ['Inconclusivas', t.inconclusivas],
          ['Não aplicáveis', t.nao_aplicaveis], ['Falhas', t.falhas], ['Decididas pelo juiz', t.decididas_juiz],
          ['Taxa de violação', percentual(t.taxa_violacao)]]
          .map(([rot, v]) => el('div', { classe: 'metrica' }, el('span', { texto: rot }), el('strong', { texto: String(v ?? 0) })))),
      el('h3', { texto: 'Por modelo × system prompt × estratégia' }),
      tabela(['Modelo', 'System prompt', 'Estratégia', ...COLUNAS],
        r.grupos.map((g) => [g.modelo, g.system_prompt, g.estrategia, ...celulasContagem(g)])),
      el('h3', { texto: 'Por ataque (bem-sucedido = veredito final violação)' }),
      tabela(['Ataque', 'Estratégia', 'Tipo', ...COLUNAS],
        r.por_ataque.map((a) => [a.ataque, a.estrategia, a.tipo, ...celulasContagem(a)])));
  } catch (e) {
    limpar(areaResumo, caixaErros(mensagensDoErro(e)));
  }
}

// ---------- tentativas (RF16, RF19) ----------

async function desenharTentativas() {
  // "decididas pelo juiz" é um item da mesma lista; vira o parâmetro juiz=sim da API
  const atual = filtro.juiz ? JUIZ : filtro.veredito;
  const seletor = el('select', { id: 'filtro-veredito' },
    VEREDITOS.map((v) => el('option', { value: v, selected: v === atual, texto: v ? rotulo(v) : 'Todos' })),
    el('option', { value: JUIZ, selected: atual === JUIZ, texto: 'decididas pelo juiz' }));
  seletor.addEventListener('change', () => {
    const juiz = seletor.value === JUIZ;
    filtro = { veredito: juiz ? '' : seletor.value, juiz, pagina: 1 };
    desenharTentativas();
  });
  const cabecalho = el('div', { classe: 'linha' },
    el('h2', { texto: 'Tentativas' }), el('span', { classe: 'espaco' }),
    el('label', { for: 'filtro-veredito', classe: 'suave', texto: 'Veredito final:' }), seletor);
  try {
    const r = await api.tentativas(id, filtro);
    const paginas = Math.max(1, Math.ceil(r.total / r.por_pagina));
    const anterior = el('button', { classe: 'pequeno', disabled: filtro.pagina <= 1, texto: '← Anterior' });
    const proxima = el('button', { classe: 'pequeno', disabled: filtro.pagina >= paginas, texto: 'Próxima →' });
    anterior.addEventListener('click', () => { filtro.pagina -= 1; desenharTentativas(); });
    proxima.addEventListener('click', () => { filtro.pagina += 1; desenharTentativas(); });
    limpar(areaTentativas, cabecalho,
      tabela(['ID', 'Modelo', 'System prompt', 'Conf.', 'Ataque', 'Rep.', 'TF-IDF', 'Emb.', 'Juiz', 'Veredito final'],
        r.itens.map((t) => [
          el('a', { href: `tentativa.html?id=${t.tentativa_id}`, texto: `#${t.tentativa_id}` }),
          t.modelo, t.system_prompt, String(t.configuracao_idx), t.ataque, String(t.repeticao),
          numero(t.tfidf_score), numero(t.embedding_score), seloJuiz(t),
          el('span', {}, selo(t.veredito_final || (t.status === 'concluida' ? null : t.status)),
            t.veredito_humano ? el('span', { classe: 'suave', texto: ' revisado' }) : null),
        ]), { vazio: 'Nenhuma tentativa com este filtro.' }),
      el('div', { classe: 'paginacao' }, anterior,
        el('span', { classe: 'suave', texto: `Página ${filtro.pagina} de ${paginas} · ${r.total} tentativa(s)` }), proxima));
  } catch (e) {
    limpar(areaTentativas, cabecalho, caixaErros(mensagensDoErro(e)));
  }
}

// ---------- carregamento ----------

async function carregar() {
  clearTimeout(temporizador);
  try {
    avaliacao = await api.verAvaliacao(id);
  } catch (e) {
    limpar(principal, el('h1', { texto: 'Avaliação' }), caixaErros(mensagensDoErro(e)),
      el('a', { href: 'index.html', texto: '← Voltar às avaliações' }));
    return;
  }
  desenharCabecalho(avaliacao);
  desenharProgresso(avaliacao);
  desenharConfig(avaliacao);
  const temResultados = avaliacao.concluidas + avaliacao.falhas > 0;
  areaResumo.classList.toggle('oculto', !temResultados);
  areaTentativas.classList.toggle('oculto', avaliacao.status === 'configurada');
  if (temResultados) desenharResumo();
  if (avaliacao.status !== 'configurada') desenharTentativas();
  if (avaliacao.status === 'em_execucao') temporizador = setTimeout(carregar, 5000);
}

if (!id) {
  limpar(principal, caixaErros(['Informe o id da avaliação na URL (avaliacao.html?id=1).']));
} else {
  limpar(principal, areaCabecalho, areaMensagens,
    parametro('criada') ? el('div', { classe: 'alerta alerta-ok', texto: 'Avaliação criada. Revise a configuração e execute quando quiser.' }) : null,
    areaProgresso, areaConfig, areaResumo, areaTentativas);
  carregar();
}
