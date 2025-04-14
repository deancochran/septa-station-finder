#!/bin/bash
set -e

# Run database migrations first
echo "Running database migrations..."
alembic upgrade head

# Then start the FastAPI application
echo "Starting FastAPI application..."
exec fastapi run app/api/main.py --host 0.0.0.0 --port 8000
