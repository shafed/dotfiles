#!/usr/bin/env python3
"""Profile-aware plan/apply/doctor/history/rollback/provision engine for dots."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import tomllib
import uuid

ROOT = Path(__file__).resolve().parents[1]


def read_toml(path: Path) -> dict:
    with path.open("rb") as handle:
        return tomllib.load(handle)


def ctx(machine: str | None = None, profile: str | None = None) -> dict:
    home = Path(os.environ.get("HOME", str(Path.home()))).expanduser()
    context = {
        "root": ROOT,
        "home": home,
        "config": Path(os.environ.get("XDG_CONFIG_HOME", home / ".config")),
        "data": Path(os.environ.get("XDG_DATA_HOME", home / ".local/share")),
        "cache": Path(os.environ.get("XDG_CACHE_HOME", home / ".cache")),
        "state": Path(os.environ.get("XDG_STATE_HOME", home / ".local/state")),
    }
    requested = machine or os.environ.get("DOTS_MACHINE") or os.uname().nodename
    machine_file = ROOT / "machines" / f"{requested}.toml"
    if not machine_file.exists():
        requested, machine_file = "default", ROOT / "machines/default.toml"
    if not machine_file.exists():
        raise RuntimeError(f"machine definition missing: {machine_file}")
    machine_data = read_toml(machine_file).get("machine", {})
    override = profile or os.environ.get("DOTS_PROFILE")
    names = (
        [entry.strip() for entry in override.split(",") if entry.strip()]
        if override
        else list(machine_data.get("profiles", []))
    )
    context.update(
        machine=requested,
        machine_file=machine_file,
        requested_profiles=names or ["base"],
    )
    return context


def ex(value: object, context: dict) -> str:
    allowed = {key: str(context[key]) for key in ("root", "home", "config", "data", "cache", "state")}
    return str(value).format_map(allowed)


def uniq(items):
    return list(dict.fromkeys(items))


def desired_for(context: dict, requested_profiles: list[str]) -> tuple[list[str], dict]:
    order: list[str] = []
    visiting: set[str] = set()
    loaded: dict[str, dict] = {}

    def visit(name: str) -> None:
        if name in order:
            return
        if name in visiting:
            raise RuntimeError(f"profile include cycle at {name}")
        path = ROOT / "profiles" / f"{name}.toml"
        if not path.exists():
            raise RuntimeError(f"profile not found: {name}")
        visiting.add(name)
        data = read_toml(path)
        loaded[name] = data
        for parent in data.get("profile", {}).get("includes", []):
            visit(str(parent))
        visiting.remove(name)
        order.append(name)

    for name in requested_profiles:
        visit(name)

    out = {
        key: []
        for key in (
            "capabilities",
            "config_dirs",
            "sources",
            "services",
            "links",
            "files",
            "packages",
            "generators",
            "prerequisites",
        )
    }
    for name in order:
        data = loaded[name]
        meta = data.get("profile", {})
        for key in ("capabilities", "config_dirs", "sources", "services"):
            out[key] += [str(item) for item in meta.get(key, [])]
        for key in ("links", "files", "packages", "generators", "prerequisites"):
            out[key] += [dict(item) for item in data.get(key, [])]

    machine = read_toml(context["machine_file"]).get("machine", {})
    out["capabilities"] += [str(item) for item in machine.get("capabilities", [])]
    disabled = {str(item) for item in machine.get("disable_capabilities", [])}
    out["capabilities"] = [item for item in uniq(out["capabilities"]) if item not in disabled]
    for key in ("config_dirs", "sources", "services"):
        out[key] = uniq(out[key])
    for key, field in (
        ("links", "destination"),
        ("files", "destination"),
        ("packages", "command"),
        ("generators", "name"),
    ):
        keyed = {}
        for item in out[key]:
            keyed[str(item[field])] = item
        out[key] = list(keyed.values())
    keyed_prereqs = {}
    for item in out["prerequisites"]:
        key = f"{item.get('kind', '')}:{item.get('name', '')}"
        keyed_prereqs[key] = item
    out["prerequisites"] = list(keyed_prereqs.values())
    return order, out


def desired(context: dict) -> tuple[list[str], dict]:
    return desired_for(context, context["requested_profiles"])


def all_known(context: dict) -> dict:
    known = {key: [] for key in ("links", "files", "services", "generators")}
    for profile_path in sorted((ROOT / "profiles").glob("*.toml")):
        data = read_toml(profile_path)
        meta = data.get("profile", {})
        for config_dir in meta.get("config_dirs", []):
            known["links"].append(
                {
                    "source": str(config_dir),
                    "destination": f"{{config}}/{config_dir}",
                    "reason": f"activate the tracked {config_dir} configuration",
                }
            )
        known["links"] += [dict(item) for item in data.get("links", [])]
        known["files"] += [dict(item) for item in data.get("files", [])]
        known["services"] += [str(item) for item in meta.get("services", [])]
        known["generators"] += [dict(item) for item in data.get("generators", [])]
    for key, field in (("links", "destination"), ("files", "destination"), ("generators", "name")):
        deduped = {}
        for item in known[key]:
            deduped[str(item[field])] = item
        known[key] = list(deduped.values())
    known["services"] = uniq(known["services"])
    return known


def links_for(data: dict) -> list[dict]:
    return [
        {
            "source": name,
            "destination": f"{{config}}/{name}",
            "reason": f"activate the tracked {name} configuration",
        }
        for name in data["config_dirs"]
    ] + data["links"]


def run(argv, context: dict, env=None, capture=True) -> subprocess.CompletedProcess:
    kwargs = {
        "cwd": ROOT,
        "env": env or os.environ.copy(),
        "text": True,
        "check": False,
    }
    if capture:
        kwargs.update(stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return subprocess.run([ex(item, context) for item in argv], **kwargs)


def remove_path(path: Path) -> None:
    if path.is_dir() and not path.is_symlink():
        shutil.rmtree(path)
    elif path.exists() or path.is_symlink():
        path.unlink()


def copy_keep(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists() or dst.is_symlink():
        remove_path(dst)
    if src.is_symlink():
        os.symlink(os.readlink(src), dst)
    elif src.is_dir():
        shutil.copytree(src, dst, symlinks=True)
    else:
        shutil.copy2(src, dst)


def tree_digest(path: Path) -> str:
    digest = hashlib.sha256()
    for child in sorted(path.rglob("*"), key=lambda item: str(item.relative_to(path))):
        rel = str(child.relative_to(path)).encode()
        digest.update(rel + b"\0")
        if child.is_symlink():
            digest.update(b"L" + os.readlink(child).encode() + b"\0")
        elif child.is_file():
            digest.update(b"F" + child.read_bytes())
        elif child.is_dir():
            digest.update(b"D")
    return digest.hexdigest()


def snapshot(path: Path, replace_from: str | None = None, replace_to: str | None = None) -> dict:
    if path.is_symlink():
        target = os.readlink(path)
        if replace_from and replace_to:
            target = target.replace(replace_from, replace_to)
        return {"type": "symlink", "target": target}
    if path.is_file():
        data = path.read_bytes()
        if replace_from and replace_to:
            data = data.replace(replace_from.encode(), replace_to.encode())
        return {
            "type": "file",
            "sha256": hashlib.sha256(data).hexdigest(),
            "mode": f"{stat.S_IMODE(path.stat().st_mode):04o}",
        }
    if path.is_dir():
        return {
            "type": "directory",
            "sha256": tree_digest(path),
            "mode": f"{stat.S_IMODE(path.stat().st_mode):04o}",
        }
    return {"type": "absent"}


def generator_render(item: dict, context: dict) -> tuple[int, str, list[dict]]:
    with tempfile.TemporaryDirectory(prefix="dots-plan-") as temp:
        temp_context = dict(context)
        home = Path(temp)
        temp_context.update(
            home=home,
            config=home / ".config",
            data=home / ".local/share",
            cache=home / ".cache",
            state=home / ".local/state",
        )
        pairs: list[tuple[Path, Path]] = []
        for template in item.get("outputs", []):
            actual = Path(ex(template, context))
            rendered = Path(ex(template, temp_context))
            pairs.append((actual, rendered))
            if actual.exists() or actual.is_symlink():
                copy_keep(actual, rendered)
        env = os.environ.copy()
        env.update(
            HOME=str(home),
            XDG_CONFIG_HOME=str(temp_context["config"]),
            XDG_DATA_HOME=str(temp_context["data"]),
            XDG_CACHE_HOME=str(temp_context["cache"]),
            XDG_STATE_HOME=str(temp_context["state"]),
            DOTS_REAL_HOME=str(context["home"]),
            DOTS_REAL_XDG_DATA_HOME=str(context["data"]),
        )
        process = run(item["apply"], temp_context, env)
        if process.returncode:
            return process.returncode, (process.stderr or process.stdout).strip(), []
        rendered = [
            snapshot(expected, str(home), str(context["home"]))
            for _, expected in pairs
        ]
        return 0, "", rendered


def generator_check(item: dict, context: dict) -> tuple[int, str]:
    first_rc, first_detail, first = generator_render(item, context)
    if first_rc:
        return first_rc, first_detail
    second_rc, second_detail, second = generator_render(item, context)
    if second_rc:
        return second_rc, second_detail
    if first != second:
        return 2, "same generator input produced different outputs"
    actual = [snapshot(Path(ex(template, context))) for template in item.get("outputs", [])]
    stale = [
        ex(template, context)
        for template, current, rendered in zip(item.get("outputs", []), actual, first)
        if current != rendered
    ]
    if stale:
        return 1, "stale outputs: " + ", ".join(stale)
    return 0, ""


def systemd_user() -> bool:
    if not shutil.which("systemctl"):
        return False
    return subprocess.run(
        ["systemctl", "--user", "show-environment"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    ).returncode == 0


def user_unit_state(unit: str, verb: str) -> str:
    process = subprocess.run(
        ["systemctl", "--user", verb, unit],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return process.stdout.strip() or "unknown"


def system_unit_enabled(unit: str) -> bool:
    if not shutil.which("systemctl"):
        return False
    process = subprocess.run(
        ["systemctl", "is-enabled", unit],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return process.returncode == 0


def add(changes: list[dict], kind: str, action: str, **extra) -> None:
    changes.append({"kind": kind, "action": action, **extra})


def migration_backup_path(detail: str, context: dict) -> Path | None:
    candidates = [context["config"] / "waybar", context["data"] / "darkman"]
    for candidate in candidates:
        if detail.startswith(str(candidate) + " ") and (candidate.exists() or candidate.is_symlink()):
            return candidate
    return None


def primary_changes(changes: list[dict]) -> list[dict]:
    return [
        item
        for item in changes
        if item["kind"] != "cache"
        and not (item["kind"] == "service" and item["action"] == "try-restart")
    ]


def plan(context: dict, mode: str = "full") -> dict:
    profiles, data = desired(context)
    known = all_known(context)
    blockers: list[str] = []
    changes: list[dict] = []
    deps: list[dict] = []

    sources = [ROOT / item for item in data["config_dirs"] + data["sources"]]
    sources += [ROOT / str(item["source"]) for item in data["links"]]
    for source in sources:
        if not source.exists() and not source.is_symlink():
            blockers.append(f"managed source is missing: {source.relative_to(ROOT)}")

    for item in data["packages"]:
        deps.append(
            {
                "command": str(item["command"]),
                "package": str(item["package"]),
                "manager": str(item.get("manager", "unknown")),
                "required": bool(item.get("required", True)),
                "reason": str(item.get("reason", "profile requirement")),
                "installed": shutil.which(str(item["command"])) is not None,
            }
        )

    pending: list[str] = []
    migratable: set[str] = set()
    migration_process = None
    if mode == "full":
        migration_process = run([str(ROOT / "scripts/dots-migrate.sh"), "--check"], context)
        pending = [line[8:].strip() for line in migration_process.stdout.splitlines() if line.startswith("PENDING ")]
        for detail in pending:
            if detail.startswith(str(context["data"] / "darkman") + " "):
                migratable.add(str(context["data"] / "darkman"))

    desired_links = links_for(data)
    desired_link_destinations = {ex(item["destination"], context) for item in desired_links}
    for item in desired_links:
        source = ROOT / str(item["source"])
        destination = Path(ex(item["destination"], context))
        same = destination.is_symlink() and os.path.realpath(source) == os.path.realpath(destination)
        if same:
            continue
        if destination.exists() and not destination.is_symlink() and str(destination) not in migratable:
            blockers.append(f"{destination} exists and is not a symlink")
            continue
        action = "replace" if destination.exists() or destination.is_symlink() else "create"
        add(
            changes,
            "symlink",
            action,
            path=str(destination),
            source=str(source),
            reason=str(item.get("reason", "managed symlink")),
        )

    # Profile changes converge in both directions. A link from another known
    # profile is removed only when it still points to the source owned by this
    # repository; unrelated user paths are never treated as garbage.
    for item in known["links"]:
        destination = Path(ex(item["destination"], context))
        if str(destination) in desired_link_destinations or not destination.is_symlink():
            continue
        source = ROOT / str(item["source"])
        if os.path.realpath(destination) == os.path.realpath(source):
            add(
                changes,
                "symlink",
                "remove",
                path=str(destination),
                source=str(source),
                reason="managed by a profile that is not selected",
            )

    desired_file_destinations = {ex(item["destination"], context) for item in data["files"]}
    for item in data["files"]:
        destination = Path(ex(item["destination"], context))
        content = ex(item["content"], context)
        modebits = int(str(item.get("mode", "0644")), 8)
        if destination.is_symlink() or (destination.exists() and not destination.is_file()):
            blockers.append(f"{destination} blocks a managed file and is not a regular file")
            continue
        current, current_mode = (
            (destination.read_text(), stat.S_IMODE(destination.stat().st_mode))
            if destination.exists()
            else (None, None)
        )
        if current != content:
            add(
                changes,
                "file",
                "update" if destination.exists() else "create",
                path=str(destination),
                mode=f"{modebits:04o}",
                reason=str(item.get("reason", "managed file")),
            )
        elif current_mode != modebits:
            add(
                changes,
                "file",
                "chmod",
                path=str(destination),
                mode=f"{modebits:04o}",
                reason=str(item.get("reason", "managed file")),
            )

    for item in known["files"]:
        destination = Path(ex(item["destination"], context))
        if str(destination) in desired_file_destinations or not destination.is_file() or destination.is_symlink():
            continue
        if destination.read_text() == ex(item["content"], context):
            add(
                changes,
                "file",
                "remove",
                path=str(destination),
                reason="managed by a profile that is not selected",
            )

    if mode == "full":
        for item in data["generators"]:
            rc, detail = generator_check(item, context)
            if rc == 1:
                add(
                    changes,
                    "generator",
                    "run",
                    name=str(item["name"]),
                    reason=str(item.get("reason", "generated runtime state is stale")),
                    outputs=[ex(output, context) for output in item.get("outputs", [])],
                    command=[ex(command, context) for command in item["apply"]],
                    check_output=detail,
                )
            elif rc:
                blockers.append(f"generator check failed for {item['name']}: {detail or f'exit {rc}'}")

        if systemd_user():
            desired_services = set(data["services"])
            for unit in data["services"]:
                enabled = user_unit_state(unit, "is-enabled")
                if enabled not in {"enabled", "static", "indirect"}:
                    add(
                        changes,
                        "service",
                        "enable",
                        unit=unit,
                        reason="selected profile requires this user service",
                    )
            for unit in known["services"]:
                if unit in desired_services:
                    continue
                state = user_unit_state(unit, "is-enabled")
                active = user_unit_state(unit, "is-active")
                if state == "enabled" or active == "active":
                    add(
                        changes,
                        "service",
                        "disable",
                        unit=unit,
                        reason="managed by a profile that is not selected",
                    )

            if "desktop" in data["capabilities"]:
                dunst_state = user_unit_state("dunst.service", "is-enabled")
                if dunst_state != "masked":
                    add(
                        changes,
                        "service",
                        "mask",
                        unit="dunst.service",
                        reason="Quickshell owns desktop notifications",
                    )

        for detail in pending:
            if "exists, but Waybar is retired" in detail:
                blockers.append(f"migration needs manual decision: {detail}")
            else:
                change = {"detail": detail, "reason": "retired runtime state"}
                backup_path = migration_backup_path(detail, context)
                if backup_path:
                    change["path"] = str(backup_path)
                add(changes, "migration", "apply", **change)
        if migration_process and migration_process.returncode not in (0, 1):
            blockers.append(
                f"migration check failed: {(migration_process.stderr or migration_process.stdout).strip()}"
            )

        if primary_changes(changes):
            runtime = context["cache"] / "dots-shell/quickshell"
            if runtime.exists() or runtime.is_symlink():
                add(
                    changes,
                    "cache",
                    "remove",
                    path=str(runtime),
                    reason="rebuild Quickshell derived runtime after changes",
                )
            for unit in data["services"]:
                add(
                    changes,
                    "service",
                    "try-restart",
                    unit=unit,
                    reason="pick up applied state if already running",
                )

    required_missing = sum(1 for item in deps if item["required"] and not item["installed"])
    optional_missing = sum(1 for item in deps if not item["required"] and not item["installed"])
    return {
        "schema": 2,
        "machine": context["machine"],
        "machine_file": str(context["machine_file"].relative_to(ROOT)),
        "profiles": profiles,
        "capabilities": data["capabilities"],
        "dependencies": deps,
        "prerequisites": data["prerequisites"],
        "changes": changes,
        "blockers": blockers,
        "summary": {
            "changes": len(changes),
            "drift_changes": len(primary_changes(changes)),
            "blockers": len(blockers),
            "required_dependencies_missing": required_missing,
            "optional_dependencies_missing": optional_missing,
            "no_op": not primary_changes(changes) and not blockers,
        },
    }


def print_plan(plan_data: dict) -> None:
    print(f"Machine: {plan_data['machine']} ({plan_data['machine_file']})")
    print(f"Profiles: {', '.join(plan_data['profiles'])}")
    print(f"Capabilities: {', '.join(plan_data['capabilities']) or '-'}")
    print("\n== dependencies ==")
    for item in plan_data["dependencies"]:
        status = "ok" if item["installed"] else ("MISSING" if item["required"] else "optional")
        print(f"  {status:<8} {item['command']:<18} {item['package']} — {item['reason']}")
    print("\n== planned changes ==")
    if not plan_data["changes"]:
        print("  no machine changes")
    for item in plan_data["changes"]:
        target = item.get("path") or item.get("unit") or item.get("name") or item.get("detail")
        print(f"  {item['action'].upper():<11} {item['kind']:<10} {target}")
        if item.get("reason"):
            print(f"              {item['reason']}")
        for output in item.get("outputs", []):
            print(f"              output: {output}")
    if plan_data["blockers"]:
        print("\n== blockers ==")
        for item in plan_data["blockers"]:
            print(f"  BLOCK {item}")
    summary = plan_data["summary"]
    print(
        f"\nPlan: {summary['drift_changes']} drift change(s), {summary['blockers']} blocker(s), "
        f"{summary['required_dependencies_missing']} required dependency/dependencies missing."
    )


def backup(path: Path, backup_dir: Path, context: dict, records: list[dict]) -> None:
    if not path.exists() and not path.is_symlink():
        return
    try:
        relative = path.relative_to(context["home"])
    except ValueError:
        relative = Path(str(path).lstrip("/"))
    destination = backup_dir / relative
    if destination.exists() or destination.is_symlink():
        return
    backup_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    copy_keep(path, destination)
    records.append({"source": str(path), "backup": str(destination)})
    print(f"  backup: {path} -> {destination}")


def git_commit() -> str:
    process = subprocess.run(
        ["git", "-C", str(ROOT), "rev-parse", "HEAD"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return process.stdout.strip() if process.returncode == 0 else "unknown"


def write_record(path: Path, record: dict) -> None:
    path.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n")


def managed_paths_from_plan(plan_data: dict) -> set[Path]:
    paths: set[Path] = set()
    for item in plan_data["changes"]:
        if item.get("path"):
            paths.add(Path(item["path"]))
        for output in item.get("outputs", []):
            paths.add(Path(output))
    return paths


def apply(context: dict, plan_data: dict, mode: str) -> int:
    print_plan(plan_data)
    if plan_data["blockers"]:
        print("\nApply refused because the plan has blockers.", file=sys.stderr)
        return 1
    if not primary_changes(plan_data["changes"]):
        print("\nApply: no changes; desired state is already converged.")
        if mode == "links":
            return 0
        print("\n== doctor ==")
        return doctor(context, as_json=False, compact=True)

    run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid.uuid4().hex[:6]
    runs_dir = context["state"] / "dotfiles/runs"
    backup_dir = context["state"] / "dotfiles/backups" / run_id
    runs_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    record_path = runs_dir / f"{run_id}.json"
    backups: list[dict] = []
    record = {
        "schema": 2,
        "id": run_id,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "commit": git_commit(),
        "operation": "apply",
        "machine": plan_data["machine"],
        "machine_file": plan_data["machine_file"],
        "profiles": plan_data["profiles"],
        "capabilities": plan_data["capabilities"],
        "mode": mode,
        "status": "running",
        "changes": plan_data["changes"],
        "backups": backups,
        "after": {},
    }
    write_record(record_path, record)

    def fail(message: str, code: int = 1) -> int:
        record["status"] = "failed"
        record["error"] = message
        record["backups"] = backups
        for path in managed_paths_from_plan(plan_data):
            record["after"][str(path)] = snapshot(path)
        write_record(record_path, record)
        print(f"\nApply failed: {message}", file=sys.stderr)
        print(f"Run recorded: {run_id}", file=sys.stderr)
        return code

    print("\n== backup ==")
    for item in plan_data["changes"]:
        if item["kind"] in {"symlink", "file"} and item["action"] in {"replace", "update", "chmod", "remove"}:
            backup(Path(item["path"]), backup_dir, context, backups)
        elif item["kind"] == "generator":
            for output in item.get("outputs", []):
                backup(Path(output), backup_dir, context, backups)
        elif item["kind"] == "migration" and item.get("path"):
            backup(Path(item["path"]), backup_dir, context, backups)
    if not backups:
        print("  no existing managed files need backup")
    record["backups"] = backups
    write_record(record_path, record)

    print("\n== changes ==")
    _, data = desired(context)
    files = {ex(item["destination"], context): item for item in data["files"]}
    generators = {str(item["name"]): item for item in data["generators"]}

    if mode == "full" and any(item["kind"] == "migration" for item in plan_data["changes"]):
        env = os.environ.copy()
        env["DOTS_BACKUP_RUN_DIR"] = str(backup_dir)
        migration = subprocess.run(
            [str(ROOT / "scripts/dots-migrate.sh")],
            cwd=ROOT,
            env=env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )
        print(migration.stdout, end="")
        if migration.returncode:
            return fail("migration failed", migration.returncode)

    for item in plan_data["changes"]:
        if item["kind"] != "symlink":
            continue
        destination = Path(item["path"])
        source = Path(item["source"])
        if item["action"] == "remove":
            if destination.is_symlink():
                destination.unlink()
                print(f"  removed {destination}")
            continue
        destination.parent.mkdir(parents=True, exist_ok=True)
        if destination.is_symlink():
            destination.unlink()
        os.symlink(source, destination, target_is_directory=source.is_dir())
        print(f"  linked  {destination} -> {source}")

    for item in plan_data["changes"]:
        if item["kind"] != "file":
            continue
        destination = Path(item["path"])
        if item["action"] == "remove":
            remove_path(destination)
            print(f"  removed {destination}")
            continue
        profile_item = files[item["path"]]
        content = ex(profile_item["content"], context)
        modebits = int(str(profile_item.get("mode", "0644")), 8)
        destination.parent.mkdir(parents=True, exist_ok=True)
        if item["action"] != "chmod":
            destination.write_text(content)
        os.chmod(destination, modebits)
        print(f"  wrote   {destination}")

    service_changes = [
        item
        for item in plan_data["changes"]
        if item["kind"] == "service" and item["action"] in {"enable", "disable", "mask"}
    ]
    if mode == "full" and service_changes and systemd_user():
        reload_process = subprocess.run(
            ["systemctl", "--user", "daemon-reload"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        if reload_process.returncode:
            return fail("could not reload systemd user manager", reload_process.returncode)

    for item in plan_data["changes"]:
        if item["kind"] != "service" or not systemd_user():
            continue
        if item["action"] == "enable":
            subprocess.run(
                ["systemctl", "--user", "unmask", item["unit"]],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )
            process = subprocess.run(
                ["systemctl", "--user", "enable", "--now", item["unit"]],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )
            if process.returncode:
                return fail(f"could not enable {item['unit']}", process.returncode)
            print(f"  enabled {item['unit']}")
        elif item["action"] == "mask":
            process = subprocess.run(
                ["systemctl", "--user", "mask", "--now", item["unit"]],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )
            if process.returncode:
                return fail(f"could not mask {item['unit']}", process.returncode)
            print(f"  masked  {item['unit']}")
        elif item["action"] == "disable":
            process = subprocess.run(
                ["systemctl", "--user", "disable", "--now", item["unit"]],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )
            if process.returncode:
                return fail(f"could not disable {item['unit']}", process.returncode)
            print(f"  disabled {item['unit']}")

    for item in plan_data["changes"]:
        if item["kind"] != "generator":
            continue
        generator = run(generators[item["name"]]["apply"], context)
        if generator.stdout:
            print(generator.stdout, end="")
        if generator.stderr:
            print(generator.stderr, end="", file=sys.stderr)
        if generator.returncode:
            return fail(f"generator failed: {item['name']}", generator.returncode)

    for item in plan_data["changes"]:
        if item["kind"] == "cache" and item["action"] == "remove":
            path = Path(item["path"])
            remove_path(path)
            print(f"  removed {path}")

    units = [
        item["unit"]
        for item in plan_data["changes"]
        if item["kind"] == "service" and item["action"] == "try-restart"
    ]
    if mode == "full" and units and systemd_user():
        subprocess.run(["systemctl", "--user", "daemon-reload"], check=False)
        for unit in units:
            subprocess.run(
                ["systemctl", "--user", "reset-failed", unit],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )
            subprocess.run(
                ["systemctl", "--user", "try-restart", unit],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )
            print(f"  refreshed {unit} if it was running")

    for path in managed_paths_from_plan(plan_data):
        record["after"][str(path)] = snapshot(path)
    record["status"] = "applied"
    record["backups"] = backups
    write_record(record_path, record)
    print(f"\nRun recorded: {run_id}")
    if mode == "links":
        return 0

    print("\n== doctor ==")
    doctor_rc = doctor(context, as_json=False, compact=True)
    if doctor_rc:
        record["status"] = "doctor_failed"
        write_record(record_path, record)
    return doctor_rc


def prerequisite_status(item: dict) -> tuple[bool, str]:
    kind = str(item.get("kind", ""))
    name = str(item.get("name", ""))
    if kind == "system-service":
        if not shutil.which("systemctl"):
            return False, "systemctl unavailable"
        enabled = system_unit_enabled(name)
        return enabled, "enabled" if enabled else "not enabled"
    return False, f"unknown prerequisite kind: {kind}"


def doctor(context: dict, as_json: bool = False, compact: bool = False) -> int:
    plan_data = plan(context, "full")
    _, data = desired(context)
    errors: list[dict] = []
    warnings: list[dict] = []
    oks: list[dict] = []

    for blocker in plan_data["blockers"]:
        errors.append({"kind": "blocker", "message": blocker})
    for item in primary_changes(plan_data["changes"]):
        target = item.get("path") or item.get("unit") or item.get("name") or item.get("detail")
        errors.append(
            {
                "kind": "drift",
                "message": f"{item['kind']} {item['action']}: {target} — {item.get('reason', 'profile drift')}",
            }
        )

    for item in plan_data["dependencies"]:
        message = f"{item['command']} ({item['package']}) — {item['reason']}"
        if item["installed"]:
            oks.append({"kind": "dependency", "message": message})
        elif item["required"]:
            errors.append({"kind": "dependency", "message": "missing: " + message})
        else:
            warnings.append({"kind": "dependency", "message": "optional missing: " + message})

    for item in data["prerequisites"]:
        ok, detail = prerequisite_status(item)
        message = f"{item.get('name')} — {item.get('reason', 'profile prerequisite')} ({detail})"
        if ok:
            oks.append({"kind": "prerequisite", "message": message})
        elif bool(item.get("required", True)):
            errors.append({"kind": "prerequisite", "message": message})
        else:
            warnings.append({"kind": "prerequisite", "message": message})

    if systemd_user():
        graphical_active = user_unit_state("graphical-session.target", "is-active") == "active"
        for unit in data["services"]:
            tracked = ROOT / "systemd/user" / unit
            if not tracked.exists() and not tracked.is_symlink():
                errors.append({"kind": "service", "message": f"tracked unit missing: systemd/user/{unit}"})
                continue
            enabled = user_unit_state(unit, "is-enabled")
            if enabled in {"enabled", "static", "indirect"}:
                oks.append({"kind": "service", "message": f"{unit} enabled ({enabled})"})
            else:
                errors.append({"kind": "service", "message": f"{unit} not enabled (state: {enabled})"})
            if graphical_active and unit in {"quickshell.service", "kanata.service"}:
                active = user_unit_state(unit, "is-active")
                if active != "active":
                    errors.append({"kind": "service", "message": f"{unit} is {active} while graphical session is active"})
    else:
        warnings.append({"kind": "service", "message": "systemd user manager unavailable; user-service runtime not checked"})

    result = {
        "schema": 1,
        "machine": plan_data["machine"],
        "machine_file": plan_data["machine_file"],
        "profiles": plan_data["profiles"],
        "capabilities": plan_data["capabilities"],
        "errors": errors,
        "warnings": warnings,
        "ok": oks,
        "summary": {"errors": len(errors), "warnings": len(warnings)},
    }
    if as_json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        if not compact:
            print(f"Machine: {result['machine']} ({result['machine_file']})")
            print(f"Profiles: {', '.join(result['profiles'])}")
            print(f"Capabilities: {', '.join(result['capabilities']) or '-'}")
        print("\n== profile drift ==")
        drift_errors = [item for item in errors if item["kind"] in {"blocker", "drift"}]
        if not drift_errors:
            print("  ok    desired profile state matches")
        for item in drift_errors:
            print(f"  FAIL  {item['message']}")
        print("\n== dependencies and prerequisites ==")
        for item in oks:
            if item["kind"] in {"dependency", "prerequisite"}:
                print(f"  ok    {item['message']}")
        for item in errors:
            if item["kind"] in {"dependency", "prerequisite"}:
                print(f"  FAIL  {item['message']}")
        for item in warnings:
            if item["kind"] in {"dependency", "prerequisite"}:
                print(f"  WARN  {item['message']}")
        print("\n== user services ==")
        service_items = [item for item in oks if item["kind"] == "service"]
        service_errors = [item for item in errors if item["kind"] == "service"]
        service_warnings = [item for item in warnings if item["kind"] == "service"]
        if not service_items and not service_errors and not service_warnings:
            print("  ok    no profile user services")
        for item in service_items:
            print(f"  ok    {item['message']}")
        for item in service_errors:
            print(f"  FAIL  {item['message']}")
        for item in service_warnings:
            print(f"  WARN  {item['message']}")
        print(f"\nDoctor: {len(errors)} error(s), {len(warnings)} warning(s).")
    return 1 if errors else 0


def load_run(context: dict, run_id: str) -> tuple[Path, dict]:
    path = context["state"] / "dotfiles/runs" / f"{run_id}.json"
    if not path.exists():
        raise RuntimeError(f"run not found: {run_id}")
    return path, json.loads(path.read_text())


def history(context: dict, as_json: bool) -> int:
    folder = context["state"] / "dotfiles/runs"
    records = []
    for path in sorted(folder.glob("*.json"), reverse=True) if folder.exists() else []:
        try:
            records.append(json.loads(path.read_text()))
        except (OSError, json.JSONDecodeError):
            pass
    if as_json:
        print(json.dumps(records, indent=2, sort_keys=True))
        return 0
    if not records:
        print("No recorded changing runs.")
        return 0
    print(f"{'RUN':<24} {'OP':<9} {'STATUS':<14} {'PROFILE':<24} {'CHANGES':>7} COMMIT")
    for record in records:
        print(
            f"{record.get('id','?'):<24} {record.get('operation','apply'):<9} {record.get('status','?'):<14} "
            f"{'+'.join(record.get('profiles',[])):<24} {len(record.get('changes',[])):>7} "
            f"{str(record.get('commit','unknown'))[:10]}"
        )
    return 0


def show(context: dict, run_id: str, as_json: bool) -> int:
    _, record = load_run(context, run_id)
    if as_json:
        print(json.dumps(record, indent=2, sort_keys=True))
        return 0
    print(
        f"Run: {record['id']}\n"
        f"Operation: {record.get('operation', 'apply')}\n"
        f"Status: {record['status']}\n"
        f"Commit: {record['commit']}\n"
        f"Machine: {record['machine']} ({record['machine_file']})\n"
        f"Profiles: {', '.join(record['profiles'])}\n"
        f"Capabilities: {', '.join(record['capabilities']) or '-'}\n\nChanges:"
    )
    for item in record.get("changes", []):
        target = item.get("path") or item.get("unit") or item.get("name") or item.get("detail")
        print(f"  {item['action']:<11} {item['kind']:<10} {target}")
    print("\nBackups:")
    if not record.get("backups"):
        print("  none")
    for item in record.get("backups", []):
        print(f"  {item['source']} -> {item['backup']}")
    if record.get("error"):
        print(f"\nError: {record['error']}")
    if record.get("rolled_back_by"):
        print(f"\nRolled back by: {record['rolled_back_by']}")
    return 0


def rollback(context: dict, run_id: str) -> int:
    target_path, target = load_run(context, run_id)
    if target.get("operation", "apply") != "apply":
        raise RuntimeError("only apply runs can be rolled back")
    if target.get("rolled_back_by"):
        raise RuntimeError(f"run already rolled back by {target['rolled_back_by']}")
    if target.get("schema", 1) < 2 or "after" not in target:
        raise RuntimeError("run predates safe rollback metadata")

    backups = {item["source"]: item["backup"] for item in target.get("backups", [])}
    created: set[str] = set()
    for item in target.get("changes", []):
        if item["kind"] in {"symlink", "file"} and item["action"] == "create":
            created.add(item["path"])
        if item["kind"] == "generator":
            for output in item.get("outputs", []):
                if output not in backups:
                    created.add(output)

    touched = set(backups) | created
    conflicts = []
    for path_s in sorted(touched):
        expected = target.get("after", {}).get(path_s)
        if expected is None:
            conflicts.append(f"{path_s}: no post-apply snapshot")
            continue
        current = snapshot(Path(path_s))
        if current != expected:
            conflicts.append(f"{path_s}: changed since run")
    if conflicts:
        print("Rollback refused; current state no longer matches the recorded run:", file=sys.stderr)
        for item in conflicts:
            print(f"  {item}", file=sys.stderr)
        return 1

    rollback_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid.uuid4().hex[:6]
    runs_dir = context["state"] / "dotfiles/runs"
    rollback_path = runs_dir / f"{rollback_id}.json"
    rollback_record = {
        "schema": 2,
        "id": rollback_id,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "commit": git_commit(),
        "operation": "rollback",
        "rollback_of": run_id,
        "machine": target["machine"],
        "machine_file": target["machine_file"],
        "profiles": target["profiles"],
        "capabilities": target["capabilities"],
        "mode": target.get("mode", "full"),
        "status": "running",
        "changes": [],
        "backups": [],
        "after": {},
    }
    write_record(rollback_path, rollback_record)

    print(f"Rollback {run_id}:")
    for path_s in sorted(created, key=lambda value: (value.count("/"), value), reverse=True):
        path = Path(path_s)
        if path.exists() or path.is_symlink():
            remove_path(path)
            rollback_record["changes"].append({"kind": "path", "action": "remove", "path": path_s})
            print(f"  removed {path}")
    for source_s, backup_s in sorted(backups.items()):
        source, backup_path_source = Path(source_s), Path(backup_s)
        if not backup_path_source.exists() and not backup_path_source.is_symlink():
            rollback_record["status"] = "failed"
            rollback_record["error"] = f"backup missing: {backup_path_source}"
            write_record(rollback_path, rollback_record)
            print(rollback_record["error"], file=sys.stderr)
            return 1
        if source.exists() or source.is_symlink():
            remove_path(source)
        copy_keep(backup_path_source, source)
        rollback_record["changes"].append(
            {"kind": "path", "action": "restore", "path": source_s, "backup": backup_s}
        )
        print(f"  restored {source} <- {backup_path_source}")

    rollback_record["status"] = "applied"
    for path_s in touched:
        rollback_record["after"][path_s] = snapshot(Path(path_s))
    write_record(rollback_path, rollback_record)
    target["rolled_back_by"] = rollback_id
    target["rolled_back_at"] = datetime.now(timezone.utc).isoformat()
    write_record(target_path, target)
    print(f"Rollback recorded: {rollback_id}")
    return 0


def provision(context: dict, check_only: bool, assume_yes: bool) -> int:
    profiles, data = desired(context)
    missing = [item for item in data["packages"] if shutil.which(str(item["command"])) is None and bool(item.get("required", True))]
    missing_optional = [item for item in data["packages"] if shutil.which(str(item["command"])) is None and not bool(item.get("required", True))]
    missing_prereqs = []
    for item in data["prerequisites"]:
        ok, detail = prerequisite_status(item)
        if not ok and bool(item.get("required", True)):
            missing_prereqs.append((item, detail))

    print(f"Machine: {context['machine']}")
    print(f"Profiles: {', '.join(profiles)}")
    print("\n== packages to install ==")
    if not missing:
        print("  no required packages missing")
    for item in missing:
        print(f"  {item.get('manager', 'unknown'):<8} {item['package']:<28} — {item.get('reason', '')}")
    for item in missing_optional:
        print(f"  optional {item['package']:<28} — {item.get('reason', '')}")
    print("\n== system prerequisites ==")
    if not missing_prereqs:
        print("  no required prerequisites missing")
    for item, detail in missing_prereqs:
        print(f"  {item.get('kind')} {item.get('name')} — {item.get('reason', '')} ({detail})")

    if check_only:
        return 1 if missing or missing_prereqs else 0
    if not missing and not missing_prereqs:
        print("\nProvision: nothing to do.")
        return 0
    if os.environ.get("ID", "") not in {"", "arch"} and Path("/etc/arch-release").exists() is False:
        print("Provision currently supports the Arch package backend only.", file=sys.stderr)
        return 2
    if not assume_yes and sys.stdin.isatty():
        answer = input("\nInstall/enable these prerequisites? [y/N] ").strip().lower()
        if answer not in {"y", "yes"}:
            print("Provision cancelled.")
            return 1

    pacman_packages = uniq([str(item["package"]) for item in missing if item.get("manager") == "pacman"])
    aur_packages = uniq([str(item["package"]) for item in missing if item.get("manager") == "aur"])
    uv_packages = uniq([str(item["package"]) for item in missing if item.get("manager") == "uv-tool"])
    unknown = [item for item in missing if item.get("manager") not in {"pacman", "aur", "uv-tool"}]
    if unknown:
        print("No provision backend for: " + ", ".join(str(item.get("manager")) for item in unknown), file=sys.stderr)
        return 2

    if pacman_packages:
        process = subprocess.run(["sudo", "pacman", "-S", "--needed", *pacman_packages], check=False)
        if process.returncode:
            return process.returncode
    if aur_packages:
        helper = shutil.which("paru") or shutil.which("yay")
        if not helper:
            print("AUR packages are missing but neither paru nor yay is installed.", file=sys.stderr)
            return 2
        process = subprocess.run([helper, "-S", "--needed", *aur_packages], check=False)
        if process.returncode:
            return process.returncode
    if uv_packages:
        uv = shutil.which("uv")
        if not uv:
            print("uv-tool packages are missing but uv is not installed.", file=sys.stderr)
            return 2
        for package in uv_packages:
            process = subprocess.run([uv, "tool", "install", package], check=False)
            if process.returncode:
                return process.returncode

    for item, _ in missing_prereqs:
        if item.get("kind") == "system-service":
            process = subprocess.run(["sudo", "systemctl", "enable", "--now", str(item["name"])], check=False)
            if process.returncode:
                return process.returncode
    print("\nProvision: done. Run `dots apply` next.")
    return 0


def verify_generators(context: dict, profile: str | None) -> int:
    requested = [entry.strip() for entry in profile.split(",") if entry.strip()] if profile else ["desktop"]
    _, data = desired_for(context, requested)
    failed = 0
    for item in data["generators"]:
        first_rc, first_detail, first = generator_render(item, context)
        second_rc, second_detail, second = generator_render(item, context)
        if first_rc or second_rc:
            detail = first_detail or second_detail or f"exit {first_rc or second_rc}"
            print(f"generator verification failed: {item['name']}: {detail}", file=sys.stderr)
            failed = 1
        elif first != second:
            print(f"generator is not reproducible: {item['name']}", file=sys.stderr)
            failed = 1
        else:
            print(f"  ok    {item['name']}")
    return failed


def common(parser) -> None:
    parser.add_argument("--machine")
    parser.add_argument("--profile")


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)

    plan_parser = sub.add_parser("plan")
    common(plan_parser)
    plan_parser.add_argument("--json", action="store_true")
    plan_parser.add_argument("--links-only", action="store_true", help=argparse.SUPPRESS)

    apply_parser = sub.add_parser("apply")
    common(apply_parser)
    apply_parser.add_argument("--check", action="store_true")
    apply_parser.add_argument("--links-only", "--link", action="store_true")

    doctor_parser = sub.add_parser("doctor")
    common(doctor_parser)
    doctor_parser.add_argument("--json", action="store_true")

    history_parser = sub.add_parser("history")
    history_parser.add_argument("--json", action="store_true")

    show_parser = sub.add_parser("show")
    show_parser.add_argument("run")
    show_parser.add_argument("--json", action="store_true")

    rollback_parser = sub.add_parser("rollback")
    rollback_parser.add_argument("run")

    provision_parser = sub.add_parser("provision")
    common(provision_parser)
    provision_parser.add_argument("--check", action="store_true")
    provision_parser.add_argument("--yes", action="store_true")

    verify_parser = sub.add_parser("verify-generators")
    verify_parser.add_argument("--profile")

    args = parser.parse_args()
    try:
        context = ctx(getattr(args, "machine", None), getattr(args, "profile", None))
        if args.cmd == "plan":
            plan_data = plan(context, "links" if args.links_only else "full")
            if args.json:
                print(json.dumps(plan_data, indent=2, sort_keys=True))
            else:
                print_plan(plan_data)
            return 1 if plan_data["blockers"] else 0
        if args.cmd == "apply":
            plan_data = plan(context, "links" if args.links_only else "full")
            if args.check:
                print_plan(plan_data)
                return 1 if plan_data["blockers"] else 0
            return apply(context, plan_data, "links" if args.links_only else "full")
        if args.cmd == "doctor":
            return doctor(context, args.json)
        if args.cmd == "history":
            return history(context, args.json)
        if args.cmd == "show":
            return show(context, args.run, args.json)
        if args.cmd == "rollback":
            return rollback(context, args.run)
        if args.cmd == "provision":
            return provision(context, args.check, args.yes)
        return verify_generators(context, args.profile)
    except (OSError, RuntimeError, json.JSONDecodeError, tomllib.TOMLDecodeError) as error:
        print(f"dots: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
