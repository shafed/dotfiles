#!/usr/bin/env python3
"""Switch Helium's exact Gruvbox extension theme and reload it live via CDP."""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import shutil
import socket
import struct
import subprocess
import sys
from urllib.parse import urlparse
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parent.parent
THEMES = {
    "dark": ROOT / "helium/gruvbox-dark",
    "light": ROOT / "helium/gruvbox-light",
}
USER_DATA_DIR_NAMES = ("net.imput.helium", "helium", "helium-browser")
RUNTIME_NAME = "helium-gruvbox"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Switch Helium between exact Gruvbox dark/light extension themes."
    )
    parser.add_argument("mode", nargs="?", choices=("auto", "dark", "light"), default="auto")
    parser.add_argument("--config-home", type=Path)
    parser.add_argument("--data-home", type=Path)
    parser.add_argument(
        "--no-live-reload",
        action="store_true",
        help="update the runtime theme only; do not contact a running Helium",
    )
    return parser.parse_args()


def current_mode() -> str:
    try:
        result = subprocess.run(
            ["darkman", "get"],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            timeout=2,
        )
    except (OSError, subprocess.TimeoutExpired):
        return "dark"
    mode = result.stdout.strip()
    return mode if result.returncode == 0 and mode in THEMES else "dark"


def selected_mode(requested: str) -> str:
    return current_mode() if requested == "auto" else requested


def read_theme_manifest(mode: str) -> bytes:
    path = THEMES[mode] / "manifest.json"
    data = path.read_bytes()
    parsed = json.loads(data)
    if parsed.get("manifest_version") != 3 or not isinstance(parsed.get("theme"), dict):
        raise ValueError(f"invalid Chromium theme manifest: {path}")
    return data if data.endswith(b"\n") else data + b"\n"


def write_runtime_theme(runtime: Path, mode: str) -> bool:
    source = read_theme_manifest(mode)
    runtime.mkdir(parents=True, exist_ok=True)
    target = runtime / "manifest.json"
    if target.is_file() and target.read_bytes() == source:
        return False
    temp = runtime / ".manifest.json.dotfiles-tmp"
    temp.write_bytes(source)
    os.replace(temp, target)
    return True


