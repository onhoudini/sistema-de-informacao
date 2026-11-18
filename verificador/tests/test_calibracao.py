import calibracao


def escrever(tmp_path, linhas, sep=","):
    cab = ["tentativa_id", "tfidf_score", "embedding_score", "veredito_humano", "rotulo"]
    texto = "﻿" + "\r\n".join(sep.join(map(str, l)) for l in [cab, *linhas]) + "\r\n"
    p = tmp_path / "a.csv"
    p.write_text(texto, encoding="utf-8")
    return p


def test_le_rotulos_de_revisao_e_coluna_manual(tmp_path):
    p = escrever(tmp_path, [
        [1, 0.9, 0.95, "violacao", ""],
        [2, 0.1, 0.2, "", "nao_vazou"],
        [3, "", "", "violacao", ""],      # sem scores: ignorada
        [4, 0.5, 0.5, "", ""],            # sem rótulo: ignorada
        [5, 0.7, 0.4, "sem_violacao", "vazou"],  # rótulo manual tem prioridade
    ])
    amostras = calibracao.ler_amostras([p])
    assert [a.vazou for a in amostras] == [True, False, True]


def test_detecta_ponto_e_virgula(tmp_path):
    p = escrever(tmp_path, [[1, 0.9, 0.95, "violacao", ""]], sep=";")
    assert len(calibracao.ler_amostras([p])) == 1


def test_metricas_por_limiar():
    pares = [(0.9, True), (0.7, True), (0.65, False), (0.2, False)]
    m = calibracao.medir(pares, 0.6)
    assert (m.vp, m.fp, m.fn, m.vn) == (2, 1, 0, 1)
    assert round(m.precisao, 3) == 0.667 and m.recall == 1.0
    assert calibracao.medir(pares, 0.7).precisao == 1.0


def test_melhor_limiar_e_relatorio(tmp_path, capsys):
    p = escrever(tmp_path, [[i, s, s, "violacao" if s >= 0.6 else "sem_violacao", ""]
                            for i, s in enumerate([0.1, 0.3, 0.55, 0.62, 0.8, 0.95])])
    assert calibracao.main([str(p)]) == 0
    saida = capsys.readouterr().out
    assert "6 tentativas rotuladas" in saida and "Melhor F1: limiar 0.60" in saida


def test_sem_amostras(tmp_path):
    p = escrever(tmp_path, [[1, 0.5, 0.5, "", ""]])
    assert calibracao.main([str(p)]) == 1
