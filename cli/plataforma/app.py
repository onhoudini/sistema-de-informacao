"""Comandos da CLI (spec §8.1). Cliente fino: coleta a entrada, chama a API e apresenta a resposta."""

from __future__ import annotations

import json
import os
import sys
import time
from enum import Enum
from pathlib import Path
from typing import Any, Callable, NoReturn, Optional

import typer
from typing_extensions import Annotated

from . import formatacao as fmt
from .api import APIInacessivel, ClienteAPI, ErroAPI

# Códigos de saída (spec §8.1)
SUCESSO, ERRO_API, USO_INCORRETO, API_INACESSIVEL = 0, 1, 2, 3

AVISO_USO = (
    "ATENÇÃO: ferramenta de natureza ofensiva. Use apenas em avaliações autorizadas (RE01)."
)

app = typer.Typer(
    name="plataforma",
    help=(
        "CLI da Plataforma Local de Avaliação de Segurança de Modelos de Linguagem.\n\n"
        f"{AVISO_USO}\n\n"
        "Todos os comandos falam só com a API da Plataforma. Use --json para obter o corpo da API sem alteração."
    ),
    no_args_is_help=True,
    add_completion=False,
    rich_markup_mode=None,
    pretty_exceptions_enable=False,
)
ataques_app = typer.Typer(help="Biblioteca de ataques (UC-01).", no_args_is_help=True)
modelos_app = typer.Typer(help="Modelos disponíveis no Ollama.", no_args_is_help=True)
avaliacoes_app = typer.Typer(help="Configurar e executar avaliações (UC-02, UC-03).", no_args_is_help=True)
resultados_app = typer.Typer(help="Resumo, tentativas e CSV de uma avaliação (UC-04).", no_args_is_help=True)
tentativas_app = typer.Typer(help="Evidências e revisão humana de tentativas (UC-04).", no_args_is_help=True)
app.add_typer(ataques_app, name="ataques")
app.add_typer(modelos_app, name="modelos")
app.add_typer(avaliacoes_app, name="avaliacoes")
app.add_typer(resultados_app, name="resultados")
app.add_typer(tentativas_app, name="tentativas")

# Ponto de injeção para os testes (httpx.MockTransport)
fabrica_cliente: Callable[[], ClienteAPI] = ClienteAPI

OpcaoJson = Annotated[bool, typer.Option("--json", help="Imprime o corpo da API sem alteração (para scripts).")]


class VereditoRevisao(str, Enum):
    violacao = "violacao"
    sem_violacao = "sem_violacao"


class Separador(str, Enum):
    virgula = "virgula"
    ponto_e_virgula = "ponto-e-virgula"


# ---------------------------------------------------------------------------
# Utilitários
# ---------------------------------------------------------------------------


def eco(msg: str = "") -> None:
    typer.echo(msg)


def erro(msg: str) -> None:
    typer.echo(msg, err=True)


def imprimir_json(dados: Any) -> None:
    typer.echo(json.dumps(dados, ensure_ascii=False, indent=2))


def sair(codigo: int) -> NoReturn:
    raise typer.Exit(codigo)


def mensagens_erro(corpo: Any) -> list[str]:
    if isinstance(corpo, dict):
        if isinstance(corpo.get("erros"), list):
            return [str(e) for e in corpo["erros"]]
        if corpo.get("erro"):
            return [str(corpo["erro"])]
        if corpo.get("message"):
            return [str(corpo["message"])]
    return []


def mostrar_avisos(corpo: Any) -> None:
    if isinstance(corpo, dict):
        for aviso in corpo.get("avisos") or []:
            erro(f"Aviso: {aviso}")


def chamar(funcao: Callable[[ClienteAPI], Any], como_json: bool) -> Any:
    """Executa uma chamada à API traduzindo falhas em mensagens PT-BR e códigos de saída."""
    try:
        return funcao(fabrica_cliente())
    except APIInacessivel as exc:
        if como_json:
            imprimir_json({"erro": str(exc)})
        else:
            erro(f"Erro: {exc}")
        sair(API_INACESSIVEL)
    except ErroAPI as exc:
        if como_json:
            imprimir_json(exc.corpo if exc.corpo is not None else {"erro": exc.texto, "status": exc.status})
        else:
            msgs = mensagens_erro(exc.corpo) or [exc.texto or "erro sem detalhes"]
            if len(msgs) == 1:
                erro(f"Erro ({exc.status}): {msgs[0]}")
            else:
                erro(f"Erro ({exc.status}):")
                for m in msgs:
                    erro(f"  - {m}")
            mostrar_avisos(exc.corpo)
        sair(ERRO_API)