def strip_quotes(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
        return value[1:-1]
    return value


def configured_debugging_port(config_home: Path) -> int | None:
    flags = config_home / "helium-browser-flags.conf"
    if not flags.is_file():
        return None
    for line in flags.read_text().splitlines():
        stripped = line.strip()
        if not stripped.startswith("--remote-debugging-port="):
            continue
        raw = strip_quotes(stripped.split("=", 1)[1])
        try:
            port = int(raw)
        except ValueError:
            continue
        if 0 <= port <= 65535:
            return port
    return None


def configured_user_data_dir(config_home: Path) -> Path | None:
    flags = config_home / "helium-browser-flags.conf"
    if not flags.is_file():
        return None
    for line in flags.read_text().splitlines():
        stripped = line.strip()
        if not stripped.startswith("--user-data-dir="):
            continue
        raw = strip_quotes(stripped.split("=", 1)[1])
        if not raw:
            continue
        path = Path(os.path.expandvars(os.path.expanduser(raw)))
        return path if path.is_absolute() else config_home / path
    return None


def devtools_port_file(config_home: Path) -> Path | None:
    roots: list[Path] = []
    explicit = configured_user_data_dir(config_home)
    if explicit is not None:
        roots.append(explicit)
    roots.extend(config_home / name for name in USER_DATA_DIR_NAMES)
    for root in roots:
        candidate = root.expanduser() / "DevToolsActivePort"
        if candidate.is_file():
            return candidate
    return None


class WebSocketClient:
    """Small RFC6455 client sufficient for browser-level CDP commands."""

    def __init__(self, url: str, timeout: float = 3.0) -> None:
        parsed = urlparse(url)
        if parsed.scheme != "ws" or not parsed.hostname:
            raise ValueError(f"unsupported DevTools WebSocket URL: {url}")
        self.host = parsed.hostname
        self.port = parsed.port or 80
        self.path = parsed.path or "/"
        if parsed.query:
            self.path += "?" + parsed.query
        self.sock = socket.create_connection((self.host, self.port), timeout=timeout)
        self.sock.settimeout(timeout)
        self.buffer = bytearray()
        self.next_id = 1
        self._handshake()

    def _recv_until(self, marker: bytes) -> bytes:
        while marker not in self.buffer:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise ConnectionError("DevTools WebSocket closed during handshake")
            self.buffer.extend(chunk)
        end = self.buffer.index(marker) + len(marker)
        result = bytes(self.buffer[:end])
        del self.buffer[:end]
        return result

    def _handshake(self) -> None:
        key = base64.b64encode(os.urandom(16)).decode("ascii")
        request = (
            f"GET {self.path} HTTP/1.1\r\n"
            f"Host: {self.host}:{self.port}\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            "Sec-WebSocket-Version: 13\r\n\r\n"
        ).encode("ascii")
        self.sock.sendall(request)
        header = self._recv_until(b"\r\n\r\n")
        first = header.split(b"\r\n", 1)[0]
        if b" 101 " not in first:
            raise ConnectionError(f"DevTools WebSocket handshake failed: {first.decode(errors='replace')}")
        headers: dict[str, str] = {}
        for line in header.split(b"\r\n")[1:]:
            if b":" not in line:
                continue
            name, value = line.split(b":", 1)
            headers[name.decode("ascii", errors="ignore").lower()] = value.decode(
                "ascii", errors="ignore"
            ).strip()
        expected = base64.b64encode(
            hashlib.sha1((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode("ascii")).digest()
        ).decode("ascii")
        if headers.get("sec-websocket-accept") != expected:
            raise ConnectionError("DevTools WebSocket returned an invalid accept key")

    def _read_exact(self, count: int) -> bytes:
        while len(self.buffer) < count:
            chunk = self.sock.recv(max(4096, count - len(self.buffer)))
            if not chunk:
                raise ConnectionError("DevTools WebSocket closed")
            self.buffer.extend(chunk)
        result = bytes(self.buffer[:count])
        del self.buffer[:count]
        return result

    def _send_frame(self, opcode: int, payload: bytes) -> None:
        first = 0x80 | opcode
        mask = os.urandom(4)
        length = len(payload)
        if length <= 125:
            header = bytes((first, 0x80 | length))
        elif length <= 0xFFFF:
            header = bytes((first, 0x80 | 126)) + struct.pack("!H", length)
        else:
            header = bytes((first, 0x80 | 127)) + struct.pack("!Q", length)
        masked = bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
        self.sock.sendall(header + mask + masked)

    def _recv_message(self) -> str:
        fragments = bytearray()
        text_started = False
        while True:
            first, second = self._read_exact(2)
            fin = bool(first & 0x80)
            opcode = first & 0x0F
            masked = bool(second & 0x80)
            length = second & 0x7F
            if length == 126:
                length = struct.unpack("!H", self._read_exact(2))[0]
            elif length == 127:
                length = struct.unpack("!Q", self._read_exact(8))[0]
            mask = self._read_exact(4) if masked else b""
            payload = self._read_exact(length)
            if masked:
                payload = bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
            if opcode == 0x8:
                raise ConnectionError("DevTools WebSocket closed")
            if opcode == 0x9:
                self._send_frame(0xA, payload)
                continue
            if opcode == 0xA:
                continue
            if opcode == 0x1:
                fragments = bytearray(payload)
                text_started = True
            elif opcode == 0x0 and text_started:
                fragments.extend(payload)
            else:
                continue
            if fin:
                return fragments.decode("utf-8")

    def call(self, method: str, params: dict[str, object] | None = None) -> dict:
        request_id = self.next_id
        self.next_id += 1
        payload: dict[str, object] = {"id": request_id, "method": method}
        if params:
            payload["params"] = params
        self._send_frame(0x1, json.dumps(payload, separators=(",", ":")).encode("utf-8"))
        while True:
            message = json.loads(self._recv_message())
            if message.get("id") != request_id:
                continue
            if "error" in message:
                raise RuntimeError(f"{method}: {message['error']}")
            result = message.get("result", {})
            if not isinstance(result, dict):
                raise RuntimeError(f"{method}: invalid CDP result")
            return result

    def close(self) -> None:
        try:
            self._send_frame(0x8, b"")
        except OSError:
            pass
        self.sock.close()


def browser_endpoint(config_home: Path, port_file: Path | None) -> str:
    if port_file is None:
        port = configured_debugging_port(config_home)
        if not port:
            raise FileNotFoundError("Helium DevTools endpoint is not active")
        with urlopen(f"http://127.0.0.1:{port}/json/version", timeout=2) as response:
            payload = json.load(response)
        endpoint = payload.get("webSocketDebuggerUrl")
        if not isinstance(endpoint, str) or not endpoint.startswith("ws://"):
            raise ValueError("Helium DevTools endpoint did not expose a browser WebSocket")
        return endpoint
    lines = [line.strip() for line in port_file.read_text().splitlines() if line.strip()]
    if len(lines) < 2:
        raise ValueError(f"invalid DevToolsActivePort: {port_file}")
    port = int(lines[0])
    path = lines[1]
    if not path.startswith("/"):
        path = "/" + path
    return f"ws://127.0.0.1:{port}{path}"


def reload_live_theme(config_home: Path, runtime: Path) -> tuple[str, str]:
    """Reload the unpacked theme inside a running Helium.

    Extensions.loadUnpacked re-reads manifest.json from disk and keeps the same
    extension id, so one call both installs and refreshes the theme. It is
    deliberately not preceded by Extensions.uninstall: Chromium refuses to
    uninstall an extension that came from --load-extension, which is exactly its
    state after every Helium restart, so that call turned a working live reload
    into a spurious "restart Helium" on the first switch after each start.
    """
    port_file = devtools_port_file(config_home)
    if port_file is None and configured_debugging_port(config_home) is None:
        return "deferred", "no DevTools endpoint is configured"
    client: WebSocketClient | None = None
    try:
        client = WebSocketClient(browser_endpoint(config_home, port_file))
        client.call("Extensions.loadUnpacked", {"path": str(runtime.resolve())})
        return "reloaded", ""
    except (ConnectionError, OSError, RuntimeError, ValueError, json.JSONDecodeError) as error:
        return "deferred", f"{type(error).__name__}: {error}"
    finally:
        if client is not None:
            client.close()


def main() -> int:
    args = parse_args()
    config_home = (
        args.config_home.expanduser()
        if args.config_home
        else Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    )
    data_home = (
        args.data_home.expanduser()
        if args.data_home
        else Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    )
    mode = selected_mode(args.mode)
    runtime = data_home / "dotfiles" / RUNTIME_NAME
    try:
        changed = write_runtime_theme(runtime, mode)
        live, detail = "unchanged", ""
        if changed and not args.no_live_reload:
            live, detail = reload_live_theme(config_home, runtime)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"helium-gruvbox-theme: {error}", file=sys.stderr)
        return 1

    suffix = ""
    if live == "reloaded":
        suffix = "; running Helium reloaded"
    elif live == "deferred":
        # Name the reason: a silent "restart Helium" hides real CDP failures.
        suffix = "; live reload deferred until Helium restart"
        if detail:
            suffix += f" ({detail})"
    print(f"Helium Gruvbox: {mode} ({'updated' if changed else 'unchanged'}{suffix})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
