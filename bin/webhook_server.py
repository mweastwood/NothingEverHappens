#!/usr/bin/env python3
"""
GitHub Webhook Server for Antigravity Code Reviewer Agent.

Listens for GitHub webhook events (e.g. pull_request, issue_comment)
and triggers the sandboxed Antigravity agent container in response.

Uses standard Python library only (0 external dependencies).
"""

import argparse
import hashlib
import hmac
import json
import logging
import os
import subprocess
import sys
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] %(levelname)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("webhook_server")

REPO_ROOT = Path(__file__).resolve().parent.parent
RUN_CONTAINER_SCRIPT = REPO_ROOT / "bin" / "run_agent_container.sh"


def verify_signature(payload_bytes: bytes, secret: str, signature_header: str) -> bool:
    """Verify HMAC SHA256 signature from GitHub."""
    if not signature_header or not signature_header.startswith("sha256="):
        return False
    expected_sig = signature_header.split("sha256=")[1]
    computed_sig = hmac.new(secret.encode("utf-8"), payload_bytes, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected_sig, computed_sig)


def run_agent_async(agent_name: str, prompt: str):
    """Run the agent container asynchronously in a separate thread."""
    def worker():
        logger.info(f"Triggering agent '{agent_name}' with prompt: '{prompt}'")
        cmd = [str(RUN_CONTAINER_SCRIPT), agent_name, prompt]
        try:
            result = subprocess.run(
                cmd,
                cwd=str(REPO_ROOT),
                capture_output=True,
                text=True,
            )
            if result.returncode == 0:
                logger.info(f"Agent finished successfully for prompt: '{prompt}'")
                if result.stdout:
                    logger.info(f"Agent stdout:\n{result.stdout.strip()}")
            else:
                logger.error(f"Agent failed with exit code {result.returncode}")
                if result.stderr:
                    logger.error(f"Agent stderr:\n{result.stderr.strip()}")
        except Exception as e:
            logger.exception(f"Error executing agent container script: {e}")

    thread = threading.Thread(target=worker, daemon=True)
    thread.start()


class WebhookHandler(BaseHTTPRequestHandler):
    secret: str = ""
    agent_name: str = "code_reviewer"

    def do_GET(self):
        """Health check endpoint."""
        if self.path in ("/", "/health"):
            self._send_json(200, {
                "status": "ok",
                "service": "antigravity-webhook-server",
                "agent": self.agent_name,
            })
        else:
            self._send_json(404, {"error": "Not Found"})

    def do_POST(self):
        """Handle incoming GitHub Webhook POST request."""
        content_length = int(self.headers.get("Content-Length", 0))
        payload_bytes = self.rfile.read(content_length)

        # Verify HMAC signature if secret is configured
        if self.secret:
            sig_header = self.headers.get("X-Hub-Signature-256", "")
            if not verify_signature(payload_bytes, self.secret, sig_header):
                logger.warning("Invalid or missing HMAC signature received.")
                self._send_json(401, {"error": "Invalid signature"})
                return

        event_type = self.headers.get("X-GitHub-Event", "unknown")
        logger.info(f"Received GitHub webhook event: {event_type}")

        try:
            payload = json.loads(payload_bytes.decode("utf-8"))
        except json.JSONDecodeError:
            logger.error("Failed to parse JSON payload.")
            self._send_json(400, {"error": "Invalid JSON payload"})
            return

        # Handle specific GitHub webhook events
        if event_type == "ping":
            self._send_json(200, {"message": "pong", "zen": payload.get("zen", "")})
            return

        elif event_type == "pull_request":
            action = payload.get("action")
            pr_number = payload.get("number") or payload.get("pull_request", {}).get("number")
            logger.info(f"Pull request #{pr_number} action: {action}")

            # Trigger code review when a PR is opened, synchronized (pushed to), or reopened
            if action in ("opened", "synchronize", "reopened"):
                prompt = f"Review PR #{pr_number}"
                run_agent_async(self.agent_name, prompt)
                self._send_json(200, {
                    "status": "accepted",
                    "action": action,
                    "pr_number": pr_number,
                    "agent": self.agent_name,
                })
                return
            else:
                self._send_json(200, {
                    "status": "ignored",
                    "reason": f"Pull request action '{action}' does not trigger review",
                })
                return

        elif event_type in ("issue_comment", "pull_request_review_comment"):
            action = payload.get("action")
            comment_body = payload.get("comment", {}).get("body", "")
            issue = payload.get("issue", {})
            pr = payload.get("pull_request") or issue.get("pull_request")

            # Check if this comment is on a PR and requests a review
            if pr and action == "created":
                pr_url = pr.get("html_url", "")
                pr_number = pr_url.rstrip("/").split("/")[-1] if pr_url else issue.get("number")
                
                # Check for triggering keywords: e.g. @antigravity or /review
                if "@antigravity" in comment_body.lower() or "/review" in comment_body.lower():
                    prompt = f"Review PR #{pr_number} (requested via comment)"
                    run_agent_async(self.agent_name, prompt)
                    self._send_json(200, {
                        "status": "accepted",
                        "pr_number": pr_number,
                        "triggered_by_comment": True,
                    })
                    return

            self._send_json(200, {
                "status": "ignored",
                "reason": "Comment did not trigger review criteria",
            })
            return

        else:
            self._send_json(200, {
                "status": "ignored",
                "reason": f"Event type '{event_type}' not handled",
            })

    def _send_json(self, status_code: int, data: dict):
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data, indent=2).encode("utf-8"))

    def log_message(self, format, *args):
        """Suppress default HTTP log formatting to use our logger."""
        logger.debug("%s - - [%s] %s" % (self.client_address[0], self.log_date_time_string(), format % args))


def main():
    parser = argparse.ArgumentParser(description="Antigravity GitHub Webhook Server")
    parser.add_argument("--host", default=os.getenv("HOST", "0.0.0.0"), help="Host IP to bind (default: 0.0.0.0)")
    parser.add_argument("--port", "-p", type=int, default=int(os.getenv("PORT", "8000")), help="Port to bind (default: 8000)")
    parser.add_argument("--secret", "-s", default=os.getenv("WEBHOOK_SECRET", os.getenv("GITHUB_WEBHOOK_SECRET", "")), help="GitHub webhook secret for HMAC verification")
    parser.add_argument("--agent", "-a", default=os.getenv("DEFAULT_AGENT", "code_reviewer"), help="Agent name to run (default: code_reviewer)")
    args = parser.parse_args()

    WebhookHandler.secret = args.secret
    WebhookHandler.agent_name = args.agent

    if not args.secret:
        logger.warning("No WEBHOOK_SECRET specified. HMAC signature verification is DISABLED.")
    else:
        logger.info("HMAC signature verification ENABLED.")

    if not RUN_CONTAINER_SCRIPT.exists():
        logger.error(f"Run agent container script not found at: {RUN_CONTAINER_SCRIPT}")
        sys.exit(1)

    server_address = (args.host, args.port)
    httpd = HTTPServer(server_address, WebhookHandler)
    logger.info(f"Starting GitHub Webhook Server on {args.host}:{args.port} (Agent: {args.agent})...")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logger.info("Stopping Webhook Server...")
        httpd.shutdown()


if __name__ == "__main__":
    main()
