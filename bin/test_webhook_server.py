#!/usr/bin/env python3
"""
Unit tests for bin/webhook_server.py.

Covers:
- HMAC Signature Verification (verify_signature)
- HTTP Request Routing & Status Codes (WebhookHandler endpoints)
- Webhook Event Dispatching Logic (pull_request, issue_comment, ping, etc.)
- Async Subprocess Dispatching (run_agent_async)
- CLI Entrypoint and Configuration (main)
"""

import hashlib
import hmac
import io
import json
import os
import sys
import threading
import unittest
import urllib.request
import urllib.error
from http.server import HTTPServer
from pathlib import Path
from unittest.mock import MagicMock, patch

# Ensure bin directory is in sys.path so webhook_server can be imported
BIN_DIR = Path(__file__).resolve().parent
if str(BIN_DIR) not in sys.path:
    sys.path.insert(0, str(BIN_DIR))

import webhook_server
from webhook_server import WebhookHandler, verify_signature, run_agent_async, main


def compute_hmac(payload: bytes, secret: str) -> str:
    """Helper to compute sha256 HMAC header string."""
    return "sha256=" + hmac.new(secret.encode("utf-8"), payload, hashlib.sha256).hexdigest()


class MockWebhookHandler(WebhookHandler):
    """
    Test helper harness for WebhookHandler that intercepts HTTP socket I/O
    into in-memory streams for fast and deterministic unit testing.
    """

    def __init__(
        self,
        method: str = "GET",
        path: str = "/",
        headers: dict = None,
        body: bytes = b"",
        secret: str = "",
        agent_name: str = "code_reviewer",
    ):
        self.secret = secret
        self.agent_name = agent_name
        self.path = path
        self.command = method
        self.headers = headers or {}
        if body and "Content-Length" not in self.headers:
            self.headers["Content-Length"] = str(len(body))
        self.rfile = io.BytesIO(body)
        self.wfile = io.BytesIO()
        self.client_address = ("127.0.0.1", 12345)
        self.status_code = None
        self.response_headers = {}

    def send_response(self, code: int, message: str = None):
        self.status_code = code

    def send_header(self, keyword: str, value: str):
        self.response_headers[keyword] = value

    def end_headers(self):
        pass

    def get_json_response(self) -> dict:
        """Parse the JSON response payload from wfile."""
        raw = self.wfile.getvalue().decode("utf-8")
        if not raw:
            return {}
        return json.loads(raw)


class TestVerifySignature(unittest.TestCase):
    """Tests for HMAC SHA256 signature verification."""

    def setUp(self):
        self.secret = "my_secret_token_12345"
        self.payload = b'{"action":"opened","number":42}'
        self.valid_sig = compute_hmac(self.payload, self.secret)

    def test_valid_signature(self):
        """Valid HMAC signature returns True."""
        result = verify_signature(self.payload, self.secret, self.valid_sig)
        self.assertTrue(result)

    def test_invalid_secret(self):
        """Mismatched secret returns False."""
        result = verify_signature(self.payload, "wrong_secret", self.valid_sig)
        self.assertFalse(result)

    def test_tampered_payload(self):
        """Altered payload with original signature returns False."""
        tampered_payload = b'{"action":"opened","number":43}'
        result = verify_signature(tampered_payload, self.secret, self.valid_sig)
        self.assertFalse(result)

    def test_corrupted_signature_hash(self):
        """Corrupted hash string returns False."""
        bad_sig = self.valid_sig[:-4] + "ffff"
        result = verify_signature(self.payload, self.secret, bad_sig)
        self.assertFalse(result)

    def test_malformed_header_missing_sha256_prefix(self):
        """Header without 'sha256=' prefix returns False."""
        raw_hash = hmac.new(self.secret.encode("utf-8"), self.payload, hashlib.sha256).hexdigest()
        self.assertFalse(verify_signature(self.payload, self.secret, raw_hash))
        self.assertFalse(verify_signature(self.payload, self.secret, f"sha1={raw_hash}"))

    def test_empty_signature_header(self):
        """Empty signature string returns False."""
        self.assertFalse(verify_signature(self.payload, self.secret, ""))

    def test_none_signature_header(self):
        """None signature header returns False without throwing exception."""
        self.assertFalse(verify_signature(self.payload, self.secret, None))

    def test_empty_payload(self):
        """Empty payload bytes verify properly against corresponding signature."""
        empty_payload = b""
        empty_sig = compute_hmac(empty_payload, self.secret)
        self.assertTrue(verify_signature(empty_payload, self.secret, empty_sig))


