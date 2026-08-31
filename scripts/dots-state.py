#!/usr/bin/env python3
"""Profile-aware plan/apply/history engine for dots."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
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


def read_toml(path):
    with path.open("rb") as f:
        return tomllib.load(f)


def ctx(machine=None, profile=None):
    home = Path(os.environ.get("HOME", str(Path.home()))).expanduser()
    c = {
        "root": ROOT,
        "home": home,
        "config": Path(os.environ.get("XDG_CONFIG_HOME", home / ".config")),
        "data": Path(os.environ.get("XDG_DATA_HOME", home / ".local/share")),
        "cache": Path(os.environ.get("XDG_CACHE_HOME", home / ".cache")),
        "state": Path(os.environ.get("XDG_STATE_HOME", home / ".local/state")),
    }
    requested = machine or os.environ.get("DOTS_MACHINE") or os.uname().nodename
    mf = ROOT / "machines" / f"{requested}.toml"
    if not mf.exists():
        requested, mf = "default", ROOT / "machines/default.toml"
    if not mf.exists():
        raise RuntimeError(f"machine definition missing: {mf}")
    m = read_toml(mf).get("machine", {})
    override = profile or os.environ.get("DOTS_PROFILE")
    names = [x.strip() for x in override.split(",") if x.strip()] if override else list(m.get("profiles", []))
    c.update(machine=requested, machine_file=mf, requested_profiles=names or ["base"])
    return c


def ex(value, c):
    return str(value).format_map({k: str(v) for k, v in c.items() if k in {"root", "home", "config", "data", "cache", "state"}})


def uniq(items):
    return list(dict.fromkeys(items))


def desired(c):
    order, visiting, loaded = [], set(), {}

    def visit(name):
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

    for name in c["requested_profiles"]:
        visit(name)

    out = {k: [] for k in ("capabilities", "config_dirs", "sources", "services", "links", "files", "packages", "generators")}
    for name in order:
        data, meta = loaded[name], loaded[name].get("profile", {})
        for key in ("capabilities", "config_dirs", "sources", "services"):
            out[key] += [str(x) for x in meta.get(key, [])]
        for key in ("links", "files", "packages", "generators"):
            out[key] += list(data.get(key, []))
    machine = read_toml(c["machine_file"]).get("machine", {})
    out["capabilities"] += [str(x) for x in machine.get("capabilities", [])]
    disabled = {str(x) for x in machine.get("disable_capabilities", [])}
    out["capabilities"] = [x for x in uniq(out["capabilities"]) if x not in disabled]
    for key in ("config_dirs", "sources", "services"):
        out[key] = uniq(out[key])
    for key, field in (("links", "destination"), ("files", "destination"), ("packages", "command"), ("generators", "name")):
        keyed = {}
        for item in out[key]:
            keyed[str(item[field])] = dict(item)
        out[key] = list(keyed.values())
    return order, out


def run(argv, c, env=None):
    return subprocess.run([ex(x, c) for x in argv], cwd=ROOT, env=env or os.environ.copy(), text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)


def copy_keep(src, dst):
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists() or dst.is_symlink():
        shutil.rmtree(dst) if dst.is_dir() and not dst.is_symlink() else dst.unlink()
    if src.is_symlink():
        os.symlink(os.readlink(src), dst)
    elif src.is_dir():
        shutil.copytree(src, dst, symlinks=True)
    else:
        shutil.copy2(src, dst)


def snap(path, old=None, new=None):
    if path.is_symlink():
        v = os.readlink(path)
        return ("link", v.replace(old, new) if old and new else v)
    if path.is_file():
        v = path.read_bytes()
        if old and new:
            v = v.replace(old.encode(), new.encode())
        return ("file", v, stat.S_IMODE(path.stat().st_mode))
    if path.is_dir():
        return ("dir", stat.S_IMODE(path.stat().st_mode))
    return ("absent",)


def generator_check(item, c):
    with tempfile.TemporaryDirectory(prefix="dots-plan-") as tmp:
        tc = dict(c)
        home = Path(tmp)
        tc.update(home=home, config=home / ".config", data=home / ".local/share", cache=home / ".cache", state=home / ".local/state")
        pairs = []
        for template in item.get("outputs", []):
            actual, expected = Path(ex(template, c)), Path(ex(template, tc))
            pairs.append((actual, expected))
            if actual.exists() or actual.is_symlink():
                copy_keep(actual, expected)
        env = os.environ.copy()
        env.update(HOME=str(home), XDG_CONFIG_HOME=str(tc["config"]), XDG_DATA_HOME=str(tc["data"]),
                   XDG_CACHE_HOME=str(tc["cache"]), XDG_STATE_HOME=str(tc["state"]))
        p = run(item["apply"], tc, env)
        if p.returncode:
            return p.returncode, (p.stderr or p.stdout).strip()
        stale = [str(a) for a, e in pairs if snap(a) != snap(e, str(home), str(c["home"]))]
        return (1, "stale outputs: " + ", ".join(stale)) if stale else (0, "")


def systemd_user():
    if not shutil.which("systemctl"):
        return False
    return subprocess.run(["systemctl", "--user", "show-environment"], stdout=subprocess.DEVNULL,
                          stderr=subprocess.DEVNULL, check=False).returncode == 0


def add(changes, kind, action, **extra):
    changes.append({"kind": kind, "action": action, **extra})


def plan(c, mode="full"):
    profiles, d = desired(c)
    blockers, changes, deps = [], [], []
    sources = [ROOT / x for x in d["config_dirs"] + d["sources"] + [str(x["source"]) for x in d["links"]]]
    for source in sources:
        if not source.exists() and not source.is_symlink():
            blockers.append(f"managed source is missing: {source.relative_to(ROOT)}")
    for item in d["packages"]:
        deps.append({"command": str(item["command"]), "package": str(item["package"]),
                     "manager": str(item.get("manager", "unknown")), "required": bool(item.get("required", True)),
                     "reason": str(item.get("reason", "profile requirement")),
                     "installed": shutil.which(str(item["command"])) is not None})

    pending, migratable, mig = [], set(), None
    if mode == "full":
        mig = run([str(ROOT / "scripts/dots-migrate.sh"), "--check"], c)
        pending = [line[8:].strip() for line in mig.stdout.splitlines() if line.startswith("PENDING ")]
        for detail in pending:
            if detail.startswith(str(c["data"] / "darkman") + " "):
                migratable.add(str(c["data"] / "darkman"))

    links = [{"source": x, "destination": f"{{config}}/{x}", "reason": f"activate the tracked {x} configuration"}
             for x in d["config_dirs"]] + d["links"]
    for item in links:
        src, dst = ROOT / str(item["source"]), Path(ex(item["destination"], c))
        same = dst.is_symlink() and os.path.realpath(src) == os.path.realpath(dst)
        if same:
            continue
        if dst.exists() and not dst.is_symlink() and str(dst) not in migratable:
            blockers.append(f"{dst} exists and is not a symlink")
            continue
        action = "replace" if dst.exists() or dst.is_symlink() else "create"
        add(changes, "symlink", action, path=str(dst), source=str(src), reason=str(item.get("reason", "managed symlink")))

    for item in d["files"]:
        dst, content, modebits = Path(ex(item["destination"], c)), ex(item["content"], c), int(str(item.get("mode", "0644")), 8)
        if dst.is_symlink() or (dst.exists() and not dst.is_file()):
            blockers.append(f"{dst} blocks a managed file and is not a regular file")
            continue
        current, curmode = (dst.read_text(), stat.S_IMODE(dst.stat().st_mode)) if dst.exists() else (None, None)
        if current != content:
            add(changes, "file", "update" if dst.exists() else "create", path=str(dst), mode=f"{modebits:04o}", reason=str(item.get("reason", "managed file")))
        elif curmode != modebits:
            add(changes, "file", "chmod", path=str(dst), mode=f"{modebits:04o}", reason=str(item.get("reason", "managed file")))

    for item in d["generators"]:
        rc, detail = generator_check(item, c)
        if rc == 1:
            add(changes, "generator", "run", name=str(item["name"]), reason=str(item.get("reason", "generated runtime state is stale")),
                outputs=[ex(x, c) for x in item.get("outputs", [])], command=[ex(x, c) for x in item["apply"]], check_output=detail)
        elif rc:
            blockers.append(f"generator check failed for {item['name']}: {detail or f'exit {rc}'}")

    if "desktop" in d["capabilities"] and systemd_user():
        state = subprocess.run(["systemctl", "--user", "is-enabled", "dunst.service"], text=True,
                               stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=False).stdout.strip()
        if state != "masked":
            add(changes, "service", "mask", unit="dunst.service", reason="Quickshell owns desktop notifications")

    if mode == "full":
        for detail in pending:
            if "exists, but Waybar is retired" in detail:
                blockers.append(f"migration needs manual decision: {detail}")
            else:
                add(changes, "migration", "apply", detail=detail, reason="retired runtime state")
        if mig and mig.returncode not in (0, 1):
            blockers.append(f"migration check failed: {(mig.stderr or mig.stdout).strip()}")
        changed = bool(changes)
        runtime = c["cache"] / "dots-shell/quickshell"
        if changed and (runtime.exists() or runtime.is_symlink()):
            add(changes, "cache", "remove", path=str(runtime), reason="rebuild Quickshell derived runtime after changes")
        if changed:
            for unit in d["services"]:
                add(changes, "service", "try-restart", unit=unit, reason="pick up applied state if already running")

    req = sum(1 for x in deps if x["required"] and not x["installed"])
    opt = sum(1 for x in deps if not x["required"] and not x["installed"])
    return {"schema": 1, "machine": c["machine"], "machine_file": str(c["machine_file"].relative_to(ROOT)),
            "profiles": profiles, "capabilities": d["capabilities"], "dependencies": deps, "changes": changes,
            "blockers": blockers, "summary": {"changes": len(changes), "blockers": len(blockers),
            "required_dependencies_missing": req, "optional_dependencies_missing": opt,
            "no_op": not changes and not blockers}}


def print_plan(p):
    print(f"Machine: {p['machine']} ({p['machine_file']})")
    print(f"Profiles: {', '.join(p['profiles'])}")
    print(f"Capabilities: {', '.join(p['capabilities']) or '-'}")
    print("\n== dependencies ==")
    for x in p["dependencies"]:
        status = "ok" if x["installed"] else ("MISSING" if x["required"] else "optional")
        print(f"  {status:<8} {x['command']:<18} {x['package']} — {x['reason']}")
    print("\n== planned changes ==")
    if not p["changes"]:
        print("  no machine changes")
    for x in p["changes"]:
        target = x.get("path") or x.get("unit") or x.get("name") or x.get("detail")
        print(f"  {x['action'].upper():<11} {x['kind']:<10} {target}")
        if x.get("reason"):
            print(f"              {x['reason']}")
        for output in x.get("outputs", []):
            print(f"              output: {output}")
    if p["blockers"]:
        print("\n== blockers ==")
        for x in p["blockers"]:
            print(f"  BLOCK {x}")
    s = p["summary"]
    print(f"\nPlan: {s['changes']} change(s), {s['blockers']} blocker(s), {s['required_dependencies_missing']} required dependency/dependencies missing.")


def backup(path, backup_dir, c, records):
    if not path.exists() and not path.is_symlink():
        return
    try:
        rel = path.relative_to(c["home"])
    except ValueError:
        rel = Path(str(path).lstrip("/"))
    dest = backup_dir / rel
    if dest.exists() or dest.is_symlink():
        return
    backup_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    copy_keep(path, dest)
    records.append({"source": str(path), "backup": str(dest)})
    print(f"  backup: {path} -> {dest}")


def commit():
    p = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True, stdout=subprocess.PIPE,
                       stderr=subprocess.DEVNULL, check=False)
    return p.stdout.strip() if p.returncode == 0 else "unknown"


def apply(c, p, mode):
    print_plan(p)
    if p["blockers"]:
        print("\nApply refused because the plan has blockers.", file=sys.stderr)
        return 1
    if not p["changes"]:
        print("\nApply: no changes; desired state is already converged.")
        if mode == "links":
            return 0
        print("\n== doctor ==")
        return subprocess.run([str(ROOT / "scripts/dots-doctor.sh")], check=False).returncode

    run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid.uuid4().hex[:6]
    runs_dir, backup_dir = c["state"] / "dotfiles/runs", c["state"] / "dotfiles/backups" / run_id
    runs_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    backups = []
    print("\n== backup ==")
    for x in p["changes"]:
        if x["kind"] in {"symlink", "file"} and x["action"] in {"replace", "update", "chmod"}:
            backup(Path(x["path"]), backup_dir, c, backups)
        elif x["kind"] == "generator":
            for output in x.get("outputs", []):
                backup(Path(output), backup_dir, c, backups)
    if not backups:
        print("  no existing managed files need backup")

    print("\n== changes ==")
    _, d = desired(c)
    files = {ex(x["destination"], c): x for x in d["files"]}
    generators = {str(x["name"]): x for x in d["generators"]}
    if mode == "full" and any(x["kind"] == "migration" for x in p["changes"]):
        env = os.environ.copy(); env["DOTS_BACKUP_RUN_DIR"] = str(backup_dir)
        m = subprocess.run([str(ROOT / "scripts/dots-migrate.sh")], cwd=ROOT, env=env, text=True,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
        print(m.stdout, end="")
        if m.returncode:
            return m.returncode
    for x in p["changes"]:
        if x["kind"] == "symlink":
            dst, src = Path(x["path"]), Path(x["source"])
            dst.parent.mkdir(parents=True, exist_ok=True)
            if dst.is_symlink(): dst.unlink()
            os.symlink(src, dst, target_is_directory=src.is_dir())
            print(f"  linked  {dst} -> {src}")
    for x in p["changes"]:
        if x["kind"] == "file":
            item = files[x["path"]]; dst = Path(x["path"]); content = ex(item["content"], c); modebits = int(str(item.get("mode", "0644")), 8)
            dst.parent.mkdir(parents=True, exist_ok=True)
            if x["action"] != "chmod": dst.write_text(content)
            os.chmod(dst, modebits); print(f"  wrote   {dst}")
    for x in p["changes"]:
        if x["kind"] == "service" and x["action"] == "mask" and systemd_user():
            subprocess.run(["systemctl", "--user", "mask", "--now", x["unit"]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
            print(f"  masked  {x['unit']}")
    for x in p["changes"]:
        if x["kind"] == "generator":
            g = run(generators[x["name"]]["apply"], c)
            if g.stdout: print(g.stdout, end="")
            if g.stderr: print(g.stderr, end="", file=sys.stderr)
            if g.returncode: return g.returncode
    for x in p["changes"]:
        if x["kind"] == "cache" and x["action"] == "remove":
            path = Path(x["path"])
            if path.is_dir() and not path.is_symlink(): shutil.rmtree(path)
            elif path.exists() or path.is_symlink(): path.unlink()
            print(f"  removed {path}")
    units = [x["unit"] for x in p["changes"] if x["kind"] == "service" and x["action"] == "try-restart"]
    if mode == "full" and units and systemd_user():
        subprocess.run(["systemctl", "--user", "daemon-reload"], check=False)
        for unit in units:
            subprocess.run(["systemctl", "--user", "reset-failed", unit], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
            subprocess.run(["systemctl", "--user", "try-restart", unit], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
            print(f"  refreshed {unit} if it was running")

    if backup_dir.exists():
        known = [Path(x["backup"]) for x in backups]
        for path in sorted(backup_dir.rglob("*")):
            if path.is_dir() and not path.is_symlink(): continue
            if any(path == k or k in path.parents for k in known): continue
            rel = path.relative_to(backup_dir)
            backups.append({"source": str(c["home"] / rel), "backup": str(path)}); known.append(path)
    record = {"schema": 1, "id": run_id, "timestamp": datetime.now(timezone.utc).isoformat(), "commit": commit(),
              "machine": p["machine"], "machine_file": p["machine_file"], "profiles": p["profiles"],
              "capabilities": p["capabilities"], "mode": mode, "status": "applied", "changes": p["changes"], "backups": backups}
    record_path = runs_dir / f"{run_id}.json"
    record_path.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n")
    print(f"\nRun recorded: {run_id}")
    if mode == "links": return 0
    print("\n== doctor ==")
    rc = subprocess.run([str(ROOT / "scripts/dots-doctor.sh")], check=False).returncode
    if rc:
        record["status"] = "doctor_failed"; record_path.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n")
    return rc


def history(c, as_json):
    folder = c["state"] / "dotfiles/runs"
    records = []
    for path in sorted(folder.glob("*.json"), reverse=True) if folder.exists() else []:
        try: records.append(json.loads(path.read_text()))
        except (OSError, json.JSONDecodeError): pass
    if as_json: print(json.dumps(records, indent=2, sort_keys=True)); return 0
    if not records: print("No recorded changing runs."); return 0
    print(f"{'RUN':<24} {'STATUS':<14} {'PROFILE':<24} {'CHANGES':>7} COMMIT")
    for r in records:
        print(f"{r.get('id','?'):<24} {r.get('status','?'):<14} {'+'.join(r.get('profiles',[])):<24} {len(r.get('changes',[])):>7} {str(r.get('commit','unknown'))[:10]}")
    return 0


def show(c, run_id, as_json):
    path = c["state"] / "dotfiles/runs" / f"{run_id}.json"
    if not path.exists(): print(f"dots show: run not found: {run_id}", file=sys.stderr); return 1
    r = json.loads(path.read_text())
    if as_json: print(json.dumps(r, indent=2, sort_keys=True)); return 0
    print(f"Run: {r['id']}\nStatus: {r['status']}\nCommit: {r['commit']}\nMachine: {r['machine']} ({r['machine_file']})\nProfiles: {', '.join(r['profiles'])}\nCapabilities: {', '.join(r['capabilities']) or '-'}\n\nChanges:")
    for x in r.get("changes", []):
        print(f"  {x['action']:<11} {x['kind']:<10} {x.get('path') or x.get('unit') or x.get('name') or x.get('detail')}")
    print("\nBackups:")
    if not r.get("backups"): print("  none")
    for x in r.get("backups", []): print(f"  {x['source']} -> {x['backup']}")
    return 0


def common(p):
    p.add_argument("--machine"); p.add_argument("--profile")


def main():
    ap = argparse.ArgumentParser(); sub = ap.add_subparsers(dest="cmd", required=True)
    pp = sub.add_parser("plan"); common(pp); pp.add_argument("--json", action="store_true"); pp.add_argument("--links-only", action="store_true", help=argparse.SUPPRESS)
    aa = sub.add_parser("apply"); common(aa); aa.add_argument("--check", action="store_true"); aa.add_argument("--links-only", "--link", action="store_true")
    hh = sub.add_parser("history"); hh.add_argument("--json", action="store_true")
    ss = sub.add_parser("show"); ss.add_argument("run"); ss.add_argument("--json", action="store_true")
    a = ap.parse_args()
    try:
        c = ctx(getattr(a, "machine", None), getattr(a, "profile", None))
        if a.cmd == "plan":
            p = plan(c, "links" if a.links_only else "full"); print(json.dumps(p, indent=2, sort_keys=True)) if a.json else print_plan(p); return 1 if p["blockers"] else 0
        if a.cmd == "apply":
            p = plan(c, "links" if a.links_only else "full")
            if a.check: print_plan(p); return 1 if p["blockers"] else 0
            return apply(c, p, "links" if a.links_only else "full")
        if a.cmd == "history": return history(c, a.json)
        return show(c, a.run, a.json)
    except (OSError, RuntimeError, tomllib.TOMLDecodeError) as e:
        print(f"dots: {e}", file=sys.stderr); return 2


if __name__ == "__main__":
    raise SystemExit(main())
