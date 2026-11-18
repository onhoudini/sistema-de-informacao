// Formulário de nova avaliação (UC-02). N, erros e avisos vêm SEMPRE de POST /api/avaliacoes/validar
// (com debounce); nenhuma regra de validação ou cálculo é feito no navegador (ADR 0001).
import * as api from './api.js';
import { caixaAvisos, caixaErros, el, limpar, mensagensDoErro, montarCabecalho, $ } from './comum.js';

montarCabecalho('nova');
const principal = $('#conteudo');

const PARAMETROS = [
  ['temperature', 'temperature', '0.1'],
  ['top_p', 'top_p', '0.05'],
  ['top_k', 'top_k', '1'],
  ['seed', 'seed', '1'],
  ['num_predict', 'num_predict', '1'],
  ['num_ctx', 'num_ctx', '1'],
];

let modelos = [];
let ataques = [];
let contador = 0;
const novoId = (p) => `${p}-${++contador}`;

// ---------- leitura do formulário (só coleta; a API valida) ----------

function valorNumerico(input) {
  const v = input.value.trim();
  if (v === '') return undefined;
  const n = Number(v.replace(',', '.'));
  return Number.isFinite(n) ? n : v; // texto inválido segue para a API apontar o erro
}

function montarCorpo() {
  const corpo = {
    nome: $('#nome').value,
    modelos: [...document.querySelectorAll('input[name="modelo"]:checked')].map((i) => i.value),
    system_prompts: [...document.querySelectorAll('.system-prompt')].map((bloco) => ({
      rotulo: bloco.querySelector('.sp-rotulo').value,
      conteudo: bloco.querySelector('.sp-conteudo').value,
    })),
    configuracoes: [...document.querySelectorAll('.configuracao')].map((bloco) => {
      const conf = {};
      for (const [chave] of PARAMETROS) {
        const v = valorNumerico(bloco.querySelector(`[data-param="${chave}"]`));
        if (v !== undefined) conf[chave] = v;
      }
      return conf;
    }),
    ataques: [...document.querySelectorAll('input[name="ataque"]:checked')].map((i) => Number(i.value)),
    repeticoes: valorNumerico($('#repeticoes')),
    timeout_chamada_s: valorNumerico($('#timeout')),
    limiar_tfidf: valorNumerico($('#limiar-tfidf')),
    limiar_embedding: valorNumerico($('#limiar-embedding')),
    modelo_juiz: $('#modelo-juiz').value,
  };
  if ($('#sem-system-prompt').checked) corpo.system_prompts.push({ rotulo: 'sem-system-prompt', conteudo: null });
  for (const k of ['repeticoes', 'timeout_chamada_s', 'limiar_tfidf', 'limiar_embedding']) {
    if (corpo[k] === undefined) delete corpo[k];
  }
  return corpo;
}

// ---------- validação ao vivo ----------

const painelN = el('div', { classe: 'destaque-n', texto: '—' });
const painelMensagens = el('div', { 'aria-live': 'polite' });
const previaJson = el('pre', { classe: 'bloco' });
const botaoSalvar = el('button', { classe: 'primario', type: 'submit', texto: 'Revisar e salvar' });
let ultimaValidacao = null;
let temporizador = null;
let sequencia = 0;

function agendarValidacao() {
  clearTimeout(temporizador);
  temporizador = setTimeout(validar, 400);
}

async function validar() {
  const corpo = montarCorpo();
  previaJson.textContent = JSON.stringify(corpo, null, 2);
  const minha = ++sequencia;
  try {
    const r = await api.validarAvaliacao(corpo);
    if (minha !== sequencia) return; // resposta antiga
    ultimaValidacao = r;
    painelN.textContent = r.n_planejado === null ? '—' : r.n_planejado.toLocaleString('pt-BR');
    limpar(painelMensagens,
      r.erros.length ? caixaErros(r.erros, 'Corrija para poder salvar:') : el('div', { classe: 'alerta alerta-ok', texto: 'Configuração válida.' }),
      caixaAvisos(r.avisos));
  } catch (e) {
    if (minha !== sequencia) return;
    ultimaValidacao = null;
    painelN.textContent = '—';
    limpar(painelMensagens, caixaErros(mensagensDoErro(e)));
  }
}

// ---------- blocos dinâmicos ----------

function blocoSystemPrompt(rotulo = '', conteudo = '') {
  const idR = novoId('sp-rotulo');
  const idC = novoId('sp-conteudo');
  const bloco = el('div', { classe: 'item-dinamico system-prompt' },
    el('div', { classe: 'campo' }, el('label', { for: idR, texto: 'Rótulo' }),
      el('input', { type: 'text', id: idR, classe: 'sp-rotulo', value: rotulo, placeholder: 'ex.: atendimento-banco' })),
    el('div', { classe: 'campo' }, el('label', { for: idC, texto: 'Conteúdo do system prompt' }),
      el('textarea', { id: idC, classe: 'sp-conteudo', rows: '4' })),
    el('button', { type: 'button', classe: 'pequeno perigo', texto: 'Remover', onclick: () => { bloco.remove(); agendarValidacao(); } }));
  bloco.querySelector('.sp-conteudo').value = conteudo;
  return bloco;
}

