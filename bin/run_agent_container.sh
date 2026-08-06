#!/usr/bin/env bash
set -euo pipefail

PR_NUMBER="${1:-}"
if [ -z "${PR_NUMBER}" ]; then
  echo "Usage: $0 <PR_NUMBER>"
  exit 1
fi

IMAGE_NAME="${ANTIGRAVITY_IMAGE:-antigravity-agent:latest}"
WORKSPACE_DIR="$(pwd)"

echo "Starting sandboxed Antigravity Agent container for PR #${PR_NUMBER}..."

docker run --rm \
  -v "${HOME}/.gemini/antigravity-cli:/root/.gemini/antigravity-cli:ro" \
  -v "${WORKSPACE_DIR}:/workspace" \
  -w /workspace \
  -e GITHUB_TOKEN="$(gh auth token 2>/dev/null || echo "")" \
  --security-opt=no-new-privileges \
  "${IMAGE_NAME}" \
  agy --agent code_reviewer --dangerously-skip-permissions --log-file /dev/stderr --prompt "Review PR #${PR_NUMBER}"
