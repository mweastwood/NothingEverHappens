#!/usr/bin/env bash
set -euo pipefail

# Read WEBHOOK_PROXY_URL from environment or ~/.bashrc if set
if [ -z "${WEBHOOK_PROXY_URL:-}" ]; then
  WEBHOOK_PROXY_URL="$(grep -i "WEBHOOK_PROXY_URL=" ~/.bashrc 2>/dev/null | cut -d'=' -f2- | tr -d '"' | tr -d "'" || true)"
fi

if [ -z "${WEBHOOK_PROXY_URL:-}" ]; then
  echo "Error: WEBHOOK_PROXY_URL is not set in your environment or ~/.bashrc"
  echo "Example: export WEBHOOK_PROXY_URL=https://smee.io/your-channel-id"
  exit 1
fi

TARGET_URL="${1:-http://localhost:8000/webhook}"

echo "Starting Smee listener proxying from ${WEBHOOK_PROXY_URL} -> ${TARGET_URL}..."
exec npx smee -u "${WEBHOOK_PROXY_URL}" -t "${TARGET_URL}"
