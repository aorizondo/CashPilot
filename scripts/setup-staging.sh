#!/usr/bin/env bash
# Bootstrap CashPilot on a fresh staging VPS in one shot.
# Idempotent: rerun to update the working tree, rebuild and restart.
#
#   bash scripts/setup-staging.sh [--branch <name>] [--repo <url>] [--ui-port 18080] [--worker-port 18081]
#
# Defaults: branch=local/spec-editor, repo=https://github.com/aorizondo/CashPilot.git,
#           UI port 18080, worker port 18081, install dir /opt/cashpilot.
#
# Sets CASHPILOT_PUBLIC_SETUP=1 so the first /register is reachable from a
# public URL (no SSH tunnel). Disable for production by removing the flag and
# rebuilding.

set -euo pipefail

REPO="https://github.com/aorizondo/CashPilot.git"
BRANCH="local/spec-editor"
UI_PORT=18080
WORKER_PORT=18081
INSTALL_DIR=/opt/cashpilot

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    --ui-port) UI_PORT="$2"; shift 2 ;;
    --worker-port) WORKER_PORT="$2"; shift 2 ;;
    --dir) INSTALL_DIR="$2"; shift 2 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

echo ">> install dir: $INSTALL_DIR"
echo ">> repo:        $REPO"
echo ">> branch:      $BRANCH"
echo ">> ports:       UI=$UI_PORT worker=$WORKER_PORT"

if [[ -d "$INSTALL_DIR/.git" ]]; then
  echo ">> repo exists — fetching latest"
  git -C "$INSTALL_DIR" fetch --depth 1 origin "$BRANCH"
  git -C "$INSTALL_DIR" checkout "$BRANCH"
  git -C "$INSTALL_DIR" reset --hard "origin/$BRANCH"
else
  echo ">> cloning"
  git clone --depth 1 -b "$BRANCH" "$REPO" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"

if [[ ! -f .env ]]; then
  echo ">> generating .env"
  FERNET=$(python3 -c "import base64,os; print(base64.urlsafe_b64encode(os.urandom(32)).decode())")
  APIKEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(40))")
  cat > .env <<EOF
TZ=UTC
CASHPILOT_SECRET_KEY=$FERNET
CASHPILOT_API_KEY=$APIKEY
CASHPILOT_PUBLIC_SETUP=1
EOF
  chmod 600 .env
else
  echo ">> .env exists — leaving it alone"
  # Ensure the public-setup flag is present so /register is reachable
  grep -q '^CASHPILOT_PUBLIC_SETUP=' .env || echo 'CASHPILOT_PUBLIC_SETUP=1' >> .env
fi

cat > docker-compose.override.yml <<EOF
services:
  cashpilot-ui:
    image: cashpilot-ui:local
    build:
      context: .
      dockerfile: Dockerfile
    environment:
      - CASHPILOT_PUBLIC_SETUP=\${CASHPILOT_PUBLIC_SETUP:-0}
    ports: !override
      - "$UI_PORT:8080"
  cashpilot-worker:
    image: cashpilot-worker:local
    build:
      context: .
      dockerfile: Dockerfile.worker
    ports: !override
      - "$WORKER_PORT:8081"
EOF

echo ">> building images"
docker compose -f docker-compose.fleet.yml -f docker-compose.override.yml build

echo ">> restarting stack"
docker compose -f docker-compose.fleet.yml -f docker-compose.override.yml up -d --force-recreate

sleep 4
docker compose -f docker-compose.fleet.yml -f docker-compose.override.yml ps

HOST=$(hostname -f 2>/dev/null || hostname)
echo
echo "============================================"
echo "  CashPilot staging is up."
echo "  UI:     http://$HOST:$UI_PORT/"
echo "  Setup:  http://$HOST:$UI_PORT/register"
echo "  Worker: http://$HOST:$WORKER_PORT/"
echo
echo "  First-run /register is reachable from any IP because"
echo "  CASHPILOT_PUBLIC_SETUP=1 is set in .env. Remove that"
echo "  line before treating this instance as production."
echo "============================================"
