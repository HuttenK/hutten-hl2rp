"""Verify the frozen core-safe pass; --apply backs up and updates two local files.

The archive combines those two files with the previous 55-file performance patch.
No data, configuration, databases, addons or remote server are modified.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/performance-audit"
GAME = Path(r"C:\Program Files (x86)\Steam\steamapps\common\GarrysMod\garrysmod\gamemodes")
BEFORE = Path(r"C:\Users\q1236\AppData\Local\Temp\ix-core-safe-before-20261018T011733Z")
FROZEN = {
    "helix/gamemode/game/items/sh_item.lua": "0b1b7f496e942fb48e38dff32e6a8bdaf74e3e116da8d687769d84e0442fcab2",
    "helix/gamemode/game/inventory/ui/cl_inventory_item.lua": "d9e429a36e67c665e33889f865b130ddf77a87de2c605b14b90a7ae232187f28",
}
README = """Cumulative performance patch, including the conservative core pass (2026-10-18).
This is a patch for the current gamemode, not a complete installation.

NEW CORE CHANGES
Item high-water-mark loading now asks the database for MAX(item_id) instead of
returning every ID. Existing allocation/reload/delayed-response safeguards stay.
This primarily reduces startup/loading work, not firefight work.
Unchanged, ordinary definition-driven inventory previews reuse their existing
model panel within the same slot. Custom/dynamic getters, LayoutIcon, late custom
items and ARC9 assembled previews retain their existing creation paths. This
reduces repeated rebuild allocations; it does not remove per-frame 3D drawing.
No generic save suppression, inventory indexes or network rewrite is included.

DEPLOYMENT AND PERSISTENCE
Stop the server before deployment. Back up garrysmod/gamemodes/, garrysmod/data/,
and the server's garrysmod/sv.db with any sv.db-wal and sv.db-shm companions.
A live copy of just sv.db is not a consistent SQLite backup.
Merge helix/ and ixhl2rp/ into garrysmod/gamemodes/. Restart and reconnect clients.
Do NOT copy a developer PC's sv.db or data folder onto the live server.
The shared record helper must be deployed together with all changed plugins.
Earlier included changes move CCTV, facility utilities, Foundation records and
world placements into the server's local sv.db, regardless of character adapter.
Helix character/item storage was confirmed to use SQLite on this server; the
ServerGuard MySQL connection is separate.
Old JSON files remain as pre-migration backups and become stale after edits.
Rollback requires a current legacy-format export or a consistent full checkpoint;
old JSON alone loses post-migration edits. Restoring an old whole sv.db also
rolls back other SQLite data. Keep normal consistent SQLite backups thereafter.

