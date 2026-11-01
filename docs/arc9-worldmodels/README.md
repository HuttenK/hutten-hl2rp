# ARC9 held weapons reverting to CSS models

## Finding

The installed ARC9 base's `cl_drawmodel.lua` selects LOD from projected size and
`arc9_lod_distance`, caching the result for 0.5 seconds. At LOD 2 its world draw
calls `DrawModel()` instead of drawing the attachment assembly. EFT defines basic
CSS world models for this path: AK-74M/AS VAL use `w_rif_ak47.mdl`; M4A1 uses
`w_rif_m4a1.mdl`. This changes appearance, not the equipped weapon or its damage.

The same source's `SetupModel` returns before creating attachments whenever LOD
is positive. A model first built at intermediate LOD can therefore remain an
incomplete assembly when the viewer gets closer. Both behaviors reproduce in
offline tests executing the installed addon functions.

The supplied server log does not record the affected client's LOD, viewpoint or
model state, so the exact trigger in that session is unconfirmed. This selector
does not use ping or FPS. A secondary camera can also seed its shared LOD cache;
the regression suite covers that possibility without claiming it happened here.

## Change

`ixhl2rp/plugins/arc9_worldmodels.lua` is a client-side Helix plugin. It decorates
only the native ARC9 methods on weapon instances, without editing Workshop files.

- For an active, mirrored weapon held by a player, cap the returned LOD at 1.5.
  Near/local levels remain unchanged; the CSS substitution is no longer selected.
- Build held world assemblies at construction LOD 0 so all installed parts exist.
  Construction happens once, not every draw. Cached assemblies created before
  the fix, or while dropped, refresh once when needed.
- Preserve ARC9's existing lower animation frequency at intermediate/distant
  LODs and the gamemode's arm-solve budgets. No added server simulation, bullet
  physics, networking or recurring whole-entity scan.
- Preserve first-person viewmodels, inventory/attachment data and custom preview
  contracts. NPC, dropped and inactive weapon behavior remains native.
- Leave third-party render overrides alone; unload restores only owned methods.

Keeping the actual gun and attachments visible at distances where ARC9 formerly
drew one CSS model does add client rendering work and can allow distant arm
solves again. Existing animation rate limits still apply. The size of that cost
has not been measured in a live session.

## Delivery and validation

Merge `HL2RP-ARC9-held-models.zip` into the server's `garrysmod/gamemodes/` folder.
It contains one new plugin, not a complete gamemode. Restart the server and have
players reconnect so they receive the client file. No Workshop upload is needed.
The installed local gamemode copy is also updated; see `delivery.json`.

31 test suites plus one standalone module passed; Lua 5.1 syntax passed.
Tests cover the native failure, cached far-camera LOD, assembly reuse/repair,
pickup/drop, attachment changes, previews, first person, wrapper ownership,
discovery, client disable/unload and server no-op. Existing shot-effects, arm
budget/helper, weapon-display and view-ownership tests also passed.

Run again:

```text
node tools/run-performance-tests.cjs arc9-worldmodels arc9-shot-effects render-budget arc9-helperbones weapon-display arc9-view-ownership
```

These are offline Lua tests, not live GMod rendering or multiplayer validation.
Check an equipped AK/M4 with attachments nearby, at distance, during a CCTV view,
and after re-equipping. If it persists, look directly at the affected player and
run `ix_arc9_worldmodel_info target` in the client console. The report shows
adapter status, original/effective LOD and assembled model count.

For an explicit A/B test, `ix_arc9_worldmodels 0` restores native behavior;
`ix_arc9_worldmodels 1` enables the fix (default).

## Other log findings

The attachment also reports an `extremefpsbooster-master` ConCommand error, GCAL
bone-write errors, WAC entities missing Type/Base, `357ammo` missing its item base,
nil character genetics, malformed addon materials and timeout messages. None is
direct evidence of the ARC9 model-selection state. This targeted patch does not
claim to repair those separate errors.

## Upstream evidence

Read-only snapshots of the installed ARC9 Workshop archive (2910505837) are in
`tools/fixtures/arc9-upstream/`. The copies were verified against that archive:

| File | SHA-256 |
| --- | --- |
| cl_drawmodel.lua | d9e273b05e97f3889b2aaa6205bafba3dedce94f6c5f9ec2dba84660adb1089f |
| cl_model.lua | fa8c0fb740ed7d4248b61e7b28b75f6f08e3ce4c7cf9be747d0831ca9c97e2ba |
| cl_wm.lua | 7037e55bf677c44f0577e13088f511d7cf6ce2de0bb8eaadc0045763e3f37ab3 |

The installed EFT base (2917343547) enables MirrorVMWM and does not override these
native methods, so it satisfies the adapter's source guards.