def ler_json(caminho: Path) -> Any:
    """Lê um arquivo JSON (caminho relativo à raiz do repositório no contêiner)."""
    try:
        conteudo = caminho.read_text(encoding="utf-8-sig")
    except FileNotFoundError:
        erro(f"Erro: arquivo não encontrado: {caminho}")
        sair(USO_INCORRETO)
    except OSError as exc:
        erro(f"Erro: não foi possível ler {caminho}: {exc.strerror}")
        sair(USO_INCORRETO)
    try:
        return json.loads(conteudo)
    except json.JSONDecodeError as exc:
        erro(f"Erro: JSON malformado em {caminho} (linha {exc.lineno}, coluna {exc.colno}): {exc.msg}")
        sair(USO_INCORRETO)


def linha_progresso(av: dict) -> str:
    return (
        f"Avaliação {av.get('id')} [{av.get('status')}]: "
        f"{av.get('concluidas', 0)} concluídas, {av.get('falhas', 0)} falhas, "
        f"{av.get('pendentes', 0)} pendentes de {av.get('n_planejado', 0)}"
    )


# ---------------------------------------------------------------------------
# ataques
# ---------------------------------------------------------------------------


@ataques_app.command("listar")
def ataques_listar(
    estrategia: Annotated[Optional[str], typer.Option(help="Filtra por estratégia.")] = None,
    como_json: OpcaoJson = False,
) -> None:
    """Lista a biblioteca de ataques, agrupada por estratégia."""
    dados = chamar(lambda c: c.listar_ataques(estrategia), como_json)
    if como_json:
        return imprimir_json(dados)
    eco(fmt.tabela(
        ["ID", "NOME", "ESTRATÉGIA", "TIPO", "ORIGEM", "MSGS"],
        [[a["id"], a["nome"], a["estrategia"], a["tipo"], a["origem"], len(a.get("mensagens") or [])] for a in dados],
    ))


@ataques_app.command("adicionar")
def ataques_adicionar(
    arquivo: Annotated[Path, typer.Argument(help="Arquivo JSON com um ataque ou uma lista (formato de ataques/schema.json).")],
    como_json: OpcaoJson = False,
) -> None:
    """Valida e grava ataques personalizados (RF05)."""
    dados = ler_json(arquivo)
    corpo = chamar(lambda c: c.adicionar_ataques(dados), como_json)
    if como_json:
        return imprimir_json(corpo)
    inseridos = corpo.get("inseridos", [])
    eco(f"{len(inseridos)} ataque(s) adicionado(s):")
    eco(fmt.tabela(["ID", "NOME", "ESTRATÉGIA", "TIPO"],
                   [[a["id"], a["nome"], a["estrategia"], a["tipo"]] for a in inseridos]))


# ---------------------------------------------------------------------------
# modelos
# ---------------------------------------------------------------------------


@modelos_app.command("listar")
def modelos_listar(como_json: OpcaoJson = False) -> None:
    """Lista os modelos disponíveis no Ollama (RF01)."""
    dados = chamar(lambda c: c.listar_modelos(), como_json)
    if como_json:
        return imprimir_json(dados)

    def tamanho(b: Any) -> str:
        return "-" if not b else f"{b / 1024 ** 3:.1f} GB"

    eco(fmt.tabela(["NOME", "FAMÍLIA", "PARÂMETROS", "QUANTIZAÇÃO", "TAMANHO"],
                   [[m["nome"], m.get("familia"), m.get("parametros"), m.get("quantizacao"),
                     tamanho(m.get("tamanho_bytes"))] for m in dados]))


# ---------------------------------------------------------------------------
# avaliacoes
# ---------------------------------------------------------------------------


