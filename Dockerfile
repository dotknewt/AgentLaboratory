# syntax=docker/dockerfile:1

ARG PYTHON_VERSION=3.12

# ---------------------------------------------------------------------------
# Builder: install all Python dependencies into an isolated virtualenv
# ---------------------------------------------------------------------------
FROM python:${PYTHON_VERSION}-slim AS builder

# CPU-only torch wheels by default (keeps the image several GB smaller).
# For NVIDIA GPU support, build with:
#   --build-arg TORCH_INDEX_URL=https://download.pytorch.org/whl/cu124
ARG TORCH_INDEX_URL=https://download.pytorch.org/whl/cpu

ENV PIP_DISABLE_PIP_VERSION_CHECK=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt /tmp/requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install torch --index-url "${TORCH_INDEX_URL}" \
    && pip install -r /tmp/requirements.txt

# ---------------------------------------------------------------------------
# Runtime: minimal image with just the venv, the app, and (optionally) LaTeX
# ---------------------------------------------------------------------------
FROM python:${PYTHON_VERSION}-slim AS runtime

# The paper-writing phase can compile reports to PDF with pdflatex
# (compile-latex: True in the experiment config). TeX Live adds ~1 GB,
# so it is opt-in:
#   docker build --build-arg WITH_LATEX=true .
ARG WITH_LATEX=false
RUN if [ "$WITH_LATEX" = "true" ]; then \
        apt-get update \
        && apt-get install -y --no-install-recommends \
            texlive-latex-base \
            texlive-latex-recommended \
            texlive-latex-extra \
            texlive-fonts-recommended \
        && rm -rf /var/lib/apt/lists/*; \
    fi

RUN useradd --create-home --uid 1000 agentlab

COPY --from=builder /opt/venv /opt/venv

WORKDIR /app
COPY --chown=agentlab:agentlab . .

# The workflow writes state_saves/, <benchmark>_research_dir/, uploads/,
# instance/ (flask-sqlalchemy) and model caches relative to the working
# directory; pre-create them so they can be volume-mounted, and make /app
# itself writable so the app can create further run directories.
RUN mkdir -p state_saves MATH_research_dir uploads instance .cache \
    && chown agentlab:agentlab /app state_saves MATH_research_dir uploads instance .cache

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    HF_HOME=/app/.cache/huggingface \
    MPLCONFIGDIR=/app/.cache/matplotlib

USER agentlab

# AgentRxiv mode serves its paper-sharing API on 5000 + lab-index
# (loopback inside the container; used by the agents themselves).
EXPOSE 5000

ENTRYPOINT ["python", "ai_lab_repo.py"]
CMD ["--yaml-location", "experiment_configs/MATH_agentlab.yaml"]
