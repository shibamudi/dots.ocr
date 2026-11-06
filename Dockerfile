# syntax=docker/dockerfile:1
#
# Multi-stage Dockerfile for the dots.ocr frontend deployment.
#
# Two final targets are produced from a shared base:
#   - `app`          : Gradio frontend (demo/demo_gradio.py) that talks to an
#                      external vLLM inference backend via OpenAI API.
#   - `interceptor`  : tiny Flask app that swallows /manifest.json and
#                      /ocr/config requests routed by Traefik.
#
# Build a specific target with `docker compose build` (see docker-compose.yml)
# or `docker build --target <app|interceptor> .`.
#
# NOTE: this Dockerfile is for the *frontend* deployment described in
# docker-compose.yml. The vLLM inference server image lives under docker/
# (docker/Dockerfile) and is a separate deployment scenario.

# =========================================================================
# Stage: base
# Common Python base + pip + working dir. No project code here.
# =========================================================================
FROM python:3.10-slim AS base
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONPATH=/app
WORKDIR /app
RUN pip install --upgrade pip

# =========================================================================
# Stage: deps-app
# Install the Gradio frontend dependencies from the locked requirements file
# (requirements-locked.txt) so that every transitive dependency is pinned to an
# exact version and builds are reproducible. Deliberately NOT running
# `pip install .` because setup.py pulls in the full inference stack
# (flash-attn, transformers...) which the frontend does not need. The
# dots_ocr package is made importable via PYTHONPATH=/app at runtime.
# =========================================================================
FROM base AS deps-app
COPY requirements-locked.txt /tmp/requirements-locked.txt
RUN pip install -r /tmp/requirements-locked.txt

# =========================================================================
# Stage: deps-interceptor
# Install only Flask for the interceptor service.
# =========================================================================
FROM base AS deps-interceptor
RUN pip install flask

# =========================================================================
# Stage: app (final runtime image for the Gradio frontend)
# =========================================================================
FROM deps-app AS app
# Copy project sources needed by the frontend.
COPY dots_ocr ./dots_ocr
COPY demo ./demo
COPY assets ./assets
COPY tools ./tools
# Keep setup.py / requirements so the in-image environment is self-describing;
# they are NOT used to install anything at build time. The locked file is what
# the image was actually built with.
COPY setup.py requirements.txt requirements-front.txt requirements-locked.txt ./
EXPOSE 7860
CMD ["python", "-u", "demo/demo_gradio.py", "--host", "0.0.0.0", "--port", "7860", "--root_path", "/ocr"]

# =========================================================================
# Stage: interceptor (final runtime image for the Flask interceptor)
# =========================================================================
FROM deps-interceptor AS interceptor
COPY docker/interceptor/app.py ./app.py
EXPOSE 8000
CMD ["python", "-u", "app.py"]
