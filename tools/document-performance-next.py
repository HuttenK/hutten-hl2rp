"""Document the next pass without changing the saved original audit evidence."""
import collections
import importlib.util
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/performance-audit'
spec = importlib.util.spec_from_file_location('deployment', ROOT / 'tools/deploy-performance-next.py')
deployment = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deployment)

def read(name):
    return json.loads((OUT / name).read_text(encoding='utf-8-sig'))

def main():
    _, current, changed, rows = deployment.plan()
    prior_path = OUT / 'overall-implementation.json'
    if not prior_path.exists():
        prior = read('implementation.json')
        if prior.get('batch') != 2:
            raise RuntimeError('Expected prior overall implementation record')
        shutil.copy2(OUT / 'implementation.json', prior_path)
    record = read('overall-implementation.json')
    baseline = read('review.json')
    verification = read('next-verification.json') if (OUT / 'next-verification.json').exists() else None
    verified = bool(verification and verification['exitCode'] == 0 and verification['runtimeHashes'] == current)
    delivered = read('next-delivery.json') if (OUT / 'next-delivery.json').exists() else None
    delivered = delivered if delivered and {row['path']: row['afterSHA256'] for row in delivered['files']} == {row['path']: row['afterSHA256'] for row in rows} else None
    inventory = read('next/inventory.json') if (OUT / 'next/inventory.json').exists() else None
    overrides = {
        'F05': ('Expanded relevant-recipient networking; live capture pending', 'CCTV metadata uses nearby devices, linked cameras, live terminal access and short admin leases with explicit removals. Single-device updates avoid an all-device scan per recipient. Existing broadcast subtitle deltas and unchanged bleeding suppression remain. Generic Helix netvars retain remote-view/medical semantics; opt-in captures now measure messages and known recipient-bytes.'),
        'F09': ('Expanded distance budgets; full assemblies retained', 'Holstered attachment-tree checks are distance-budgeted, skeleton indices cached, and replaced/invalid assemblies refresh immediately. Full EFT assemblies and mounts draw each frame. No CSS model substitution or attachment removal was added.'),
        'F10': ('Expanded distance budgets; live model verification pending', 'Distant ARC9 arm targets recompute at 10 or 5 Hz, while native DoTPIK, helper repair, height checks and post-pose callbacks run every draw. Local/near helper rigs retain full frequency; ordinary rigs retain native cadence and foreign-wrapper fallback preserves native behavior. Model/action/view changes invalidate cached targets.'),
        'F16': ('Implemented incremental allocation and staggered maintenance', 'Unchanged facility allocation plans are reused until dependencies change or one-second reconciliation. Live cable obstruction/movement, source availability, blackout and fuel checks remain; exhausted sources revoke power in the same update. Shared contention and priority rebuild together. Discovery/save jobs are phase-staggered on the cooperative scheduler.'),
        'F17': ('Implemented per-record transactions and bounded snapshots', 'Foundation, CCTV, facility and world stores use changed-record local SQLite transactions with typed transforms, legacy migration and initialized-store corruption guards. Unchanged rows produce no writes. World autosave captures eight entities per slice; critical saves remain immediate and failed saves remain dirty. Back up server sv.db and data together before migration; old JSON becomes stale.'),
        'F18': ('Expanded idle behavior and bounded maintenance', 'Intercom publication sleeps until relevant events/hardware changes with five-second reconciliation. Shared maintenance staggers jobs and admits at most eight callbacks or 1.5 ms per frame before yielding; it cannot preempt a running callback. No catch-up storms; errors back off. Earlier idle voice, NPC and bodycam improvements remain.'),
        'F21': ('Implemented CCTV subscriptions; render budgets retained', 'CCTV metadata goes to nearby/linked/authorized viewers rather than all clients. Departure/access loss/removal clears records; camera feed authorization remains live. Discovery visits at most four clients per 0.1 seconds and can exceed one second at high population. Existing TV/CCTV render limits are retained; recent remote viewpoints protect nearby arm fidelity.'),
        'F24': ('Implemented indexed CPT hearing and conservative prop sleep', 'The verified CPTBase sound hook now visits its tracked NPC registry rather than all map entities on each emitted sound. Eligibility and hearing callbacks remain live. Source path, line range and normalized CRC guard the adapter; unknown replacements remain untouched. A bounded prop pass sleeps only settled, supported, ordinary non-map props; no bodies/items/NPCs are deleted or frozen.'),
        'F26': ('Expanded opt-in diagnostics; live latency validation pending', 'Captures add current plugin/cache/hook/receiver/job inclusive and self wall time, Lua net buffer bytes with known recipients, SQLite timings and MySQL submission/completion. Wrappers exist only during capture and preserve callback/return/error semantics. Linux read-only sampling collects selected-PID scheduling/throttling and aggregate counters. None measures real remote latency until run on the server.'),
        'F30': ('Implemented hitscan, ricochet/penetration off and audio preset', 'Ordinary ARC9 physics bullets and shotgun physics remain disabled; penetration and ricochets now default off, removing secondary material traces/bullets. Explicit special projectiles remain. Optimized indoor classification uses one trace per 0.25 seconds and retains shot audio; baseline is available for A/B. This and indexed sound hearing reduce source-confirmed wall-shot work, without proving the exact ping-spike cause.')
    }
    record['findings'].update({key: dict(status=value[0], detail=value[1]) for key, value in overrides.items()})
    assert set(record['findings']) == {finding['id'] for finding in baseline['findings']}
    plugin_count = group_count = None
    if inventory:
        plugins = {entry['group'] for entry in inventory['entries'] if entry['path'].startswith(('helix/plugins/', 'ixhl2rp/plugins/')) and (entry['path'].endswith('/sh_plugin.lua') or entry['path'].count('/') == 2)}
        plugin_count, group_count = len(plugins), len(inventory['groups'])
        cumulative = {row['path'] for row in rows}
        coverage = []
        for name, group in inventory['groups'].items():
            entries = [entry for entry in inventory['entries'] if entry['group'] == name]
            paths = {entry['path'] for entry in entries}
            related = [finding['id'] for finding in baseline['findings'] if any(ref.rsplit(':', 1)[0] in paths for ref in finding['refs'])]
            edits, earlier = sorted(paths & set(changed)), sorted(paths & cumulative - set(changed))
            coverage.append(dict(group=name, loadablePlugin=name in plugins, files=group['files'], lines=group['lines'], findings=related,
                                 nextPassFiles=edits, earlierPerformanceFiles=earlier,
                                 review='Current pass targeted semantic review and focused regression coverage; engine validation pending' if edits else
                                 'Earlier implementation retained and combined suite rerun; no further source-confirmed edit selected' if earlier else
                                 'Original finding and retained decision linked; full structural rescan' if related else
                                 'Full structural rescan; no additional targeted semantic-review claim',
                                 scope=sorted({entry['scope'] for entry in entries}), liveCost='Not measured on the remote Linux server'))
        (OUT / 'next/coverage.json').write_text(json.dumps(coverage, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    summary = f'Next optimization pass covers all seven approved options across {len(changed)} runtime files; cumulative patch contains {len(rows)} files. ARC9 ricochets and penetration are disabled, maintenance is staggered, persistence writes changed records, and client/network work is budgeted.'
    if inventory:
        summary += f' Fresh structural scan: {inventory["files"]:,} Lua files, {plugin_count} loadable plugin entries and {group_count} source groups.'
    summary += ' Actual FPS, server tick time and latency remain unmeasured.'
    record.update(updated='18 October 2026', batch=3, artifactPrefix='next', summary=summary, coverage='next/coverage.json', details='next.md',
                  tests=verification['tests'] if verified else {'status': 'Final combined verification pending'},
                  deployment='Local files backed up and hash-verified; cumulative server patch prepared. See next-delivery.json. Remote Linux server not updated automatically.' if delivered else 'Prepared; final verification/review and local deployment pending.',
                  branchSync='Working on master with substantial pre-existing changes. No staging, commit or push performed. This patch is isolated by before/after runtime snapshots; GitHub is unchanged.')
    (OUT / 'implementation.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    verification_text = 'Final combined tests and inventory are pending; no final verification or deployment is claimed yet.'
    if verified:
        counts = verification['tests']
        verification_text = f'''The combined suite completed with **{counts['focusedPassed']} focused checks passed, {counts['focusedFailed']} failed, and {counts['standaloneModules']} standalone modules completed**. The standalone modules contain their own assertions; they are not counted as one test each. [Full command and output](next-regression-tests.log). Runtime source hashes were unchanged throughout the run.

The deployment-source scan parsed **{counts['syntaxFiles']:,} Lua files with {counts['syntaxFailures']} failures**. The wider six-root scan parsed **{counts['fullInventoryFiles']:,} Lua files with {counts['fullInventorySyntaxFailures']} failures**, covering **{plugin_count} loadable plugin entries and {group_count} source groups**. [Syntax log](next-syntax.log), [rescan](next/inventory.json), [per-system coverage ledger](next/coverage.json), [verification manifest](next-verification.json).

These are structural scans plus targeted semantic reviews and mocked production-Lua tests. They are not an exhaustive execution of every external Workshop addon. The record-store suite uses a real temporary SQLite engine, with mocked GMod vector/entity APIs. The previously recorded broad-runner Act-capabilities failure remains a separate baseline issue; see [baseline output](baseline-tests.log). It is not claimed fixed or hidden in the passing selected suite.'''
    delivery_text = 'Deployment tooling is ready; final review, combined verification and local copying are pending.'
    if delivered:
        delivery_text = f'''The installed local gamemode copy was updated and all **{delivered['verified']} files** verified by SHA-256. Backup: `{delivered['backup']}`. [Delivery manifest](next-delivery.json).

[Download the cumulative server patch](optimization-next-gamemodes.zip). It includes earlier performance patches and this pass, and is intended to merge into the current gamemode. Every archive runtime member was hash-checked against the source. The remote Linux server was not changed automatically.'''
    text = f'''# Next performance pass — 18 October 2026

{summary}

Having many systems matters when their repeated work accumulates; merely installing many idle plugins is not an equivalent cost. This pass reduces shared scans, frequent serialization, broad metadata delivery and unnecessary remote presentation work while retaining interaction and medical timing.

## All seven approved options

| Approved option | Implemented work | Deliberate limits |
| --- | --- | --- |
| Relevant-recipient networking | CCTV metadata subscriptions for nearby screens/cameras, linked remote feeds, live terminal access and short admin leases; explicit removal on access loss; encoded payload reuse | Foundation pages retain authenticated recipient sessions. Generic health/Helix netvars remain available to authorized remote-camera, medical and HUD consumers. |
| Incremental facility and power work | Dependency-based allocation reuse; rebuild priority/contention together when topology or eligibility changes; one-second reconciliation | Cable movement, obstruction, blackout eligibility, fuel/charge and resource exhaustion stay live. Source exhaustion revokes power in the same update. |
| Staggered background jobs | Cooperative round-robin scheduler; phase-staggered discovery/saves; world snapshots capture eight entities per slice; prop checks process twelve per slice | The 1.5 ms/eight-callback admission budget cannot preempt a long callback. It yields between callbacks, avoids catch-up storms and backs off repeated errors. Critical gameplay validation remains immediate. |
| Smaller durable persistence | Changed-record transactional local SQLite for Foundation, CCTV, facility and world stores; typed transforms; initialized-store validation; failed writes stay dirty | Some record encoding remains synchronous. Critical saves are not delayed. Deployment changes backup/rollback requirements below. |
| Stronger idle behavior | Event-driven intercom publication with five-second reconciliation, staggered discovery and no unchanged record writes | Existing idle voice/bodycam/NPC improvements remain. Active possession, health, treatment, dragging and access checks retain their cadence. |
| Distance-based client work | Distant TPIK recomputation, holster attachment refresh and repeated muzzle effects use 10/5 Hz budgets; model/bone caches and immediate state invalidation | Models, full weapon assemblies and arm/helper/height/post-pose application still draw each frame. Local and close helper rigs preserve full frequency; ordinary rigs retain native cadence. |
| NPC and physics work | Indexed eligible CPTBase hearing NPCs; bounded conservative sleep for ordinary settled props | No NPC/ragdoll/item deletion, global AI slowdown, map-prop sleep or movement freezing. Unknown/replaced CPT hooks remain untouched. |

## Gunfire and client defaults

- Ordinary firearm and shotgun bullet physics stay disabled. **Penetration and ricochets are now disabled**: shooting through cover and reflected bullets are intentionally removed. Explicit special projectiles retain their native behavior.
- `ix_arc9_indoor_mode` defaults to `0`: one indoor-classification trace per 0.25 seconds. Normal shot sounds still play. Baseline mode `1` performs three traces per 0.1 seconds; detailed mode `2` performs eight per 0.02 seconds. Those are source-defined work limits, not measured speedups.
- Server console/superadmin A/B commands: `ix_arc9_sound_mode baseline`, `ix_arc9_sound_mode optimized`, `ix_arc9_sound_mode detailed`. Numeric `0`, `1`, `2` are accepted. Server policy reconciles ARC9 settings every five seconds.
- Client `ix_render_budget 1` and `ix_render_budget_arms 1` default on. Local/near subjects within 768 Source units preserve their prior cadence; farther subjects use 10 Hz through 1536 units and 5 Hz beyond. Relevant recent CCTV/reflection views are included. Helper-only full-rate behavior is preserved nearby; foreign arm-wrapper fallback uses native behavior.
- `ix_render_budget_status` reports state/counters. `ix_render_budget_arms 0` restores original arm timing independently. `ix_render_budget 0` disables the new distance preset; use `1` to restore it. The adapter restores its owned helper preference and muzzle registration on unload.

One additional gunfire cost was confirmed in source: CPTBase's advanced hearing hook enumerated every map entity for each emitted sound. The adapter now visits its tracked NPC list, preserving current flags and the original hearing callback. It installs only for the verified source path/line range/normalized CRC and leaves unknown hooks or active profiler wrappers alone. This is a plausible wall-shot contributor, **not proof that it caused the observed ping spike**.

Details and engine checks: [ARC9/client changes](next-client-rendering.md), [network/storage/measurement changes](next-network-storage.md).

## Required deployment and backup

{delivery_text}

**Stop the server first. Back up `garrysmod/gamemodes/`, `garrysmod/data/`, and the server's `garrysmod/sv.db`, including any `sv.db-wal` and `sv.db-shm` companions.** A live copy of only the main SQLite file is not a consistent backup. Merge the patch's `helix/` and `ixhl2rp/` into `garrysmod/gamemodes/`, restart, then reconnect clients. The shared record helper and dependent plugins must be deployed together.

The new records use the **server's local SQLite**, even when characters use MySQL. Old JSON files are retained as pre-migration backups and become stale after later edits. A code rollback requires a current legacy-format export or consistent full checkpoint restoration; old JSON alone loses post-migration edits. Restoring the entire old `sv.db` also rolls back other SQLite data. **Never copy the developer PC's database or data folder to the live server.** No addon contents, data files, configuration or slides are included in this patch. Addon Lua hashes match the before-pass snapshot.

Git handoff: the checkout is on `master` and contains substantial unrelated pre-existing changes. Nothing was staged, committed or pushed. The patch uses the pass snapshot and prior delivery manifest to isolate runtime files; GitHub and the remote server are unchanged. Do not commit the entire working tree as an optimization commit.

## Verification and capture

{verification_text}

Run identical idle, wall-firing and populated scenes on the Linux server, using `ix_perf_server 60` in the server console and `ix_perf_client 60` on a representative client. Reports stay in `garrysmod/data/ix_performance/`. The recorder adds current plugin/hook/receiver/job inclusive/self wall time, Lua net buffer bytes/known recipients and database submission/completion timing. Capture adds overhead. Native work, voice, engine datatables and unknown PVS/PAS recipient counts are not fully measured.

Optional host collection: copy [collect-linux-performance.sh](../../tools/collect-linux-performance.sh) to the server and run `bash collect-linux-performance.sh SERVER_PID 60 2 > linux-performance.txt` as the game-server account. It reads the selected process and aggregate counters; no environment variables, full process arguments or unrelated process command lines are collected. It changes no host settings. No remote host measurement has been performed here.

Before a populated session, verify persistence after a clean restart; move/block power cables and exhaust a source; revoke camera access and test linked remote feeds; test SD/Beta-7/imported-model arms, reloads, dragging, heights and CCTV closeups; compare optimized/baseline indoor classification while firing at a wall. Real tick time, ping, capacity, native rendering and audio remain unmeasured.

## Audit continuity

The original [audit report](report.html), saved inventory and 30 finding identifiers are retained. Their implementation decisions are updated rather than replaced by a new baseline. The current ledger distinguishes changed paths, inherited optimizations and structural-only rescans; it does not claim every line or addon was semantically reviewed in this pass.
'''
    (OUT / 'next.md').write_text(text, encoding='utf-8')
    print(json.dumps(dict(nextPassFiles=len(changed), cumulativeFiles=len(rows), verified=verified, deployed=bool(delivered),
                          plugins=plugin_count, groups=group_count, findings=len(record['findings'])), indent=2))

if __name__ == '__main__':
    main()
