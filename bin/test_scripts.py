"""
Sanity tests for repository utility scripts in bin/.
"""

import os
from pathlib import Path
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
        import json
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
        import subprocess
        tag_script = str(BIN_DIR / "tag.sh")
        # Test help
        res = subprocess.run([tag_script, "--help"], capture_output=True, text=True)
        self.assertIn("Usage:", res.stdout)
        # Test invalid argument
        res_err = subprocess.run([tag_script, "invalid_arg"], capture_output=True, text=True)
        self.assertNotEqual(res_err.returncode, 0)


if __name__ == "__main__":
    unittest.main()
