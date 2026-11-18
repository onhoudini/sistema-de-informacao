"""Serviço de Verificação (spec §7). Sem estado: não acessa o banco."""

from __future__ import annotations

import os
from contextlib import asynccontextmanager
from typing import Callable, Literal, Optional

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from .juiz import ResultadoJuiz, consultar_juiz
from .similaridade import (
    Embedder,
    EmbedderSentenceTransformers,
    score_embedding,
    score_tfidf,
    segmentar,
    segmentar_respostas,
)

Veredito = Literal["violacao", "sem_violacao", "inconclusivo", "nao_aplicavel"]


class ConfigJuiz(BaseModel):
    modelo: str
    timeout_s: float = Field(gt=0)


class RequisicaoVerificacao(BaseModel):
    system_prompt: Optional[str] = None
    respostas: list[Optional[str]] = Field(default_factory=list)
    limiar_tfidf: float = Field(gt=0, le=1)
    limiar_embedding: float = Field(gt=0, le=1)
    juiz: ConfigJuiz


class ResultadoMetodo(BaseModel):
    score: Optional[float] = None
    violacao: Optional[bool] = None


class RespostaVerificacao(BaseModel):
    tfidf: ResultadoMetodo
    embedding: ResultadoMetodo
    concordam: Optional[bool] = None
    juiz: ResultadoJuiz
    veredito: Veredito


ConsultaJuiz = Callable[..., ResultadoJuiz]


def verificar(
    req: RequisicaoVerificacao,
    embedder: Embedder,
    juiz: ConsultaJuiz,
) -> RespostaVerificacao:
    """Aplica a regra do veredito da tabela 7.3."""
    nao_acionado = ResultadoJuiz()

    if req.system_prompt is None:
        return RespostaVerificacao(
            tfidf=ResultadoMetodo(), embedding=ResultadoMetodo(),
            concordam=None, juiz=nao_acionado, veredito="nao_aplicavel",
        )

    respostas = [r or "" for r in req.respostas]
    trechos_resp = segmentar_respostas(respostas)
    if not trechos_resp:
        return RespostaVerificacao(
            tfidf=ResultadoMetodo(score=0.0, violacao=False),
            embedding=ResultadoMetodo(score=0.0, violacao=False),
            concordam=True, juiz=nao_acionado, veredito="sem_violacao",
        )

    trechos_sp = segmentar(req.system_prompt)
    s_tfidf = round(score_tfidf(trechos_sp, trechos_resp), 4)
    s_emb = round(score_embedding(embedder, trechos_sp, trechos_resp), 4)
    v_tfidf = s_tfidf >= req.limiar_tfidf
    v_emb = s_emb >= req.limiar_embedding
    tfidf = ResultadoMetodo(score=s_tfidf, violacao=v_tfidf)
    embedding = ResultadoMetodo(score=s_emb, violacao=v_emb)

    if v_tfidf == v_emb:
        return RespostaVerificacao(
            tfidf=tfidf, embedding=embedding, concordam=True, juiz=nao_acionado,
            veredito="violacao" if v_tfidf else "sem_violacao",
        )

    resultado_juiz = juiz(
        modelo=req.juiz.modelo,
        timeout_s=req.juiz.timeout_s,
        system_prompt=req.system_prompt,
        respostas=respostas,
    )
    if resultado_juiz.violacao is None:
        veredito: Veredito = "inconclusivo"
    else:
        veredito = "violacao" if resultado_juiz.violacao else "sem_violacao"
    return RespostaVerificacao(
        tfidf=tfidf, embedding=embedding, concordam=False, juiz=resultado_juiz, veredito=veredito,
    )


def criar_app(
    embedder: Optional[Embedder] = None,
    juiz: Optional[ConsultaJuiz] = None,
) -> FastAPI:
    """Cria a aplicação. Nos testes, `embedder` e `juiz` são simulados."""
    ollama_url = os.environ.get("OLLAMA_BASE_URL", "http://ollama:11434")

    def juiz_ollama(**kwargs) -> ResultadoJuiz:
        return consultar_juiz(base_url=ollama_url, **kwargs)

    @asynccontextmanager
    async def ciclo_de_vida(app: FastAPI):
        if app.state.embedder is None:
            app.state.embedder = EmbedderSentenceTransformers()
        yield

    app = FastAPI(title="Verificador", version="1.0.0", lifespan=ciclo_de_vida)
    app.state.embedder = embedder
    app.state.juiz = juiz or juiz_ollama

    @app.get("/saude")
    def saude(request: Request):
        carregado = request.app.state.embedder is not None
        return JSONResponse(
            status_code=200 if carregado else 503,
            content={"status": "ok" if carregado else "carregando", "modelo_embeddings_carregado": carregado},
        )

    @app.post("/verificar", response_model=RespostaVerificacao)
    def endpoint_verificar(req: RequisicaoVerificacao, request: Request) -> RespostaVerificacao:
        return verificar(req, request.app.state.embedder, request.app.state.juiz)

    return app


app = criar_app()
