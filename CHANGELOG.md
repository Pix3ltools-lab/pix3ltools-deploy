# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.1.0] - 2026-03-10

### Added

- **Pix3lMCP service** — Added `pix3lmcp` (MCP server for pix3lboard REST API v1) to the Docker Compose stack on port 3010; depends on `pix3lboard`
- **MCP credentials in `setup.sh`** — New interactive step `[4/9]` collects MCP account email, password and workspace IDs; variables are written to `.env` with upsert logic (safe to re-run)
- **MCP domain in `setup-https.sh`** — Prompts for a dedicated MCP domain (custom or sslip.io auto-generated); adds `pix3lmcp` Traefik router with TLS and rate-limit middleware to the generated `docker-compose.override.yml`; prints `claude mcp add` registration command in the summary
- **MCP health check in `smoke-test.sh`** — New check on `GET /api/health` (port 3010); accepts optional second positional argument `[mcp_url]`
- **`pix3lmcp` in CI workflow** — `build-and-push.yml` now includes a `pix3lmcp_ref` input and a parallel `build-pix3lmcp` job that pushes to `ghcr.io/pix3ltools-lab/pix3lmcp`

### Changed

- **`setup.sh` step numbering** — All steps renumbered from `/8` to `/9` to accommodate the new MCP credentials step
- **README** — Updated to document pix3lmcp in the intro, Quick Start URLs, services table, environment variables, building images section and related repos

---

## [1.0.0] - 2026-02-27

### Added

- **Full Pix3lTools stack** — Docker Compose deployment for Pix3lBoard (Kanban, port 3000), Pix3lWiki (Wiki, port 3001), Pix3lPrompt (AI prompt editor, port 3002) and sqld (LibSQL database, port 8080)
- **Pix3lPrompt service** — Added pix3lprompt to the stack as a stateless container (no database, no volumes); `PIX3LPROMPT_URL` env var wired to pix3lboard for CORS
- **`setup.sh`** — Interactive setup: checks prerequisites (Docker, Node.js), generates a secure `.env` with random `JWT_SECRET`, prompts for admin credentials, starts the stack and initializes both databases automatically
- **`setup-https.sh`** — Configures Traefik as HTTPS reverse proxy with automatic Let's Encrypt certificates; generates `docker-compose.override.yml` with per-service domain routing, rate limiting middleware and TLS resolver
- **`setup-fail2ban.sh`** — Installs and configures fail2ban to protect against brute-force attacks and port scanners; monitors Traefik access log with a custom filter and jail
- **Watchtower** — Automatic image update monitor (monitor-only mode, notifications only — no automatic restarts in production)
- **Traefik rate limiting** — Global rate limit middleware applied to all HTTP routers to mitigate abuse
- **Smoke test** — `smoke-test.sh` validates that all containers are up and healthy after deployment; includes force-dynamic and `__PIX3L_CONFIG__` endpoint checks
- **CI workflow** — GitHub Actions E2E deployment test on every push
- **Security hardening** — `.env` file created with `chmod 600`; generated `docker-compose.override.yml` protected the same way
- **Documentation** — `README.md` with quick-start for local and VPS deployments; `TROUBLESHOOTING.md` for common issues; `CONTRIBUTING.md` with contribution guidelines; `MIT LICENSE`
