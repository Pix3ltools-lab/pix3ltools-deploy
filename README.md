# Pix3lTools Deploy

Docker deployment for the Pix3lTools stack: **Pix3lBoard** (Kanban) + **Pix3lWiki** (Wiki) + **sqld** (SQLite database).

## Prerequisites

### Docker

**Linux:**
```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Log out and back in for group changes to take effect
```

**macOS / Windows:**
Download and install [Docker Desktop](https://www.docker.com/products/docker-desktop/).

Verify the installation:
```bash
docker --version
docker compose version
```

### Node.js (required for database initialization)

**Linux:**
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
```

**macOS:**
```bash
brew install node@20
```

**Windows:**
Download the installer from [nodejs.org](https://nodejs.org/).

Verify the installation:
```bash
node --version   # v20 or higher
npm --version
```

### Git

Git is required to clone the repositories. Install it from [git-scm.com](https://git-scm.com/) if not already available:
```bash
git --version
```

## Quick Start

### Local machine (WSL, macOS, Linux)

```bash
git clone https://github.com/Pix3ltools-lab/pix3ltools-deploy.git
cd pix3ltools-deploy
./setup.sh
```

`setup.sh` checks prerequisites, generates a secure `.env`, prompts for admin credentials, starts the Docker stack, and initializes the databases automatically.

Open in browser: `http://localhost:3000` (Pix3lBoard) and `http://localhost:3001` (Pix3lWiki).

### VPS / Remote server

```bash
git clone https://github.com/Pix3ltools-lab/pix3ltools-deploy.git
cd pix3ltools-deploy
./setup.sh
./setup-https.sh
```

HTTPS is required on remote servers: without it, browser security policy blocks authentication cookies and data is never persisted. `setup-https.sh` configures Traefik as a reverse proxy with automatic Let's Encrypt certificates.

`setup-https.sh` will ask:
1. **Domain type** — custom domain (e.g. `board.example.com`) or [sslip.io](https://sslip.io) (no domain needed, derives one from the server IP automatically)
2. **Email** — for Let's Encrypt certificate notifications

It then generates a `docker-compose.override.yml` with the Traefik configuration and restarts the stack. Certificates are issued automatically on first access.

## Manual Setup

```bash
# 1. Clone this repo
git clone https://github.com/Pix3ltools-lab/pix3ltools-deploy.git
cd pix3ltools-deploy

# 2. Create .env file
cp .env.example .env
# Edit .env and set a strong JWT_SECRET (minimum 32 characters)

# 3. Start the stack
docker compose up -d

# 4. Initialise the databases (first run only)
# Clone pix3lboard repo for the db-init script:
git clone https://github.com/Pix3ltools-lab/pix3lboard.git /tmp/pix3lboard
TURSO_DATABASE_URL=http://localhost:8080 TURSO_AUTH_TOKEN=dummy \
  E2E_USER_EMAIL=admin@example.com E2E_USER_PASSWORD=YourPassword123 \
  bash /tmp/pix3lboard/scripts/db-init.sh

# Clone pix3lwiki repo for its db-init script:
git clone https://github.com/Pix3ltools-lab/pix3lwiki.git /tmp/pix3lwiki
source .env
TURSO_DATABASE_URL=http://localhost:8080 TURSO_AUTH_TOKEN=dummy JWT_SECRET="$JWT_SECRET" \
  E2E_USER_EMAIL=admin@example.com E2E_USER_PASSWORD=YourPassword123 \
  bash /tmp/pix3lwiki/scripts/db-init.sh

# 5. Open in browser
# Pix3lBoard: http://localhost:3000
# Pix3lWiki:  http://localhost:3001
```

## Services

| Service | Port | Description |
|---------|------|-------------|
| pix3lboard | 3000 | Kanban board with drag & drop, calendar, analytics |
| pix3lwiki | 3001 | Wiki with markdown editor, versioning, categories |
| sqld | 8080 | LibSQL database server (SQLite compatible) |
| watchtower | — | Checks for updated images every hour and redeploys automatically |

On VPS deployments (after running `setup-https.sh`), a `traefik` container is also added. It handles HTTPS termination and routes traffic from ports 80/443 to the apps.

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `JWT_SECRET` | Shared secret for JWT authentication (min 32 chars) | Yes |

## Updating

Container images are updated automatically by **Watchtower**, which checks for new versions every hour and redeploys changed containers without manual intervention.

To update manually:

```bash
docker compose pull
docker compose up -d
```

## Data

- **Database**: stored in the `db-data` Docker volume
- **File uploads** (pix3lboard): stored in the `blob-storage` Docker volume

To back up:
```bash
docker compose cp sqld:/var/lib/sqld ./backup-db
docker compose cp pix3lboard:/data/blob-storage ./backup-blobs
```

## Stopping

```bash
# Stop containers (data preserved)
docker compose down

# Stop and delete all data
docker compose down -v
```

## Building Images

Images are built and published to GitHub Container Registry via the **Build and Push** workflow. Trigger it manually from the Actions tab:

1. Go to **Actions** → **Build and Push Docker Images**
2. Click **Run workflow**
3. Enter the git ref (tag or branch) for each app
4. Images are pushed to `ghcr.io/pix3ltools-lab/pix3lboard` and `ghcr.io/pix3ltools-lab/pix3lwiki`

## E2E Testing

An automated end-to-end test verifies the full deployment stack. It runs automatically after a successful **Build and Push** workflow, or you can trigger it manually:

1. Go to **Actions** → **E2E Deploy Test**
2. Click **Run workflow**

The test spins up the entire stack on the CI runner and checks:

- All 3 containers start and stay running
- sqld responds to SQL queries
- Database initialization scripts complete successfully
- Login works on both Pix3lBoard and Pix3lWiki
- Protected API endpoints reject unauthenticated requests
- Data persists across a `docker compose down` / `up` cycle

If any step fails, container logs are collected automatically for debugging.

## Related Repos

- [pix3lboard](https://github.com/Pix3ltools-lab/pix3lboard) — Kanban board source
- [pix3lwiki](https://github.com/Pix3ltools-lab/pix3lwiki) — Wiki source
