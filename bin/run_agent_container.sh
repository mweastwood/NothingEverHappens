#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "Usage: $0 [AGENT_NAME] <PROMPT>"
  echo "Examples:"
  echo "  $0 code_reviewer \"Review PR #427\""
  echo "  $0 \"Review PR #427\""
  exit 1
fi

# Determine if first argument specifies an agent or is the prompt
AGENT_NAME="${DEFAULT_AGENT:-code_reviewer}"
PROMPT=""

if [ "$#" -ge 2 ]; then
  AGENT_NAME="$1"
  shift
  PROMPT="$*"
else
  PROMPT="$1"
fi

IMAGE_NAME="${ANTIGRAVITY_IMAGE:-antigravity-agent:latest}"
WORKSPACE_DIR="$(pwd)"

echo "Starting sandboxed Antigravity Agent container (Agent: ${AGENT_NAME})..."

docker run --rm \
  -v "${HOME}/.gemini/antigravity-cli:/root/.gemini/antigravity-cli:ro" \
  -v "${WORKSPACE_DIR}:/workspace" \
  -w /workspace \
  -e GITHUB_TOKEN="$(gh auth token 2>/dev/null || echo "")" \
  --security-opt=no-new-privileges \
  "${IMAGE_NAME}" \
  agy --agent "${AGENT_NAME}" --dangerously-skip-permissions --log-file /dev/stderr --prompt "${PROMPT}"
