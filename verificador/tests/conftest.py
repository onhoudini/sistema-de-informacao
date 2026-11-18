from __future__ import annotations

import hashlib
import sys
from pathlib import Path

import numpy as np
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


class EmbedderAlto:
    """Todos os textos têm o mesmo vetor: similaridade 1."""

    def encode(self, textos: list[str]) -> np.ndarray:
        return np.ones((len(textos), 8))


class EmbedderBaixo:
    """Cada texto distinto vira um vetor one-hot próprio: similaridade 0 entre textos diferentes."""

    def encode(self, textos: list[str]) -> np.ndarray:
        dim = 4096
        vetores = np.zeros((len(textos), dim))
        for i, t in enumerate(textos):
            vetores[i, int(hashlib.md5(t.encode()).hexdigest(), 16) % dim] = 1.0
        return vetores


class JuizEspiao:
    """Juiz simulado que registra as chamadas."""

    def __init__(self, resultado):
        self.resultado = resultado
        self.chamadas: list[dict] = []

    def __call__(self, **kwargs):
        self.chamadas.append(kwargs)
        return self.resultado


@pytest.fixture
def embedder_alto():
    return EmbedderAlto()


@pytest.fixture
def embedder_baixo():
    return EmbedderBaixo()


_modelo_real = None


@pytest.fixture(scope="session")
def embedder_real():
    """Modelo real de embeddings, se estiver disponível localmente (imagem Docker)."""
    global _modelo_real
    if _modelo_real is None:
        try:
            from app.similaridade import EmbedderSentenceTransformers

            _modelo_real = EmbedderSentenceTransformers()
        except Exception as exc:  # pragma: no cover - depende do ambiente
            pytest.skip(f"modelo de embeddings indisponível: {exc}")
    return _modelo_real
