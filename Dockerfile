# STAGE 1: Build dependencies
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim AS builder

WORKDIR /app

# Install build dependencies (needed for PostgreSQL drivers)
RUN apt-get update && apt-get install -y --no-install-recommends \
	build-essential \
	libpq-dev \
	&& rm -rf /var/lib/apt/lists/*

# Copy requirements file
COPY requirements.txt .

# Create and activate a virtual environment
RUN python -m venv /venv
ENV PATH="/venv/bin:$PATH"

# Install dependencies with caching
ENV UV_LINK_MODE=copy
RUN uv pip install --no-cache -r requirements.txt

# STAGE 2: Runtime
FROM python:3.12-slim-bookworm AS runtime

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
	libpq5 \
	&& rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PATH="/venv/bin:$PATH"

# Copy virtual environment from builder stage
COPY --from=builder /venv /venv

# Copy application code
COPY app/ app/
COPY data/ data/
COPY alembic.ini .
COPY entrypoint.sh .

RUN chmod +x /entrypoint.sh
# Use ENTRYPOINT to run the script
ENTRYPOINT ["/entrypoint.sh"]