class TestWebhookHandlerEndpoints(unittest.TestCase):
    """Tests for HTTP endpoint routing and response status codes."""

    def test_get_root(self):
        """GET / returns HTTP 200 with status ok and agent name."""
        handler = MockWebhookHandler(method="GET", path="/", agent_name="test_agent")
        handler.do_GET()
        self.assertEqual(handler.status_code, 200)
        data = handler.get_json_response()
        self.assertEqual(data.get("status"), "ok")
        self.assertEqual(data.get("service"), "antigravity-webhook-server")
        self.assertEqual(data.get("agent"), "test_agent")

    def test_get_health(self):
        """GET /health returns HTTP 200 with status ok."""
        handler = MockWebhookHandler(method="GET", path="/health", agent_name="code_reviewer")
        handler.do_GET()
        self.assertEqual(handler.status_code, 200)
        data = handler.get_json_response()
        self.assertEqual(data.get("status"), "ok")
        self.assertEqual(data.get("service"), "antigravity-webhook-server")
        self.assertEqual(data.get("agent"), "code_reviewer")

    def test_get_unknown_path_returns_404(self):
        """GET /unknown returns HTTP 404."""
        handler = MockWebhookHandler(method="GET", path="/unknown")
        handler.do_GET()
        self.assertEqual(handler.status_code, 404)
        data = handler.get_json_response()
        self.assertEqual(data.get("error"), "Not Found")

    def test_post_ping_event(self):
        """POST with X-GitHub-Event: ping returns HTTP 200 pong with zen message."""
        body = json.dumps({"zen": "Keep it simple."}).encode("utf-8")
        headers = {
            "Content-Type": "application/json",
            "X-GitHub-Event": "ping",
        }
        handler = MockWebhookHandler(method="POST", path="/", headers=headers, body=body)
        handler.do_POST()
        self.assertEqual(handler.status_code, 200)
        data = handler.get_json_response()
        self.assertEqual(data.get("message"), "pong")
        self.assertEqual(data.get("zen"), "Keep it simple.")

    def test_post_invalid_hmac_signature_returns_401(self):
        """POST with configured secret and invalid HMAC returns HTTP 401."""
        body = json.dumps({"action": "opened"}).encode("utf-8")
        headers = {
            "Content-Type": "application/json",
            "X-GitHub-Event": "pull_request",
            "X-Hub-Signature-256": "sha256=invalidhexsignature",
        }
        handler = MockWebhookHandler(
            method="POST",
            path="/",
            headers=headers,
            body=body,
            secret="test_secret",
        )
        handler.do_POST()
        self.assertEqual(handler.status_code, 401)
        data = handler.get_json_response()
        self.assertEqual(data.get("error"), "Invalid signature")

    def test_post_valid_hmac_signature_accepted(self):
        """POST with configured secret and valid HMAC signature succeeds."""
        body = json.dumps({"zen": "Responsive is better than fast."}).encode("utf-8")
        secret = "super_secure_secret"
        sig = compute_hmac(body, secret)
        headers = {
            "Content-Type": "application/json",
            "X-GitHub-Event": "ping",
            "X-Hub-Signature-256": sig,
        }
        handler = MockWebhookHandler(
            method="POST",
            path="/",
            headers=headers,
            body=body,
            secret=secret,
        )
        handler.do_POST()
        self.assertEqual(handler.status_code, 200)
        data = handler.get_json_response()
        self.assertEqual(data.get("message"), "pong")

    def test_post_malformed_json_returns_400(self):
        """POST with malformed JSON body returns HTTP 400."""
        body = b"this is not valid json {"
        headers = {
            "Content-Type": "application/json",
            "X-GitHub-Event": "pull_request",
        }
        handler = MockWebhookHandler(method="POST", path="/", headers=headers, body=body)
        handler.do_POST()
        self.assertEqual(handler.status_code, 400)
        data = handler.get_json_response()
        self.assertEqual(data.get("error"), "Invalid JSON payload")

    def test_post_unhandled_event_type(self):
        """POST with unhandled event type returns HTTP 200 with status ignored."""
        body = json.dumps({"action": "created"}).encode("utf-8")
        headers = {
            "Content-Type": "application/json",
            "X-GitHub-Event": "star",
        }
        handler = MockWebhookHandler(method="POST", path="/", headers=headers, body=body)
        handler.do_POST()
        self.assertEqual(handler.status_code, 200)
        data = handler.get_json_response()
        self.assertEqual(data.get("status"), "ignored")
        self.assertIn("star", data.get("reason", ""))

    def test_log_message_debug_format(self):
        """log_message method runs without error."""
        handler = MockWebhookHandler(method="GET", path="/")
        with patch.object(webhook_server.logger, "debug") as mock_debug:
            handler.log_message("Test format %s", "arg1")
            mock_debug.assert_called_once()


