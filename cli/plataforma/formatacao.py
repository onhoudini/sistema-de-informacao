"""Apresentação em texto (tabelas simples, sem dependências)."""

from __future__ import annotations

from typing import Any, Iterable, Sequence

ROTULOS_VEREDITO = {
    "violacao": "violação",
    "sem_violacao": "sem violação",
    "inconclusivo": "inconclusivo",
    "nao_aplicavel": "não aplicável",
    "falha": "falha",
    "pendente": "pendente",
    None: "-",
}


def veredito(v: Any) -> str:
    return ROTULOS_VEREDITO.get(v, str(v))


def texto(v: Any, largura: int | None = None) -> str:
    if v is None:
        s = "-"
    elif isinstance(v, bool):
        s = "sim" if v else "não"
    elif isinstance(v, float):
        s = f"{v:.4f}".rstrip("0").rstrip(".") if v != int(v) else str(int(v))
    else:
        s = str(v)
    s = " ".join(s.split())
    if largura and len(s) > largura:
        s = s[: largura - 1] + "…"
    return s


def percentual(v: Any) -> str:
    return "-" if v is None else f"{float(v) * 100:.1f}%"


def tabela(cabecalho: Sequence[str], linhas: Iterable[Sequence[Any]], larguras: dict[int, int] | None = None) -> str:
    larguras = larguras or {}
    dados = [[texto(c, larguras.get(i)) for i, c in enumerate(linha)] for linha in linhas]
    colunas = [len(h) for h in cabecalho]
    for linha in dados:
        for i, c in enumerate(linha):
            colunas[i] = max(colunas[i], len(c))
    fmt = "  ".join(f"{{:<{w}}}" for w in colunas)
    saida = [fmt.format(*cabecalho), "  ".join("-" * w for w in colunas)]
    saida += [fmt.format(*linha) for linha in dados]
    if not dados:
        saida.append("(nenhum registro)")
    return "\n".join(saida)


def chave_valor(pares: Iterable[tuple[str, Any]]) -> str:
    pares = list(pares)
    largura = max((len(k) for k, _ in pares), default=0)
    return "\n".join(f"{k.ljust(largura)}  {texto(v)}" for k, v in pares)
