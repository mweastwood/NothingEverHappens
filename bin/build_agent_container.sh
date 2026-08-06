#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${1:-antigravity-agent:latest}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Building Antigravity Agent Docker container image: ${IMAGE_NAME}..."
docker build -t "${IMAGE_NAME}" -f "${SCRIPT_DIR}/docker/Dockerfile" "${SCRIPT_DIR}/docker"

echo "Build complete!"
echo "Run an agent review container with: bin/run_agent_container.sh <PR_NUMBER>"