@avaliacoes_app.command("validar")
def avaliacoes_validar(
    arquivo: Annotated[Path, typer.Argument(help="Arquivo JSON no formato de POST /avaliacoes (spec §5.1).")],
    como_json: OpcaoJson = False,
) -> None:
    """Valida a configuração e mostra N, erros e avisos, sem gravar."""
    dados = ler_json(arquivo)
    corpo = chamar(lambda c: c.validar_avaliacao(dados), como_json)
    erros = corpo.get("erros") or []
    if como_json:
        imprimir_json(corpo)
    else:
        n = corpo.get("n_planejado")
        eco(f"Quantidade planejada de tentativas (N): {n if n is not None else 'não calculável'}")
        for e in erros:
            erro(f"Erro: {e}")
        mostrar_avisos(corpo)
        eco("Configuração válida." if not erros else f"Configuração inválida ({len(erros)} erro(s)).")
    if erros:
        sair(ERRO_API)


@avaliacoes_app.command("criar")
def avaliacoes_criar(
    arquivo: Annotated[Path, typer.Argument(help="Arquivo JSON no formato de POST /avaliacoes (spec §5.1).")],
    como_json: OpcaoJson = False,
) -> None:
    """Cria uma avaliação com status 'configurada'."""
    dados = ler_json(arquivo)
    corpo = chamar(lambda c: c.criar_avaliacao(dados), como_json)
    if como_json:
        return imprimir_json(corpo)
    mostrar_avisos(corpo)
    eco(f"Avaliação {corpo['id']} criada. N planejado: {corpo['n_planejado']}.")
    eco(f"Para executar: avaliacoes executar {corpo['id']}")


@avaliacoes_app.command("listar")
def avaliacoes_listar(como_json: OpcaoJson = False) -> None:
    """Lista as avaliações com status e progresso."""
    dados = chamar(lambda c: c.listar_avaliacoes(), como_json)
    if como_json:
        return imprimir_json(dados)
    eco(fmt.tabela(
        ["ID", "NOME", "STATUS", "N", "CONCLUÍDAS", "FALHAS", "PENDENTES", "CRIADA EM"],
        [[a["id"], a["nome"], a["status"], a["n_planejado"], a.get("concluidas"), a.get("falhas"),
          a.get("pendentes"), str(a.get("criado_em", ""))[:16].replace("T", " ")] for a in dados],
        larguras={1: 40},
    ))


@avaliacoes_app.command("ver")
def avaliacoes_ver(id_: Annotated[int, typer.Argument(metavar="ID")], como_json: OpcaoJson = False) -> None:
    """Mostra a configuração completa e o progresso de uma avaliação."""
    av = chamar(lambda c: c.ver_avaliacao(id_), como_json)
    if como_json:
        return imprimir_json(av)
    eco(fmt.chave_valor([
        ("ID", av["id"]), ("Nome", av["nome"]), ("Status", av["status"]),
        ("Modelos", ", ".join(av.get("modelos", []))),
        ("Repetições", av.get("repeticoes")), ("Tempo máximo por chamada", f"{av.get('timeout_chamada_s')} s"),
        ("Limiar TF-IDF", av.get("limiar_tfidf")), ("Limiar embeddings", av.get("limiar_embedding")),
        ("Modelo juiz", av.get("modelo_juiz")), ("N planejado", av.get("n_planejado")),
        ("Progresso", f"{av.get('concluidas')} concluídas, {av.get('falhas')} falhas, {av.get('pendentes')} pendentes"),
        ("Criada em", av.get("criado_em")), ("Iniciada em", av.get("iniciado_em")),
        ("Finalizada em", av.get("finalizado_em")),
    ]))
    eco("\nSystem prompts:")
    eco(fmt.tabela(["RÓTULO", "CONTEÚDO"],
                   [[s["rotulo"], s["conteudo"] if s["conteudo"] is not None else "(sem system prompt)"]
                    for s in av.get("system_prompts", [])], larguras={1: 80}))
    eco("\nConfigurações:")
    eco(fmt.tabela(["#", "PARÂMETROS"],
                   [[i, json.dumps(c, ensure_ascii=False)] for i, c in enumerate(av.get("configuracoes", []))]))
    eco("\nAtaques:")
    eco(fmt.tabela(["ID", "NOME", "ESTRATÉGIA", "TIPO"],
                   [[a["id"], a["nome"], a["estrategia"], a["tipo"]] for a in av.get("ataques", [])]))


