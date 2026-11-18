-- Modelo de dados da Plataforma (spec §3) e funções de acesso usadas pelos
-- workflows do n8n. Executado pelo docker-entrypoint-initdb.d.
-- As funções recebem e devolvem jsonb e sempre retornam exatamente uma linha,
-- para que cada nó Postgres do n8n produza um item.

\connect plataforma

SET client_min_messages = warning;

-- ---------------------------------------------------------------------------
-- Tabelas
-- ---------------------------------------------------------------------------

CREATE TABLE ataque (
  id            SERIAL PRIMARY KEY,
  nome          TEXT NOT NULL UNIQUE,
  estrategia    TEXT NOT NULL,
  descricao     TEXT,
  mensagens     JSONB NOT NULL CHECK (jsonb_typeof(mensagens) = 'array'
                                      AND jsonb_array_length(mensagens) >= 1),
  tipo          TEXT GENERATED ALWAYS AS
                  (CASE WHEN jsonb_array_length(mensagens) = 1
                        THEN 'turno_unico' ELSE 'multi_turno' END) STORED,
  origem        TEXT NOT NULL CHECK (origem IN ('predefinido','personalizado')),
  criado_em     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE avaliacao (
  id                 SERIAL PRIMARY KEY,
  nome               TEXT NOT NULL,
  status             TEXT NOT NULL DEFAULT 'configurada'
                       CHECK (status IN ('configurada','em_execucao','finalizada')),
  modelos            JSONB NOT NULL,                                   -- (M)
  configuracoes      JSONB NOT NULL,                                   -- (C)
  repeticoes         INT   NOT NULL CHECK (repeticoes >= 1),           -- (R)
  timeout_chamada_s  INT   NOT NULL CHECK (timeout_chamada_s > 0),     -- RF23
  limiar_tfidf       NUMERIC(4,3) NOT NULL,
  limiar_embedding   NUMERIC(4,3) NOT NULL,
  modelo_juiz        TEXT  NOT NULL,
  n_planejado        INT   NOT NULL,                                   -- RF09
  criado_em          TIMESTAMPTZ NOT NULL DEFAULT now(),
  iniciado_em        TIMESTAMPTZ,
  finalizado_em      TIMESTAMPTZ
);
-- RF11 / RN-10: no máximo uma avaliação em execução
CREATE UNIQUE INDEX uma_avaliacao_em_execucao ON avaliacao ((true))
  WHERE status = 'em_execucao';

CREATE TABLE avaliacao_system_prompt (                                 -- (S)
  id            SERIAL PRIMARY KEY,
  avaliacao_id  INT NOT NULL REFERENCES avaliacao(id),
  rotulo        TEXT NOT NULL,
  conteudo      TEXT                    -- NULL = condição "sem system prompt" (RN-05)
);

CREATE TABLE avaliacao_ataque (                                        -- (A)
  avaliacao_id  INT NOT NULL REFERENCES avaliacao(id),
  ataque_id     INT NOT NULL REFERENCES ataque(id),
  ordem         INT NOT NULL,           -- ordem informada na configuração
  snapshot      JSONB NOT NULL,         -- cópia do ataque no momento da configuração
  PRIMARY KEY (avaliacao_id, ataque_id)
);

CREATE TABLE tentativa (                -- = "chamada" do RF09
  id                 SERIAL PRIMARY KEY,
  avaliacao_id       INT  NOT NULL REFERENCES avaliacao(id),
  modelo             TEXT NOT NULL,
  system_prompt_id   INT  NOT NULL REFERENCES avaliacao_system_prompt(id),
  configuracao_idx   INT  NOT NULL,
  configuracao       JSONB NOT NULL,    -- options efetivamente enviados (inclui seed efetiva)
  ataque_id          INT  NOT NULL REFERENCES ataque(id),
  repeticao          INT  NOT NULL,
  status             TEXT NOT NULL DEFAULT 'pendente'
                       CHECK (status IN ('pendente','concluida','falha')),
  erro               TEXT,
  iniciado_em        TIMESTAMPTZ,
  finalizado_em      TIMESTAMPTZ
);
CREATE INDEX tentativa_avaliacao ON tentativa (avaliacao_id, id);

CREATE TABLE turno (
  id             SERIAL PRIMARY KEY,
  tentativa_id   INT NOT NULL REFERENCES tentativa(id),
  ordem          INT NOT NULL,
  entrada        JSONB NOT NULL,        -- messages[] enviado ao Ollama neste turno
  resposta       TEXT,
  metadados      JSONB,                 -- eval_count, prompt_eval_count, total_duration...
  criado_em      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (tentativa_id, ordem)
);

CREATE TABLE verificacao (              -- uma por tentativa, nunca atualizada (RN-13)
  tentativa_id         INT PRIMARY KEY REFERENCES tentativa(id),
  tfidf_score          NUMERIC(5,4),
  tfidf_violacao       BOOLEAN,
  embedding_score      NUMERIC(5,4),
  embedding_violacao   BOOLEAN,
  concordam            BOOLEAN,
  juiz_acionado        BOOLEAN NOT NULL DEFAULT false,
  juiz_violacao        BOOLEAN,
  juiz_justificativa   TEXT,
  juiz_bruto           TEXT,
  veredito             TEXT NOT NULL
                         CHECK (veredito IN ('violacao','sem_violacao','inconclusivo','nao_aplicavel')),
  criado_em            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE revisao (                  -- append-only (RF17, RN-12, RN-13)
  id             SERIAL PRIMARY KEY,
  tentativa_id   INT  NOT NULL REFERENCES tentativa(id),
  veredito       TEXT NOT NULL CHECK (veredito IN ('violacao','sem_violacao')),
  comentario     TEXT,
  criado_em      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX revisao_tentativa ON revisao (tentativa_id, id);

-- RN-13: verificacao e revisao nunca recebem UPDATE nem DELETE
CREATE FUNCTION bloquear_alteracao() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'A tabela % é imutável (RN-13): % não permitido', TG_TABLE_NAME, TG_OP;
END $$;

CREATE TRIGGER verificacao_imutavel BEFORE UPDATE OR DELETE ON verificacao
  FOR EACH ROW EXECUTE FUNCTION bloquear_alteracao();
CREATE TRIGGER revisao_imutavel BEFORE UPDATE OR DELETE ON revisao
  FOR EACH ROW EXECUTE FUNCTION bloquear_alteracao();
CREATE TRIGGER verificacao_sem_truncate BEFORE TRUNCATE ON verificacao
  FOR EACH STATEMENT EXECUTE FUNCTION bloquear_alteracao();
CREATE TRIGGER revisao_sem_truncate BEFORE TRUNCATE ON revisao
  FOR EACH STATEMENT EXECUTE FUNCTION bloquear_alteracao();

-- ---------------------------------------------------------------------------
-- View de resultados (relatórios e CSV leem daqui)
-- ---------------------------------------------------------------------------

CREATE VIEW v_resultado AS
SELECT
  t.id                         AS tentativa_id,
  t.avaliacao_id,
  t.modelo,
  t.system_prompt_id,
  sp.rotulo                    AS system_prompt,
  sp.conteudo                  AS system_prompt_conteudo,
  t.configuracao_idx,
  t.configuracao,
  t.ataque_id,
  aa.snapshot->>'nome'         AS ataque,
  aa.snapshot->>'estrategia'   AS estrategia,
  aa.snapshot->>'tipo'         AS tipo,
  t.repeticao,
  t.status,
  t.erro,
  t.iniciado_em,
  t.finalizado_em,
  v.tfidf_score,
  v.tfidf_violacao,
  v.embedding_score,
  v.embedding_violacao,
  v.concordam,
  v.juiz_acionado,
  v.juiz_violacao,
  v.juiz_justificativa,
  v.veredito                   AS veredito_automatico,
  r.veredito                   AS veredito_humano,
  r.comentario                 AS revisao_comentario,
  r.criado_em                  AS revisado_em,
  COALESCE(r.veredito, v.veredito) AS veredito_final,
  -- classificação usada nos agregados: veredito final, ou o status quando não há veredito
  COALESCE(r.veredito, v.veredito, t.status) AS situacao
FROM tentativa t
JOIN avaliacao_system_prompt sp ON sp.id = t.system_prompt_id
JOIN avaliacao_ataque aa ON aa.avaliacao_id = t.avaliacao_id AND aa.ataque_id = t.ataque_id
LEFT JOIN verificacao v ON v.tentativa_id = t.id
LEFT JOIN LATERAL (
  SELECT veredito, comentario, criado_em FROM revisao
  WHERE tentativa_id = t.id ORDER BY id DESC LIMIT 1
) r ON true;

-- ---------------------------------------------------------------------------
-- Funções de acesso (chamadas pelos workflows do n8n)
-- ---------------------------------------------------------------------------

-- Ataques -------------------------------------------------------------------

CREATE FUNCTION api_listar_ataques(p_estrategia text) RETURNS jsonb
LANGUAGE sql STABLE AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'id', id, 'nome', nome, 'estrategia', estrategia, 'descricao', descricao,
           'mensagens', mensagens, 'tipo', tipo, 'origem', origem, 'criado_em', criado_em)
         ORDER BY estrategia, nome), '[]'::jsonb)
  FROM ataque
  WHERE p_estrategia IS NULL OR p_estrategia = '' OR estrategia = p_estrategia;
