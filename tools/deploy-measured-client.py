"""Check/package the frozen measured-client pass; --apply also updates local files.

Default is read-only. --package creates only the cumulative archive/manifest.
--apply requires matching completed verification, backs up originals first and
refuses divergent local files unless their exact hashes were separately reviewed.
No database, config, addon, game process or remote server is modified.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile
import uuid
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/performance-audit"
GAME = Path(r"C:\Program Files (x86)\Steam\steamapps\common\GarrysMod\garrysmod\gamemodes")
BEFORE = Path(r"C:\Users\q1236\AppData\Local\Temp\ix-measured-client-before-20261018T015619Z-efe2ca49")
ALLOWED = {
    "ixhl2rp/plugins/blackout/cl_lighting.lua",
    "ixhl2rp/plugins/zz_legends_interface/cl_anatomy.lua",
    "ixhl2rp/plugins/zz_legends_interface/cl_gameplay.lua",
    "ixhl2rp/plugins/status_display/cl_status.lua",
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def runtime_hashes():
    return {p.relative_to(ROOT).as_posix(): sha(p)
            for name in ("helix", "ixhl2rp", "addons")
            for p in (ROOT / name).rglob("*.lua")}


def contained(base, relative):
    value = (base / relative).resolve()
    value.relative_to(base.resolve())
    if not relative.startswith(("helix/", "ixhl2rp/")) or not relative.endswith(".lua"):
        raise RuntimeError("Unexpected runtime target: " + relative)
    return value


def check():
    baseline = {x["path"]: x["sha256"] for x in read_json(BEFORE / "manifest.json")["files"]}
    current = runtime_hashes()
    frozen = read_json(OUT / "measured-client-freeze.json")
    changed = {p: h for p, h in current.items() if baseline.get(p) != h}
    if not changed or set(baseline) != set(current) or changed != frozen["runtimeChanges"]:
        raise RuntimeError("Runtime scope/hash differs from the frozen measured-client pass")
    if not set(changed).issubset(ALLOWED):
        raise RuntimeError("Unexpected runtime changes outside the measured client scope")
    verified = read_json(OUT / "measured-client-verification.json")
    if verified.get("exitCode") != 0 or verified.get("sourceChangedDuringRun"):
        raise RuntimeError("Verification did not succeed on stable sources")
    for name in ("runtimeHashes", "runtimeHashesBefore", "runtimeHashesAfter"):
        if verified.get(name) != current:
            raise RuntimeError("Verification hashes differ from current runtime: " + name)
    stats = verified["tests"]
    for name in ("focusedFailed", "syntaxFailures", "fullInventorySyntaxFailures"):
        if stats.get(name) != 0:
            raise RuntimeError("Missing or nonzero verification failure counter: " + name)
    if not stats.get("focusedPassed") or stats.get("syntaxFiles") != len(current):
        raise RuntimeError("Verification did not cover focused tests and complete runtime syntax")
    scope = verified["scopeComparison"]
    if set(scope["changed"]) != set(changed) or scope["removed"] or scope["added"] or scope["addonsChanged"]:
        raise RuntimeError("Verification reports unexpected runtime changes")
    prior = {x["path"]: x for x in read_json(OUT / "core-safe-delivery.json")["files"]}
    rows = []
    for name in sorted(set(prior) | set(changed)):
        contained(ROOT, name)
        local = contained(GAME, name)
        if name in prior and name not in changed and current[name] != prior[name]["afterSHA256"]:
            raise RuntimeError("Prior delivery source changed outside this pass: " + name)
        local_hash = sha(local)
        permitted = {current[name], baseline[name]} if name in changed else {current[name]}
        state = "current" if local_hash == current[name] else ("ready" if local_hash in permitted else "divergent")
        rows.append(dict(path=name, measuredClientPass=name in changed,
                         beforeSHA256=baseline[name], afterSHA256=current[name],
                         localBeforeSHA256=local_hash, state=state))
    return current, verified, rows


def make_readme():
    # Retain the full migration/rollback instructions shipped in the prior patch.
    previous = read_json(OUT / "core-safe-delivery.json")
    prior_zip = Path(previous["archive"])
    if sha(prior_zip) != previous["archiveSHA256"]:
        raise RuntimeError("Prior cumulative archive no longer matches its manifest")
    with zipfile.ZipFile(prior_zip) as package:
        prior_readme = package.read("README-performance.txt").decode("utf-8")
    return """MEASURED CLIENT FOLLOW-UP (2026-10-18)
This cumulative patch includes the 57-file core-safe delivery and the measured
client HUD/blackout changes documented in measured-client.md.
Do not install this as a complete gamemode; merge it into the current installation.
No SCP blink/addon files are changed or removed. The user manages that addon.
The selected relevant suite passed; four unrelated server-test failures also
reproduced against the untouched baseline and remain documented, not fixed.
No measured FPS improvement is claimed; repeat matching client captures afterward.
Restart the server and reconnect clients after merging helix/ and ixhl2rp/ into
garrysmod/gamemodes/. Check blackout transitions, observer/dead views, player
anatomy, fresh injuries and MTF status indicators before a live session.