def _acompanhar(id_: int, como_json: bool, intervalo: float) -> None:
    """Consulta GET /avaliacoes/:id até 'finalizada'. Ctrl+C encerra só o acompanhamento (RF12)."""
    try:
        anterior = None
        while True:
            av = chamar(lambda c: c.ver_avaliacao(id_), como_json)
            linha = linha_progresso(av)
            if linha != anterior:
                (erro if como_json else eco)(linha)
                anterior = linha
            if av.get("status") == "finalizada":
                if como_json:
                    typer.echo(json.dumps(av, ensure_ascii=False))
                else:
                    eco(f"Avaliação finalizada. Resumo: resultados resumo {id_}")
                return
            if av.get("status") != "em_execucao":
                erro(f"A avaliação está '{av.get('status')}', não em execução.")
                if como_json:
                    typer.echo(json.dumps(av, ensure_ascii=False))
                return
            time.sleep(intervalo)
    except KeyboardInterrupt:
        erro("")
        erro("Acompanhamento interrompido. A avaliação continua em execução no servidor (RF12).")
        erro(f"Para voltar a acompanhar: avaliacoes acompanhar {id_}")


def _intervalo() -> float:
    try:
        return float(os.environ.get("PLATAFORMA_INTERVALO_S", "5"))
    except ValueError:
        return 5.0


@avaliacoes_app.command("executar")
def avaliacoes_executar(
    id_: Annotated[int, typer.Argument(metavar="ID")],
    sem_acompanhar: Annotated[bool, typer.Option("--sem-acompanhar", help="Só inicia a execução, sem acompanhar.")] = False,
    como_json: OpcaoJson = False,
) -> None:
    """Inicia a execução e acompanha o progresso (Ctrl+C para só o acompanhamento)."""
    corpo = chamar(lambda c: c.executar_avaliacao(id_), como_json)
    if como_json:
        typer.echo(json.dumps(corpo, ensure_ascii=False))
    else:
        eco(corpo.get("mensagem") or f"Execução da avaliação {id_} iniciada.")
    if not sem_acompanhar:
        _acompanhar(id_, como_json, _intervalo())


@avaliacoes_app.command("acompanhar")
def avaliacoes_acompanhar(id_: Annotated[int, typer.Argument(metavar="ID")], como_json: OpcaoJson = False) -> None:
    """Acompanha o progresso a cada 5 s até a avaliação ser finalizada."""
    _acompanhar(id_, como_json, _intervalo())


# ---------------------------------------------------------------------------
# resultados
# ---------------------------------------------------------------------------


def _linhas_contagem(itens: list[dict], chaves: list[str]) -> list[list[Any]]:
    return [[*(i.get(k) for k in chaves), i["tentativas"], i["violacoes"], i["sem_violacao"], i["inconclusivas"],
             i["nao_aplicaveis"], i["falhas"], i["pendentes"], i.get("decididas_juiz", 0),
             fmt.percentual(i.get("taxa_violacao"))] for i in itens]


CABECALHO_CONTAGEM = ["TENT.", "VIOL.", "SEM VIOL.", "INCONCL.", "N/A", "FALHAS", "PEND.", "JUIZ", "TAXA VIOL."]


def situacao_juiz(t: dict) -> str:
    """'decidido' = o LLM juiz desempatou; 'falhou' = acionado sem resultado válido (inconclusivo)."""
    if not t.get("juiz_acionado"):
        return "-"
    return "falhou" if t.get("juiz_violacao") is None else "decidido"