$$;

CREATE FUNCTION api_nomes_ataques() RETURNS jsonb
LANGUAGE sql STABLE AS $$
  SELECT COALESCE(jsonb_agg(nome), '[]'::jsonb) FROM ataque;
$$;

CREATE FUNCTION api_ids_ataques() RETURNS jsonb
LANGUAGE sql STABLE AS $$
  SELECT COALESCE(jsonb_agg(id ORDER BY id), '[]'::jsonb) FROM ataque;
$$;

-- p: array de ataques já validados
CREATE FUNCTION api_inserir_ataques(p jsonb) RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
  v_inseridos jsonb;
BEGIN
  WITH ins AS (
    INSERT INTO ataque (nome, estrategia, descricao, mensagens, origem)
    SELECT x->>'nome', x->>'estrategia', NULLIF(x->>'descricao', ''), x->'mensagens', 'personalizado'
    FROM jsonb_array_elements(p) x
    ON CONFLICT (nome) DO NOTHING
    RETURNING id, nome, estrategia, tipo
  )
  SELECT COALESCE(jsonb_agg(jsonb_build_object('id', id, 'nome', nome,
           'estrategia', estrategia, 'tipo', tipo) ORDER BY id), '[]'::jsonb)
  INTO v_inseridos FROM ins;
  RETURN jsonb_build_object('inseridos', v_inseridos);
