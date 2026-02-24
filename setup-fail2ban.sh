#!/usr/bin/env bash
# Pix3lTools Deploy - fail2ban setup for Traefik access logs
# Must be run as root on the VPS host, after setup-https.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "========================================="
echo "  Pix3lTools Deploy - fail2ban Setup"
echo "========================================="
echo ""

# --- 0. Root check ---
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: This script must be run as root (sudo ./setup-fail2ban.sh)."
  exit 1
fi

# --- 1. Log path ---
echo "[1/5] Configure Traefik access log path"
echo ""
DEFAULT_LOG="$SCRIPT_DIR/logs/access.log"
read -rp "  Traefik access log path [$DEFAULT_LOG]: " LOG_PATH
LOG_PATH="${LOG_PATH:-$DEFAULT_LOG}"
echo ""

if [ ! -f "$LOG_PATH" ]; then
  echo "  WARNING: $LOG_PATH not found."
  echo "  Make sure setup-https.sh has been run and the stack is running."
  echo "  fail2ban will be configured for that path and will activate once logs appear."
  echo ""
fi

# --- 2. Install fail2ban ---
echo "[2/5] Installing fail2ban..."

if command -v fail2ban-server &> /dev/null; then
  echo "  fail2ban already installed: $(fail2ban-server --version 2>&1 | head -1)"
else
  if command -v apt-get &> /dev/null; then
    apt-get update -q && apt-get install -y -q fail2ban
  elif command -v dnf &> /dev/null; then
    dnf install -y fail2ban
  elif command -v yum &> /dev/null; then
    yum install -y fail2ban
  else
    echo "ERROR: No supported package manager found (apt/dnf/yum)."
    echo "Install fail2ban manually then re-run this script."
    exit 1
  fi
  echo "  fail2ban installed."
fi

# --- 3. Custom Docker-aware ban action ---
echo "[3/5] Creating Docker-aware ban action..."

# NOTE: fail2ban's default iptables action writes to the INPUT chain.
# Docker forwards container traffic via the FORWARD chain (after DNAT), so
# INPUT rules are bypassed. The DOCKER-USER chain is the correct insertion
# point: Docker processes it before its own FORWARD rules, and it persists
# across Docker restarts (Docker flushes FORWARD but not DOCKER-USER).
cat > /etc/fail2ban/action.d/iptables-docker.conf <<'ACTION'
# fail2ban action: ban via DOCKER-USER chain (required for Docker deployments)
# The standard INPUT chain is bypassed by Docker's DNAT/FORWARD rules.

[Definition]
actionstart = iptables  -N  f2b-traefik 2>/dev/null || true
              iptables  -I  DOCKER-USER -j f2b-traefik 2>/dev/null || true
              ip6tables -N  f2b-traefik 2>/dev/null || true
              ip6tables -I  DOCKER-USER -j f2b-traefik 2>/dev/null || true

actionstop  = iptables  -D  DOCKER-USER -j f2b-traefik 2>/dev/null || true
              iptables  -F  f2b-traefik 2>/dev/null || true
              iptables  -X  f2b-traefik 2>/dev/null || true
              ip6tables -D  DOCKER-USER -j f2b-traefik 2>/dev/null || true
              ip6tables -F  f2b-traefik 2>/dev/null || true
              ip6tables -X  f2b-traefik 2>/dev/null || true

actionban   = iptables  -I f2b-traefik 1 -s <ip> -j DROP 2>/dev/null || true
              ip6tables -I f2b-traefik 1 -s <ip> -j DROP 2>/dev/null || true

actionunban = iptables  -D f2b-traefik -s <ip> -j DROP 2>/dev/null || true
              ip6tables -D f2b-traefik -s <ip> -j DROP 2>/dev/null || true
ACTION

echo "  Created /etc/fail2ban/action.d/iptables-docker.conf"

# --- 4. Traefik filters ---
echo "[4/5] Creating Traefik log filters..."

# Filter: login brute force
# Traefik CLF format: <ip> - - [date] "METHOD path proto" status bytes ... router service duration
cat > /etc/fail2ban/filter.d/traefik-auth.conf <<'FILTER'
# fail2ban filter: Traefik login endpoint brute force
# Triggers on: POST /api/auth/login → HTTP 401 (wrong password)

[Definition]
failregex = ^<HOST> - - \[.+\] "POST /api/auth/login\S* HTTP/\S+" 401 .*$
ignoreregex =
FILTER

# Filter: general 4xx scanner/abuse
# Ignores missing static assets (404 on .ico/.png/etc.) to avoid false positives
# from legitimate browsers requesting missing favicons etc.
cat > /etc/fail2ban/filter.d/traefik-4xx.conf <<'FILTER'
# fail2ban filter: Traefik general 4xx scanner/abuse
# Triggers on: any 4xx response (scanners, path traversal, probing)

[Definition]
failregex = ^<HOST> - - \[.+\] "[A-Z]+ \S+ HTTP/\S+" 4[0-9][0-9] .*$
ignoreregex = ^<HOST> - - \[.+\] "GET /[^"]*\.(ico|png|jpg|jpeg|gif|svg|css|js|woff2?|ttf|eot|map) HTTP/\S+" 404 .*$
FILTER

echo "  Created /etc/fail2ban/filter.d/traefik-auth.conf"
echo "  Created /etc/fail2ban/filter.d/traefik-4xx.conf"

# --- 5. Jail configuration ---
echo "[5/5] Creating jail configuration..."

cat > /etc/fail2ban/jail.d/pix3ltools.conf <<JAIL
# fail2ban jail: Pix3lTools (Pix3lBoard + Pix3lWiki via Traefik)
# Reads from the Traefik access log written to the host-mounted ./logs/ volume.
# Ban action targets DOCKER-USER chain — required because Docker bypasses INPUT.

[traefik-auth]
enabled  = true
filter   = traefik-auth
action   = iptables-docker
logpath  = $LOG_PATH
maxretry = 5
findtime = 300
bantime  = 3600
# 5 failed logins in 5 minutes → banned for 1 hour

[traefik-4xx]
enabled  = true
filter   = traefik-4xx
action   = iptables-docker
logpath  = $LOG_PATH
maxretry = 50
findtime = 60
bantime  = 600
# 50 4xx errors in 1 minute → banned for 10 minutes
JAIL

echo "  Created /etc/fail2ban/jail.d/pix3ltools.conf"

# --- Enable and start ---
systemctl enable fail2ban
systemctl restart fail2ban

echo ""
echo "  Waiting for fail2ban to start..."
sleep 3

echo ""
echo "========================================="
echo "  fail2ban setup complete!"
echo "========================================="
echo ""
echo "  Log file monitored: $LOG_PATH"
echo ""

# Show jail status
if fail2ban-client ping &>/dev/null; then
  echo "  Active jails:"
  fail2ban-client status 2>/dev/null | grep -E "(Jail|Socket)" || true
else
  echo "  WARNING: fail2ban did not respond. Check: systemctl status fail2ban"
fi

echo ""
echo "  Useful commands:"
echo "    fail2ban-client status                        # list active jails"
echo "    fail2ban-client status traefik-auth           # auth jail (bans + failures)"
echo "    fail2ban-client status traefik-4xx            # scanner jail"
echo "    fail2ban-client set traefik-auth unbanip <ip> # manual unban"
echo "    tail -f /var/log/fail2ban.log                 # live activity"
echo ""
echo "  Verify bans are applied to DOCKER-USER chain:"
echo "    iptables -L f2b-traefik -n --line-numbers"
echo ""