The earlier SQLite migration and backup/rollback requirements below STILL APPLY.
Never copy this developer PC's sv.db or data folder onto the Linux server.

""" + prior_readme


def package_only(current, verified, rows):
    if runtime_hashes() != current:
        raise RuntimeError("Runtime changed before packaging")
    archive = OUT / "optimization-measured-client-gamemodes.zip"
    temporary = archive.with_suffix(".building.zip")
    with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED) as package:
        for row in rows:
            package.write(ROOT / row["path"], row["path"])
        package.writestr("README-performance.txt", make_readme())
    with zipfile.ZipFile(temporary) as package:
        expected = {x["path"] for x in rows} | {"README-performance.txt"}
        if package.testzip() is not None or set(package.namelist()) != expected:
            raise RuntimeError("Archive member/integrity check failed")
        for row in rows:
            if hashlib.sha256(package.read(row["path"])).hexdigest() != row["afterSHA256"]:
                raise RuntimeError("Archive source hash mismatch: " + row["path"])
    if runtime_hashes() != current:
        raise RuntimeError("Runtime changed during packaging")
    os.replace(temporary, archive)
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    result = dict(generatedUTC=stamp, localGame=str(GAME), sourceBaseline=str(BEFORE),
                  archive=str(archive), archiveSHA256=sha(archive),
                  verificationSHA256=sha(OUT / "measured-client-verification.json"),
                  measuredClientPassFiles=sum(x["measuredClientPass"] for x in rows),
                  cumulativeFiles=len(rows), runtimeHashesVerified=len(current),
                  tests=verified["tests"], files=rows, localUpdated=False,
                  remoteServerUpdated=False, githubUpdated=False)
    write_json(OUT / "measured-client-delivery.json", result)
    return result


def apply_local(current, rows, result, reviewed):
    selected = [x for x in rows if x["measuredClientPass"] or x["state"] != "current"]
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backup = Path(tempfile.gettempdir()) / ("ix-measured-client-local-backup-" + stamp + "-" + uuid.uuid4().hex[:8])
    backup.mkdir(exist_ok=False)
    for row in selected:
        local, saved = contained(GAME, row["path"]), contained(backup, row["path"])
        if sha(local) != row["localBeforeSHA256"]:
            raise RuntimeError("Local target changed while backing up: " + row["path"])
        if local.is_file():
            saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(local, saved)
            if sha(saved) != row["localBeforeSHA256"]:
                raise RuntimeError("Backup hash mismatch: " + row["path"])
    write_json(backup / "manifest.json", selected)
    divergent = [x["path"] for x in rows if x["state"] == "divergent"
                 and (x["path"] not in reviewed or reviewed[x["path"]] != x["localBeforeSHA256"])]
    if divergent:
        raise RuntimeError("Divergent local originals saved at " + str(backup) + "; copying refused pending exact-hash review: " + ", ".join(divergent))
    copied = []
    try:
        if runtime_hashes() != current:
            raise RuntimeError("Runtime changed after verification")
        for row in selected:
            local = contained(GAME, row["path"])
            if sha(local) != row["localBeforeSHA256"]:
                raise RuntimeError("Local changed after backup: " + row["path"])
            copied.append(row)
            local.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / row["path"], local)
        for row in rows:
            if sha(contained(GAME, row["path"])) != row["afterSHA256"]:
                raise RuntimeError("Local hash verification failed: " + row["path"])
        if runtime_hashes() != current:
            raise RuntimeError("Runtime changed during local deployment")
    except Exception:
        for row in reversed(copied):
            local, saved = contained(GAME, row["path"]), contained(backup, row["path"])
            if row["localBeforeSHA256"] is None:
                local.unlink(missing_ok=True)  # Exact checked file only; never recursive.
            else:
                shutil.copy2(saved, local)
            if sha(local) != row["localBeforeSHA256"]:
                raise RuntimeError("Rollback hash failed; backup at " + str(backup))
        raise
    result.update(localUpdated=True, backup=str(backup), verified=len(rows))
    write_json(OUT / "measured-client-delivery.json", result)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    operation = parser.add_mutually_exclusive_group()
    operation.add_argument("--package", action="store_true")
    operation.add_argument("--apply", action="store_true")
    parser.add_argument("--reviewed-local-hashes", type=Path,
                        help="Optional reviewed {relativePath: previousSHA256} JSON for divergent local originals")
    args = parser.parse_args()
    current, verified, rows = check()
    if not (args.package or args.apply):
        print(json.dumps(dict(mode="check", runtimeHashes=len(current), cumulativeFiles=len(rows),
                              measuredClientPassFiles=sum(x["measuredClientPass"] for x in rows),
                              readyLocalFiles=sum(x["state"] == "ready" for x in rows),
                              divergentLocalFiles=[x for x in rows if x["state"] == "divergent"], tests=verified["tests"]), indent=2))
        return
    result = package_only(current, verified, rows)
    if args.apply:
        reviewed = read_json(args.reviewed_local_hashes) if args.reviewed_local_hashes else {}
        result = apply_local(current, rows, result, reviewed)
    print(json.dumps({k: v for k, v in result.items() if k != "files"}, indent=2))


if __name__ == "__main__":
    main()
