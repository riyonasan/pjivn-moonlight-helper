#!/usr/bin/env python3
"""Dedicated Linux browser launcher; doctor/commands never start a browser."""

import argparse
import contextlib
import fcntl
import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent
GAME_URL = "https://play.games.dmm.co.jp/game/pjivn_293854"
PROFILE_MARKER = "pjivn-linux-dedicated-profile-v1\n"


class HelperError(Exception):
    pass


def read_config(path):
    config = json.loads(path.read_text(encoding="utf-8"))
    fields = {"BrowserPath", "SunshineConfigPath", "SunshineOutput", "DesktopOutput"}
    if not isinstance(config, dict) or set(config) != fields:
        raise HelperError("設定キーは BrowserPath, SunshineConfigPath, SunshineOutput, DesktopOutput です。")
    for key, value in config.items():
        if not isinstance(value, str) or not value.strip() or any(c in value for c in "\r\n\0"):
            raise HelperError(f"設定 {key} に確認済みの値を入れてください。")
    for key in ("BrowserPath", "SunshineConfigPath"):
        if not Path(config[key]).is_absolute():
            raise HelperError(f"{key} は絶対パスで指定してください。")
    browser = Path(config["BrowserPath"])
    if not browser.is_file() or not os.access(browser, os.X_OK):
        raise HelperError("BrowserPath の実行ファイルが見つかりません。")
    # Track the actual browser, not a Snap/Flatpak/shell launcher that detaches.
    with browser.open("rb") as stream:
        if stream.read(4) != b"\x7fELF":
            raise HelperError("BrowserPath にはChrome/Chromium本体のELF実行ファイルを指定してください。")
    return config


def data_root():
    base = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
    if not base.is_absolute():
        raise HelperError("XDG_DATA_HOME は絶対パスで指定してください。")
    return base / "pjivn-moonlight-helper"


def sunshine_display(path):
    # Read only display selection. Never print the configuration or credentials.
    result = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        key, separator, value = line.partition("=")
        if separator and key.strip() in ("capture", "output_name"):
            result[key.strip()] = value.split("#", 1)[0].strip()
    return result


def current_displays():
    try:
        import gi
        gi.require_version("Gio", "2.0")
        from gi.repository import Gio
        bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        reply = bus.call_sync(
            "org.gnome.Mutter.DisplayConfig", "/org/gnome/Mutter/DisplayConfig",
            "org.gnome.Mutter.DisplayConfig", "GetCurrentState", None, None,
            Gio.DBusCallFlags.NONE, 5000, None,
        )
        return reply.unpack()
    except Exception as error:
        raise HelperError("GNOMEの画面情報を読めません。デスクトップの通常ユーザーで実行し、python3-giを確認してください。") from error


def select_display(state, connector):
    _, monitors, logical_monitors, _ = state
    # Native Wayland placement is compositor-controlled. Support the observed
    # single-output workflow instead of pretending --window-position controls it.
    if len(logical_monitors) != 1 or len(logical_monitors[0][5]) != 1:
        raise HelperError("Linux版は有効な画面1台に対応します。GNOME設定で配信用画面だけを有効にしてください。")
    logical = logical_monitors[0]
    if logical[5][0][0] != connector or logical[3] != 0:
        raise HelperError("有効な画面がDesktopOutputと違うか、回転しています。画面設定を確認してください。")
    physical = [monitor for monitor in monitors if monitor[0][0] == connector]
    modes = [mode for monitor in physical for mode in monitor[1] if mode[6].get("is-current")]
    if len(modes) != 1:
        raise HelperError("配信用画面の現在の解像度を特定できません。")
    _, width, height, refresh, *_ = modes[0]
    scale = logical[2]
    if height <= 0 or scale <= 0 or abs(width / height - 16 / 9) > .001:
        raise HelperError("配信用画面は横向き16:9にしてください。解像度・倍率は自動変更しません。")
    return {"connector": connector, "width": width, "height": height,
            "scale": scale, "logical_width": width / scale,
            "logical_height": height / scale, "refresh_hz": round(refresh, 3)}


def diagnose(config):
    if sys.platform != "linux" or os.environ.get("XDG_SESSION_TYPE") != "wayland":
        raise HelperError("Linux版の対象はGNOME Waylandセッションです。")
    sunshine = sunshine_display(Path(config["SunshineConfigPath"]))
    if sunshine.get("capture") != "kms" or sunshine.get("output_name") != config["SunshineOutput"]:
        raise HelperError("Sunshineのcapture=kms / output_nameとローカル設定が一致していません。")
    return select_display(current_displays(), config["DesktopOutput"])


def assert_browser_available(profile):
    singleton = profile / "SingletonLock"
    message = "専用ブラウザーが使用中、またはロックの所有者を確認できません。専用窓を閉じてから確認してください。"
    if not singleton.is_symlink():
        if singleton.exists():
            raise HelperError(message)
        return
    # Chromium uses a deliberately dangling hostname-PID link. Only a confirmed
    # dead PID on this host is stale; let Chromium recover it without deleting it.
    host, separator, pid_text = os.readlink(singleton).rpartition("-")
    if (not separator or host != socket.gethostname() or not pid_text.isascii()
            or not pid_text.isdecimal() or int(pid_text) <= 0):
        raise HelperError(message)
    try:
        os.kill(int(pid_text), 0)
    except ProcessLookupError:
        return
    except OSError as error:
        raise HelperError(message) from error
    raise HelperError(message)