EARLIER DEFAULTS AND CHECKS
Ordinary ARC9 bullets are hitscan; penetration and ricochets are disabled.
Explicit special projectiles retain their original behavior.
ARC9 indoor classification uses optimized mode 0; shot audio remains enabled.
Server/superadmin: ix_arc9_sound_mode baseline (A/B), optimized (restore).
Client: ix_render_budget_status; ix_render_budget_arms 0 for arm-only A/B;
ix_render_budget 0 disables distance presentation budgets (1 restores).
Server console: ix_perf_server 60. Client console: ix_perf_client 60.
Captures stay in garrysmod/data/ix_performance/. Profiling adds overhead.
Test inventory rotation, stacks, skins, materials, liquids, syringes, custom
items and assembled weapons, plus item creation/loading after a clean restart.
Also verify persisted devices, camera access, cables/source depletion and poses.
Offline tests do not measure live Linux tick time, latency or visual quality.
No data, database, config, slides or addon contents are included or overwritten.
"""


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def runtime_hashes():
    return {p.relative_to(ROOT).as_posix(): sha(p)
            for name in ("helix", "ixhl2rp", "addons")
            for p in (ROOT / name).rglob("*.lua")}


def check():
    baseline = read_json(BEFORE / "manifest.json")
    current = runtime_hashes()
    changed = {p: h for p, h in current.items() if baseline.get(p) != h}
    if changed != FROZEN or set(baseline) != set(current):
        raise RuntimeError("Runtime scope/hash differs from the frozen two-file pass")
    verified = read_json(OUT / "core-safe-verification.json")
    if verified.get("exitCode") != 0 or verified.get("sourceChangedDuringRun"):
        raise RuntimeError("Verification did not finish successfully on stable sources")
    if any(verified.get(name) != current for name in ("runtimeHashes", "runtimeHashesBefore", "runtimeHashesAfter")):
        raise RuntimeError("Verification hashes do not match the complete current runtime")
    stats = verified["tests"]
    if stats["focusedFailed"] or stats["syntaxFailures"] or stats["fullInventorySyntaxFailures"]:
        raise RuntimeError("Verification contains failures")
    scope = verified["scopeComparison"]
    if set(scope["changed"]) != set(FROZEN) or scope["removed"] or scope["added"] or scope["addonsChanged"]:
        raise RuntimeError("Verification reports unexpected runtime changes")
    prior = {x["path"]: x for x in read_json(OUT / "next-delivery.json")["files"]}
    rows = []
    for name in sorted(set(prior) | set(FROZEN)):
        if not name.startswith(("helix/", "ixhl2rp/")) or not name.endswith(".lua"):
            raise RuntimeError("Unexpected archive entry: " + name)
        (ROOT / name).resolve().relative_to(ROOT.resolve())
        (GAME / name).resolve().relative_to(GAME.resolve())
        if name in prior and current[name] != prior[name]["afterSHA256"]:
            raise RuntimeError("Previous delivery source has changed: " + name)
        local = sha(GAME / name)
        allowed = {current[name], baseline[name]} if name in FROZEN else {current[name]}
        if local not in allowed:
            raise RuntimeError("Local divergence requires review before copying: " + name)
        rows.append(dict(path=name, coreSafePass=name in FROZEN,
                         beforeSHA256=baseline[name], afterSHA256=current[name],
                         localBeforeSHA256=local,
                         state="current" if local == current[name] else "ready"))
    return current, verified, rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    current, verified, rows = check()
    if not args.apply:
        print(json.dumps(dict(mode="check", runtimeHashes=len(current),
                              coreSafePassFiles=len(FROZEN), cumulativeFiles=len(rows),
                              changedLocalFiles=sum(x["state"] == "ready" for x in rows),
                              tests=verified["tests"]), indent=2))
        return

    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backup = Path(os.environ["TEMP"]) / ("ix-core-safe-local-backup-" + stamp)
    backup.mkdir(exist_ok=False)
    selected = [x for x in rows if x["coreSafePass"]]
    # Snapshot both existing local targets before overwriting either one.
    for row in selected:
        local, saved = GAME / row["path"], backup / row["path"]
        if sha(local) != row["localBeforeSHA256"]:
            raise RuntimeError("Local file changed while preparing backup: " + row["path"])
        saved.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(local, saved)
        if sha(saved) != row["localBeforeSHA256"]:
            raise RuntimeError("Backup verification failed: " + row["path"])
    (backup / "manifest.json").write_text(json.dumps(selected, indent=2) + "\n", encoding="utf-8")

    archive = OUT / "optimization-core-safe-gamemodes.zip"
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as package:
        for row in rows:
            package.write(ROOT / row["path"], row["path"])
        package.writestr("README-performance.txt", README)
    with zipfile.ZipFile(archive) as package:
        if package.testzip() is not None or set(package.namelist()) != {x["path"] for x in rows} | {"README-performance.txt"}:
            raise RuntimeError("Archive integrity/member check failed")
        for row in rows:
            if hashlib.sha256(package.read(row["path"])).hexdigest() != row["afterSHA256"]:
                raise RuntimeError("Archive source hash changed: " + row["path"])

    copied = []
    try:
        if runtime_hashes() != current:
            raise RuntimeError("Runtime changed after verification")
        for row in selected:
            local = GAME / row["path"]
            if sha(local) != row["localBeforeSHA256"]:
                raise RuntimeError("Local changed after backup: " + row["path"])
            copied.append(row)
            shutil.copy2(ROOT / row["path"], local)
        for row in rows:
            if sha(GAME / row["path"]) != row["afterSHA256"]:
                raise RuntimeError("Local hash verification failed: " + row["path"])
        if runtime_hashes() != current:
            raise RuntimeError("Runtime changed during delivery")
    except Exception:
        for row in reversed(copied):
            shutil.copy2(backup / row["path"], GAME / row["path"])
            if sha(GAME / row["path"]) != row["localBeforeSHA256"]:
                raise RuntimeError("Rollback hash failed; verified backup is at " + str(backup))
        raise

    result = dict(generatedUTC=stamp, localGame=str(GAME), backup=str(backup),
                  archive=str(archive), archiveSHA256=sha(archive),
                  verificationSHA256=sha(OUT / "core-safe-verification.json"),
                  coreSafePassFiles=len(FROZEN), verified=len(rows),
                  runtimeHashesVerified=len(current), tests=verified["tests"], files=rows,
                  remoteServerUpdated=False, githubUpdated=False)
    (OUT / "core-safe-delivery.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: v for k, v in result.items() if k != "files"}, indent=2))


if __name__ == "__main__":
    main()