END $$;

-- Avaliações ----------------------------------------------------------------

CREATE FUNCTION api_progresso(p_id int) RETURNS jsonb
LANGUAGE sql STABLE AS $$
  SELECT jsonb_build_object(
    'concluidas', COUNT(*) FILTER (WHERE t.status = 'concluida'),
    'falhas',     COUNT(*) FILTER (WHERE t.status = 'falha'),
    'pendentes',  a.n_planejado - COUNT(*) FILTER (WHERE t.status IN ('concluida','falha')))
  FROM avaliacao a LEFT JOIN tentativa t ON t.avaliacao_id = a.id
  WHERE a.id = p_id
  GROUP BY a.id, a.n_planejado;
$$;

-- p: corpo validado pelo workflow (inclui n_planejado calculado pela rotina única)
CREATE FUNCTION api_criar_avaliacao(p jsonb) RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
  v_id int;
BEGIN
  INSERT INTO avaliacao (nome, modelos, configuracoes, repeticoes, timeout_chamada_s,
                         limiar_tfidf, limiar_embedding, modelo_juiz, n_planejado)
  VALUES (p->>'nome', p->'modelos', p->'configuracoes', (p->>'repeticoes')::int,
          (p->>'timeout_chamada_s')::int, (p->>'limiar_tfidf')::numeric,
          (p->>'limiar_embedding')::numeric, p->>'modelo_juiz', (p->>'n_planejado')::int)
  RETURNING id INTO v_id;

  INSERT INTO avaliacao_system_prompt (avaliacao_id, rotulo, conteudo)
  SELECT v_id, sp->>'rotulo', sp->>'conteudo'
  FROM jsonb_array_elements(p->'system_prompts') WITH ORDINALITY AS x(sp, i)
  ORDER BY i;

  INSERT INTO avaliacao_ataque (avaliacao_id, ataque_id, ordem, snapshot)
  SELECT v_id, a.id, x.i,
         jsonb_build_object('id', a.id, 'nome', a.nome, 'estrategia', a.estrategia,
                            'descricao', a.descricao, 'mensagens', a.mensagens,
                            'tipo', a.tipo, 'origem', a.origem)
  FROM jsonb_array_elements_text(p->'ataques') WITH ORDINALITY AS x(ataque_id, i)
  JOIN ataque a ON a.id = x.ataque_id::int;

  RETURN jsonb_build_object('id', v_id);
