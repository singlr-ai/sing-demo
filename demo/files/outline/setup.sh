#!/bin/bash
set -euo pipefail

cd ~/workspace/outline

echo "==> Outline Dev Environment Setup"
echo

# Generate secrets automatically
SECRET_KEY=$(openssl rand -hex 32)
UTILS_SECRET=$(openssl rand -hex 32)

# Defaults for our Podman-based setup
DB_USER="outline"
DB_PASS="outline"
DB_NAME="outline"
DB_HOST="localhost"
DB_PORT="5432"
REDIS_HOST="localhost"
REDIS_PORT="6379"
PORT="3000"

# Let user customize if they want
read -rp "  App port [${PORT}]: " input && PORT="${input:-$PORT}"
read -rp "  Postgres user [${DB_USER}]: " input && DB_USER="${input:-$DB_USER}"
read -rp "  Postgres password [${DB_PASS}]: " input && DB_PASS="${input:-$DB_PASS}"
read -rp "  Database name [${DB_NAME}]: " input && DB_NAME="${input:-$DB_NAME}"

echo
echo "==> Creating Postgres user and database..."
podman exec postgres psql -U postgres -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';" 2>/dev/null || echo "    User already exists"
podman exec postgres psql -U postgres -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};" 2>/dev/null || echo "    Database already exists"

echo "==> Generating .env..."
cat > .env << EOF
NODE_ENV=development
URL=http://localhost:${PORT}
PORT=${PORT}
WEB_CONCURRENCY=1

SECRET_KEY=${SECRET_KEY}
UTILS_SECRET=${UTILS_SECRET}

DATABASE_URL=postgres://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}
DATABASE_CONNECTION_POOL_MIN=0
DATABASE_CONNECTION_POOL_MAX=5
PGSSLMODE=disable

REDIS_URL=redis://${REDIS_HOST}:${REDIS_PORT}

DEFAULT_LANGUAGE=en_US
RATE_LIMITER_ENABLED=true
RATE_LIMITER_REQUESTS=1000
RATE_LIMITER_DURATION_WINDOW=60

ENABLE_UPDATES=false
DEBUG=http
LOG_LEVEL=info
EOF
echo "    .env written"

echo "==> Installing Node.js dependencies..."
yarn install --frozen-lockfile

echo "==> Running database migrations..."
yarn db:create --env=development 2>/dev/null || true
yarn db:migrate --env=development

echo
echo "==> Done! Start the dev server with:"
echo "    cd ~/workspace/outline && yarn dev"

