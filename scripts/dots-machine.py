#!/usr/bin/env python3
"""Machine-wide drift, provisioning and staging helpers for dots."""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
STATE_PATH = ROOT / "scripts/dots-state.py"
spec = importlib.util.spec_from_file_location("dots_state", STATE_PATH)
if spec is None or spec.loader is None:
    raise RuntimeError(f"cannot load state engine: {STATE_PATH}")
state = importlib.util.module_from_spec(spec)
spec.loader.exec_module(state)


def run(argv, *, cwd=ROOT, env=None, capture=True):
    kwargs = {
        "cwd": cwd,
        "env": env or os.environ.copy(),
        "text": True,
        "check": False,
    }
    if capture:
        kwargs.update(stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return subprocess.run([str(item) for item in argv], **kwargs)


def explicit_pacman_packages() -> list[str] | None:
    """Return explicitly installed Arch packages, not dependency closure."""
    if not shutil.which("pacman"):
        return None
    process = run(["pacman", "-Qqe"])
    if process.returncode:
        return None
    return sorted({line.strip() for line in process.stdout.splitlines() if line.strip()})


def unexpected_user_services(context: dict, desired_services: set[str]) -> list[str]:
    """Report enabled local user units that are outside the selected manifest."""
    if not state.systemd_user():
        return []
    unit_dirs = [context["config"] / "systemd/user", context["data"] / "systemd/user"]
    local_units = set()
    for unit_dir in unit_dirs:
        if unit_dir.exists():
            local_units.update(path.name for path in unit_dir.glob("*.service"))
    unexpected = []
    for unit in sorted(local_units - desired_services):
        if state.user_unit_state(unit, "is-enabled") == "enabled":
            unexpected.append(unit)
    return unexpected


def drift(context: dict) -> dict:
    profiles, desired = state.desired(context)
    plan_data = state.plan(context, "full")
    managed = state.primary_changes(plan_data["changes"])
    missing_required = [
        item
        for item in plan_data["dependencies"]
        if item["required"] and not item["installed"]
    ]
    missing_optional = [
        item
        for item in plan_data["dependencies"]
        if not item["required"] and not item["installed"]
    ]

    explicit = explicit_pacman_packages()
    declared_explicit = {
        str(item["package"])
        for item in desired["packages"]
        if str(item.get("manager", "")) in {"pacman", "aur"}
    }
    extras = [] if explicit is None else sorted(set(explicit) - declared_explicit)
    unexpected = unexpected_user_services(context, set(desired["services"]))
    required_drift = bool(managed or plan_data["blockers"] or missing_required)

    return {
        "schema": 1,
        "type": "drift",
        "machine": plan_data["machine"],
        "machine_file": plan_data["machine_file"],
        "profiles": profiles,
        "capabilities": plan_data["capabilities"],
        "managed_changes": managed,
        "blockers": plan_data["blockers"],
        "missing_required": missing_required,
        "missing_optional": missing_optional,
        "extra_explicit_packages": extras,
        "explicit_package_inventory_available": explicit is not None,
        "unexpected_user_services": unexpected,
        "summary": {
            "managed_changes": len(managed),
            "blockers": len(plan_data["blockers"]),
            "missing_required": len(missing_required),
            "missing_optional": len(missing_optional),
            "extra_explicit_packages": len(extras),
            "unexpected_user_services": len(unexpected),
            "required_drift": required_drift,
        },
    }


def print_drift(result: dict) -> None:
    print(f"Machine: {result['machine']} ({result['machine_file']})")
    print(f"Profiles: {', '.join(result['profiles'])}")
    print(f"Capabilities: {', '.join(result['capabilities']) or '-'}")

    print("\n== required drift ==")
    if not result["managed_changes"] and not result["blockers"] and not result["missing_required"]:
        print("  none")
    for item in result["missing_required"]:
        print(f"  missing package  {item['package']} ({item['manager']}) — {item['reason']}")
    for item in result["managed_changes"]:
        target = item.get("path") or item.get("unit") or item.get("name") or item.get("detail")
        print(f"  {item['kind']:<10} {item['action']:<11} {target}")
    for blocker in result["blockers"]:
        print(f"  blocker          {blocker}")

    print("\n== informational drift ==")
    for item in result["missing_optional"]:
        print(f"  optional missing {item['package']} — {item['reason']}")
    if result["explicit_package_inventory_available"]:
        for package in result["extra_explicit_packages"]:
            print(f"  extra explicit   {package}")
    else:
        print("  explicit package inventory unavailable (pacman not found)")
    for unit in result["unexpected_user_services"]:
        print(f"  unexpected user service {unit}")
    if (
        not result["missing_optional"]
        and not result["extra_explicit_packages"]
        and not result["unexpected_user_services"]
    ):
        print("  none")

    summary = result["summary"]
    print(
        f"\nDrift: {summary['managed_changes']} managed change(s), "
        f"{summary['missing_required']} required package(s) missing, "
        f"{summary['blockers']} blocker(s); extras are informational."
    )


def provision_plan(context: dict) -> dict:
    profiles, desired = state.desired(context)
    missing = [
        dict(item)
        for item in desired["packages"]
        if bool(item.get("required", True)) and not shutil.which(str(item["command"]))
    ]
    missing_optional = [
        dict(item)
        for item in desired["packages"]
        if not bool(item.get("required", True)) and not shutil.which(str(item["command"]))
    ]
    missing_prerequisites = []
    for item in desired["prerequisites"]:
        ok, detail = state.prerequisite_status(item)
        if not ok and bool(item.get("required", True)):
            missing_prerequisites.append({**item, "detail": detail})

    groups: dict[str, list[str]] = {}
    for item in missing:
        groups.setdefault(str(item.get("manager", "unknown")), []).append(str(item["package"]))

    actions = []
    blockers = []
    requires_arch = bool(groups.get("pacman") or groups.get("aur"))
    if requires_arch and not Path("/etc/arch-release").exists():
        blockers.append("pacman/AUR provisioning is declared, but this is not an Arch system")

    pacman_packages = sorted(set(groups.get("pacman", [])))
    if pacman_packages:
        if not shutil.which("pacman"):
            blockers.append("pacman packages are missing, but pacman is not available")
        elif os.geteuid() != 0 and not shutil.which("sudo"):
            blockers.append("pacman provisioning needs sudo, but sudo is not available")
        else:
            prefix = [] if os.geteuid() == 0 else ["sudo"]
            actions.append(
                {
                    "manager": "pacman",
                    "argv": prefix + ["pacman", "-S", "--needed", *pacman_packages],
                }
            )

    aur_packages = sorted(set(groups.get("aur", [])))
    if aur_packages:
        helper = shutil.which("paru") or shutil.which("yay")
        if not helper:
            blockers.append("AUR packages are missing, but neither paru nor yay is available")
        else:
            actions.append(
                {"manager": "aur", "argv": [helper, "-S", "--needed", *aur_packages]}
            )

    uv_packages = sorted(set(groups.get("uv-tool", [])))
    if uv_packages:
        uv = shutil.which("uv")
        uv_will_be_installed = any(
            str(item.get("command")) == "uv" and str(item.get("manager")) == "pacman"
            for item in missing
        )
        if not uv and not uv_will_be_installed:
            blockers.append("uv-tool packages are missing, but uv is not available or planned")
        else:
            executable = uv or "uv"
            for package in uv_packages:
                actions.append(
                    {"manager": "uv-tool", "argv": [executable, "tool", "install", package]}
                )

    supported = {"pacman", "aur", "uv-tool"}
    for manager, packages in sorted(groups.items()):
        if manager not in supported:
            blockers.append(
                f"no installer is defined for {manager!r}: {', '.join(sorted(set(packages)))}"
            )

    for item in missing_prerequisites:
        if item.get("kind") != "system-service":
            blockers.append(f"no prerequisite installer is defined for kind {item.get('kind')!r}")
            continue
        if not shutil.which("systemctl"):
            blockers.append(f"system prerequisite {item.get('name')} needs systemctl")
            continue
        if os.geteuid() != 0 and not shutil.which("sudo"):
            blockers.append(f"system prerequisite {item.get('name')} needs sudo")
            continue
        prefix = [] if os.geteuid() == 0 else ["sudo"]
        actions.append(
            {
                "manager": "system-service",
                "argv": prefix + ["systemctl", "enable", "--now", str(item["name"])],
            }
        )

    return {
        "schema": 1,
        "type": "provision",
        "machine": context["machine"],
        "machine_file": str(context["machine_file"].relative_to(ROOT)),
        "profiles": profiles,
        "capabilities": desired["capabilities"],
        "missing": missing,
        "missing_optional": missing_optional,
        "missing_prerequisites": missing_prerequisites,
        "actions": actions,
        "blockers": blockers,
        "summary": {
            "missing": len(missing),
            "missing_optional": len(missing_optional),
            "missing_prerequisites": len(missing_prerequisites),
            "actions": len(actions),
            "blockers": len(blockers),
            "no_op": not missing and not missing_prerequisites,
        },
    }


def print_provision(result: dict, dry_run: bool) -> None:
    print(f"Machine: {result['machine']} ({result['machine_file']})")
    print(f"Profiles: {', '.join(result['profiles'])}")

    print("\n== missing programs ==")
    if not result["missing"]:
        print("  none")
    for item in result["missing"]:
        print(f"  {item['package']:<28} {item.get('manager', 'unknown'):<8} — {item.get('reason', '')}")
    for item in result["missing_optional"]:
        print(f"  optional {item['package']:<19} — {item.get('reason', '')}")

    print("\n== missing prerequisites ==")
    if not result["missing_prerequisites"]:
        print("  none")
    for item in result["missing_prerequisites"]:
        print(
            f"  {item.get('kind')} {item.get('name')} — "
            f"{item.get('reason', '')} ({item.get('detail')})"
        )

    print("\n== actions ==")
    if not result["actions"]:
        print("  none")
    for action in result["actions"]:
        prefix = "DRY-RUN " if dry_run else "RUN     "
        print("  " + prefix + " ".join(action["argv"]))

    if result["blockers"]:
        print("\n== blockers ==")
        for blocker in result["blockers"]:
            print(f"  BLOCK {blocker}")


def provision(context: dict, dry_run: bool, assume_yes: bool, as_json: bool) -> int:
    result = provision_plan(context)
    if as_json:
        print(json.dumps({**result, "dry_run": dry_run}, indent=2, sort_keys=True))
    else:
        print_provision(result, dry_run)

    if result["blockers"]:
        return 2
    if dry_run or not result["actions"]:
        return 0
    if not assume_yes and sys.stdin.isatty():
        answer = input("\nRun these provisioning actions? [y/N] ").strip().lower()
        if answer not in {"y", "yes"}:
            print("Provision cancelled.")
            return 1

    for action in result["actions"]:
        process = run(action["argv"], capture=False)
        if process.returncode:
            return process.returncode
    print("\nProvision: done. Run `dots apply` next.")
    return 0


def stage(ref: str, machine: str | None, profile: str | None, as_json: bool) -> int:
    """Validate a candidate in a detached temporary worktree and HOME."""
    with tempfile.TemporaryDirectory(prefix="dots-stage-") as temp:
        base = Path(temp)
        checkout = base / "checkout"
        home = base / "home"
        home.mkdir()
        added = run(["git", "-C", ROOT, "worktree", "add", "--detach", checkout, ref])
        if added.returncode:
            print(added.stderr or added.stdout, file=sys.stderr, end="")
            return 2
        try:
            env = os.environ.copy()
            env.update(
                HOME=str(home),
                XDG_CONFIG_HOME=str(home / ".config"),
                XDG_DATA_HOME=str(home / ".local/share"),
                XDG_CACHE_HOME=str(home / ".cache"),
                XDG_STATE_HOME=str(home / ".local/state"),
            )
            check = run([checkout / "dots", "check"], cwd=checkout, env=env)
            plan_argv = [checkout / "dots", "plan", "--json"]
            if machine:
                plan_argv += ["--machine", machine]
            if profile:
                plan_argv += ["--profile", profile]
            preview = run(plan_argv, cwd=checkout, env=env)
            try:
                plan_data = json.loads(preview.stdout) if preview.stdout else None
            except json.JSONDecodeError:
                plan_data = None
            ready = check.returncode == 0 and preview.returncode == 0 and plan_data is not None
            result = {
                "schema": 1,
                "type": "stage",
                "ref": ref,
                "candidate_ready": ready,
                "check": {
                    "returncode": check.returncode,
                    "stdout": check.stdout,
                    "stderr": check.stderr,
                },
                "plan": {
                    "returncode": preview.returncode,
                    "data": plan_data,
                    "stderr": preview.stderr,
                },
                "activation": "explicit: run dots apply from the checkout chosen for activation",
            }
            if as_json:
                print(json.dumps(result, indent=2, sort_keys=True))
            else:
                print(f"Candidate: {ref}")
                print(f"dots check: {'ok' if check.returncode == 0 else 'FAILED'}")
                if check.stdout:
                    print(check.stdout, end="")
                if check.stderr:
                    print(check.stderr, end="", file=sys.stderr)
                if plan_data is not None:
                    state.print_plan(plan_data)
                elif preview.stdout:
                    print(preview.stdout, end="")
                if preview.stderr:
                    print(preview.stderr, end="", file=sys.stderr)
                print("\nCandidate ready." if ready else "\nCandidate is not ready.")
                print("No active ~/.config links were switched; activation remains explicit.")
            return 0 if ready else 1
        finally:
            run(["git", "-C", ROOT, "worktree", "remove", "--force", checkout])


def common(parser) -> None:
    parser.add_argument("--machine")
    parser.add_argument("--profile")


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)

    drift_parser = sub.add_parser("drift", help="compare the whole machine with the manifest")
    common(drift_parser)
    drift_parser.add_argument("--json", action="store_true")

    provision_parser = sub.add_parser("provision", help="install missing manifest programs")
    common(provision_parser)
    provision_parser.add_argument("--dry-run", action="store_true")
    provision_parser.add_argument("--yes", action="store_true")
    provision_parser.add_argument("--json", action="store_true")

    stage_parser = sub.add_parser("stage", help="validate a ref in an isolated worktree")
    stage_parser.add_argument("ref", nargs="?", default="HEAD")
    stage_parser.add_argument("--machine")
    stage_parser.add_argument("--profile")
    stage_parser.add_argument("--json", action="store_true")

    args = parser.parse_args()
    try:
        if args.cmd == "stage":
            return stage(args.ref, args.machine, args.profile, args.json)
        context = state.ctx(args.machine, args.profile)
        if args.cmd == "drift":
            result = drift(context)
            if args.json:
                print(json.dumps(result, indent=2, sort_keys=True))
            else:
                print_drift(result)
            return 1 if result["summary"]["required_drift"] else 0
        return provision(context, args.dry_run, args.yes, args.json)
    except (OSError, RuntimeError) as error:
        print(f"dots: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