function blocoConfiguracao(valores = {}) {
  const bloco = el('div', { classe: 'item-dinamico configuracao' },
    el('div', { classe: 'grade-parametros' }, PARAMETROS.map(([chave, rotulo, passo]) => {
      const id = novoId(`p-${chave}`);
      return el('div', {}, el('label', { for: id, texto: rotulo }),
        el('input', { type: 'number', id, step: passo, 'data-param': chave, value: valores[chave] ?? '' }));
    })),
    el('div', { classe: 'linha' },
      el('span', { classe: 'ajuda', texto: 'Campos vazios não são enviados (o Ollama usa o padrão do modelo).' }),
      el('span', { classe: 'espaco' }),
      el('button', { type: 'button', classe: 'pequeno perigo', texto: 'Remover', onclick: () => { bloco.remove(); agendarValidacao(); } })));
  return bloco;
}

function grupoAtaques() {
  const porEstrategia = new Map();
  for (const a of ataques) {
    if (!porEstrategia.has(a.estrategia)) porEstrategia.set(a.estrategia, []);
    porEstrategia.get(a.estrategia).push(a);
  }
  return [...porEstrategia].map(([estrategia, lista]) => {
    const caixas = lista.map((a) => el('label', { classe: 'opcao' },
      el('input', { type: 'checkbox', name: 'ataque', value: String(a.id) }),
      el('span', {}, a.nome, ' ', el('span', { classe: 'suave', texto: a.tipo === 'multi_turno' ? `· multi-turno (${a.mensagens.length})` : '' }))));
    const todos = el('button', {
      type: 'button', classe: 'pequeno', texto: 'Marcar todos',
      onclick: () => {
        const inputs = caixas.map((c) => c.querySelector('input'));
        const marcar = inputs.some((i) => !i.checked);
        inputs.forEach((i) => { i.checked = marcar; });
        agendarValidacao();
      },
    });
    return el('details', { classe: 'grupo' },
      el('summary', {}, estrategia, el('span', { classe: 'selo', texto: String(lista.length) })),
      el('div', { classe: 'grupo-corpo' }, todos, el('div', { classe: 'colunas-opcoes' }, caixas)));
  });
}

// ---------- montagem ----------

function campoNumero(id, rotulo, ajuda, atributos = {}) {
  return el('div', { classe: 'campo' },
    el('label', { for: id }, rotulo, ajuda ? el('span', { classe: 'ajuda', texto: ajuda }) : null),
    el('input', { type: 'number', id, ...atributos }));
}

async function salvar(evento) {
  evento.preventDefault();
  await validar();
  if (!ultimaValidacao || ultimaValidacao.erros.length) {
    painelMensagens.scrollIntoView({ behavior: 'smooth', block: 'center' });
    return;
  }
  const corpo = montarCorpo();
  const resumo = [
    `Nome: ${corpo.nome}`,
    `Modelos: ${corpo.modelos.join(', ')}`,
    `System prompts: ${corpo.system_prompts.map((s) => s.rotulo).join(', ')}`,
    `Configurações: ${corpo.configuracoes.map((c) => JSON.stringify(c)).join(' | ')}`,
    `Ataques: ${corpo.ataques.map((id) => ataques.find((a) => a.id === id)?.nome ?? id).join(', ')}`,
    `Modelo juiz: ${corpo.modelo_juiz}`,
    '',
    `Quantidade planejada de tentativas (N): ${ultimaValidacao.n_planejado}`,
  ].join('\n');
  if (!window.confirm(`Confirme a configuração da avaliação:\n\n${resumo}\n\nSalvar?`)) return;
  botaoSalvar.disabled = true;
  try {
    const r = await api.criarAvaliacao(corpo);
    window.location.href = `avaliacao.html?id=${r.id}&criada=1`;
  } catch (e) {
    limpar(painelMensagens, caixaErros(mensagensDoErro(e)), caixaAvisos(e.corpo && e.corpo.avisos));
    botaoSalvar.disabled = false;
  }
}

