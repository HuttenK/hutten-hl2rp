"""Verify the ARC9 effects pass; --apply backs up/copies it and builds a cumulative patch."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/performance-audit"
GAME = Path(r"C:\Program Files (x86)\Steam\steamapps\common\GarrysMod\garrysmod\gamemodes")
ALLOWED = {
    "ixhl2rp/plugins/render_efficiency/cl_budget.lua",
    "ixhl2rp/plugins/arc9_shot_effects/sh_plugin.lua",
    "ixhl2rp/plugins/arc9_shot_effects/sv_effects.lua",
    "ixhl2rp/plugins/arc9_shot_effects/cl_effects.lua",
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def target(base, relative):
    result = (base / relative).resolve()
    result.relative_to(base.resolve())
    if not relative.startswith(("helix/", "ixhl2rp/")) or not relative.endswith(".lua"):
        raise RuntimeError("Unexpected target " + relative)
    return result


def runtime():
    return {p.relative_to(ROOT).as_posix(): sha(p)
            for name in ("helix", "ixhl2rp", "addons")
            for p in (ROOT / name).rglob("*.lua")}


def main(apply):
    verified = read(OUT / "arc9-effects-verification.json")
    current = runtime()
    if (verified["exitCode"] != 0 or not verified["stable"] or verified["syntaxErrors"]
            or verified["regressionExitCode"] != 0 or verified["passed"] != 45
            or verified["runtimeHashes"] != current):
        raise RuntimeError("Verification failed or sources changed")
    baseline = {x["path"]: x["sha256"] for x in read(Path(verified["baseline"]) / "manifest.json")}
    changed = {p: h for p, h in current.items() if baseline.get(p) != h}
    if set(baseline) - set(current) or set(changed) != ALLOWED or changed != verified["runtimeChanges"]:
        raise RuntimeError("Unexpected runtime scope")
    previous = read(OUT / "measured-client-delivery.json")
    prior = {x["path"]: x for x in previous["files"]}
    rows = []
    for relative in sorted(set(prior) | ALLOWED):
        target(ROOT, relative)
        local_hash = sha(target(GAME, relative))
        if relative not in ALLOWED and current[relative] != prior[relative]["afterSHA256"]:
            raise RuntimeError("Previous delivery changed: " + relative)
        permitted = {current[relative], baseline.get(relative)} if relative in ALLOWED else {current[relative]}
        if local_hash not in permitted:
            raise RuntimeError("Divergent local file: " + relative)
        rows.append(dict(path=relative, arc9EffectsPass=relative in ALLOWED,
                         beforeSHA256=baseline.get(relative), localBeforeSHA256=local_hash,
                         afterSHA256=current[relative]))
    prior_archive = Path(previous["archive"])
    if sha(prior_archive) != previous["archiveSHA256"]:
        raise RuntimeError("Previous archive hash mismatch")
    with zipfile.ZipFile(prior_archive) as package:
        readme = package.read("README-performance.txt").decode("utf-8")
    print(json.dumps(dict(verified=True, runtimeFiles=len(current), cumulativeFiles=len(rows),
                          changedFiles=sorted(ALLOWED), apply=apply), indent=2))
    if not apply:
        return
    backup = Path(tempfile.mkdtemp(prefix="ix-arc9-effects-local-backup-"))
    selected = [r for r in rows if r["arc9EffectsPass"]]
    for row in selected:
        local, saved = target(GAME, row["path"]), target(backup, row["path"])
        if sha(local) != row["localBeforeSHA256"]:
            raise RuntimeError("Local source changed before backup")
        if local.is_file():
            saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(local, saved)
            if sha(saved) != row["localBeforeSHA256"]:
                raise RuntimeError("Backup verification failed")
    write(backup / "manifest.json", selected)
    if runtime() != current:
        raise RuntimeError("Sources changed before copying")
    copied = []
    try:
        for row in selected:
            local = target(GAME, row["path"])
            if sha(local) != row["localBeforeSHA256"]:
                raise RuntimeError("Local target changed before copying")
            local.parent.mkdir(parents=True, exist_ok=True)
            copied.append(row)
            shutil.copy2(target(ROOT, row["path"]), local)
        for row in rows:
            if sha(target(GAME, row["path"])) != row["afterSHA256"]:
                raise RuntimeError("Local parity failed: " + row["path"])
    except Exception:
        for row in copied:
            local, saved = target(GAME, row["path"]), target(backup, row["path"])
            if row["localBeforeSHA256"] is None:
                local.unlink(missing_ok=True)
            else:
                shutil.copy2(saved, local)
        raise
    archive = OUT / "optimization-arc9-effects-gamemodes.zip"
    temporary = archive.with_suffix(".building.zip")
    prefix = """ARC9 SHOT-EFFECTS FOLLOW-UP (2026-10-18)
This cumulative patch includes the preceding 60-file measured-client update.
Four runtime files remove muzzle throttling and adapt native muzzle dispatch and
hitscan tracers. No Workshop files, attachments or physical bullets are changed.
45 targeted checks and 3,018 Lua syntax checks passed; live effects are unverified.
Merge helix/ and ixhl2rp/ into garrysmod/gamemodes/, then restart the server and
reconnect clients. Test another player's unsuppressed fire nearby and at distance,
then check a suppressed weapon. Client diagnostics: ix_arc9_effects_info.
This is a PATCH, not a complete gamemode. Retain existing content and configuration.
The inherited database backup/rollback instructions below STILL APPLY.

"""
    with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED) as package:
        for row in rows:
            package.write(target(ROOT, row["path"]), row["path"])
        package.writestr("README-performance.txt", prefix + readme)
    with zipfile.ZipFile(temporary) as package:
        if package.testzip() or set(package.namelist()) != {r["path"] for r in rows} | {"README-performance.txt"}:
            raise RuntimeError("Archive member verification failed")
        for row in rows:
            if hashlib.sha256(package.read(row["path"])).hexdigest() != row["afterSHA256"]:
                raise RuntimeError("Archive parity failed")
    if runtime() != current:
        raise RuntimeError("Sources changed during delivery")
    os.replace(temporary, archive)
    result = dict(generatedUTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                  localGame=str(GAME), localBackup=str(backup), localUpdated=True,
                  remoteServerUpdated=False, githubUpdated=False,
                  archive=str(archive), archiveSHA256=sha(archive),
                  verificationSHA256=sha(OUT / "arc9-effects-verification.json"),
                  runtimeHashesVerified=len(current), cumulativeFiles=len(rows),
                  arc9EffectsPassFiles=len(selected), focusedPassed=verified["passed"],
                  syntaxFiles=verified["syntaxFiles"], files=rows)
    write(OUT / "arc9-effects-delivery.json", result)
    print(json.dumps({k: v for k, v in result.items() if k != "files"}, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    main(parser.parse_args().apply)
