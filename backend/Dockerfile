FROM ghcr.io/astral-sh/uv:python3.12-slim

WORKDIR /app

# Compile bytecode for faster startup; copy files instead of symlinks for portability
ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy

# Install dependencies first (separate layer — only rebuilds when deps change)
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

COPY . .

ENV PYTHONPATH=/app
ENV PATH="/app/.venv/bin:$PATH"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