END $$;

CREATE FUNCTION api_listar_avaliacoes() RETURNS jsonb
LANGUAGE sql STABLE AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'id', a.id, 'nome', a.nome, 'status', a.status, 'n_planejado', a.n_planejado,
           'criado_em', a.criado_em, 'iniciado_em', a.iniciado_em,
           'finalizado_em', a.finalizado_em) || api_progresso(a.id)
         ORDER BY a.id DESC), '[]'::jsonb)
  FROM avaliacao a;
$$;

-- Configuração completa e progresso; NULL se não existir
CREATE FUNCTION api_avaliacao(p_id int) RETURNS jsonb
LANGUAGE sql STABLE AS $$
  SELECT jsonb_build_object(
    'id', a.id, 'nome', a.nome, 'status', a.status,
    'modelos', a.modelos,
    'system_prompts', (SELECT COALESCE(jsonb_agg(jsonb_build_object(
                         'id', sp.id, 'rotulo', sp.rotulo, 'conteudo', sp.conteudo) ORDER BY sp.id), '[]')
                       FROM avaliacao_system_prompt sp WHERE sp.avaliacao_id = a.id),
    'configuracoes', a.configuracoes,
    'ataques', (SELECT COALESCE(jsonb_agg(aa.snapshot ORDER BY aa.ordem), '[]')
                FROM avaliacao_ataque aa WHERE aa.avaliacao_id = a.id),
    'repeticoes', a.repeticoes,
    'timeout_chamada_s', a.timeout_chamada_s,
    'limiar_tfidf', a.limiar_tfidf,
    'limiar_embedding', a.limiar_embedding,
    'modelo_juiz', a.modelo_juiz,
    'n_planejado', a.n_planejado,
    'criado_em', a.criado_em, 'iniciado_em', a.iniciado_em, 'finalizado_em', a.finalizado_em
  ) || api_progresso(a.id)
  FROM avaliacao a WHERE a.id = p_id;
$$;

-- Execução ------------------------------------------------------------------

-- Passa a avaliação para em_execucao e gera as N tentativas (se ainda não existirem).
-- resultado: ok | nao_encontrada | status_invalido | ocupado (RF11)
CREATE FUNCTION api_iniciar_execucao(p_id int) RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
  v_status text;
  v_outra  int;
BEGIN
  SELECT status INTO v_status FROM avaliacao WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('resultado', 'nao_encontrada');
  END IF;
  IF v_status <> 'configurada' THEN
    RETURN jsonb_build_object('resultado', 'status_invalido', 'status', v_status);
  END IF;

  BEGIN
    UPDATE avaliacao SET status = 'em_execucao', iniciado_em = COALESCE(iniciado_em, now())
    WHERE id = p_id AND status = 'configurada';
  EXCEPTION WHEN unique_violation THEN
    SELECT id INTO v_outra FROM avaliacao WHERE status = 'em_execucao' LIMIT 1;
    RETURN jsonb_build_object('resultado', 'ocupado', 'em_execucao', v_outra);
  END;

  -- Combinações na ordem modelo → system prompt → configuração → ataque → repetição
  -- (minimiza troca de modelos carregados no Ollama, RNF02). Seed efetiva:
  -- seed + (repeticao − 1), gravada em tentativa.configuracao.
  IF NOT EXISTS (SELECT 1 FROM tentativa WHERE avaliacao_id = p_id) THEN
    INSERT INTO tentativa (avaliacao_id, modelo, system_prompt_id, configuracao_idx,
                           configuracao, ataque_id, repeticao)
    SELECT a.id, m.modelo, sp.id, c.idx,
           CASE WHEN c.conf ? 'seed' AND jsonb_typeof(c.conf->'seed') = 'number'
                THEN jsonb_set(c.conf, '{seed}', to_jsonb((c.conf->>'seed')::bigint + r.rep - 1))
                ELSE c.conf END,
           aa.ataque_id, r.rep
    FROM avaliacao a
    CROSS JOIN LATERAL jsonb_array_elements_text(a.modelos) WITH ORDINALITY AS m(modelo, mi)
    JOIN avaliacao_system_prompt sp ON sp.avaliacao_id = a.id
    CROSS JOIN LATERAL jsonb_array_elements(a.configuracoes) WITH ORDINALITY AS c0(conf, ci)
    CROSS JOIN LATERAL (SELECT (c0.ci - 1)::int AS idx, c0.conf) c
    JOIN avaliacao_ataque aa ON aa.avaliacao_id = a.id
    CROSS JOIN LATERAL generate_series(1, a.repeticoes) AS r(rep)
    WHERE a.id = p_id
    ORDER BY m.mi, sp.id, c.idx, aa.ordem, r.rep;
  END IF;

  RETURN jsonb_build_object('resultado', 'ok');
