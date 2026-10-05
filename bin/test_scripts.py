"""
Sanity tests for repository utility scripts in bin/.
"""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

BIN_DIR = Path(__file__).resolve().parent


class TestRepositoryScripts(unittest.TestCase):
    """Sanity checks for executable utility scripts in bin/."""

    def test_scripts_exist_and_executable(self):
        scripts = [
            "build_agent_container.sh",
            "generate_icons.sh",
            "run_agent_container.sh",
            "run_webhook_listener.sh",
            "tag.sh",
        ]
        for script_name in scripts:
            script_path = BIN_DIR / script_name
            self.assertTrue(script_path.is_file(), f"{script_name} should exist")
            self.assertTrue(
                os.access(script_path, os.X_OK),
                f"{script_name} should have executable permissions",
            )

    def test_graviton_config_valid(self):
        config_path = BIN_DIR.parent / ".graviton.json"
        self.assertTrue(config_path.is_file(), ".graviton.json should exist")
        with open(config_path, "r", encoding="utf-8") as f:
            cfg = json.load(f)
        self.assertIn("release", cfg)
        release = cfg["release"]
        self.assertIn("commands", release)
        self.assertEqual(release.get("branch"), "main")
        self.assertIn("patch", release["commands"])
        self.assertIn("minor", release["commands"])
        self.assertIn("major", release["commands"])

    def test_tag_script_help_and_dry_run(self):
        tag_script = str(BIN_DIR / "tag.sh")
        repo_root = str(BIN_DIR.parent)
        # Strip git environment variables (e.g. from pre-commit hooks) so subprocesses
        # operate strictly within the isolated temp repository.
        env = {
            k: v
            for k, v in os.environ.items()
            if not k.startswith("GIT_")
        }
        env["TAG_SH_SKIP_FETCH"] = "1"

        # Test help (--help, -h, and positional help)
        for help_arg in ["--help", "-h", "help"]:
            res = subprocess.run(
                [tag_script, help_arg],
                capture_output=True,
                text=True,
                cwd=repo_root,
                env=env,
            )
            self.assertIn("Usage:", res.stdout)
            self.assertNotEqual(res.returncode, 0)

        # Test invalid argument
        res_err = subprocess.run(
            [tag_script, "invalid_arg"],
            capture_output=True,
            text=True,
            cwd=repo_root,
            env=env,
        )
        self.assertNotEqual(res_err.returncode, 0)
        self.assertIn("Error: Unknown option invalid_arg", res_err.stderr)

        # Test missing increment type error when invoking dry-run options
        for dry_arg in ["--dry-run", "dry-run"]:
            res_dry = subprocess.run(
                [tag_script, dry_arg],
                capture_output=True,
                text=True,
                cwd=repo_root,
                env=env,
            )
            self.assertNotEqual(res_dry.returncode, 0)
            self.assertIn(
                "Error: Increment type is required",
                res_dry.stderr,
            )

        # Test proper argument parsing for positional and flag-style commands
        # across ordering variations
        increment_options = [
            "patch", "minor", "major", "--patch", "--minor", "--major",
        ]
        dry_run_options = ["--dry-run", "dry-run"]
        expected_tags = {"patch": "v1.0.1", "minor": "v1.1.0", "major": "v2.0.0"}

        with tempfile.TemporaryDirectory() as temp_dir:
            def run_git(*args):
                return subprocess.run(
                    ["git", *args],
                    cwd=temp_dir,
                    check=True,
                    capture_output=True,
                    text=True,
                    env=env,
                )

            # Initialize an isolated git repository with main branch and disabled GPG signing
            run_git("-c", "init.defaultBranch=main", "init", "-b", "main")
            run_git("config", "user.name", "Test User")
            run_git("config", "user.email", "test@example.com")
            run_git("config", "commit.gpgsign", "false")
            run_git("config", "tag.gpgsign", "false")
            run_git("commit", "--allow-empty", "-m", "Initial commit")
            run_git("tag", "v1.0.0")

            for inc_opt in increment_options:
                for dry_opt in dry_run_options:
                    expected_tag = expected_tags[inc_opt.lstrip("-")]
                    for args in [[inc_opt, dry_opt], [dry_opt, inc_opt]]:
                        res = subprocess.run(
                            [tag_script] + args,
                            capture_output=True,
                            text=True,
                            cwd=temp_dir,
                            env=env,
                        )
                        self.assertEqual(
                            res.returncode,
                            0,
                            f"tag.sh {' '.join(args)} failed: {res.stderr}",
                        )
                        self.assertIn(
                            f"Incrementing to new tag: {expected_tag}",
                            res.stdout,
                        )
                        self.assertIn("[DRY RUN]", res.stdout)

            # Verify TAG_SH_SKIP_FETCH bypasses remote fetch when remote is present
            run_git(
                "remote",
                "add",
                "origin",
                "https://invalid.example.com/repo.git",
            )

            # 1. On main branch with configured remote
            res_main_bypass = subprocess.run(
                [tag_script, "--patch", "--dry-run"],
                capture_output=True,
                text=True,
                cwd=temp_dir,
                env=env,
            )
            self.assertEqual(
                res_main_bypass.returncode,
                0,
                f"tag.sh bypass on main failed: {res_main_bypass.stderr}",
            )
            self.assertNotIn("Fetching", res_main_bypass.stdout)
            self.assertIn(
                "Incrementing to new tag: v1.0.1",
                res_main_bypass.stdout,
            )
            self.assertIn(
                "[DRY RUN] Would push tag v1.0.1 to origin.",
                res_main_bypass.stdout,
            )

            # 2. On non-main branch with configured remote
            run_git("checkout", "-b", "feature")
            res_branch_bypass = subprocess.run(
                [tag_script, "--patch", "--dry-run"],
                capture_output=True,
                text=True,
                cwd=temp_dir,
                env=env,
            )
            self.assertEqual(
                res_branch_bypass.returncode,
                0,
                f"tag.sh bypass on feature branch failed: {res_branch_bypass.stderr}",
            )
            self.assertNotIn("Fetching", res_branch_bypass.stdout)
            self.assertIn(
                "Incrementing to new tag: v1.0.1",
                res_branch_bypass.stdout,
            )
            self.assertIn(
                "[DRY RUN] Would push tag v1.0.1 to origin.",
                res_branch_bypass.stdout,
            )

        # Test conflicting increment arguments error handling
        conflict_cases = [
            ["patch", "minor"],
            ["--patch", "--minor"],
            ["major", "--patch"],
            ["--minor", "patch"],
        ]
        for args in conflict_cases:
            res_conflict = subprocess.run(
                [tag_script] + args,
                capture_output=True,
                text=True,
                cwd=repo_root,
                env=env,
            )
            self.assertNotEqual(
                res_conflict.returncode,
                0,
                f"tag.sh {' '.join(args)} should fail with non-zero exit code",
            )
            self.assertIn(
                "Error: Only one increment argument or flag can be specified.",
                res_conflict.stderr,
            )


if __name__ == "__main__":
    unittest.main()
