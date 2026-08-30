#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
runtime="$(python3 "$root/prepare.py")"
python3 "$root/center-title.py" "$runtime/shell.qml"
python3 "$root/agents-panel.py" "$runtime/shell.qml"
python3 "$root/prepare-agents-refresh-ui.py" "$runtime"
python3 "$root/prepare-launcher.py" "$runtime"
python3 "$root/prepare-ui-fixes.py" "$runtime"
exec quickshell -p "$runtime"
