# ==========================================================
# CEMS Multi-Stage Production Dockerfile
# Base: python:3.11-slim
# ==========================================================

# ----------------- Stage 1: Builder -----------------
FROM python:3.11-slim AS builder

WORKDIR /build

# Install build dependencies required for compiling binary wheels (e.g. bcrypt, Pillow)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    default-libmysqlclient-dev \
    pkg-config \
    gcc \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# Build wheels in a wheels cache folder
RUN pip install --no-cache-dir --upgrade pip && \
    pip wheel --no-cache-dir --no-deps --wheel-dir /build/wheels -r requirements.txt


# ----------------- Stage 2: Final Runtime -----------------
FROM python:3.11-slim AS final

# Standard Python container environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=5000 \
    HOST=0.0.0.0 \
    APP_HOME=/app

WORKDIR ${APP_HOME}

# Install minimal runtime shared libraries and curl for health checks
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    libjpeg62-turbo \
    zlib1g \
    && rm -rf /var/lib/apt/lists/*

# Install python dependencies from wheels built in Stage 1
COPY --from=builder /build/wheels /wheels
COPY requirements.txt .
RUN pip install --no-cache-dir --no-index --find-links=/wheels -r requirements.txt && \
    rm -rf /wheels

# Create dedicated non-root user and group for security compliance
RUN groupadd -g 10001 cemsgroup && \
    useradd -u 10001 -g cemsgroup -s /bin/bash -m cemsuser

# Copy application code into container
COPY --chown=cemsuser:cemsgroup app.py config.py init_db.py wsgi.py gunicorn.conf.py ./
COPY --chown=cemsuser:cemsgroup templates/ ./templates/
COPY --chown=cemsuser:cemsgroup static/ ./static/
COPY --chown=cemsuser:cemsgroup certs/ ./certs/

# Switch to non-root user
USER cemsuser:cemsgroup

# Expose internal application port
EXPOSE 5000

# Container healthcheck using the lightweight /health endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -f http://127.0.0.1:5000/health || exit 1

# Production start command using Gunicorn
CMD ["gunicorn", "--config", "gunicorn.conf.py", "wsgi:app"]