class TestWebhookEventDispatching(unittest.TestCase):
    """Tests for event dispatching logic on pull_request and comments."""

    @patch("webhook_server.run_agent_async")
    def test_pull_request_opened_triggers_review(self, mock_run_agent):
        """PR opened event triggers code review async execution."""
        body = json.dumps({"action": "opened", "number": 101}).encode("utf-8")
        headers = {"X-GitHub-Event": "pull_request"}
        handler = MockWebhookHandler(method="POST", headers=headers, body=body, agent_name="custom_reviewer")
        handler.do_POST()

        self.assertEqual(handler.status_code, 200)
        data = handler.get_json_response()
        self.assertEqual(data.get("status"), "accepted")
        self.assertEqual(data.get("action"), "opened")
        self.assertEqual(data.get("pr_number"), 101)
        mock_run_agent.assert_called_once_with("custom_reviewer", "Review PR #101")

    @patch("webhook_server.run_agent_async")
    def test_pull_request_synchronize_triggers_review(self, mock_run_agent):
        """PR synchronize (push) event triggers code review async execution."""
        body = json.dumps({"action": "synchronize", "pull_request": {"number": 202}}).encode("utf-8")
        headers = {"X-GitHub-Event": "pull_request"}
        handler = MockWebhookHandler(method="POST", headers=headers, body=body, agent_name="code_reviewer")
        handler.do_POST()

        self.assertEqual(handler.status_code, 200)
        data = handler.get_json_response()
        self.assertEqual(data.get("status"), "accepted")
        self.assertEqual(data.get("pr_number"), 202)
        mock_run_agent.assert_called_once_with("code_reviewer", "Review PR #202")

    @patch("webhook_server.run_agent_async")
    def test_pull_request_reopened_triggers_review(self, mock_run_agent):
        """PR reopened event triggers code review async execution."""
        body = json.dumps({"action": "reopened", "number": 303}).encode("utf-8")
        headers = {"X-GitHub-Event": "pull_request"}
        handler = MockWebhookHandler(method="POST", headers=headers, body=body)
        handler.do_POST()

        self.assertEqual(handler.status_code, 200)
        data = handler.get_json_response()
        self.assertEqual(data.get("status"), "accepted")
        self.assertEqual(data.get("pr_number"), 303)
        mock_run_agent.assert_called_once_with("code_reviewer", "Review PR #303")

    @patch("webhook_server.run_agent_async")
    def test_pull_request_non_triggering_actions_ignored(self, mock_run_agent):
        """PR actions like closed, labeled, edited, assigned are ignored."""
        ignored_actions = ["closed", "labeled", "assigned", "unassigned", "edited", "review_requested"]
        for action in ignored_actions:
            mock_run_agent.reset_mock()
            body = json.dumps({"action": action, "number": 404}).encode("utf-8")
            headers = {"X-GitHub-Event": "pull_request"}
            handler = MockWebhookHandler(method="POST", headers=headers, body=body)
            handler.do_POST()

            self.assertEqual(handler.status_code, 200)
            data = handler.get_json_response()
            self.assertEqual(data.get("status"), "ignored")
            self.assertIn(action, data.get("reason", ""))
            mock_run_agent.assert_not_called()

    @patch("webhook_server.run_agent_async")
    def test_issue_comment_with_antigravity_mention_on_pr(self, mock_run_agent):
        """Issue comment containing @antigravity on a PR triggers review."""
        body = json.dumps({
            "action": "created",
            "issue": {
                "number": 505,
                "pull_request": {"html_url": "https://github.com/org/repo/pull/505"},
            },
            "comment": {"body": "Hey @antigravity, please review this PR."},
        }).encode("utf-8")
        headers = {"X-GitHub-Event": "issue_comment"}
        handler = MockWebhookHandler(method="POST", headers=headers, body=body, agent_name="code_reviewer")
        handler.do_POST()

        self.assertEqual(handler.status_code, 200)
        data = handler.get_json_response()
        self.assertEqual(data.get("status"), "accepted")
        self.assertEqual(data.get("pr_number"), "505")
        self.assertTrue(data.get("triggered_by_comment"))
        mock_run_agent.assert_called_once_with("code_reviewer", "Review PR #505 (requested via comment)")

    @patch("webhook_server.run_agent_async")
    def test_issue_comment_with_slash_review_command(self, mock_run_agent):
        """Issue comment containing /review triggers review."""
        body = json.dumps({
            "action": "created",
            "pull_request": {"html_url": "https://github.com/org/repo/pull/606"},
            "comment": {"body": "/review"},
        }).encode("utf-8")
        headers = {"X-GitHub-Event": "issue_comment"}
        handler = MockWebhookHandler(method="POST", headers=headers, body=body, agent_name="code_reviewer")
        handler.do_POST()

        self.assertEqual(handler.status_code, 200)
        data = handler.get_json_response()
        self.assertEqual(data.get("status"), "accepted")
        self.assertEqual(data.get("pr_number"), "606")
        mock_run_agent.assert_called_once_with("code_reviewer", "Review PR #606 (requested via comment)")

    @patch("webhook_server.run_agent_async")
    def test_pull_request_review_comment_with_trigger(self, mock_run_agent):
        """Review diff comment containing @antigravity triggers review."""
        body = json.dumps({
            "action": "created",
            "pull_request": {"html_url": "https://github.com/org/repo/pull/707"},
            "comment": {"body": "@Antigravity check this inline change"},
        }).encode("utf-8")
        headers = {"X-GitHub-Event": "pull_request_review_comment"}
        handler = MockWebhookHandler(method="POST", headers=headers, body=body)
        handler.do_POST()

        self.assertEqual(handler.status_code, 200)
        data = handler.get_json_response()
        self.assertEqual(data.get("status"), "accepted")
        self.assertEqual(data.get("pr_number"), "707")
        mock_run_agent.assert_called_once_with("code_reviewer", "Review PR #707 (requested via comment)")

    @patch("webhook_server.run_agent_async")
    def test_comment_without_trigger_keyword_is_ignored(self, mock_run_agent):
        """Comment on a PR without @antigravity or /review is ignored."""
        body = json.dumps({
            "action": "created",
            "pull_request": {"html_url": "https://github.com/org/repo/pull/808"},
            "comment": {"body": "Looks great to me, thanks!"},
        }).encode("utf-8")
        headers = {"X-GitHub-Event": "issue_comment"}
        handler = MockWebhookHandler(method="POST", headers=headers, body=body)
        handler.do_POST()

        self.assertEqual(handler.status_code, 200)
        data = handler.get_json_response()
        self.assertEqual(data.get("status"), "ignored")
        self.assertEqual(data.get("reason"), "Comment did not trigger review criteria")
        mock_run_agent.assert_not_called()

    @patch("webhook_server.run_agent_async")
    def test_comment_action_not_created_is_ignored(self, mock_run_agent):
        """Edited or deleted comments are ignored even if trigger keyword is present."""
        body = json.dumps({
            "action": "edited",
            "pull_request": {"html_url": "https://github.com/org/repo/pull/909"},
            "comment": {"body": "@antigravity review please"},
        }).encode("utf-8")
        headers = {"X-GitHub-Event": "issue_comment"}
        handler = MockWebhookHandler(method="POST", headers=headers, body=body)
        handler.do_POST()

        self.assertEqual(handler.status_code, 200)
        data = handler.get_json_response()
        self.assertEqual(data.get("status"), "ignored")
        mock_run_agent.assert_not_called()

    @patch("webhook_server.run_agent_async")
    def test_issue_comment_not_on_pr_is_ignored(self, mock_run_agent):
        """Comment with trigger on a regular issue (not PR) is ignored."""
        body = json.dumps({
            "action": "created",
            "issue": {"number": 999},  # No pull_request key
            "comment": {"body": "@antigravity please fix this issue"},
        }).encode("utf-8")
        headers = {"X-GitHub-Event": "issue_comment"}
        handler = MockWebhookHandler(method="POST", headers=headers, body=body)
        handler.do_POST()

        self.assertEqual(handler.status_code, 200)
        data = handler.get_json_response()
        self.assertEqual(data.get("status"), "ignored")
        mock_run_agent.assert_not_called()