END $$;

-- Próxima tentativa pendente (ou tentativa_id nulo quando acabou).
-- Uma tentativa pendente já iniciada significa que a execução anterior foi
-- interrompida: ela é registrada como falha e o loop segue (RF12).
CREATE FUNCTION api_proxima_tentativa(p_avaliacao int) RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
  v_id int;
BEGIN
  UPDATE tentativa SET status = 'falha', finalizado_em = now(),
         erro = COALESCE(erro, 'Execução da tentativa interrompida antes da conclusão')
  WHERE avaliacao_id = p_avaliacao AND status = 'pendente' AND iniciado_em IS NOT NULL;

  SELECT id INTO v_id FROM tentativa
  WHERE avaliacao_id = p_avaliacao AND status = 'pendente'
  ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED;

  IF v_id IS NOT NULL THEN
    UPDATE tentativa SET iniciado_em = now() WHERE id = v_id;
  END IF;
  RETURN jsonb_build_object('tentativa_id', v_id);
END $$;

-- Próximo passo de uma tentativa. O contexto da conversa (RF06) é reconstruído
-- a partir do snapshot do ataque e das respostas já gravadas em turno.
-- acao: turno | verificar | fim
CREATE FUNCTION api_proximo_passo(p_tentativa int) RETURNS jsonb
LANGUAGE plpgsql STABLE AS $$
DECLARE
  t         record;
  v_msgs    jsonb := '[]'::jsonb;
  v_resps   jsonb := '[]'::jsonb;
  v_total   int;
  v_feitos  int := 0;
  tu        record;
BEGIN
  SELECT tt.*, sp.conteudo AS sp_conteudo, aa.snapshot->'mensagens' AS mensagens,
         av.timeout_chamada_s, av.limiar_tfidf, av.limiar_embedding, av.modelo_juiz
  INTO t
  FROM tentativa tt
  JOIN avaliacao av ON av.id = tt.avaliacao_id
  JOIN avaliacao_system_prompt sp ON sp.id = tt.system_prompt_id
  JOIN avaliacao_ataque aa ON aa.avaliacao_id = tt.avaliacao_id AND aa.ataque_id = tt.ataque_id
  WHERE tt.id = p_tentativa;

  IF NOT FOUND OR t.status <> 'pendente' THEN
    RETURN jsonb_build_object('acao', 'fim', 'tentativa_id', p_tentativa);
  END IF;

  IF t.sp_conteudo IS NOT NULL THEN
    v_msgs := jsonb_build_array(jsonb_build_object('role', 'system', 'content', t.sp_conteudo));
  END IF;

  FOR tu IN SELECT ordem, resposta FROM turno WHERE tentativa_id = p_tentativa ORDER BY ordem LOOP
    v_msgs := v_msgs
      || jsonb_build_object('role', 'user', 'content', t.mensagens->>(tu.ordem - 1))
      || jsonb_build_object('role', 'assistant', 'content', COALESCE(tu.resposta, ''));
    v_resps := v_resps || to_jsonb(COALESCE(tu.resposta, ''));
    v_feitos := tu.ordem;
  END LOOP;

  v_total := jsonb_array_length(t.mensagens);

  IF v_feitos < v_total THEN
    v_msgs := v_msgs || jsonb_build_object('role', 'user', 'content', t.mensagens->>v_feitos);
    RETURN jsonb_build_object(
      'acao', 'turno',
      'tentativa_id', p_tentativa,
      'ordem', v_feitos + 1,
      'timeout_ms', t.timeout_chamada_s * 1000,
      'requisicao', jsonb_build_object(
        'model', t.modelo, 'messages', v_msgs, 'stream', false,
        'options', t.configuracao, 'keep_alive', '10m'));
  END IF;

  RETURN jsonb_build_object(
    'acao', 'verificar',
    'tentativa_id', p_tentativa,
    -- verificador: juiz pode levar até timeout_chamada_s; margem para TF-IDF/embeddings
    'timeout_ms', (t.timeout_chamada_s + 60) * 1000,
    'requisicao', jsonb_build_object(
      'system_prompt', t.sp_conteudo,
      'respostas', v_resps,
      'limiar_tfidf', t.limiar_tfidf,
      'limiar_embedding', t.limiar_embedding,
      'juiz', jsonb_build_object('modelo', t.modelo_juiz, 'timeout_s', t.timeout_chamada_s)));
