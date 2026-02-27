#!/usr/bin/env bash
# Pix3lTools Deploy - One-click setup script
# Installs and initializes the full stack: pix3lboard + pix3lwiki + sqld
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TURSO_URL="http://localhost:8080"
TURSO_TOKEN="dummy"
SETUP_TMPDIR=$(mktemp -d)
trap 'rm -rf "$SETUP_TMPDIR"' EXIT

echo ""
echo "========================================="
echo "  Pix3lTools Deploy - One-click Setup"
echo "========================================="
echo ""

# --- 0. Ensure enough memory (create swap if needed) ---
TOTAL_MEM_MB=$(free -m | awk '/^Mem:/{print $2}')
TOTAL_SWAP_MB=$(free -m | awk '/^Swap:/{print $2}')
TOTAL_AVAILABLE_MB=$(( TOTAL_MEM_MB + TOTAL_SWAP_MB ))

if [ "$TOTAL_AVAILABLE_MB" -lt 1800 ]; then
  echo "[0/8] Low memory detected (${TOTAL_MEM_MB}MB RAM, ${TOTAL_SWAP_MB}MB swap)."
  if [ ! -f /swapfile ]; then
    echo "  Creating 1GB swapfile..."
    if fallocate -l 1G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=1024 status=none; then
      chmod 600 /swapfile
      mkswap /swapfile > /dev/null
      swapon /swapfile
      echo "  Swap enabled."
    else
      echo "  WARNING: Could not create swap (try running as root). npm ci may be killed on low RAM."
    fi
  else
    echo "  /swapfile already exists, enabling..."
    swapon /swapfile 2>/dev/null || true
    echo "  Swap enabled."
  fi
fi

# --- 1. Check prerequisites ---
echo "[1/8] Checking prerequisites..."

missing=()
for cmd in docker git node npm curl; do
  if ! command -v "$cmd" &> /dev/null; then
    missing+=("$cmd")
  fi
done

if ! docker compose version &> /dev/null 2>&1; then
  missing+=("docker-compose-plugin")
fi

if [ ${#missing[@]} -gt 0 ]; then
  echo "ERROR: Missing required tools: ${missing[*]}"
  echo ""
  echo "Install them first. See README.md for instructions."
  exit 1
fi

echo "  All prerequisites found."

# --- 2. Create .env if missing ---
echo "[2/8] Configuring environment..."

if [ ! -f "$SCRIPT_DIR/.env" ]; then
  JWT_SECRET=$(openssl rand -base64 48)
  echo "JWT_SECRET=$JWT_SECRET" > "$SCRIPT_DIR/.env"
  echo "  Created .env with auto-generated JWT_SECRET"
else
  echo "  .env already exists, keeping existing configuration"
fi
chmod 600 "$SCRIPT_DIR/.env"
echo "  Secured .env permissions (600)"

# --- 3. Prompt for admin credentials ---
echo "[3/8] Setting up admin account..."
echo ""

read -rp "  Admin email [admin@example.com]: " ADMIN_EMAIL
ADMIN_EMAIL=${ADMIN_EMAIL:-admin@example.com}

while true; do
  read -rsp "  Admin password (min 8 chars): " ADMIN_PASSWORD
  echo ""
  if [ ${#ADMIN_PASSWORD} -lt 8 ]; then
    echo "  Password must be at least 8 characters. Try again."
  else
    read -rsp "  Confirm password: " ADMIN_PASSWORD_CONFIRM
    echo ""
    if [ "$ADMIN_PASSWORD" != "$ADMIN_PASSWORD_CONFIRM" ]; then
      echo "  Passwords do not match. Try again."
    else
      break
    fi
  fi
done

echo ""

# --- 4. Start Docker Compose stack ---
echo "[4/8] Starting Docker Compose stack..."

cd "$SCRIPT_DIR"
docker compose up -d

echo "  Containers started."

# --- 5. Wait for sqld ---
echo "[5/8] Waiting for sqld to be ready..."

for i in $(seq 1 30); do
  if curl -sf "$TURSO_URL/health" > /dev/null 2>&1 || \
     curl -sf "$TURSO_URL/" > /dev/null 2>&1; then
    echo "  sqld is ready."
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo ""
    echo "ERROR: sqld failed to start within 60 seconds."
    echo "Check logs with: docker compose logs sqld"
    exit 1
  fi
  sleep 2
done

# --- 6. Initialize databases ---
echo "[6/8] Initializing databases (this may take a minute)..."

# Load JWT_SECRET for pix3lwiki init
source "$SCRIPT_DIR/.env"

# pix3lboard
echo "  Setting up pix3lboard database..."
git clone --depth 1 --quiet https://github.com/Pix3ltools-lab/pix3lboard.git "$SETUP_TMPDIR/pix3lboard"
cd "$SETUP_TMPDIR/pix3lboard"
npm ci --silent 2>/dev/null
TURSO_DATABASE_URL="$TURSO_URL" TURSO_AUTH_TOKEN="$TURSO_TOKEN" \
  E2E_USER_EMAIL="$ADMIN_EMAIL" E2E_USER_PASSWORD="$ADMIN_PASSWORD" \
  bash scripts/db-init.sh

# pix3lwiki
echo "  Setting up pix3lwiki database..."
git clone --depth 1 --quiet https://github.com/Pix3ltools-lab/pix3lwiki.git "$SETUP_TMPDIR/pix3lwiki"
cd "$SETUP_TMPDIR/pix3lwiki"
npm ci --silent 2>/dev/null
TURSO_DATABASE_URL="$TURSO_URL" TURSO_AUTH_TOKEN="$TURSO_TOKEN" \
  JWT_SECRET="$JWT_SECRET" \
  E2E_USER_EMAIL="$ADMIN_EMAIL" E2E_USER_PASSWORD="$ADMIN_PASSWORD" \
  bash scripts/db-init.sh

# --- 7/8. Done ---
cd "$SCRIPT_DIR"

echo ""
echo "========================================="
echo "  Setup complete!"
echo "========================================="
echo ""
echo "  Pix3lBoard:   http://localhost:3000"
echo "  Pix3lWiki:    http://localhost:3001"
echo "  Pix3lPrompt:  http://localhost:3002"
echo ""
echo "  Login with:  $ADMIN_EMAIL"
echo ""
echo "  Deploying on a remote server? Enable HTTPS next:"
echo "    ./setup-https.sh"
echo ""
echo "  Useful commands:"
echo "    docker compose ps        # Check status"
echo "    docker compose logs -f   # View logs"
echo "    docker compose down      # Stop (data preserved)"
echo ""