@contextlib.contextmanager
def profile_lock(root, setup=False):
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    with (root / "launcher.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise HelperError("専用ブラウザーは使用中です。先にそのウィンドウを閉じてください。") from error
        profile = root / "browser-profile"
        marker = root / "profile-owner.txt"
        if not marker.exists():
            if profile.exists() or profile.is_symlink():
                raise HelperError("所有記録のない既存プロファイルは使用しません。手動確認してください。")
            if not setup:
                raise HelperError("先に setup で専用ブラウザーを準備してください。")
            profile.mkdir(mode=0o700)
            marker.write_text(PROFILE_MARKER, encoding="utf-8")
        if marker.read_text(encoding="utf-8") != PROFILE_MARKER or not profile.is_dir() or profile.is_symlink():
            raise HelperError("専用プロファイルの所有記録が一致しません。手動確認してください。")
        assert_browser_available(profile)
        yield profile


def browser_arguments(config, profile, setup=False):
    args = [config["BrowserPath"], f"--user-data-dir={profile}",
            "--ozone-platform=wayland", "--no-first-run", "--no-default-browser-check"]
    if setup:
        return args + ["--new-window", GAME_URL]
    # CfT's non-interactive banner otherwise consumes part of the game viewport.
    # Keep setup unchanged so initial browser notices remain visible there.
    return args + ["--kiosk", "--disable-infobars", "--new-window", GAME_URL]


def supervise(args):
    """Own one direct child; forward graceful termination, never search/kill peers."""
    requested = []
    previous = {}
    child = None

    def request_stop(signum, _frame):
        if not requested:
            requested.append(signum)

    try:
        for signum in (signal.SIGTERM, signal.SIGINT):
            previous[signum] = signal.signal(signum, request_stop)
        # Browser stderr can include URLs or session information; do not log it.
        child = subprocess.Popen(args, stdin=subprocess.DEVNULL,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        started = time.monotonic()
        while child.poll() is None:
            if requested:
                child.terminate()
                try:
                    child.wait(timeout=10)
                except subprocess.TimeoutExpired as error:
                    raise HelperError("専用ブラウザーが終了しません。画面から手動で閉じてください。強制終了はしていません。") from error
                return 0
            try:
                child.wait(timeout=.25)
            except subprocess.TimeoutExpired:
                pass
        if child.returncode:
            raise HelperError(f"専用ブラウザーが終了コード {child.returncode} で停止しました。setupで手動確認してください。")
        if time.monotonic() - started < 2:
            raise HelperError("ブラウザーがすぐ終了しました。起動成功とは判定できません。setupで確認してください。")
        return 0
    finally:
        for signum, handler in previous.items():
            signal.signal(signum, handler)


def sunshine_argument(value):
    # Sunshine expands $(NAME) before Boost.Process v1 parses double quotes.
    # This is not a shell: shlex's single-quoted paths are not interchangeable.
    if any(char in '$"\\' or ord(char) < 32 or ord(char) == 127 for char in value):
        raise HelperError('Sunshineコマンドのパスには $、二重引用符、バックスラッシュ、制御文字を使えません。')
    return '"' + value + '"'


def sunshine_application(config_path):
    command = " ".join(sunshine_argument(value) for value in
                       [sys.executable, str(ROOT / "launch-pjivn-linux.py"),
                        "--config", str(config_path.resolve()), "run"])
    sunshine_argument(str(ROOT))  # working-dir is also subject to $(NAME).
    return {"name": "イヴンタイト(Linux Moonlight)", "cmd": command,
            "working-dir": str(ROOT), "auto-detach": False, "wait-all": False,
            "exit-timeout": 15, "prep-cmd": [], "detached": []}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=ROOT / "config.linux.local.json")
    parser.add_argument("action", choices=("doctor", "commands", "setup", "run"))
    args = parser.parse_args(argv)
    try:
        config = read_config(args.config)
        if args.action == "commands":
            print(json.dumps(sunshine_application(args.config), ensure_ascii=False, indent=2))
            return 0
        display = diagnose(config)
        if args.action == "doctor":
            print(json.dumps({"display": display, "sunshine_output": config["SunshineOutput"],
                              "browser_found": True, "profile_directory": str(data_root() / "browser-profile"),
                              "extension_directory": str(ROOT / "linux-extension"),
                              "browser_started": False, "game_verified": False,
                              "note": "拡張読込み・ログイン・表示・タッチ・終了は本人の実機確認が必要です。"},
                             ensure_ascii=False, indent=2))
            return 0
        with profile_lock(data_root(), setup=args.action == "setup") as profile:
            return supervise(browser_arguments(config, profile, setup=args.action == "setup"))
    except (HelperError, OSError, ValueError) as error:
        # JSON errors can contain user input; report location without document text.
        if isinstance(error, json.JSONDecodeError):
            message = f"設定JSONを読めません（行 {error.lineno}）。"
        elif isinstance(error, HelperError):
            message = str(error)
        else:
            message = f"ファイルまたは設定を確認してください（{type(error).__name__}）。"
        print(f"pjivn: {message}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