END $$;

-- p: {tentativa_id, ordem, entrada, resposta, metadados}
CREATE FUNCTION api_registrar_turno(p jsonb) RETURNS jsonb
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO turno (tentativa_id, ordem, entrada, resposta, metadados)
  VALUES ((p->>'tentativa_id')::int, (p->>'ordem')::int, p->'entrada', p->>'resposta', p->'metadados');
  RETURN jsonb_build_object('ok', true);
END $$;

-- p: {tentativa_id, erro}. Falha não interrompe a avaliação (RF12, RF23).
CREATE FUNCTION api_registrar_falha(p jsonb) RETURNS jsonb
LANGUAGE plpgsql AS $$
BEGIN
  UPDATE tentativa SET status = 'falha', erro = left(p->>'erro', 4000), finalizado_em = now()
  WHERE id = (p->>'tentativa_id')::int AND status = 'pendente';
  RETURN jsonb_build_object('ok', true);
END $$;

-- p: {tentativa_id, resultado: <resposta do verificador §7.1>}
CREATE FUNCTION api_registrar_verificacao(p jsonb) RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
  r jsonb := p->'resultado';
  v_id int := (p->>'tentativa_id')::int;
BEGIN
  INSERT INTO verificacao (tentativa_id, tfidf_score, tfidf_violacao, embedding_score,
                           embedding_violacao, concordam, juiz_acionado, juiz_violacao,
                           juiz_justificativa, juiz_bruto, veredito)
  VALUES (v_id,
          (r->'tfidf'->>'score')::numeric, (r->'tfidf'->>'violacao')::boolean,
          (r->'embedding'->>'score')::numeric, (r->'embedding'->>'violacao')::boolean,
          (r->>'concordam')::boolean,
          COALESCE((r->'juiz'->>'acionado')::boolean, false),
          (r->'juiz'->>'violacao')::boolean,
          COALESCE(r->'juiz'->>'justificativa', r->'juiz'->>'erro'),
          r->'juiz'->>'bruto',
          r->>'veredito');
  UPDATE tentativa SET status = 'concluida', finalizado_em = now()
  WHERE id = v_id AND status = 'pendente';
  RETURN jsonb_build_object('ok', true);
END $$;

CREATE FUNCTION api_finalizar_avaliacao(p_id int) RETURNS jsonb
LANGUAGE plpgsql AS $$
BEGIN
  UPDATE avaliacao SET status = 'finalizada', finalizado_em = now()
  WHERE id = p_id AND status = 'em_execucao';
  RETURN api_avaliacao(p_id);
END $$;

-- Resultados ----------------------------------------------------------------

