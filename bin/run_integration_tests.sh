#!/bin/bash
set -e

# Get the directory of this script (repository root/bin)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( dirname "$SCRIPT_DIR" )"

echo "=== Starting Chromedriver ==="
chromedriver --port=4444 &
CHROMEDRIVER_PID=$!

# Wait for chromedriver to initialize
sleep 2

# Ensure chromedriver is killed when the script exits
cleanup() {
    echo "=== Shutting down Chromedriver ==="
    kill $CHROMEDRIVER_PID 2>/dev/null || true
}
trap cleanup EXIT

echo "=== Running Flutter Integration Tests against Local Emulator Suite (Chrome Headless Release) ==="

# Navigate to backend directory to run the emulator exec command
cd "$REPO_ROOT/backend"

# Execute the flutter test inside the emulator environment using flutter drive on chrome
npx firebase emulators:exec --only firestore,auth "cd \"$REPO_ROOT/app\" && flutter drive --release --driver=test_driver/integration_test.dart --target=integration_test/security_rules_test.dart -d chrome --web-browser-flag=\"--headless=new\" --web-browser-flag=\"--disable-gpu\" --web-browser-flag=\"--no-sandbox\""
