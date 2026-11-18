FROM python:3.12.16-slim-trixie

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONPATH=/cli \
    # testes: `docker compose --profile cli run --rm --entrypoint pytest cli`
    PYTEST_ADDOPTS="-p no:cacheprovider /cli/tests"

WORKDIR /cli
# Dependências instaladas só aqui, na instalação; em execução o contêiner fica sem internet
# Versões exatas: requirements.txt (diretas) + constraints.txt (todas, inclusive transitivas)
COPY requirements.txt constraints.txt ./
RUN pip install -r requirements.txt -c constraints.txt
COPY plataforma ./plataforma
COPY tests ./tests

# A raiz do repositório é montada em /projeto (somente leitura) e é o diretório de trabalho
WORKDIR /projeto
ENTRYPOINT ["python", "-m", "plataforma"]
