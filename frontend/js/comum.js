// Utilitários de apresentação compartilhados pelas páginas (sem regras de negócio).

export function el(tag, atributos = {}, ...filhos) {
  const no = document.createElement(tag);
  for (const [k, v] of Object.entries(atributos || {})) {
    if (v === undefined || v === null || v === false) continue;
    if (k === 'classe') no.className = v;
    else if (k === 'texto') no.textContent = v;
    else if (k.startsWith('on') && typeof v === 'function') no.addEventListener(k.slice(2), v);
    else if (v === true) no.setAttribute(k, '');
    else no.setAttribute(k, v);
  }
  for (const f of filhos.flat()) {
    if (f === null || f === undefined || f === false) continue;
    no.append(f instanceof Node ? f : document.createTextNode(String(f)));
  }
  return no;
}

export const $ = (seletor, raiz = document) => raiz.querySelector(seletor);

export function limpar(no, ...filhos) {
  no.replaceChildren(...filhos.flat().filter((f) => f !== null && f !== undefined && f !== false));
  return no;
}

export function parametro(nome) {
  return new URLSearchParams(window.location.search).get(nome);
}

const ROTULOS = {
  violacao: 'violação',
  sem_violacao: 'sem violação',
  inconclusivo: 'inconclusivo',
  nao_aplicavel: 'não aplicável',
  falha: 'falha',
  pendente: 'pendente',
  concluida: 'concluída',
  configurada: 'configurada',
  em_execucao: 'em execução',
  finalizada: 'finalizada',
};

export const rotulo = (v) => (v === null || v === undefined ? '—' : ROTULOS[v] || String(v));

export function selo(valor, extra = '') {
  return el('span', { classe: `selo selo-${valor || 'nenhum'} ${extra}`.trim(), texto: rotulo(valor) });
}

export function numero(v, casas = 4) {
  if (v === null || v === undefined || v === '') return '—';
  const n = Number(v);
  return Number.isFinite(n) ? n.toLocaleString('pt-BR', { maximumFractionDigits: casas }) : String(v);
}

export function percentual(v) {
  if (v === null || v === undefined) return '—';
  return `${(Number(v) * 100).toLocaleString('pt-BR', { maximumFractionDigits: 1 })}%`;
}

export function dataHora(v) {
  if (!v) return '—';
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? String(v) : d.toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' });
}

export function barra(valor, total, rotuloAcessivel) {
  const fracao = total > 0 ? Math.min(1, Math.max(0, valor / total)) : 0;
  const preenchida = el('span', { classe: 'barra-preenchida' });
  preenchida.style.width = `${(fracao * 100).toFixed(1)}%`;
  return el('span', {
    classe: 'barra', role: 'progressbar', 'aria-valuemin': '0', 'aria-valuemax': String(total || 0),
    'aria-valuenow': String(valor || 0), 'aria-label': rotuloAcessivel || '',
  }, preenchida);
}

export function caixaErros(mensagens, titulo = 'Não foi possível concluir:') {
  if (!mensagens || mensagens.length === 0) return null;
  return el('div', { classe: 'alerta alerta-erro', role: 'alert' },
    el('strong', { texto: titulo }),
    el('ul', {}, mensagens.map((m) => el('li', { texto: m }))));
}

export function caixaAvisos(mensagens) {
  if (!mensagens || mensagens.length === 0) return null;
  return el('div', { classe: 'alerta alerta-aviso', role: 'status' },
    el('strong', { texto: 'Avisos' }),
    el('ul', {}, mensagens.map((m) => el('li', { texto: m }))));
}

export function mensagensDoErro(e) {
  return e && Array.isArray(e.mensagens) ? e.mensagens : [String(e && e.message ? e.message : e)];
}

export function tabela(cabecalhos, linhas, { vazio = 'Nenhum registro.', classe = '' } = {}) {
  if (!linhas.length) return el('p', { classe: 'vazio', texto: vazio });
  return el('div', { classe: 'tabela-rolagem' },
    el('table', { classe },
      el('thead', {}, el('tr', {}, cabecalhos.map((c) => el('th', { scope: 'col', texto: c })))),
      el('tbody', {}, linhas.map((l) => el('tr', {}, l.map((c) => el('td', {}, c)))))));
}

// Cabeçalho, navegação e aviso de uso autorizado (RE01), comuns a todas as páginas
export function montarCabecalho(ativo) {
  const links = [
    ['index.html', 'Avaliações', 'avaliacoes'],
    ['nova-avaliacao.html', 'Nova avaliação', 'nova'],
    ['ataques.html', 'Biblioteca de ataques', 'ataques'],
  ];
  const cabecalho = el('header', { classe: 'topo' },
    el('div', { classe: 'topo-conteudo' },
      el('a', { href: 'index.html', classe: 'marca' },
        el('span', { classe: 'marca-icone', 'aria-hidden': 'true' }),
        el('span', {}, 'Plataforma de Avaliação de Segurança', el('small', { texto: 'SLMs e LLMs locais' }))),
      el('nav', { 'aria-label': 'Principal' },
        links.map(([href, texto, chave]) =>
          el('a', { href, classe: chave === ativo ? 'ativo' : '', 'aria-current': chave === ativo ? 'page' : null, texto })))));
  const aviso = el('div', { classe: 'aviso-uso', role: 'note' },
    el('strong', { texto: 'Uso autorizado: ' }),
    'ferramenta de natureza ofensiva, para uso exclusivo em avaliações autorizadas (RE01). ',
    'Todos os dados permanecem no ambiente local.');
  document.body.prepend(cabecalho, aviso);
}
