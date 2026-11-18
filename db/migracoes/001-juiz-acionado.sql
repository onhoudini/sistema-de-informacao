-- Migração 001: marcador "decidida pelo juiz".
-- api_tentativas ganha o filtro p_juiz e devolve juiz_violacao;
-- api_resumo passa a contar decididas_juiz.
-- Só substitui funções: não altera dados (RN-13). Pode ser aplicada mais de uma vez.
-- Aplicar num banco existente:
--   Get-Content db/migracoes/001-juiz-acionado.sql | docker compose exec -T postgres psql -U postgres -d plataforma

\connect plataforma

BEGIN;

DROP FUNCTION IF EXISTS api_tentativas(int, text, int, int);
DROP FUNCTION IF EXISTS api_tentativas(int, text, int, boolean, int);

-- Lista paginada (RF16, RF19). p_veredito filtra pelo veredito final ou pelo
-- status (falha, pendente); p_juiz = true traz só as tentativas em que o LLM
-- juiz foi acionado. Página começa em 1.
CREATE FUNCTION api_tentativas(p_id int, p_veredito text, p_pagina int,
                               p_juiz boolean DEFAULT NULL, p_por_pagina int DEFAULT 50)
RETURNS jsonb
LANGUAGE sql STABLE AS $$
  WITH r AS (
    SELECT * FROM v_resultado
    WHERE avaliacao_id = p_id
      AND (p_veredito IS NULL OR p_veredito = '' OR situacao = p_veredito)
      AND (p_juiz IS NULL OR COALESCE(juiz_acionado, false) = p_juiz)
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
          'juiz_acionado', juiz_acionado, 'juiz_violacao', juiz_violacao,
          'veredito_automatico', veredito_automatico, 'veredito_humano', veredito_humano,
          'veredito_final', veredito_final) ORDER BY tentativa_id)
        FROM (SELECT * FROM r ORDER BY tentativa_id
              OFFSET (GREATEST(p_pagina, 1) - 1) * p_por_pagina LIMIT p_por_pagina) pg), '[]'))
  END;
$$;

-- Resumo (RF21, RF22): agregados por modelo × system prompt × estratégia e por ataque.
-- taxa_violacao = violações / (violações + sem violação), sobre o veredito final.
-- decididas_juiz = métodos discordaram e o LLM juiz foi acionado (marcador, não veredito).
CREATE OR REPLACE FUNCTION api_resumo(p_id int) RETURNS jsonb
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
           COUNT(*) FILTER (WHERE veredito_humano IS NOT NULL) AS revisadas,
           COUNT(*) FILTER (WHERE juiz_acionado)              AS decididas_juiz
    FROM r GROUP BY GROUPING SETS ((modelo, system_prompt, estrategia), (ataque, estrategia, tipo), (modelo), ())
  ),
  j AS (
    SELECT *, jsonb_build_object(
      'tentativas', tentativas, 'violacoes', violacoes, 'sem_violacao', sem_violacao,
      'inconclusivas', inconclusivas, 'nao_aplicaveis', nao_aplicaveis, 'falhas', falhas,
      'pendentes', pendentes, 'revisadas', revisadas, 'decididas_juiz', decididas_juiz,
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

DO $$
DECLARE app text := COALESCE(NULLIF(current_setting('plataforma.app_user', true), ''), 'plataforma_app');
BEGIN
  EXECUTE format('GRANT EXECUTE ON FUNCTION api_tentativas(int, text, int, boolean, int) TO %I', app);
  EXECUTE format('GRANT EXECUTE ON FUNCTION api_resumo(int) TO %I', app);
END $$;

COMMIT;
