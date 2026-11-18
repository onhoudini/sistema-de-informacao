// Lista de avaliações (status, N e progresso) e atalhos.
import * as api from './api.js';
import { barra, caixaErros, dataHora, el, limpar, mensagensDoErro, montarCabecalho, selo, tabela, $ } from './comum.js';

montarCabecalho('avaliacoes');
const principal = $('#conteudo');
let temporizador = null;

function linhaAvaliacao(a) {
  const feitas = (a.concluidas || 0) + (a.falhas || 0);
  return [
    el('a', { href: `avaliacao.html?id=${a.id}`, texto: `#${a.id}` }),
    el('a', { href: `avaliacao.html?id=${a.id}`, texto: a.nome }),
    selo(a.status),
    el('span', { classe: 'num', texto: String(a.n_planejado) }),
    el('div', {},
      barra(feitas, a.n_planejado, `Progresso da avaliação ${a.id}`),
      el('div', { classe: 'progresso-texto', texto: `${a.concluidas} concluídas · ${a.falhas} falhas · ${a.pendentes} pendentes` })),
    dataHora(a.criado_em),
  ];
}

async function carregar() {
  clearTimeout(temporizador);
  try {
    const avaliacoes = await api.listarAvaliacoes();
    limpar(principal,
      el('div', { classe: 'cabecalho-pagina' },
        el('div', {}, el('h1', { texto: 'Avaliações' }),
          el('p', { texto: 'Avaliações configuradas, em execução e finalizadas. Só uma avaliação executa por vez.' })),
        el('div', { classe: 'linha' },
          el('a', { classe: 'botao', href: 'ataques.html', texto: 'Biblioteca de ataques' }),
          el('a', { classe: 'botao primario', href: 'nova-avaliacao.html', texto: 'Nova avaliação' }))),
      el('section', { classe: 'cartao' },
        tabela(['ID', 'Nome', 'Status', 'N', 'Progresso', 'Criada em'], avaliacoes.map(linhaAvaliacao), {
          vazio: 'Nenhuma avaliação ainda. Comece por "Nova avaliação".',
        })));
    if (avaliacoes.some((a) => a.status === 'em_execucao')) temporizador = setTimeout(carregar, 5000);
  } catch (e) {
    limpar(principal, el('h1', { texto: 'Avaliações' }), caixaErros(mensagensDoErro(e)),
      el('button', { onclick: carregar, texto: 'Tentar de novo' }));
  }
}

carregar();
