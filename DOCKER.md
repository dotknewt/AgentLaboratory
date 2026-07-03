# Running Agent Laboratory in Docker

The image bundles Python 3.12, all dependencies from `requirements.txt`
(CPU-only PyTorch by default), and runs `ai_lab_repo.py` as a non-root user.

## Build

```bash
docker build -t agentlaboratory .
```

Build options:

| Build arg | Default | Purpose |
|-----------|---------|---------|
| `WITH_LATEX` | `false` | Set to `true` to install TeX Live so `compile-latex: True` configs can produce PDFs (adds ~1 GB). |
| `TORCH_INDEX_URL` | CPU wheels | Set to e.g. `https://download.pytorch.org/whl/cu124` for NVIDIA GPU wheels (run with `--gpus all`). |
| `PYTHON_VERSION` | `3.12` | Base Python version. |

Example with LaTeX support:

```bash
docker build --build-arg WITH_LATEX=true -t agentlaboratory .
```

## Run

Put your API key in the environment (or in the YAML config) and run:

```bash
docker run --rm -it \
  -e OPENAI_API_KEY \
  -v "$PWD/experiment_configs:/app/experiment_configs" \
  -v "$PWD/output/state_saves:/app/state_saves" \
  -v "$PWD/output/MATH_research_dir:/app/MATH_research_dir" \
  agentlaboratory --yaml-location experiment_configs/MATH_agentlab.yaml
```

Any arguments after the image name are passed straight to `ai_lab_repo.py`;
with no arguments it defaults to `experiment_configs/MATH_agentlab.yaml`.

`-it` matters when `copilot-mode: True` — the workflow pauses for human
feedback on stdin.

## Or with Docker Compose

```bash
export OPENAI_API_KEY=sk-...
docker compose run --rm agentlab
# or a different config:
docker compose run --rm agentlab --yaml-location experiment_configs/MATH_agentrxiv.yaml
```

Outputs (`state_saves/`, `MATH_research_dir/`, `uploads/`) appear under
`./output/` on the host, and Hugging Face model downloads persist in the
`model_cache` named volume.

## Notes

- **AgentRxiv mode** (`agentRxiv: True` / `parallel-labs: True`) starts its
  Flask paper-sharing server *inside* the same container on
  `127.0.0.1:5000 + lab-index`; nothing extra to deploy.
- The experiment phase executes agent-generated Python in-process, so the
  container doubles as a sandbox for that code — a good reason to run it
  containerized rather than on the host.
- If your generated experiments need TensorFlow, it is intentionally not in
  `requirements.txt`; add it there and rebuild, or `pip install tensorflow`
  in a derived image.