async function iniciar() {
  try {
    [modelos, ataques] = await Promise.all([api.listarModelos(), api.listarAtaques()]);
  } catch (e) {
    limpar(principal, el('h1', { texto: 'Nova avaliação' }), caixaErros(mensagensDoErro(e)),
      el('button', { onclick: iniciar, texto: 'Tentar de novo' }));
    return;
  }

  const listaSP = el('div', { classe: 'lista-itens' }, blocoSystemPrompt());
  const listaConf = el('div', { classe: 'lista-itens' }, blocoConfiguracao({ temperature: 0, seed: 42 }));

  const formulario = el('form', { id: 'form-avaliacao', onsubmit: salvar, oninput: agendarValidacao, onchange: agendarValidacao },
    el('section', { classe: 'cartao' },
      el('div', { classe: 'campo' }, el('label', { for: 'nome', texto: 'Nome da avaliação' }),
        el('input', { type: 'text', id: 'nome', placeholder: 'ex.: baseline-modelos-pequenos' }))),

    el('fieldset', { classe: 'cartao' }, el('legend', { texto: 'Modelos avaliados (M)' }),
      modelos.length
        ? el('div', { classe: 'colunas-opcoes' }, modelos.map((m) => el('label', { classe: 'opcao' },
          el('input', { type: 'checkbox', name: 'modelo', value: m.nome }),
          el('span', {}, m.nome, ' ', el('span', { classe: 'suave', texto: [m.parametros, m.quantizacao].filter(Boolean).join(' · ') })))))
        : el('p', { classe: 'vazio', texto: 'Nenhum modelo no Ollama. Baixe com "ollama pull <modelo>".' })),

    el('fieldset', { classe: 'cartao' }, el('legend', { texto: 'System prompts (S)' }),
      listaSP,
      el('div', { classe: 'linha' },
        el('button', { type: 'button', classe: 'pequeno', texto: '+ System prompt', onclick: () => { listaSP.append(blocoSystemPrompt()); agendarValidacao(); } }),
        el('label', { classe: 'opcao' }, el('input', { type: 'checkbox', id: 'sem-system-prompt' }),
          el('span', { texto: 'Incluir a condição "sem system prompt"' })))),

    el('fieldset', { classe: 'cartao' }, el('legend', { texto: 'Configurações de execução (C)' }),
      el('p', { classe: 'ajuda', texto: 'Aplicadas igualmente a todos os modelos.' }),
      listaConf,
      el('button', { type: 'button', classe: 'pequeno', texto: '+ Configuração', onclick: () => { listaConf.append(blocoConfiguracao()); agendarValidacao(); } })),

    el('fieldset', { classe: 'cartao' }, el('legend', { texto: 'Ataques (A)' }),
      el('p', { classe: 'ajuda' }, 'Combine ataques predefinidos e personalizados. ', el('a', { href: 'ataques.html', texto: 'Ver a biblioteca' })),
      grupoAtaques()),

    el('fieldset', { classe: 'cartao' }, el('legend', { texto: 'Execução e verificação' }),
      el('div', { classe: 'grade grade-2' },
        campoNumero('repeticoes', 'Repetições por ataque (R)', null, { min: '1', step: '1', value: '1' }),
        campoNumero('timeout', 'Tempo máximo por chamada (s)', 'Vazio = padrão da API.', { min: '1', step: '1' }),
        campoNumero('limiar-tfidf', 'Limiar TF-IDF', 'Vazio = padrão da API.', { step: '0.05', min: '0', max: '1' }),
        campoNumero('limiar-embedding', 'Limiar embeddings', 'Vazio = padrão da API.', { step: '0.05', min: '0', max: '1' }),
        el('div', { classe: 'campo' },
          el('label', { for: 'modelo-juiz' }, 'Modelo juiz', el('span', { classe: 'ajuda', texto: 'Acionado só quando TF-IDF e embeddings discordam.' })),
          el('select', { id: 'modelo-juiz' }, el('option', { value: '', texto: 'Selecione…' }),
            modelos.map((m) => el('option', { value: m.nome, texto: m.nome })))))));

  const lateral = el('aside', { classe: 'cartao fixo' },
    el('h2', { texto: 'Resumo' }),
    el('div', { classe: 'suave', texto: 'Quantidade planejada de tentativas (N)' }),
    painelN,
    el('p', { classe: 'ajuda', texto: 'Calculada e validada pela API da Plataforma a cada alteração.' }),
    painelMensagens,
    el('details', {}, el('summary', { texto: 'Ver o JSON enviado' }), previaJson),
    el('div', { classe: 'linha' }, el('span', { classe: 'espaco' }), botaoSalvar));
  botaoSalvar.setAttribute('form', 'form-avaliacao');

  limpar(principal,
    el('div', { classe: 'cabecalho-pagina' },
      el('div', {}, el('h1', { texto: 'Nova avaliação' }),
        el('p', { texto: 'Modelos × system prompts × configurações × ataques × repetições.' }))),
    el('div', { classe: 'grade grade-lateral' }, formulario, lateral));
  validar();
}

iniciar();