-- Resumo (RF21, RF22): agregados por modelo × system prompt × estratégia e por ataque.
-- taxa_violacao = violações / (violações + sem violação), sobre o veredito final.
CREATE FUNCTION api_resumo(p_id int) RETURNS jsonb
LANGUAGE sql STABLE AS $$
  WITH r AS (SELECT * FROM v_resultado WHERE avaliacao_id = p_id),
  agg AS (
    SELECT modelo, system_prompt, estrategia, ataque, tipo,
           COUNT(*)                                          AS tentativas,
           COUNT(*) FILTER (WHERE situacao = 'violacao')      AS violacoes,
           COUNT(*) FILTER (WHERE situacao = 'sem_violacao')  AS sem_violacao,
           COUNT(*) FILTER (WHERE situacao = 'inconclusivo')  AS inconclusivas,
           COUNT(*) FILTER (WHERE situacao = 'nao_aplicavel') AS nao_aplicaveis,
           COUNT(*) FILTER (WHERE situacao = 'falha')         AS falhas,
           COUNT(*) FILTER (WHERE situacao = 'pendente')      AS pendentes,
           COUNT(*) FILTER (WHERE veredito_humano IS NOT NULL) AS revisadas
    FROM r GROUP BY GROUPING SETS ((modelo, system_prompt, estrategia), (ataque, estrategia, tipo), (modelo), ())
  ),
  j AS (
    SELECT *, jsonb_build_object(
      'tentativas', tentativas, 'violacoes', violacoes, 'sem_violacao', sem_violacao,
      'inconclusivas', inconclusivas, 'nao_aplicaveis', nao_aplicaveis, 'falhas', falhas,
      'pendentes', pendentes, 'revisadas', revisadas,
      'taxa_violacao', CASE WHEN violacoes + sem_violacao > 0
                            THEN round(violacoes::numeric / (violacoes + sem_violacao), 4) END) AS c
    FROM agg
  )
  SELECT CASE WHEN NOT EXISTS (SELECT 1 FROM avaliacao WHERE id = p_id) THEN NULL ELSE
    jsonb_build_object(
      'avaliacao', (SELECT jsonb_build_object('id', id, 'nome', nome, 'status', status,
                     'n_planejado', n_planejado) || api_progresso(id) FROM avaliacao WHERE id = p_id),
      'total', COALESCE((SELECT c FROM j WHERE modelo IS NULL AND ataque IS NULL AND system_prompt IS NULL AND estrategia IS NULL), '{}'::jsonb),
      'por_modelo', COALESCE((SELECT jsonb_agg(jsonb_build_object('modelo', modelo) || c ORDER BY modelo)
                     FROM j WHERE modelo IS NOT NULL AND system_prompt IS NULL AND estrategia IS NULL AND ataque IS NULL), '[]'),
      'grupos', COALESCE((SELECT jsonb_agg(jsonb_build_object('modelo', modelo, 'system_prompt', system_prompt,
                     'estrategia', estrategia) || c ORDER BY modelo, system_prompt, estrategia)
                     FROM j WHERE modelo IS NOT NULL AND estrategia IS NOT NULL), '[]'),
      'por_ataque', COALESCE((SELECT jsonb_agg(jsonb_build_object('ataque', ataque, 'estrategia', estrategia,
                     'tipo', tipo) || c ORDER BY estrategia, ataque)
                     FROM j WHERE ataque IS NOT NULL), '[]'))
  END;
$$;

-- Lista paginada (RF16, RF19). p_veredito filtra pelo veredito final ou pelo
-- status (falha, pendente). Página começa em 1.
CREATE FUNCTION api_tentativas(p_id int, p_veredito text, p_pagina int, p_por_pagina int DEFAULT 50)
RETURNS jsonb
LANGUAGE sql STABLE AS $$
  WITH r AS (
    SELECT * FROM v_resultado
    WHERE avaliacao_id = p_id
      AND (p_veredito IS NULL OR p_veredito = '' OR situacao = p_veredito)
  )
  SELECT CASE WHEN NOT EXISTS (SELECT 1 FROM avaliacao WHERE id = p_id) THEN NULL ELSE
    jsonb_build_object(
      'pagina', p_pagina, 'por_pagina', p_por_pagina,
      'total', (SELECT COUNT(*) FROM r),
      'itens', COALESCE((SELECT jsonb_agg(jsonb_build_object(
          'tentativa_id', tentativa_id, 'modelo', modelo, 'system_prompt', system_prompt,
          'configuracao_idx', configuracao_idx, 'configuracao', configuracao,
          'ataque', ataque, 'estrategia', estrategia, 'tipo', tipo, 'repeticao', repeticao,
          'status', status, 'erro', erro,
          'tfidf_score', tfidf_score, 'embedding_score', embedding_score,
          'juiz_acionado', juiz_acionado,
          'veredito_automatico', veredito_automatico, 'veredito_humano', veredito_humano,
          'veredito_final', veredito_final) ORDER BY tentativa_id)
        FROM (SELECT * FROM r ORDER BY tentativa_id
              OFFSET (GREATEST(p_pagina, 1) - 1) * p_por_pagina LIMIT p_por_pagina) pg), '[]'))
  END;
$$;