class TestRunAgentAsync(unittest.TestCase):
    """Tests for asynchronous subprocess execution."""

    @patch("subprocess.run")
    def test_run_agent_async_success(self, mock_subprocess_run):
        """run_agent_async launches background thread and invokes script successfully."""
        mock_subprocess_run.return_value = MagicMock(returncode=0, stdout="Agent completed successfully.", stderr="")

        run_agent_async("code_reviewer", "Review PR #42")

        # Give thread brief moment to complete worker execution
        for thread in threading.enumerate():
            if thread is not threading.current_thread() and thread.is_alive():
                thread.join(timeout=2.0)

        mock_subprocess_run.assert_called_once_with(
            [str(webhook_server.RUN_CONTAINER_SCRIPT), "code_reviewer", "Review PR #42"],
            cwd=str(webhook_server.REPO_ROOT),
            capture_output=True,
            text=True,
        )

    @patch("subprocess.run")
    def test_run_agent_async_handles_nonzero_exit_code(self, mock_subprocess_run):
        """run_agent_async handles nonzero exit code without raising exception."""
        mock_subprocess_run.return_value = MagicMock(returncode=1, stdout="", stderr="Fatal error in agent")

        with patch.object(webhook_server.logger, "error") as mock_log_err:
            run_agent_async("code_reviewer", "Review PR #99")

            for thread in threading.enumerate():
                if thread is not threading.current_thread() and thread.is_alive():
                    thread.join(timeout=2.0)

            mock_log_err.assert_any_call("Agent failed with exit code 1")

    @patch("subprocess.run")
    def test_run_agent_async_handles_execution_exception(self, mock_subprocess_run):
        """run_agent_async catches exceptions from subprocess.run gracefully."""
        mock_subprocess_run.side_effect = FileNotFoundError("Executable not found")

        with patch.object(webhook_server.logger, "exception") as mock_log_exc:
            run_agent_async("code_reviewer", "Review PR #123")

            for thread in threading.enumerate():
                if thread is not threading.current_thread() and thread.is_alive():
                    thread.join(timeout=2.0)

            mock_log_exc.assert_called_once()


