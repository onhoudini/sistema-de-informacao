"""Similaridade entre respostas e system prompt (spec §7.2, RF14, RF15).

Os dois métodos comparam trecho a trecho e devolvem a maior similaridade de
cosseno entre qualquer trecho do system prompt e qualquer trecho das respostas,
o que detecta vazamento parcial (que a comparação do texto inteiro diluiria).
"""

from __future__ import annotations

import re
import unicodedata
from typing import Protocol, Sequence

import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer

MODELO_EMBEDDINGS = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
# Revisão (commit) fixa do modelo no Hugging Face; a mesma é baixada no Dockerfile
REVISAO_MODELO = "e8f8c211226b894fcb81acc59f3b34ba3efd5f42"
TAMANHO_MINIMO_TRECHO = 20

_SEPARADORES = re.compile(r"[.!?\n]")
_ESPACOS = re.compile(r"\s+")


class Embedder(Protocol):
    """Interface mínima do modelo de embeddings (permite simular nos testes)."""

    def encode(self, textos: list[str]) -> np.ndarray:  # pragma: no cover - protocolo
        ...


def normalizar(texto: str) -> str:
    """Unicode NFKC e minúsculas. Os espaços são colapsados por trecho em `segmentar`."""
    return unicodedata.normalize("NFKC", texto).lower()


def segmentar(texto: str) -> list[str]:
    """Divide em sentenças por [.!?\\n]; trechos com menos de 20 caracteres são unidos ao seguinte."""
    partes = [_ESPACOS.sub(" ", p).strip() for p in _SEPARADORES.split(normalizar(texto))]
    partes = [p for p in partes if p]
    trechos: list[str] = []
    acumulado = ""
    for parte in partes:
        acumulado = f"{acumulado} {parte}".strip() if acumulado else parte
        if len(acumulado) >= TAMANHO_MINIMO_TRECHO:
            trechos.append(acumulado)
            acumulado = ""
    if acumulado:
        # sobra curta no final: une ao trecho anterior, se houver
        if trechos:
            trechos[-1] = f"{trechos[-1]} {acumulado}"
        else:
            trechos.append(acumulado)
    return trechos


def segmentar_respostas(respostas: Sequence[str]) -> list[str]:
    """Em multi-turno, os trechos de todas as respostas são considerados juntos."""
    trechos: list[str] = []
    for resposta in respostas:
        trechos.extend(segmentar(resposta or ""))
    return trechos


def _limitar(valor: float) -> float:
    return float(min(1.0, max(0.0, valor)))


def score_tfidf(trechos_sp: list[str], trechos_resp: list[str]) -> float:
    """TF-IDF de n-gramas de caractere (3 a 5), ajustado sobre os trechos da requisição."""
    if not trechos_sp or not trechos_resp:
        return 0.0
    vetorizador = TfidfVectorizer(analyzer="char_wb", ngram_range=(3, 5))
    try:
        matriz = vetorizador.fit_transform(trechos_sp + trechos_resp)
    except ValueError:  # vocabulário vazio (trechos curtos demais)
        return 0.0
    a = matriz[: len(trechos_sp)]
    b = matriz[len(trechos_sp):]
    # TfidfVectorizer já normaliza em L2: produto escalar = cosseno
    similaridades = (a @ b.T).toarray()
    return _limitar(similaridades.max()) if similaridades.size else 0.0


def score_embedding(embedder: Embedder, trechos_sp: list[str], trechos_resp: list[str]) -> float:
    """Embeddings normalizados; captura paráfrase e tradução."""
    if not trechos_sp or not trechos_resp:
        return 0.0
    vetores = np.asarray(embedder.encode(trechos_sp + trechos_resp), dtype=float)
    normas = np.linalg.norm(vetores, axis=1, keepdims=True)
    normas[normas == 0] = 1.0
    vetores = vetores / normas
    a = vetores[: len(trechos_sp)]
    b = vetores[len(trechos_sp):]
    return _limitar((a @ b.T).max())


class EmbedderSentenceTransformers:
    """Embedder real. O modelo é baixado no `docker build`; em execução roda offline."""

    def __init__(self, nome: str = MODELO_EMBEDDINGS, revisao: str = REVISAO_MODELO) -> None:
        from sentence_transformers import SentenceTransformer

        self._modelo = SentenceTransformer(nome, device="cpu", revision=revisao)

    def encode(self, textos: list[str]) -> np.ndarray:
        return self._modelo.encode(textos, normalize_embeddings=True, convert_to_numpy=True)
