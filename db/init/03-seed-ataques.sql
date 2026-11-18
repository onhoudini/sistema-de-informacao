-- Carrega a coleção predefinida de ataques (spec §4, RF04, RN-01).
-- O arquivo ataques/predefinidos.json é montado em /ataques no contêiner do Postgres.

\connect plataforma

INSERT INTO ataque (nome, estrategia, descricao, mensagens, origem)
SELECT x->>'nome', x->>'estrategia', x->>'descricao', x->'mensagens', 'predefinido'
FROM jsonb_array_elements(pg_read_file('/ataques/predefinidos.json')::jsonb) AS x
ON CONFLICT (nome) DO NOTHING;
