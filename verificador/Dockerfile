FROM python:3.12.16-slim-trixie

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    HF_HOME=/modelos \
    SENTENCE_TRANSFORMERS_HOME=/modelos

WORKDIR /servico

# Downloads acontecem só aqui, na instalação (RNF01, RNF03).
# Versões exatas: requirements.txt (diretas) + constraints.txt (todas, inclusive transitivas).
COPY requirements.txt constraints.txt ./
RUN pip install --extra-index-url https://download.pytorch.org/whl/cpu \
      -r requirements.txt torch==2.5.1+cpu -c constraints.txt

# Modelo de embeddings numa revisão fixa (a mesma de REVISAO_MODELO em app/similaridade.py)
ARG REVISAO_MODELO=e8f8c211226b894fcb81acc59f3b34ba3efd5f42
RUN python -c "from sentence_transformers import SentenceTransformer; \
SentenceTransformer('sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2', device='cpu', revision='${REVISAO_MODELO}')"

COPY app ./app
COPY calibracao.py .
COPY tests ./tests
COPY pytest.ini .

# Em execução, nada é baixado
ENV HF_HUB_OFFLINE=1 \
    TRANSFORMERS_OFFLINE=1

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
