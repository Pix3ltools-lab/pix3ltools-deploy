# Pix3lTools Deploy

Docker deployment for the Pix3lTools stack: **Pix3lBoard** (Kanban) + **Pix3lWiki** (Wiki) + **sqld** (SQLite database).

## Quick Start

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

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `JWT_SECRET` | Shared secret for JWT authentication (min 32 chars) | Yes |

## Updating

```bash
# Pull latest images
docker compose pull

# Restart with new images
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

## Related Repos

- [pix3lboard](https://github.com/Pix3ltools-lab/pix3lboard) — Kanban board source
- [pix3lwiki](https://github.com/Pix3ltools-lab/pix3lwiki) — Wiki source
