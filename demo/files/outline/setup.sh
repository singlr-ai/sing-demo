#!/bin/bash
set -euo pipefail

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

export PATH="$HOME/.local/bin:$PATH"
corepack enable --install-directory ~/.local/bin yarn

cd ~/workspace/outline

echo "==> Outline Dev Environment Setup"
echo

# Generate secrets automatically
SECRET_KEY=$(openssl rand -hex 32)
UTILS_SECRET=$(openssl rand -hex 32)

# Defaults — match sing.yaml Postgres config (superuser=dev, db=outline)
PG_ADMIN="dev"
DB_USER="dev"
DB_PASS="dev"
DB_NAME="outline"
DB_HOST="localhost"
DB_PORT="5432"
REDIS_HOST="localhost"
REDIS_PORT="6379"
PORT="3000"

# Let user customize if they want
read -rp "  App port [${PORT}]: " input && PORT="${input:-$PORT}"
read -rp "  Database name [${DB_NAME}]: " input && DB_NAME="${input:-$DB_NAME}"

echo
echo "==> Ensuring database exists..."
podman exec postgres psql -U "${PG_ADMIN}" -d postgres -tc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1 \
  || podman exec postgres psql -U "${PG_ADMIN}" -d postgres -c "CREATE DATABASE ${DB_NAME};"
echo "    Database '${DB_NAME}' ready"

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
export COREPACK_ENABLE_AUTO_PIN=0
yarn install --immutable

echo "==> Building Outline (required before migrations)..."
yarn build

echo "==> Running database migrations..."
yarn db:create --env=development 2>/dev/null || true
yarn db:migrate --env=development

echo
echo "==> Done! Start the dev server with:"
echo "    cd ~/workspace/outline && yarn dev"

