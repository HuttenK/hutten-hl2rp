## Current SCP schema snapshot (2026-10-15)

The `scp-schema` branch contains the current Helix framework, SCP schema, and
companion addons used by this version.

Installation:

1. Copy `helix` and `ixhl2rp` into `garrysmod/gamemodes`.
2. Copy the folders inside `addons` into `garrysmod/addons` on the server and
   clients. Follow the included addon READMEs for dependency and mount details.
3. Keep the required Workshop collection below installed; the companion addons
   do not replace all Workshop dependencies.
4. Restart the server and clients after updating Lua or animation content.

Recent changes include blackout lighting and physical power connections,
multi-screen devices, weapon equipment slots and ARC9/SD animation support,
helmet cameras, and one-handed dragging of downed players. While dragging,
press E on the carried body to release it, or hold R to raise/lower the weapon;
reloading is disabled until the body is released.

This update adds cart transport for downed players, including patient bleeding
effects and corrected hand placement. The cart now uses the Episode Two model
with matching grips and cargo geometry. It also updates item models, names and
descriptions, replaces retired crafting items, and fixes spawning unnamed books.

Further updates add character height, the ragdoll-to-crawl severe injury flow,
SCP NPC possession and medical compatibility, blackout electronics control,
and persistent keycard restrictions for Zone Tsade's map doors and buttons.

### Map door access

Aim at a nearby door button or moving door leaf and use:

```text
/MapDoorAccess <level> [department]
```

- `level`: an integer from `0` to `4`; cards must meet or exceed this level.
- `department`: optional, one of `science`, `security`, or `military`.
  Omit it to accept any department with sufficient clearance.
- `/MapDoorAccess 0` allows public access without a card. Power checks remain.
- `/MapDoorAccessInfo` shows the selected group's rule.
- `/MapDoorAccessRemove` removes the group's rule.
- `/MapDoorAccessTest true` makes your administrator account obey card checks.
  Use `false` to restore the default administrator bypass.

Examples: `/MapDoorAccess 3 science`, `/MapDoorAccess 2 security`,
`/MapDoorAccess 4 military`, or `/MapDoorAccess 2` for any department.
The card must be equipped, issued, and not revoked. One department can be
specified per rule. Administrators bypass card checks by default.
See [door access instructions](docs/map-keycard-access.txt) for supported maps
and testing. The optional command refresh script in `tools` must be copied to
`garrysmod/lua` before running it; a normal server restart loads the fix too.

Local diagnostics, deployment backups, and copied stock gamemodes are not part
of this snapshot.

---

DESCRIPTION - WIP
Numerous features/plugins/changes and addon dependencies haven't been listed/described/explained yet


A modified version of autonomous hl2rpg (https://github.com/SchwarzKruppzo/autonomous-hl2rpg) created by Schwarz Kruppzo

Most of the changes were made using AI code and intended for personal use

Requires the following Steam addon collection - https://steamcommunity.com/sharedfiles/filedetails/?id=3680347522

Features:
1) VRMod x64 support (WIP) - working Helix menu, items and interactions - https://steamcommunity.com/sharedfiles/filedetails/?id=3725053591
2) D/GL4 support - https://steamcommunity.com/sharedfiles/filedetails/?id=3717221550
send messages to players real-time through Start-Up Window using ix_hudmsg "your message" in console
3) Slide-based intro and ending (z_ending; z_intro; z_endingnotext in ixhl2rp plugins)
4) Item-based sound player
5) Screen Effects - applies different screen effects to any/all players using chat commands
6) Points of interest - glowing interactable dots (points) which can display text when pressed on.
7) Realistic Visuals - enhanced hit indicators, camera shaking, etc

