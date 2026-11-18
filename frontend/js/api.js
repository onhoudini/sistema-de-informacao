// Cliente da API da Plataforma (spec §5). Todas as chamadas da Interface Web passam por aqui
// e usam caminhos relativos /api/... (o gateway faz o proxy). Nenhuma regra de negócio (ADR 0001).

export class ErroAPI extends Error {
  constructor(status, corpo, mensagens) {
    super(mensagens.join('\n'));
    this.status = status;
    this.corpo = corpo;
    this.mensagens = mensagens;
  }
}

function mensagensDe(status, corpo) {
  if (corpo && Array.isArray(corpo.erros)) return corpo.erros.map(String);
  if (corpo && corpo.erro) return [String(corpo.erro)];
  if (status === 404 && corpo && /webhook/i.test(corpo.message || '')) {
    return ['O workflow do n8n que atende esta rota não está ativo. Execute scripts/configurar-n8n.'];
  }
  if (corpo && corpo.message) return [String(corpo.message)];
  return [`Erro HTTP ${status}.`];
}

async function requisitar(metodo, caminho, { corpo, params } = {}) {
  let url = `/api${caminho}`;
  if (params) {
    const qs = new URLSearchParams();
    for (const [k, v] of Object.entries(params)) {
      if (v !== undefined && v !== null && v !== '') qs.set(k, v);
    }
    const texto = qs.toString();
    if (texto) url += `?${texto}`;
  }
  const opcoes = { method: metodo, headers: { Accept: 'application/json' } };
  if (corpo !== undefined) {
    opcoes.headers['Content-Type'] = 'application/json';
    opcoes.body = JSON.stringify(corpo);
  }
  let resposta;
  try {
    resposta = await fetch(url, opcoes);
  } catch {
    throw new ErroAPI(0, null, ['Não foi possível conectar à API da Plataforma. Verifique se o ambiente está no ar.']);
  }
  let dados = null;
  try {
    dados = await resposta.json();
  } catch {
    dados = null;
  }
  if (!resposta.ok) throw new ErroAPI(resposta.status, dados, mensagensDe(resposta.status, dados));
  return dados;
}

// Ataques (UC-01)
export const listarAtaques = (estrategia) => requisitar('GET', '/ataques', { params: { estrategia } });
export const adicionarAtaques = (dados) => requisitar('POST', '/ataques', { corpo: dados });

// Modelos
export const listarModelos = () => requisitar('GET', '/modelos');

// Avaliações (UC-02, UC-03)
export const validarAvaliacao = (dados) => requisitar('POST', '/avaliacoes/validar', { corpo: dados });
export const criarAvaliacao = (dados) => requisitar('POST', '/avaliacoes', { corpo: dados });
export const listarAvaliacoes = () => requisitar('GET', '/avaliacoes');
export const verAvaliacao = (id) => requisitar('GET', `/avaliacoes/${encodeURIComponent(id)}`);
export const executarAvaliacao = (id) => requisitar('POST', `/avaliacoes/${encodeURIComponent(id)}/executar`);

// Resultados (UC-04)
export const resumo = (id) => requisitar('GET', `/avaliacoes/${encodeURIComponent(id)}/resumo`);
export const tentativas = (id, { veredito, pagina, juiz } = {}) =>
  requisitar('GET', `/avaliacoes/${encodeURIComponent(id)}/tentativas`, {
    params: { veredito, pagina, juiz: juiz ? 'sim' : undefined },
  });
export const urlCsv = (id, separador = ',') =>
  `/api/avaliacoes/${encodeURIComponent(id)}/csv${separador === ';' ? '?separador=%3B' : ''}`;
export const verTentativa = (id) => requisitar('GET', `/tentativas/${encodeURIComponent(id)}`);
export const revisar = (id, veredito, comentario) =>
  requisitar('POST', `/tentativas/${encodeURIComponent(id)}/revisao`, {
    corpo: comentario ? { veredito, comentario } : { veredito },
  });
