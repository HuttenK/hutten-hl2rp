"""Refresh the implementation record without rewriting the original audit inventory."""
import collections
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/performance-audit'
read=lambda p: json.loads((OUT/p).read_text(encoding='utf-8-sig'))
inventory=read('overall/inventory.json')
baseline=read('review.json')
delivery=read('overall-delivery.json')
changed={r['path'] for r in delivery['files']}
findings={
 'F01':('Implemented; live verification pending','Unchanged equipped ARC9 inventory state produces no database save or replication; changed fields share one immediate save. Nested attachments, drop/unequip and shutdown remain covered by batch 1 tests.'),
 'F02':('Implemented; live voice test pending','Idle talkers skip pairwise routing. Active sweeps reuse one transmission lookup per talker, stationary radios use a lifecycle registry, and listener permissions remain live. No permission cache persists across sweeps.'),
 'F03':('Implemented; visual verification pending','Bleeding has a 20-Hz cadence, reused emitters and a fair six-burst budget. Medical bleeding rates, cart/ragdoll positioning and effect cleanup are retained.'),
 'F04':('Implemented; visual verification pending','Blackout beam stencil/full-screen layers reduced from 64 to 24. Mesh closure, endpoints, attenuation and render-state restoration are tested. Banding and actual GPU cost require an engine check.'),
 'F05':('Partially optimized; capture remaining producers','SetBleeding suppresses unchanged isBleeding assignments. Opt-in capture counts custom netvars by scope/key. Generic networking is deliberately not equality-cached: mutable tables, removals and explicit resync must retain their semantics.'),
 'F06':('Implemented; live logging test pending','Routine shootSuccess XP log entries aggregate by character into two-second count/total summaries. Awards are immediate; character switches, privacy changes, disconnect and shutdown flush. Damage/admin/security logs are not globally batched.'),
 'F07':('Implemented through gamemode adapter','SD material application checks relevant bodygroups and submaterials, skips unchanged application, and reconciles periodically. Entity discovery is bounded; original addon restoration and asset readiness logic remain authoritative. Addon files are untouched.'),
 'F08':('Implemented through gamemode adapter','Thermal rendering uses a lifecycle entity registry and a 10-Hz hot-source list instead of rebuilding the whole entity list each render. Existing heat eligibility is checked before drawing; rendering errors restore blend/color/lighting state.'),
 'F09':('Partially optimized; assembly fidelity retained','Weapon display cache compares attachment trees without JSON serialization on every draw. Nested edits invalidate the model. Required ARC9 bone work and full EFT assemblies remain; no default CSS-model fallback was introduced.'),
 'F10':('Partially optimized; compatibility paths retained','Remote contextual action discovery runs at 10 Hz; active actors and the local player still animate each frame. Height, headwear, ragdoll and ARC9 bone compatibility is not removed without engine evidence.'),
 'F11':('Implemented; live dense-area test pending','Legacy area volumes, disjoint volumes and measures are cached. Multi-volume areas reject outside their outer bounds early but preserve exact holes/union membership. AreaThink filters non-location types once and stops at the first matching location. Supported edits invalidate caches.'),
 'F12':('Implemented; live physics test pending','Flood broad-phase entity searches run at 5 Hz with a movement margin; exact volume/depth checks and buoyancy forces still run each tick. Damping changes only when needed, and original damping is restored on exit/unload.'),
 'F13':('Implemented; live treatment test pending','Only active medical sessions are visited by Think. Eligibility, range, ownership, cancellation and completion checks remain per tick.'),
 'F14':('Implemented; live jitter test pending','Automatic PDA closes are bounded and retry until acknowledged. Server duplicate closes are idempotent. Other security-sensitive requests are not blindly throttled.'),
 'F15':('Implemented; live multiplayer test pending','Moving subtitle attachments send revisioned index/position deltas instead of all text and payloads. Structural changes and new clients still receive complete snapshots; stale movement cannot edit a replacement entry.'),
 'F16':('Implemented; live loaded-grid test pending','Power ordering is reused until membership, record identity, kind or priority changes. Cable validity is reused within a solve. Blackout lights use an entity lifecycle registry. Power/access/isolation/fault/fuel decisions are still recomputed at the existing cadence.'),
 'F17':('Partially optimized; critical saves retained','Periodic world persistence skips identical snapshots. Movement, edits, cleanup and shutdown still save. Critical item/reward writes are not delayed; wider save staggering and journal changes require measured storage timings and crash/restart tests.'),
 'F18':('Implemented for confirmed idle work','Bodycam discovery fallback reduced from four checks per second to one; immediate equipment/death/character hooks and viewing authorization remain. Empty base NPC Think schedules once per second. Active controllers and interaction validation retain their cadence.'),
 'F19':('Implemented for broken schedules; other paths retained','GONews/taskboard use SetNextClientThink for their existing half-second interval. Other world panels were rechecked; existing visibility, distance and interval limits remain where no duplicate work was established.'),
 'F20':('Implemented; live HUD test pending','Door candidates are cached for 0.2 seconds with a movement margin; door geometry updates on transform/model/bounds changes or a one-second reconciliation. Waypoint visibility and bed hints trace at 10 Hz. Server interaction validation is unchanged.'),
 'F21':('Reviewed; existing budgets retained','CCTV/TV render limits, subscription validation and camera range checks are retained. Bodycam fallback discovery was reduced under F18. Remaining render cost needs live active-screen/player measurements; no blanket display disable or lower fidelity was added.'),
 'F22':('Implemented; live map test pending','Static native terminal maps reuse their rendered texture until the view, height slice, bake version, props, theme or dirty state changes. Dynamic markers and area labels remain separate live overlays.'),
 'F23':('Partially optimized; shadow budget retained','Flashlight candidate discovery/sorting runs at 10 Hz; selected light transforms update every frame. The existing three-shadow-light limit and brightness are retained. Further shadow changes require GPU profiling.'),
 'F24':('Partially optimized; external AI requires profiling','Client waste-effect entity discovery runs once per second with a range margin; emission and exact distance checks retain their cadence. SCP possession, medical hazard logic and third-party NPC AI are retained pending entity-count profiling.'),
 'F25':('Implemented; live jitter test pending','Stale world-item requests validate entity, class, item binding, character, range and action before method calls, preventing the observed nil-method failure without weakening authorization.'),
 'F26':('Reviewed; controlled-latency validation remains','Timeouts and leases are not extended indiscriminately. Existing cancellation, permissions and duplicate guards remain; PDA requests were bounded. Runtime capture is expanded, but real high-ping interaction/packet-loss tests remain necessary.'),
 'F27':('Partially optimized; remaining menus retained','Craft labels check availability at 10 Hz and update color only on change. Crafting still validates at execution. Broader menu/inventory work needs representative large-inventory profiling; financial/reward authorization is not cached.'),
 'F28':('Reviewed; authoritative timing retained','Health/stamina are already bounded/change-aware in the audited paths. Active dragging, movement, possession and medical checks keep their timing. Applying a global slow Think interval would risk the previous movement/medical bugs.'),
 'F29':('Partially addressed; external content remains','The stale item exception was fixed, syntax checked across the source tree, and thermal render failures restore state and report once. Missing Workshop materials/models and native Linux modules cannot be repaired by gamemode scheduling; addon contents remain unchanged.'),
 'F30':('Implemented: normal firearm hitscan','Server policy disables arc9_bullet_physics and arc9_bullet_physics_shotguns at startup and reconciles settings every five seconds. Actual installed firing code is covered by a matching fixture: hit callbacks/pellets remain, explicit ShootEnt/AlwaysPhysBullet projectiles retain their behavior. Nearby wall shots could already trace instantly, so this is not a proven complete explanation of the ping spike.'),
}
assert set(findings)=={f['id'] for f in baseline['findings']}
plugins={e['group'] for e in inventory['entries'] if e['path'].startswith(('helix/plugins/','ixhl2rp/plugins/'))
         and (e['path'].endswith('/sh_plugin.lua') or e['path'].count('/')==2)}
