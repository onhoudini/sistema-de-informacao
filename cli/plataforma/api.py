"""Cliente HTTP da API da Plataforma (spec §5). Única porta de saída da CLI (ADR 0001)."""

from __future__ import annotations

import os
from typing import Any, Optional

import httpx

URL_PADRAO = "http://gateway/api"


class ErroAPI(Exception):
    """Erro de validação ou de negócio devolvido pela API (400, 404, 409...)."""

    def __init__(self, status: int, corpo: Any, texto: str = "") -> None:
        self.status = status
        self.corpo = corpo
        self.texto = texto
        super().__init__(f"HTTP {status}")


class APIInacessivel(Exception):
    """gateway ou n8n fora do ar, ou workflow inativo."""


def _corpo(resposta: httpx.Response) -> Any:
    try:
        return resposta.json()
    except ValueError:
        return None


class ClienteAPI:
    def __init__(
        self,
        base_url: Optional[str] = None,
        transport: Optional[httpx.BaseTransport] = None,
        timeout: float = 60.0,
    ) -> None:
        self.base_url = (base_url or os.environ.get("PLATAFORMA_API_URL") or URL_PADRAO).rstrip("/")
        self._cliente = httpx.Client(base_url=self.base_url, transport=transport, timeout=timeout)

    def requisitar(self, metodo: str, caminho: str, **kwargs: Any) -> httpx.Response:
        try:
            resposta = self._cliente.request(metodo, caminho, **kwargs)
        except httpx.TransportError as exc:
            raise APIInacessivel(
                f"Não foi possível conectar à API da Plataforma em {self.base_url} ({exc.__class__.__name__}). "
                "Verifique se o ambiente está no ar (docker compose up -d)."
            ) from exc

        corpo = _corpo(resposta)
        if resposta.status_code in (502, 503, 504):
            detalhe = corpo.get("erro") if isinstance(corpo, dict) else None
            raise APIInacessivel(detalhe or f"API da Plataforma indisponível (HTTP {resposta.status_code}).")
        if (
            resposta.status_code == 404
            and isinstance(corpo, dict)
            and "webhook" in str(corpo.get("message", "")).lower()
        ):
            raise APIInacessivel(
                "A rota existe, mas o workflow do n8n que a atende não está ativo. "
                "Ative os workflows (scripts/configurar-n8n) e tente de novo."
            )
        if resposta.status_code >= 400:
            raise ErroAPI(resposta.status_code, corpo, resposta.text)
        return resposta

    def _json(self, metodo: str, caminho: str, **kwargs: Any) -> Any:
        return self.requisitar(metodo, caminho, **kwargs).json()

    # --- Ataques (UC-01) ---
    def listar_ataques(self, estrategia: Optional[str] = None) -> Any:
        params = {"estrategia": estrategia} if estrategia else None
        return self._json("GET", "/ataques", params=params)

    def adicionar_ataques(self, dados: Any) -> Any:
        return self._json("POST", "/ataques", json=dados)

    # --- Modelos ---
    def listar_modelos(self) -> Any:
        return self._json("GET", "/modelos")

    # --- Avaliações (UC-02, UC-03) ---
    def validar_avaliacao(self, dados: Any) -> Any:
        return self._json("POST", "/avaliacoes/validar", json=dados)

    def criar_avaliacao(self, dados: Any) -> Any:
        return self._json("POST", "/avaliacoes", json=dados)

    def listar_avaliacoes(self) -> Any:
        return self._json("GET", "/avaliacoes")

    def ver_avaliacao(self, id_: int) -> Any:
        return self._json("GET", f"/avaliacoes/{id_}")

    def executar_avaliacao(self, id_: int) -> Any:
        return self._json("POST", f"/avaliacoes/{id_}/executar")

    # --- Resultados (UC-04) ---
    def resumo(self, id_: int) -> Any:
        return self._json("GET", f"/avaliacoes/{id_}/resumo")

    def tentativas(self, id_: int, veredito: Optional[str] = None, pagina: int = 1, juiz: bool = False) -> Any:
        params: dict[str, Any] = {"pagina": pagina}
        if veredito:
            params["veredito"] = veredito
        if juiz:
            params["juiz"] = "sim"
        return self._json("GET", f"/avaliacoes/{id_}/tentativas", params=params)

    def csv(self, id_: int, separador: str = ",") -> bytes:
        params = {"separador": separador} if separador != "," else None
        return self.requisitar("GET", f"/avaliacoes/{id_}/csv", params=params).content

    def ver_tentativa(self, id_: int) -> Any:
        return self._json("GET", f"/tentativas/{id_}")

    def revisar(self, id_: int, veredito: str, comentario: Optional[str] = None) -> Any:
        corpo: dict[str, Any] = {"veredito": veredito}
        if comentario is not None:
            corpo["comentario"] = comentario
        return self._json("POST", f"/tentativas/{id_}/revisao", json=corpo)
