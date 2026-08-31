#!/usr/bin/env python3
"""Attach the executed preview and post-apply doctor result to a run record."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run", required=True)
    parser.add_argument("--plan", required=True)
    args = parser.parse_args()

    run_path = Path(args.run)
    plan_path = Path(args.plan)
    if not run_path.exists() or not plan_path.exists():
        return 0

    try:
        record = json.loads(run_path.read_text())
        plan = json.loads(plan_path.read_text())
    except (OSError, json.JSONDecodeError):
        return 0

    command = [
        sys.executable,
        str(ROOT / "scripts/dots-state.py"),
        "doctor",
        "--json",
        "--machine",
        str(plan["machine"]),
        "--profile",
        ",".join(str(item) for item in plan["profiles"]),
    ]
    process = subprocess.run(
        command,
        cwd=ROOT,
        env=os.environ.copy(),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    try:
        doctor = json.loads(process.stdout) if process.stdout else None
    except json.JSONDecodeError:
        doctor = None

    record["plan"] = plan
    record["doctor"] = {
        "exit_code": process.returncode,
        "result": doctor,
    }
    if doctor is None:
        record["doctor"]["stdout"] = process.stdout
        record["doctor"]["stderr"] = process.stderr

    run_path.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
