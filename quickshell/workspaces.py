#!/usr/bin/env python3
"""Print occupied regular Hyprland workspaces as a JSON array."""

import json
import subprocess


def main():
    try:
        result = subprocess.run(
            ["hyprctl", "-j", "clients"],
            check=False,
            capture_output=True,
            text=True,
            timeout=2,
        )
        clients = json.loads(result.stdout) if result.returncode == 0 else []
        workspaces = sorted({
            int(client.get("workspace", {}).get("id", 0))
            for client in clients
            if int(client.get("workspace", {}).get("id", 0)) > 0
        })
    except Exception:
        workspaces = []
    print(json.dumps(workspaces, separators=(",", ":")))


if __name__ == "__main__":
    main()
