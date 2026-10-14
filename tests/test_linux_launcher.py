"""No browser, desktop interaction, network, or real browser profile access."""
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("linux_launcher", ROOT / "launch-pjivn-linux.py")
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


def screen_state(width=1920, height=1080, scale=1.25):
    connector = ("HDMI-3", "Example", "Dummy", "fixture")
    mode = ("current", width, height, 60., scale, [1., scale], {"is-current": True})
    return (1, [(connector, [mode], {})], [(0, 0, scale, 0, True, [connector], {})], {})


class LinuxLauncherTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="pjivn-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.sunshine = self.root / "sunshine.conf"
        self.sunshine.write_text("capture = kms\noutput_name = HDMI-A-3\n")
        self.config = {"BrowserPath": sys.executable,
                       "SunshineConfigPath": str(self.sunshine),
                       "SunshineOutput": "HDMI-A-3", "DesktopOutput": "HDMI-3"}

    def test_config_requires_explicit_paths_and_values(self):
        path = self.root / "config.json"
        path.write_text(json.dumps(self.config))
        self.assertEqual(helper.read_config(path), self.config)
        for change in ({"BrowserPath": "/missing/browser"}, {"DesktopOutput": ""},
                       {"SunshineConfigPath": "relative.conf"}, {"Profile": "Default"}):
            path.write_text(json.dumps(self.config | change))
            with self.assertRaises(helper.HelperError):
                helper.read_config(path)
        wrapper = self.root / "wrapper"
        wrapper.write_text("#!/bin/sh\nexit 0\n")
        wrapper.chmod(0o700)
        path.write_text(json.dumps(self.config | {"BrowserPath": str(wrapper)}))
        with self.assertRaisesRegex(helper.HelperError, "ELF"):
            helper.read_config(path)

    def test_fractional_scale_is_not_treated_as_resolution(self):
        display = helper.select_display(screen_state(), "HDMI-3")
        self.assertEqual((display["width"], display["height"]), (1920, 1080))
        self.assertEqual((display["logical_width"], display["logical_height"]), (1536, 864))

    def test_incompatible_displays_fail(self):
        cases = [screen_state(height=1200)]
        multi = screen_state()
        multi[2].append(multi[2][0])
        cases.append(multi)
        rotated = screen_state()
        rotated[2][0] = (0, 0, 1.25, 1, True, rotated[2][0][5], {})
        cases.append(rotated)
        for state in cases:
            with self.assertRaises(helper.HelperError):
                helper.select_display(state, "HDMI-3")
        with self.assertRaises(helper.HelperError):
            helper.select_display(screen_state(), "DP-1")

    def test_diagnosis_checks_actual_sunshine_output_without_writes(self):
        original = self.sunshine.read_bytes()
        with patch.dict(os.environ, {"XDG_SESSION_TYPE": "wayland"}), \
             patch.object(helper, "current_displays", return_value=screen_state()):
            self.assertEqual(helper.diagnose(self.config)["scale"], 1.25)
            for change in ({"SunshineOutput": "0"}, {"DesktopOutput": "DP-1"}):
                with self.assertRaises(helper.HelperError):
                    helper.diagnose(self.config | change)
        self.assertEqual(original, self.sunshine.read_bytes())

    def test_setup_creates_only_its_own_profile_and_lock_prevents_double_start(self):
        root = self.root / "data"
        with helper.profile_lock(root, setup=True) as profile:
            self.assertTrue(profile.is_dir())
            self.assertEqual(profile.stat().st_mode & 0o777, 0o700)
            with self.assertRaises(helper.HelperError):
                with helper.profile_lock(root, setup=True):
                    self.fail("second launcher entered")
        with helper.profile_lock(root) as profile:
            self.assertEqual(profile.name, "browser-profile")

    def test_unowned_profile_and_stale_browser_lock_are_preserved(self):
        root = self.root / "unowned"
        (root / "browser-profile").mkdir(parents=True)
        sample = root / "browser-profile/user-file"
        sample.write_text("preserve me")
        with self.assertRaises(helper.HelperError):
            with helper.profile_lock(root, setup=True):
                self.fail("unowned profile accepted")
        self.assertEqual(sample.read_text(), "preserve me")
        owned = self.root / "owned"
        with helper.profile_lock(owned, setup=True) as profile:
            (profile / "SingletonLock").symlink_to("absent-host-123")
        with self.assertRaises(helper.HelperError):
            with helper.profile_lock(owned):
                self.fail("browser lock accepted")
        self.assertTrue((owned / "browser-profile/SingletonLock").is_symlink())

    def test_only_confirmed_dead_local_browser_lock_is_recoverable(self):
        root = self.root / "stale"
        with helper.profile_lock(root, setup=True) as profile:
            lock = profile / "SingletonLock"
            lock.symlink_to("mini-pc-2461736")
            sample = profile / "user-file"
            sample.write_text("preserve me")
        with patch.object(helper.socket, "gethostname", return_value="mini-pc"), \
             patch.object(helper.os, "kill", side_effect=ProcessLookupError) as probe:
            with helper.profile_lock(root) as reopened:
                self.assertEqual(reopened, profile)
            probe.assert_called_once_with(2461736, 0)
        self.assertEqual(os.readlink(lock), "mini-pc-2461736")
        self.assertEqual(sample.read_text(), "preserve me")
        for error in (None, PermissionError(), OSError()):
            with patch.object(helper.socket, "gethostname", return_value="mini-pc"), \
                 patch.object(helper.os, "kill", side_effect=error):
                with self.assertRaises(helper.HelperError):
                    with helper.profile_lock(root):
                        self.fail("live or unknown lock accepted")
        lock.unlink()  # Test fixture only, never a browser profile.
        for target in ("other-pc-123", "mini-pc-0", "mini-pc--1", "mini-pc-invalid"):
            lock.symlink_to(target)
            with patch.object(helper.socket, "gethostname", return_value="mini-pc"), \
                 patch.object(helper.os, "kill") as probe:
                with self.assertRaises(helper.HelperError):
                    helper.assert_browser_available(profile)
                probe.assert_not_called()
            self.assertEqual(os.readlink(lock), target)
            lock.unlink()
        lock.write_text("unknown file")
        with self.assertRaises(helper.HelperError):
            helper.assert_browser_available(profile)
        self.assertEqual(lock.read_text(), "unknown file")

    def test_profile_must_be_prepared_and_never_symlinked(self):
        with self.assertRaises(helper.HelperError):
            with helper.profile_lock(self.root / "not-prepared"):
                self.fail("unprepared launch accepted")
        root = self.root / "linked"
        root.mkdir()
        (root / "browser-profile").symlink_to(self.root / "missing")
        with self.assertRaises(helper.HelperError):
            with helper.profile_lock(root, setup=True):
                self.fail("symlink accepted")

    def test_commands_use_boost_double_quotes_not_shell_single_quotes(self):
        path = self.root / "ゲーム settings ' name.local.json"
        app = helper.sunshine_application(path)
        self.assertEqual(app["cmd"], f'"{sys.executable}" "{ROOT / "launch-pjivn-linux.py"}" '
                                    f'"--config" "{path}" "run"')
        for character in ("$", '"', "\\", "\n", "\t", "\x7f"):
            with self.assertRaises(helper.HelperError):
                helper.sunshine_application(self.root / f"bad{character}path.json")
            with patch.object(helper, "ROOT", self.root / f"bad{character}directory"):
                with self.assertRaises(helper.HelperError):
                    helper.sunshine_application(path)
            with patch.object(helper.sys, "executable", f"/bad{character}python"):
                with self.assertRaises(helper.HelperError):
                    helper.sunshine_application(path)
        self.assertFalse(app["auto-detach"])
        self.assertFalse(app["wait-all"])
        self.assertEqual(app["prep-cmd"], [])
        args = helper.browser_arguments(self.config, self.root / "profile with spaces")
        self.assertIn("--kiosk", args)
        self.assertIn("--disable-infobars", args)
        self.assertIn("--ozone-platform=wayland", args)
        self.assertNotIn("--kiosk", helper.browser_arguments(self.config, self.root, setup=True))
        self.assertNotIn("--disable-infobars", helper.browser_arguments(self.config, self.root, setup=True))
        self.assertFalse(any("debugging" in arg or "no-sandbox" in arg for arg in args))

    def test_doctor_and_commands_do_not_launch_or_create_profile(self):
        config_path = self.root / "test.local.json"
        config_path.write_text(json.dumps(self.config))
        with patch.object(helper, "diagnose", return_value={}), \
             patch.object(helper, "data_root", return_value=self.root / "untouched"), \
             patch.object(helper, "supervise") as run, \
             patch("builtins.print"):
            self.assertEqual(helper.main(["--config", str(config_path), "doctor"]), 0)
            self.assertEqual(helper.main(["--config", str(config_path), "commands"]), 0)
            run.assert_not_called()
        self.assertFalse((self.root / "untouched").exists())

    def test_child_failure_is_not_reported_as_success(self):
        with self.assertRaisesRegex(helper.HelperError, "7"):
            helper.supervise([sys.executable, "-c", "raise SystemExit(7)"])
        with self.assertRaisesRegex(helper.HelperError, "すぐ終了"):
            helper.supervise([sys.executable, "-c", "pass"])

    def test_shutdown_reaches_only_the_owned_child(self):
        # Real process/signal test with a Python fixture, never a browser.
        fixture = self.root / "child.py"
        fixture.write_text(
            "import signal, sys\nfrom pathlib import Path\n"
            "def stop(*args):\n Path(sys.argv[2]).write_text('terminated'); sys.exit(0)\n"
            "signal.signal(signal.SIGTERM, stop)\n"
            "print('ready', flush=True)\nPath(sys.argv[1]).write_text('ready')\n"
            "while True: signal.pause()\n"
        )
        # Supervisor's Popen is real. Readiness synchronization comes through a
        # pipe wrapper, so no busy polling or arbitrary startup sleeps are needed.
        harness = self.root / "supervisor.py"
        harness.write_text(
            "import importlib.util, subprocess, sys\n"
            f"spec=importlib.util.spec_from_file_location('helper', {str(ROOT / 'launch-pjivn-linux.py')!r})\n"
            "helper=importlib.util.module_from_spec(spec); spec.loader.exec_module(helper)\n"
            "original=helper.subprocess.Popen\n"
            "def child(*args, **kwargs):\n"
            " kwargs['stdout']=None\n return original(*args, **kwargs)\n"
            "helper.subprocess.Popen=child\n"
            f"sys.exit(helper.supervise([sys.executable, {str(fixture)!r}, sys.argv[1], sys.argv[2]]))\n"
        )
        unrelated = subprocess.Popen([sys.executable, "-c", "import signal; signal.pause()"])
        process = subprocess.Popen([sys.executable, str(harness), str(self.root / "ready"),
                                    str(self.root / "stopped")], stdout=subprocess.PIPE, text=True)
        try:
            import select
            self.assertTrue(select.select([process.stdout], [], [], 5)[0], "fixture did not start")
            self.assertEqual(process.stdout.readline().strip(), "ready")
            process.send_signal(signal.SIGTERM)
            self.assertEqual(process.wait(timeout=5), 0)
            self.assertEqual((self.root / "stopped").read_text(), "terminated")
            self.assertIsNone(unrelated.poll())
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            process.stdout.close()
            unrelated.terminate()
            unrelated.wait(timeout=5)

    def test_css_and_versions_stay_in_sync(self):
        self.assertEqual((ROOT / "linux-extension/layout.css").read_bytes(),
                         (ROOT / "demado/pjivn.css").read_bytes())
        version = (ROOT / "VERSION").read_text().strip()
        for directory in ("linux-extension", "cursor-extension"):
            manifest = json.loads((ROOT / directory / "manifest.json").read_text())
            self.assertEqual(manifest["version"], version)
        manifest = json.loads((ROOT / "linux-extension/manifest.json").read_text())
        self.assertNotIn("permissions", manifest)
        self.assertEqual(manifest["content_scripts"][0]["matches"], [helper.GAME_URL + "*"])
        self.assertFalse(manifest["content_scripts"][0]["all_frames"])


if __name__ == "__main__":
    unittest.main()
