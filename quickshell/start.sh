#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
runtime="$(python3 "$root/prepare.py")"
exec quickshell -p "$runtime"