@resultados_app.command("resumo")
def resultados_resumo(id_: Annotated[int, typer.Argument(metavar="ID")], como_json: OpcaoJson = False) -> None:
    """Taxa de violação por modelo, system prompt e estratégia; ataques bem e malsucedidos (RF21, RF22)."""
    r = chamar(lambda c: c.resumo(id_), como_json)
    if como_json:
        return imprimir_json(r)
    av = r.get("avaliacao", {})
    eco(linha_progresso(av))
    eco("Taxa de violação = violações / (violações + sem violação), sobre o veredito final.")
    eco("JUIZ = tentativas em que TF-IDF e embeddings discordaram e o LLM juiz desempatou "
        "(inconclusivo = o juiz não conseguiu decidir).\n")
    total = r.get("total") or {}
    if total:
        eco(fmt.tabela(CABECALHO_CONTAGEM, _linhas_contagem([total], [])))
    eco("\nPor modelo:")
    eco(fmt.tabela(["MODELO", *CABECALHO_CONTAGEM], _linhas_contagem(r.get("por_modelo", []), ["modelo"])))
    eco("\nPor modelo × system prompt × estratégia:")
    eco(fmt.tabela(["MODELO", "SYSTEM PROMPT", "ESTRATÉGIA", *CABECALHO_CONTAGEM],
                   _linhas_contagem(r.get("grupos", []), ["modelo", "system_prompt", "estrategia"])))
    eco("\nPor ataque (bem-sucedido = veredito final violação):")
    eco(fmt.tabela(["ATAQUE", "ESTRATÉGIA", "TIPO", *CABECALHO_CONTAGEM],
                   _linhas_contagem(r.get("por_ataque", []), ["ataque", "estrategia", "tipo"])))