class TestMainCli(unittest.TestCase):
    """Tests for CLI arguments, server initialization, and error handling."""

    @patch("webhook_server.HTTPServer")
    @patch("webhook_server.RUN_CONTAINER_SCRIPT")
    def test_main_starts_http_server(self, mock_script, mock_http_server_class):
        """main parses arguments and initializes HTTPServer."""
        mock_script.exists.return_value = True
        mock_server_instance = MagicMock()
        mock_http_server_class.return_value = mock_server_instance
        # Stop serve_forever immediately
        mock_server_instance.serve_forever.side_effect = KeyboardInterrupt()

        test_args = [
            "webhook_server.py",
            "--host", "127.0.0.1",
            "--port", "9000",
            "--secret", "cli_secret_key",
            "--agent", "pr_drafter",
        ]
        with patch.object(sys, "argv", test_args):
            main()

        mock_http_server_class.assert_called_once_with(("127.0.0.1", 9000), WebhookHandler)
        self.assertEqual(WebhookHandler.secret, "cli_secret_key")
        self.assertEqual(WebhookHandler.agent_name, "pr_drafter")
        mock_server_instance.serve_forever.assert_called_once()
        mock_server_instance.shutdown.assert_called_once()

    @patch("webhook_server.RUN_CONTAINER_SCRIPT")
    def test_main_exits_when_container_script_missing(self, mock_script):
        """main exits with status 1 if run_agent_container.sh does not exist."""
        mock_script.exists.return_value = False
        test_args = ["webhook_server.py"]
        with patch.object(sys, "argv", test_args):
            with self.assertRaises(SystemExit) as cm:
                main()
            self.assertEqual(cm.exception.code, 1)


class TestLiveHttpServerIntegration(unittest.TestCase):
    """Integration test with an ephemeral live HTTPServer socket."""

    @classmethod
    def setUpClass(cls):
        WebhookHandler.secret = ""
        WebhookHandler.agent_name = "test_server"
        cls.server = HTTPServer(("127.0.0.1", 0), WebhookHandler)
        cls.host, cls.port = cls.server.server_address
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=2.0)

    def test_live_get_health(self):
        """Sends real HTTP GET /health over TCP socket to running server."""
        url = f"http://{self.host}:{self.port}/health"
        with urllib.request.urlopen(url, timeout=3) as resp:
            self.assertEqual(resp.status, 200)
            data = json.loads(resp.read().decode("utf-8"))
            self.assertEqual(data.get("status"), "ok")
            self.assertEqual(data.get("agent"), "test_server")

    def test_live_post_ping(self):
        """Sends real HTTP POST / with ping event over TCP socket."""
        url = f"http://{self.host}:{self.port}/"
        payload = json.dumps({"zen": "Live test."}).encode("utf-8")
        req = urllib.request.Request(
            url,
            data=payload,
            headers={
                "Content-Type": "application/json",
                "X-GitHub-Event": "ping",
            },
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=3) as resp:
            self.assertEqual(resp.status, 200)
            data = json.loads(resp.read().decode("utf-8"))
            self.assertEqual(data.get("message"), "pong")
            self.assertEqual(data.get("zen"), "Live test.")


if __name__ == "__main__":
    unittest.main()