coverage=[]
for name,group in inventory['groups'].items():
    entries=[e for e in inventory['entries'] if e['group']==name]
    paths={e['path'] for e in entries}
    related=[f['id'] for f in baseline['findings'] if any(r.rsplit(':',1)[0] in paths for r in f['refs'])]
    edits=sorted(paths&changed)
    coverage.append(dict(group=name,loadablePlugin=name in plugins,files=group['files'],lines=group['lines'],
                         findings=related,changedFiles=edits,
                         review='Changed paths reviewed and regression-tested' if edits else
                         'Finding re-reviewed; see implementation decision' if related else
                         'Full structural rescan and hot-path triage; no source-confirmed change selected',
                         scope=sorted({e['scope'] for e in entries}),
                         liveCost='Not measured on the remote Linux server'))
assert len(coverage)==len(inventory['groups'])
record=dict(updated='18 October 2026',batch=2,
 summary=f'Overall optimization pass implemented across {delivery["pass2Files"]} runtime files; cumulative patch contains {delivery["verified"]} files including batch 1. All 30 audit findings were re-reviewed. Fresh structural scan: {inventory["files"]:,} Lua files, {len(plugins)} loadable plugin entries and {len(coverage)} source groups. Normal ARC9 firearms now use hitscan. Changes reduce confirmed repeated work; actual FPS, tick time and latency remain unmeasured.',
 findings={k:dict(status=v[0],detail=v[1]) for k,v in findings.items()},
 tests=dict(focusedPassed=213,focusedFailed=0,standaloneModules=9,syntaxFiles=2688,syntaxFailures=0,
            fullInventoryFiles=inventory['files'],fullInventorySyntaxFailures=sum(e['syntax']!='pass' for e in inventory['entries'])),
 baselineFailure='The pre-edit broad test runner fails at Act capabilities: native, Cellar, hybrid, zero, missing and unloaded models. See baseline-tests.log. This unrelated baseline failure is not claimed fixed.',
 deployment='Local files backed up and hash-verified; cumulative server patch prepared. See overall-delivery.json. Remote Linux server not updated automatically.',
 coverage='overall/coverage.json',details='overall.md',
 validationLimits='Mocked production-Lua regression tests and static parsing do not prove engine rendering, native module behavior, live networking, server capacity or physical FPS.')
(OUT/'overall/coverage.json').write_text(json.dumps(coverage,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(OUT/'implementation.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(findings=len(findings),plugins=len(plugins),groups=len(coverage),files=inventory['files'],
                      pluginCounts=dict(collections.Counter(p.split('/')[0] for p in plugins))),indent=2))