@resultados_app.command("tentativas")
def resultados_tentativas(
    id_: Annotated[int, typer.Argument(metavar="ID")],
    veredito: Annotated[Optional[str], typer.Option(help="violacao, sem_violacao, inconclusivo, nao_aplicavel, falha ou pendente.")] = None,
    pagina: Annotated[int, typer.Option(help="Página (50 por página).")] = 1,
    juiz: Annotated[bool, typer.Option("--juiz", help="Só as tentativas em que o LLM juiz foi acionado (métodos discordaram).")] = False,
    como_json: OpcaoJson = False,
) -> None:
    """Lista paginada das tentativas com o veredito final (RF16, RF19)."""
    r = chamar(lambda c: c.tentativas(id_, veredito, pagina, juiz), como_json)
    if como_json:
        return imprimir_json(r)
    itens = r.get("itens", [])
    eco(fmt.tabela(
        ["ID", "MODELO", "SYSTEM PROMPT", "CONF", "ATAQUE", "REP", "STATUS", "TF-IDF", "EMB.", "JUIZ", "VEREDITO FINAL"],
        [[t["tentativa_id"], t["modelo"], t["system_prompt"], t["configuracao_idx"], t["ataque"], t["repeticao"],
          t["status"], t.get("tfidf_score"), t.get("embedding_score"), situacao_juiz(t),
          fmt.veredito(t.get("veredito_final") or (t["status"] if t["status"] != "concluida" else None))
          + (" (revisado)" if t.get("veredito_humano") else "")] for t in itens],
        larguras={2: 24, 4: 32},
    ))
    total, por_pagina = r.get("total", 0), r.get("por_pagina", 50) or 50
    paginas = max(1, -(-total // por_pagina))
    eco(f"\nPágina {r.get('pagina', pagina)} de {paginas} ({total} tentativa(s)).")


@resultados_app.command("csv")
def resultados_csv(
    id_: Annotated[int, typer.Argument(metavar="ID")],
    saida: Annotated[Optional[Path], typer.Option("-o", "--saida", help="Arquivo de saída (padrão: saida/avaliacao-<id>.csv).")] = None,
    separador: Annotated[Separador, typer.Option(help="Separador de colunas (ponto-e-vírgula abre direto no Excel em português).")] = Separador.virgula,
    como_json: OpcaoJson = False,
) -> None:
    """Grava o histórico da avaliação em CSV (UTF-8 com BOM, RF20)."""
    destino = saida or Path("saida") / f"avaliacao-{id_}.csv"
    sep = ";" if separador == Separador.ponto_e_virgula else ","
    conteudo = chamar(lambda c: c.csv(id_, sep), como_json)
    try:
        destino.parent.mkdir(parents=True, exist_ok=True)
        destino.write_bytes(conteudo)
    except OSError as exc:
        erro(f"Erro: não foi possível gravar {destino}: {exc.strerror}. No contêiner, só a pasta saida/ aceita escrita.")
        sair(USO_INCORRETO)
    if como_json:
        return imprimir_json({"arquivo": str(destino), "bytes": len(conteudo)})
    eco(f"CSV gravado em {destino} ({len(conteudo)} bytes).")


# ---------------------------------------------------------------------------
# tentativas
# ---------------------------------------------------------------------------


@tentativas_app.command("ver")
def tentativas_ver(
    id_: Annotated[int, typer.Argument(metavar="ID")],
    completo: Annotated[bool, typer.Option("--completo", help="Mostra o system prompt inteiro (por padrão ele fica minimizado).")] = False,
    como_json: OpcaoJson = False,
) -> None:
    """Evidências de uma tentativa: turnos, scores, juiz e revisões (RF16)."""
    t = chamar(lambda c: c.ver_tentativa(id_), como_json)
    if como_json:
        return imprimir_json(t)
    ataque = t.get("ataque") or {}
    sp = t.get("system_prompt") or {}
    eco(fmt.chave_valor([
        ("Tentativa", t["tentativa_id"]), ("Avaliação", t["avaliacao_id"]), ("Modelo", t["modelo"]),
        ("System prompt", sp.get("rotulo")), ("Configuração", json.dumps(t.get("configuracao"), ensure_ascii=False)),
        ("Ataque", f"{ataque.get('nome')} ({ataque.get('estrategia')}, {ataque.get('tipo')})"),
        ("Repetição", t.get("repeticao")), ("Status", t.get("status")), ("Erro", t.get("erro")),
        ("Veredito automático", fmt.veredito(t.get("veredito_automatico"))),
        ("Veredito humano", fmt.veredito(t.get("veredito_humano"))),
        ("Veredito final", fmt.veredito(t.get("veredito_final"))),
    ]))
    if sp.get("conteudo") is None:
        eco("\nSystem prompt: (sem system prompt)")
    elif completo:
        eco("\nSystem prompt utilizado:")
        eco(sp["conteudo"])
    else:
        eco("\nSystem prompt utilizado: (minimizado; use --completo para mostrar)")
    for turno in t.get("turnos", []):
        entrada = turno.get("entrada") or []
        pergunta = entrada[-1].get("content") if entrada else ""
        eco(f"\n--- Turno {turno['ordem']} ---")
        eco(f"[entrada] {pergunta}")
        eco(f"[resposta] {turno.get('resposta') or ''}")
    v = t.get("verificacao")
    eco("\nVerificação:")
    if v:
        eco(fmt.chave_valor([
            ("TF-IDF", f"{fmt.texto(v.get('tfidf_score'))} (violação: {fmt.texto(v.get('tfidf_violacao'))})"),
            ("Embeddings", f"{fmt.texto(v.get('embedding_score'))} (violação: {fmt.texto(v.get('embedding_violacao'))})"),
            ("Métodos concordam", v.get("concordam")),
            ("Juiz acionado", v.get("juiz_acionado")),
            ("Decisão do juiz", v.get("juiz_violacao")),
            ("Justificativa do juiz", v.get("juiz_justificativa")),
            ("Veredito", fmt.veredito(v.get("veredito"))),
        ]))
    else:
        eco("(sem verificação: a tentativa não foi concluída)")
    eco("\nRevisões (mais recente primeiro):")
    eco(fmt.tabela(["ID", "VEREDITO", "COMENTÁRIO", "EM"],
                   [[r["id"], fmt.veredito(r["veredito"]), r.get("comentario"), str(r.get("criado_em"))[:19].replace("T", " ")]
                    for r in t.get("revisoes", [])], larguras={2: 60}))


@tentativas_app.command("revisar")
def tentativas_revisar(
    id_: Annotated[int, typer.Argument(metavar="ID")],
    veredito: Annotated[VereditoRevisao, typer.Option(help="Veredito da revisão humana.")],
    comentario: Annotated[Optional[str], typer.Option(help="Comentário opcional.")] = None,
    como_json: OpcaoJson = False,
) -> None:
    """Registra uma revisão humana; o veredito automático é preservado (RF17, RN-13)."""
    r = chamar(lambda c: c.revisar(id_, veredito.value, comentario), como_json)
    if como_json:
        return imprimir_json(r)
    eco(f"Revisão {r['id']} registrada na tentativa {id_}: {fmt.veredito(r['veredito'])}.")


def main() -> None:
    app(prog_name="plataforma")
