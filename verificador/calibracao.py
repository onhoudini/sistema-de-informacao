"""Calibração dos limiares de TF-IDF e embeddings (spec §11, fase F8).

Lê um ou mais CSVs exportados pela plataforma (GET /avaliacoes/:id/csv) e mede
precisão, recall e F1 de cada método para limiares de 0,05 a 1,00.

Rótulo de cada tentativa ("vazou" ou não), em ordem de prioridade:
  1. coluna `rotulo` acrescentada à mão (violacao/sem_violacao, sim/não, 1/0, vazou/nao_vazou);
  2. coluna `veredito_humano` (revisões feitas na CLI ou na Interface Web).
Tentativas sem rótulo ou sem scores (falhas, sem system prompt) são ignoradas.

Uso (só biblioteca padrão; roda no host ou no contêiner):
  python verificador/calibracao.py saida/avaliacao-3.csv [saida/avaliacao-4.csv ...]
"""

from __future__ import annotations

import argparse
import csv
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Optional

POSITIVOS = {"violacao", "sim", "1", "true", "vazou", "s"}
NEGATIVOS = {"sem_violacao", "nao", "não", "0", "false", "nao_vazou", "não_vazou", "n"}


@dataclass
class Amostra:
    tfidf: float
    embedding: float
    vazou: bool


@dataclass
class Metricas:
    limiar: float
    precisao: Optional[float]
    recall: Optional[float]
    f1: Optional[float]
    vp: int
    fp: int
    fn: int
    vn: int


def rotulo(linha: dict) -> Optional[bool]:
    for coluna in ("rotulo", "veredito_humano"):
        valor = (linha.get(coluna) or "").strip().lower()
        if valor in POSITIVOS:
            return True
        if valor in NEGATIVOS:
            return False
    return None


def ler_amostras(caminhos: Iterable[Path]) -> list[Amostra]:
    amostras: list[Amostra] = []
    for caminho in caminhos:
        with caminho.open(encoding="utf-8-sig", newline="") as f:
            amostra = f.read(4096)
            f.seek(0)
            separador = ";" if amostra.count(";") > amostra.count(",") else ","
            for linha in csv.DictReader(f, delimiter=separador):
                r = rotulo(linha)
                try:
                    tfidf = float(linha["tfidf_score"])
                    emb = float(linha["embedding_score"])
                except (KeyError, TypeError, ValueError):
                    continue
                if r is not None:
                    amostras.append(Amostra(tfidf, emb, r))
    return amostras


def medir(scores_rotulos: list[tuple[float, bool]], limiar: float) -> Metricas:
    vp = sum(1 for s, r in scores_rotulos if s >= limiar and r)
    fp = sum(1 for s, r in scores_rotulos if s >= limiar and not r)
    fn = sum(1 for s, r in scores_rotulos if s < limiar and r)
    vn = sum(1 for s, r in scores_rotulos if s < limiar and not r)
    precisao = vp / (vp + fp) if vp + fp else None
    recall = vp / (vp + fn) if vp + fn else None
    f1 = (2 * precisao * recall / (precisao + recall)) if precisao and recall else (0.0 if vp + fp and vp + fn else None)
    return Metricas(limiar, precisao, recall, f1, vp, fp, fn, vn)


def limiares() -> list[float]:
    return [round(0.05 * i, 2) for i in range(1, 21)]


def curva(amostras: list[Amostra], metodo: str) -> list[Metricas]:
    pares = [(getattr(a, metodo), a.vazou) for a in amostras]
    return [medir(pares, l) for l in limiares()]


def melhor(metricas: list[Metricas]) -> Optional[Metricas]:
    validas = [m for m in metricas if m.f1 is not None]
    return max(validas, key=lambda m: (m.f1, m.precisao or 0, m.limiar)) if validas else None


def _fmt(v: Optional[float]) -> str:
    return "  -  " if v is None else f"{v:.3f}"


def relatorio(amostras: list[Amostra]) -> str:
    positivos = sum(a.vazou for a in amostras)
    linhas = [f"{len(amostras)} tentativas rotuladas ({positivos} vazaram, {len(amostras) - positivos} não vazaram)."]
    for metodo, nome in (("tfidf", "TF-IDF"), ("embedding", "Embeddings")):
        c = curva(amostras, metodo)
        linhas += ["", f"== {nome} ==", "limiar  precisão  recall  F1     VP  FP  FN  VN"]
        for m in c:
            linhas.append(f"{m.limiar:5.2f}   {_fmt(m.precisao)}     {_fmt(m.recall)}   {_fmt(m.f1)}  "
                          f"{m.vp:3d} {m.fp:3d} {m.fn:3d} {m.vn:3d}")
        b = melhor(c)
        if b:
            linhas.append(f"Melhor F1: limiar {b.limiar:.2f} (precisão {_fmt(b.precisao)}, recall {_fmt(b.recall)}, F1 {_fmt(b.f1)})")
    return "\n".join(linhas)


def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Mede precisão e recall por limiar a partir de CSVs rotulados.")
    parser.add_argument("csv", nargs="+", type=Path, help="CSV(s) exportado(s) pela plataforma")
    args = parser.parse_args(argv)
    faltando = [str(c) for c in args.csv if not c.exists()]
    if faltando:
        print(f"Arquivo não encontrado: {', '.join(faltando)}", file=sys.stderr)
        return 2
    amostras = ler_amostras(args.csv)
    if not amostras:
        print("Nenhuma tentativa rotulada com scores. Revise tentativas (veredito_humano) ou acrescente a coluna 'rotulo'.",
              file=sys.stderr)
        return 1
    print(relatorio(amostras))
    return 0


if __name__ == "__main__":
    sys.exit(main())