-- Linhas do CSV (RF20); a serialização em CSV é feita no workflow
CREATE FUNCTION api_linhas_csv(p_id int) RETURNS jsonb
LANGUAGE sql STABLE AS $$
  SELECT CASE WHEN NOT EXISTS (SELECT 1 FROM avaliacao WHERE id = p_id) THEN NULL ELSE
    COALESCE(jsonb_agg(jsonb_build_object(
      'avaliacao_id', r.avaliacao_id, 'tentativa_id', r.tentativa_id, 'modelo', r.modelo,
      'system_prompt', r.system_prompt, 'configuracao', r.configuracao, 'ataque', r.ataque,
      'estrategia', r.estrategia, 'tipo', r.tipo, 'repeticao', r.repeticao,
      'status', r.status, 'erro', r.erro,
      'entradas', (SELECT COALESCE(jsonb_agg(tu.entrada->-1->'content' ORDER BY tu.ordem), '[]')
                   FROM turno tu WHERE tu.tentativa_id = r.tentativa_id),
      'respostas', (SELECT COALESCE(jsonb_agg(to_jsonb(tu.resposta) ORDER BY tu.ordem), '[]')
                    FROM turno tu WHERE tu.tentativa_id = r.tentativa_id),
      'tfidf_score', r.tfidf_score, 'tfidf_violacao', r.tfidf_violacao,
      'embedding_score', r.embedding_score, 'embedding_violacao', r.embedding_violacao,
      'concordam', r.concordam, 'juiz_acionado', r.juiz_acionado,
      'juiz_violacao', r.juiz_violacao, 'juiz_justificativa', r.juiz_justificativa,
      'veredito_automatico', r.veredito_automatico, 'veredito_humano', r.veredito_humano,
      'veredito_final', r.veredito_final,
      'iniciado_em', r.iniciado_em, 'finalizado_em', r.finalizado_em) ORDER BY r.tentativa_id), '[]')
  END
  FROM v_resultado r WHERE r.avaliacao_id = p_id;
$$;

-- Detalhe de uma tentativa (RF16, RF17); NULL se não existir
CREATE FUNCTION api_tentativa(p_id int) RETURNS jsonb
LANGUAGE sql STABLE AS $$
  SELECT jsonb_build_object(
    'tentativa_id', r.tentativa_id, 'avaliacao_id', r.avaliacao_id, 'modelo', r.modelo,
    'system_prompt', jsonb_build_object('id', r.system_prompt_id, 'rotulo', r.system_prompt,
                                        'conteudo', r.system_prompt_conteudo),
    'configuracao_idx', r.configuracao_idx, 'configuracao', r.configuracao,
    'ataque', (SELECT snapshot FROM avaliacao_ataque aa
               WHERE aa.avaliacao_id = r.avaliacao_id AND aa.ataque_id = r.ataque_id),
    'repeticao', r.repeticao, 'status', r.status, 'erro', r.erro,
    'iniciado_em', r.iniciado_em, 'finalizado_em', r.finalizado_em,
    'turnos', (SELECT COALESCE(jsonb_agg(jsonb_build_object(
                 'ordem', tu.ordem, 'entrada', tu.entrada, 'resposta', tu.resposta,
                 'metadados', tu.metadados, 'criado_em', tu.criado_em) ORDER BY tu.ordem), '[]')
               FROM turno tu WHERE tu.tentativa_id = r.tentativa_id),
    'verificacao', (SELECT to_jsonb(v) - 'tentativa_id' FROM verificacao v WHERE v.tentativa_id = r.tentativa_id),
    'revisoes', (SELECT COALESCE(jsonb_agg(jsonb_build_object(
                   'id', rv.id, 'veredito', rv.veredito, 'comentario', rv.comentario,
                   'criado_em', rv.criado_em) ORDER BY rv.id DESC), '[]')
                 FROM revisao rv WHERE rv.tentativa_id = r.tentativa_id),
    'veredito_automatico', r.veredito_automatico,
    'veredito_humano', r.veredito_humano,
    'veredito_final', r.veredito_final)
  FROM v_resultado r WHERE r.tentativa_id = p_id;
$$;

-- Revisão humana: sempre INSERT (RF17, RN-13). NULL se a tentativa não existir.
CREATE FUNCTION api_registrar_revisao(p jsonb) RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
  v_rev revisao;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM tentativa WHERE id = (p->>'tentativa_id')::int) THEN
    RETURN NULL;
  END IF;
  INSERT INTO revisao (tentativa_id, veredito, comentario)
  VALUES ((p->>'tentativa_id')::int, p->>'veredito', NULLIF(p->>'comentario', ''))
  RETURNING * INTO v_rev;
  RETURN to_jsonb(v_rev);
END $$;

-- Permissões do usuário da aplicação: 04-permissoes.sh
