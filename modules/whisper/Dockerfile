# Stage 1: Build stage with UV
FROM ghcr.io/astral-sh/uv:python3.11-bookworm-slim AS builder

WORKDIR /app

# Copy project files
COPY app/pyproject.toml app/.python-version app/uv.lock ./

# Install dependencies with UV (super fast!)
RUN uv sync --frozen --no-dev

# Stage 2: Runtime stage
FROM python:3.11-slim

# Install ffmpeg (required by faster-whisper)
RUN apt-get update && \
    apt-get install -y --no-install-recommends ffmpeg && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy UV-installed dependencies from builder
COPY --from=builder /app/.venv /app/.venv

# Copy application code
COPY app/main.py .

# Create models directory for persistence
RUN mkdir -p /models && chmod 777 /models

# Add virtual environment to PATH
ENV PATH="/app/.venv/bin:$PATH"

EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

# Run with Uvicorn
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]