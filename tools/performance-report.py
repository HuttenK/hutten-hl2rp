"""Build a coverage report from the source inventory and reviewed findings.

No game code, addon content, configuration or deployed copy is modified.
"""
import collections
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'docs' / 'performance-audit'
inventory = json.loads((OUT / 'inventory.json').read_text(encoding='utf-8'))
findings = []


def add(id, priority, title, domain, evidence, change, guard, refs, conditional=False):
    findings.append(dict(id=id, priority=priority, title=title, domain=domain,
                         evidence=evidence, change=change, guard=guard, refs=refs,
                         confidence='Conditional / measure before changing' if conditional else 'Source-confirmed mechanism; cost unmeasured'))


add('F01', 'First', 'Five periodic item saves for an unchanged equipped ARC9 weapon', 'Server / database / network',
    'ARC9_Hook_Think calls A.Save once per second. A.Save sets ammo, ammo2, ammoType, ammoType2 and arc9_atts. ITEM:SetData has no equality guard and immediately resumes Async_SaveData; that coroutine executes the queue without a batching delay. SaveData serializes the item and issues an UPDATE for each setter. This is scheduling work immediately, not proof that the database driver itself is synchronous. Twenty eligible thinking weapons can schedule about 100 update requests/second.',
    'Track dirty fields; serialize attachments only after modification; coalesce writes per item; send changed fields to the correct recipients. Instrument requests, serialized bytes and flush time.',
    'Preserve ammo and attachment identity through drop, trade, death, disconnect and shutdown. Flush critical ownership transitions; define and test crash durability. Do not indiscriminately delay every inventory write.',
    ['ixhl2rp/plugins/ammo_cringe/sh_plugin.lua:140', 'ixhl2rp/plugins/ammo_cringe/sh_arc9.lua:67', 'helix/gamemode/game/items/sh_item.class.lua:521', 'helix/gamemode/game/items/sh_item.lua:235'])
add('F02', 'First', 'Voice routes recomputed for every player pair at 10 Hz', 'Server / voice',
    'ixRadioFilterRoutes loops all talkers and all listeners every 0.1 seconds whenever the filter backend exists. This includes idle players. Theoretical route counts: 20 players = 4,000/second; 40 = 16,000/second. Route helpers can inspect equipment, traces and stationary radios. Engine voice permission polling also calls routing.',
    'Maintain active talkers, cache per-talker transmission data and device registries, invalidate on radio/channel/power/character changes, and update native filter routes only when needed. Retain a bounded refresh for spatial movement and effect-tail cleanup.',
    'Do not leak voice across channels, clearance or blackout boundaries. Preserve local occlusion, PA echo tails, rapid PTT release and immediate access revocation.',
    ['ixhl2rp/plugins/proximity_voice/sv_filter.lua:96', 'ixhl2rp/plugins/proximity_voice/sv_voice.lua:64'])
add('F03', 'First', 'Bleeding particle creation scales with frame rate and casualties', 'Client / combat effects',
    'cl_criticalstate HUDPaint calls DrawBleeding each frame. Each nearby bleeding player creates an effect, a fresh ParticleEmitter, five smoke particles and five colliding blood particles. At 60 FPS this is about 600 particles and 60 emitters created per second per bleeding player. The one-second player-list refresh does not throttle emission.',
    'Move emission to a time-based budget, reuse emitters, cap total cosmetic births, and apply distance/visibility budgets. Keep existing blood trails and visible bleeding cues.',
    'Do not change medical bleeding rates. Verify carts, ragdolls, standing players, multiple casualties, emitter cleanup and equal visual density at 30/60/144 FPS.',
    ['ixhl2rp/plugins/!healthsystem/cl_criticalstate.lua:133', 'ixhl2rp/plugins/!healthsystem/cl_fx.lua:58', 'ixhl2rp/plugins/!healthsystem/cl_fx.lua:101'])
add('F04', 'First', 'Blackout flashlight uses 64 stencil/full-screen passes', 'Client / GPU',
    'Blackout flashlight restoration iterates 64 cone layers, clears/configures stencil and submits full-screen textured drawing per layer. This runs in the relevant blackout/flashlight view, not every scene. It is 64 submissions/passes, not evidence that every screen pixel is shaded 64 times.',
    'Benchmark a lower-pass or shader-based restoration while maintaining the intended beam and darkness. Keep a documented visual comparison.',
    'Test active and inactive zones, doors, moving lights, scopes, CCTV and NVG; never restore brightness outside the authorized flashlight region.',
    ['ixhl2rp/plugins/blackout/cl_lighting.lua:211', 'ixhl2rp/plugins/blackout/cl_lighting.lua:267'])
add('F05', 'First', 'Helix custom network variables transmit unchanged assignments', 'Server / network',
    'ENTITY:SetNetVar, PLAYER:SetNetVar and PLAYER:SetLocalVar write and send on every assignment without comparing the old value. The custom entity/player setters broadcast by default. This is distinct from engine NW/NW2 setters; repeated NW2 calls are not by themselves proof of repeated packets.',
    'Measure top variable names/bytes, eliminate unchanged calls at frequent producers, and add explicit delta/full-sync semantics if changing the shared transport. Bound initial synchronization bursts.',
    'Equality must handle mutable tables/vectors, targeted receivers, newly joined clients and explicit resync/clear requests. A global naive old==new early return can break synchronization.',
    ['helix/gamemode/core/sh_networking.lua:323', 'helix/gamemode/core/sh_networking.lua:347', 'helix/gamemode/core/sh_networking.lua:371'])
add('F06', 'First', 'Combat skill logs perform access lookup, transmission and file append', 'Server / combat / I/O',
    'Successful shooting damage calls DoAction(shootSuccess). Awarded actions log unless noLogging is set. ix.log.Add resolves admin recipients, sends log messages, prints to console and dispatches a file.Append handler per record. This can add combat-related work; the measured frequency and filesystem cost are still unknown.',
    'Aggregate routine XP/training messages over a short interval and batch file output. Cache authorized log subscribers with permission invalidation. Keep damage/XP calculation immediate.',
    'Retain important administrative, death, inventory and security audit events. Do not remove accountability to improve FPS.',
    ['ixhl2rp/plugins/!healthsystem/sv_combat.lua:685', 'ixhl2rp/plugins/!!skills/libs/sh_actions.lua:118', 'helix/gamemode/core/libs/sh_log.lua:105', 'helix/gamemode/core/libs/sh_log.lua:157'])
add('F07', 'Next', 'SD companion scans all entities and reapplies materials', 'Client / clothing',
    'The bundled SD companion runs ents.GetAll every 0.25 seconds and calls D.Apply; PrePlayerDraw calls it as well. Supported entities can receive SetSubMaterial with the already-applied value. Model profiles are already cached.',
    'Keep a registry of supported entities, react to model/bodygroup/submaterial changes, and write only changed material slots. Keep a slow reconciliation pass for external changes.',
    'Maintain hair colour, D-class uniforms, armor, preview models, corpses and cart patient materials. Prefer a gamemode compatibility integration while preserving original third-party addons.',
    ['addons/sd_dclass_companion/lua/autorun/sd_dclass_companion.lua:169', 'addons/sd_dclass_companion/lua/autorun/sd_dclass_companion.lua:215'])
add('F08', 'Next', 'Thermal vision entity cache count is never updated', 'Client / thermal vision',
    'The bundled Arctic NVG implementation initializes ents_count=0, compares it to ents.GetCount, but never assigns the new count. In the ThermalVision branch it therefore rebuilds ents.GetAll on each render pass on a nonempty map, then scans/draws eligible heat sources. This affects thermal goggles only if that branch is used.',
    'Use a maintained heat-source registry and bounded visibility work. A count-only cache also misses remove/add replacements with equal entity counts; use lifecycle events or periodic reconciliation.',
    'Preserve intended thermal visibility rules and ragdoll cooling. Do not silently change detection gameplay. Integrate through a compatible gamemode adapter rather than editing an external addon.',
    ['addons/legends_field_actions/lua/autorun/cl_arctic_nvg.lua:237', 'addons/legends_field_actions/lua/autorun/cl_arctic_nvg.lua:273'])
add('F09', 'Next', 'Detailed holstered/dropped weapon assembly work', 'Client / weapon rendering',
    'A.Get builds its cache signature with TableToJSON on drawing paths. A.Draw invalidates part bones and draws the assembly. Preview carriers force ShouldLOD to zero and the assembly is reused for world/holster displays. Multiple guns per character multiply this work.',
    'Use attachment revision keys, cache model/bone metadata, and implement distance/screen-size budgets for holstered and dropped assemblies. Keep close held guns detailed.',
    'Preserve installed attachments, caliber conversions, ammo display, skins, trace shapes and holster placement. Avoid visibly replacing nearby guns with unrelated CSS models.',
    ['ixhl2rp/plugins/arccw_item_atts/cl_display.lua:18', 'ixhl2rp/plugins/arccw_item_atts/cl_display.lua:34', 'ixhl2rp/plugins/arccw_item_atts/cl_preview.lua:43', 'ixhl2rp/plugins/ammo_cringe/cl_weapon_holsters.lua:65'])
add('F10', 'Measure', 'Overlapping character animation and bone work', 'Client / animation',
    'ARC9 helper-bone wrapping, SD reference anchoring, shared poses, contextual actions, dragging, cart IK, hair/headwear and Pose Studio all contribute hooks or bone callbacks. Several discover active players every Think. SD donor sampling already has a per-frame cache, height application has a state guard, and Pose Studio skips dormant actors; retain these protections.',
    'Profile combined cost per visible actor; cache skeleton topology and capability lookups; update registries on state changes; consolidate duplicate solver/SetupBones work and budget remote actors by distance. Compare the installed ARC9 native helper handling before retaining two repair layers.',
    'Recheck SD, Beta-7 and guard models, all heights, amputations, weapons, prone, seats, beds, carts and portable poses. Never remove a compatibility fix solely because it appears expensive.',
    ['ixhl2rp/plugins/arc9_helperbones.lua:142', 'helix/gamemode/core/libs/cl_arc9sdpose.lua:84', 'ixhl2rp/plugins/action_animations/cl_actions.lua:101', 'ixhl2rp/plugins/pose_studio/cl_playback.lua:124', 'ixhl2rp/plugins/character_height/sh_height.lua:52'], True)
add('F11', 'Next', 'Repeated area membership work across systems', 'Both / spatial queries',
    'AreaThink checks players against all location areas. Infection, flood, power and quest zones perform their own spatial loops. GetVolumes constructs fresh boxes/vectors for legacy single-box areas. Outline and disjoint-volume calculations already have caches.',
    'Cache normalized volume geometry, index areas spatially, share suitable per-position queries and filter by area type before detailed checks. Invalidate on edits, teleport and map cleanup.',
    'Keep irregular union shapes, overlap behavior, height slicing and holes correct. Do not replace exact membership with the outer bounding box.',
    ['helix/plugins/area/sv_hooks.lua:41', 'helix/plugins/area/sh_geometry.lua:7', 'ixhl2rp/plugins/infectionzone/sv_plugin.lua:571', 'ixhl2rp/plugins/quest_director/sv_runtime.lua:486'])
add('F12', 'Next', 'Flood buoyancy performs area searches every simulation tick', 'Server / physics',
    'Flood:Tick iterates flood areas and ApplyBuoyancy performs ents.FindInBox, exact containment, Wake, force and damping work for submerged movable props/items. Per-object force is simulation-sensitive; candidate discovery does not need the same frequency.',
    'Separate slower membership discovery from per-tick force integration; cache active wet objects; avoid redundant damping changes and repeated overlapping-zone treatment. Measure physics cost with many floating props.',
    'Preserve stable buoyancy, damping restoration, pump progress, drowning and item pickup. Do not throttle force application without correctly integrating elapsed time.',
    ['ixhl2rp/plugins/flood/sv_plugin.lua:169', 'ixhl2rp/plugins/flood/sv_plugin.lua:197'])
add('F13', 'Next', 'Medical sessions scan every player every frame', 'Server / treatment',
    'ixMedicalSessions is a Think hook that loops player.GetAll even when there are no active treatments. Active sessions run ownership/state/deadline checks there.',
    'Maintain an active-session set with immediate cancellation events and a suitable bounded validation cadence. Keep completion/deadline checks authoritative.',
    'Preserve interruption on damage, movement, item transfer, weapon selection and character change. Stress RTT and weapon deployment delays.',
    ['ixhl2rp/plugins/medical/sv_treatment.lua:337'])
add('F14', 'First', 'PDA close requests repeat while waiting for server replication', 'Client to server / latency',
    'FieldlinkDevice sends ixFieldlinkClose every Think while a blocking UI is open and the replicated weapon still reports equipped. There is no local pending latch in this branch. The server receiver directly calls PdaOff. Delayed replication can extend this burst.',
    'Send once per close transition, track a pending request/acknowledgment, permit a bounded retry and clear on device/character changes. Make handling idempotent.',
    'Keep console/menu transitions, manual close and reopen reliable; never let retries duplicate inventory changes.',
    ['ixhl2rp/plugins/site_pda/cl_device.lua:24', 'ixhl2rp/plugins/site_pda/sv_fieldlink.lua:64'])
add('F15', 'Next', 'Moving a subtitle point broadcasts the whole list at up to 10 Hz', 'Server / network',
    'ixSubtitlePointPropUpdate checks attached point movement every 0.1 seconds. If any point moves over the threshold it serializes every subtitle point and sends the full list to all clients.',
    'Replicate the attachment entity and local offset; otherwise send changed positions only at a bounded rate. Use full snapshots for initial sync or edits.',
    'Retain point activation range, removal and authoring semantics. Test late join and attachment disappearance.',
    ['ixhl2rp/plugins/subtitlepoint/sh_plugin.lua:378'])
add('F16', 'Next', 'Power graph rebuilt and blackout entities rediscovered repeatedly', 'Server / facility',
    'Facility Think runs binding restoration, lockdown restoration, comms pruning, jobs and RecomputePower every 0.25 seconds. RecomputePower revisits/sorts devices, sources and links. Blackout RefreshLights scans ents.GetAll periodically.',
    'Use dirty topology and entity registries, separate power solving from charge/fuel integration, spread noncritical job discovery and use direct zone/device membership caches.',
    'Preserve generator/battery door power, active blackout exceptions, cable range/obstruction validation, faults and immediate access changes.',
    ['ixhl2rp/plugins/facility_utilities/sv_network.lua:186', 'ixhl2rp/plugins/facility_utilities/sv_power.lua:37', 'ixhl2rp/plugins/blackout/sv_plugin.lua:46'])
add('F17', 'Next', 'Save bursts and repeated complete snapshots', 'Server / disk / hitching',
    'ix.data.Set immediately JSON-encodes and file.Write writes a complete value. Global SaveData dispatch runs every 600 seconds; world persistence also recaptures/saves all tracked placements every 30 seconds. Other plugins save on mutations. Quest Director writes and reads back a complete generation, sometimes for progress updates or reward steps.',
    'Measure per-plugin snapshot bytes and duration, stagger normal autosaves, maintain dirty records, coalesce burst edits/destruction and consider a bounded journal plus periodic snapshot for large quest stores.',
    'Preserve verified reward receipts, two-generation recovery, shutdown flush, unknown entity records and single persistence ownership. Do not recreate disappearing TVs/CCTV or reward duplication.',
    ['helix/gamemode/core/sh_data.lua:19', 'helix/gamemode/core/sh_data.lua:115', 'ixhl2rp/plugins/world_persistence/sv_store.lua:44', 'ixhl2rp/plugins/world_persistence/sv_store.lua:159', 'ixhl2rp/plugins/quest_director/sv_store.lua:36'])
add('F18', 'Next', 'Frequent no-change equipment discovery and idle entity Think', 'Both / background work',
    'Bodycams refresh every player at 4 Hz; height, held-weapon, NVG, PDA, amputation and HUD-access watchdogs independently scan populations. Static dialogue NPC Think schedules itself for the current time without work. Some other entity Think functions only check coarse expiry.',
    'Move equipment and faction refresh to known state-change events with slow reconciliation; keep active registries and remove empty per-tick entity callbacks when engine behavior permits.',
    'Keep fallback reconciliation for external SetModel/equipment code and correct cleanup on reload/disconnect. Do not combine unrelated security state in an unsafe cache.',
    ['ixhl2rp/plugins/bodycams/sv_bodycams.lua:62', 'ixhl2rp/plugins/character_height/sh_height.lua:81', 'ixhl2rp/plugins/field_equipment/sv_equipment.lua:85', 'ixhl2rp/plugins/npcs/entities/entities/ix_basenpc.lua:70', 'ixhl2rp/plugins/status_display/sv_status.lua:50'])
add('F19', 'Next', 'Legacy world panels use the server Think scheduler on the client', 'Client / world UI',
    'The client branches of news and taskboard entities call NextThink(CurTime()+0.5) after panel/range checks. The documented client scheduling API is SetNextClientThink. These calls do not provide the intended client scheduling contract.',
    'Use the correct client cadence or a shared visibility manager; create panels only when needed and suspend offscreen work. Audit loyalist and scanner terminals for the same pattern.',
    'Preserve world-space interaction, manual painting, power checks and camera state restoration. Measure actual Think frequency before/after.',
    ['ixhl2rp/plugins/gonews/entities/entities/ix_gonews_terminal.lua:51', 'ixhl2rp/plugins/taskboard/entities/entities/ix_taskboard.lua:54'])
add('F20', 'Next', 'Door labels and HUD hints repeatedly search and trace', 'Client / world UI',
    'Door rendering performs FindInSphere and door geometry traces during PostDrawTranslucentRenderables. Waypoints perform line-of-sight checks in HUDPaint. Sleeping hints issue a fresh trace in ordinary HUDPaint. Other prompts call cached GetEyeTrace; those should not all be counted as unique engine traces.',
    'Cache static door label frames, refresh nearby candidates and waypoint visibility at bounded rates, and share compatible main-view interaction sampling.',
    'Keep moving doors and interaction rays correct. CCTV RenderView can change camera globals; use the main player view where required.',
    ['helix/plugins/doors/cl_plugin.lua:96', 'ixhl2rp/plugins/waypoints/cl_hooks.lua:6', 'ixhl2rp/plugins/sleep/cl_sleep.lua:32'])
add('F21', 'Measure', 'CCTV, bodycams and TV already have budgets; measure remaining cost', 'Both / surveillance / media',
    'CCTV has a four-feed pool, visibility/trace caching and a total 16 captures/second per viewer (8/camera). TV has visibility-based texture rates and shared channel browsers. CCTV server visibility still extends PVS and revalidates watchers; multiple terminals/bodycams can increase scene and network work.',
    'Measure captures, unique feeds, watchers, PVS traffic and HTML/media memory. Tune resolution/rates adaptively and reuse identical feeds. Retain existing caps.',
    'Keep access checks, camera damage/power, terminal cursor mapping, offscreen audio semantics and persistence. Do not replace all screens with blank props.',
    ['ixhl2rp/plugins/cctv/cl_render.lua:1', 'ixhl2rp/plugins/cctv/sv_network.lua:64', 'ixhl2rp/plugins/tv_screen/cl_plugin.lua:89'], True)
add('F22', 'Measure', 'Terminal map native view refreshes even while unchanged', 'Client / map renderer',
    'The native map path permits reuse only until nextRefresh, then renders again; after a successful render nextRefresh is RealTime()+0.25. The map implementation also has dirty keys, baked geometry and clipping. The fallback is throttled and cached too.',
    'Separate static map imagery from dynamic markers; refresh static render targets only for view/layer/bake changes when possible. Measure bake and large-map triangle/prop costs.',
    'Maintain floor cuts, admin height limits, one label per logical area and moving device/incident markers.',
    ['ixhl2rp/plugins/foundation_network/cl_map3d.lua:160', 'ixhl2rp/plugins/foundation_network/cl_map.lua:328'], True)
add('F23', 'Measure', 'Flashlight selection and shadow cost in crowds', 'Client / lighting',
    'Flashlight Think scans players, sorts nearby candidates and updates up to three shadow-enabled projected textures each frame. The three-light limit already exists.',
    'Refresh candidate selection less often while updating chosen light transforms smoothly; budget remote shadows and test scenes with muzzle flashes and blackout.',
    'Keep the local light responsive, existing brightness and meaningful distant light cues.',
    ['ixhl2rp/plugins/flashlight/cl_flashlight.lua:6'], True)
add('F24', 'Measure', 'SCP/NPC and hazard simulation need entity-count profiles', 'Server / AI / physics',
    'Infection processing checks zones and player proximity, already limits flora/NPC populations and despawns distant zone zombies. SCP-610 has active registries and a one-growth budget per control tick. Player possession aim sends are already bounded at 30 Hz. External CPT/VJ native and Lua costs are not covered by the repository alone.',
    'Profile active/possessed versus idle AI, navigation and physics; use global population budgets and stagger discovery. Cache infection waste props instead of a 1,400-unit sphere search every 0.12 seconds.',
    'Never pause a possessed SCP, remove an active medical patient, disable required map doors, or alter SCP injury/corrosion rules as a hidden optimization.',
    ['ixhl2rp/plugins/infectionzone/sv_plugin.lua:571', 'ixhl2rp/plugins/infectionzone/cl_plugin.lua:363', 'ixhl2rp/plugins/scp610_control/sv_control.lua:155', 'ixhl2rp/plugins/scp_npc_compat/cl_control.lua:4'], True)
add('F25', 'First', 'Stale item request can throw during delayed interaction', 'Server / correctness under latency',
    'item.entity.action reads an entity and calls entity:GetItem(), then reads item.functions_bits before checking that the entity and item still exist. A delayed request can arrive after removal/transfer; the previously supplied log contains this failure.',
    'Validate entity type, item identity, action bounds, current ownership/range and session before reading dependent fields or performing a mutation; reject stale requests cleanly.',
    'Use idempotent request handling where retries are allowed. Retain authorization checks and avoid duplicate pickup/trade outcomes.',
    ['helix/entities/entities/ix_item.lua:220'])
add('F26', 'Measure', 'Short leases and pending actions require delay testing', 'Both / latency / reliability',
    'CCTV watcher grants expire after 1.5 seconds. Voice PTT/effect state, medical weapon selection, cart actions, inventory transfers and UI sessions also use deadlines. Some already have tokens, revisions and validation; increasing every timeout is not a fix.',
    'Test jitter, lost/delayed refreshes, server stalls, reconnect and stale responses. Add explicit pending state, acknowledgments and bounded recovery to failing flows; instrument expiry reasons.',
    'Do not let refresh grace preserve revoked clearance or electricity access. Do not relax damage or inventory authority.',
    ['ixhl2rp/plugins/cctv/sv_network.lua:68', 'ixhl2rp/plugins/medical/sv_treatment.lua:337', 'helix/gamemode/game/inventory/sh_inventory.class.lua:1459'], True)
add('F27', 'Measure', 'Crafting, vendors, books and menus should be event-driven', 'Both / UI / inventory',
    'Most recipes and item definitions are registration data, not per-frame workloads. Crafting panels still update label colors in Think; large catalogs and vendor/character screens can build many controls/models. Inventory already has delta movement support; keep it.',
    'Measure opening large catalogs, virtualize visible rows, cache filtering and craftability by inventory/skill revision, and avoid rebuilding icons/models for unchanged data.',
    'Preserve server recipe revalidation, atomic costs/rewards, skill learning, item migrations and NVG/uniform equipment semantics.',
    ['ixhl2rp/plugins/ixcraft/derma/cl_craft_item.lua:386', 'helix/gamemode/game/inventory/sh_inventory.class.lua:1067'], True)
add('F28', 'Measure', 'Health updates and movement need targeted profiling, not blanket slowdowns', 'Both / health / movement',
    'Health uses a four-second tick and cached derived values; changed hediffs have owner-targeted synchronization, while some effects send individual updates. Stamina sends only on change. Body dragging iterates active states and uses simulation Tick deliberately. These are not all-player full-health broadcasts every frame.',
    'Measure damage processing, equipped armor lookup, hediff update bytes and active drag/ragdoll physics separately. Consolidate multiple changed hediff updates if justified.',
    'Keep timing for five-second fall, crawl window, give-up, paralysis/corrosion, treatment and limb damage. Do not halve simulation updates indiscriminately.',
    ['ixhl2rp/plugins/!healthsystem/sh_health.class.lua:489', 'ixhl2rp/plugins/!healthsystem/sh_effects.define.lua:141', 'helix/plugins/stamina/sh_plugin.lua:50', 'ixhl2rp/plugins/body_drag/sv_drag.lua:137'], True)
add('F29', 'Measure', 'Error floods and legacy/load-order failures amplify busy scenes', 'Both / error handling',
    'Earlier supplied logs show repeated missing screen_ready material errors, obsolete ammo-base registration warnings and stale item errors. The repository contains legacy code under _old which is not loaded by the normal plugin loader. Existing performance options mainly set client cvars, not server algorithms.',
    'Eliminate repeat error sources, fix registration order without breaking item IDs, validate content packaging and document enabled plugins/addon versions. Rate-limit repeated diagnostics while retaining the first useful stack.',
    'Do not edit or delete unrelated addons or legacy data without an explicit migration. Verify actual server content; local presence is not proof of remote mounting.',
    ['helix/gamemode/core/libs/sh_plugin.lua:245', 'helix/plugins/au_performance/cl_hooks.lua:1', 'ixhl2rp/schema/items/ammo/sh_ar2ammo.lua:1'], True)
add('F30', 'Optional', 'ARC9 physical bullet and cosmetic combat presets', 'Both / external ARC9 dependency',
    'Previous targeted inspection of the installed ARC9 base found physical-bullet spawn replication to other clients, client bullet progression and configurable bullet physics/effects. This report does not establish the current remote server settings or a complete audit of every external weapon addon.',
    'A/B test identical scenes with ordinary physical bullets enabled/disabled and cosmetic light/brass budgets. Inspect external native TPIK and effect settings before adding more wrappers.',
    'Hitscan changes bullet travel/drop and may interact with penetration and medical damage. This is an explicit gameplay option, not a silent default. Preserve grenade/special projectile behavior.',
    ['ixhl2rp/plugins/arc9_compat.lua:93'], True)

# Family coverage applies to every loadable plugin, even when no finding is proven.
families = [
 ('Combat, medicine and equipment', '!healthsystem medical downed_state amputation ammo_cringe arccw_item_atts arc9_compat.lua arc9_eft_grenade_network.lua body_drag field_equipment gasmask_immersion flashlight persistent_corpses.lua searchragdoll.lua ragdollfix.lua shootlock.lua propkillprotection.lua tranq'.split()),
 ('Animation, models and character presentation', 'action_animations arc9_helperbones.lua au_imfirstperson au_visualemote cellaranims.lua character_height emotemoods.lua emotes holsteredweapons.lua items_clothing items_mpf legs.lua player_controls pose_studio pronesupport.lua sd_creation.lua sd_hair_colour sd_material_repair sithelper turning.lua vrmod_compat act thirdperson.lua'.split()),
 ('Facility, power, hazards and world persistence', 'blackout bodycams cctv combinelocks contrabandscanner decontamination emp_hack facility_utilities flood forcefields furnishing infectionzone map_keycards pushcart sleep water_sources world_persistence doorsaving.lua doorlock.lua persistence.lua saveitems.lua spawnsaver.lua propprotect.lua perma_protection.lua'.split()),
 ('NPCs, SCPs and world simulation', 'combinescanners farming mining npcs npc_relations.lua npc_reward.lua recyclefactory scp_npc_compat scp610_control testdummy vortigaunts'.split()),
 ('Communications, screens, terminals and information', '!acceptsearch !new_datafile !new_terminal au_notes chat citizenids civic_journal datafile datafileterminal foundation_network goalert gonews languages loudspeaker paperwork proximity_voice radio requestdevice site_pda soundplayer statictexts status_display subtitlepoint subtitles taskboard terminals tv_screen waypoints 3dpanel.lua 3dtext.lua chatbox recognition.lua typing.lua admin_chat.lua displaychat.lua'.split()),
 ('Economy, inventory, skills, quests and crafting', '!!levelsystem !!skills basic_quests.lua citysystem construction customizable_items food inventoryaction.lua items_cooking items_crafting ixcraft keysystem loot magazines new_containers.lua quest_director radiationsystem rations recipe_unlock_notify recipes_cooking recipes_crafting skill_books subscription vehiclekeys vendor containers reagents stamina strength ammosave.lua'.split()),
 ('Core, permissions, UI and visual effects', '!!!anonymous !character admincontextinventory.lua ambientmusic antibunnyhop.lua autowalk.lua combine_hud.lua compass.lua dupe_protection.lua edictlimit.lua f1menu hidephase local_sound.lua object_descriptions.lua object_spawnmenu.lua observer_enhanced.lua properties radialmenu.lua screen_effects stormfox.lua transvil unionlight z_ending z_endingnotext z_intro zz_immersion zz_legends_interface zz_legends_visuals au_performance clientsideprops crosshair.lua logging.lua mapscene.lua observer.lua pac.lua permakill.lua realistic_visuals spawns.lua tempflags.lua visuals wepselect.lua'.split()),
]
family_for = {name:family for family,names in families for name in names}
family_for.update({'area':'Facility, power, hazards and world persistence',
                   'doors':'Facility, power, hazards and world persistence',
                   'bodygroupmanager':'Animation, models and character presentation',
                   'cassette_player':'Communications, screens, terminals and information',
                   'performance_monitor':'Administration, diagnostics and client presentation'})
# Keep baseline coverage tied to the saved inventory, even as implementation
# adds plugins. A fresh inventory can be generated for a separate later audit.
plugins = sorted({entry['group'] for entry in inventory['entries']
                  if entry['path'].startswith(('helix/plugins/','ixhl2rp/plugins/'))
                  and (entry['path'].endswith('/sh_plugin.lua') or entry['path'].count('/') == 2)})
plugin_set=set(plugins)
coverage=[]
for name,g in inventory['groups'].items():
    entries=[e for e in inventory['entries'] if e['group']==name]
    related=[f['id'] for f in findings if any(ref.rsplit(':',1)[0] in {e['path'] for e in entries} for ref in f['refs'])]
    if any('/_old/' in e['path'] for e in entries):
        status='Legacy source scanned; not loaded by the normal plugin directory loader'
        family='Legacy source (not a runtime bottleneck merely by existing)'
    elif name.startswith(('base/','sandbox/','terrortown/')):
        status='Base/other gamemode source scanned; runtime relevance depends on inheritance/use'
        family='Base dependencies and other gamemodes'
    else:
        status='Static inventory plus targeted semantic review of cited paths' if related else 'Static inventory/entry-point triage; no specific bottleneck established'
        family=family_for.get(name.split('/')[-1], 'Core/shared library or bundled dependency')
    coverage.append(dict(name=name,family=family,loadablePlugin=name in plugin_set,status=status,files=g['files'],lines=g['lines'],findings=related,
                         periodicCandidates=len(g['hotFunctions']),signals=g['signals'],paths=[e['path'] for e in entries],
                         followUp='Profile enabled hooks and representative usage; retain existing behavior unless a measured or source-confirmed improvement is demonstrated.'))

missing_plugins=plugin_set-{c['name'] for c in coverage}
unclassified=[x for x in plugins if x.split('/')[-1] not in family_for]
assert not missing_plugins, missing_plugins
assert not unclassified, unclassified
assert len({f['id'] for f in findings})==len(findings)
for f in findings:
    for ref in f['refs']:
        p,line=ref.rsplit(':',1)
        source=ROOT/p
        assert source.is_file(), ref
        assert 1<=int(line)<=len(source.read_text(encoding='utf-8-sig').splitlines()), ref

measurement = [
 'Capture actual Linux server CPU/model, game branch/tick interval, database adapter, enabled plugins, Workshop versions, entity/constraint/NPC counts and live cvar values. The local checkout cannot prove those.',
 'Use identical map locations/loadouts and increasing real player counts. Record quiet idle, simultaneous firing at walls, firing at targets, the same scene with bleeding casualties, and physical bullets on/off as separate tests.',
 'Record server frame-time percentiles and long spikes, per-thread CPU, Lua hook/function self and total time, database update count/latency, serialized/network bytes, choke/loss and outbound traffic. Averages alone can hide stalls.',
 'On clients record frame time/1% lows, resolution and GPU settings, visible actors/holsters, particle births, bone work, projected lights, render captures, HTML panels and memory. Separate CPU/Lua and GPU limits.',
 'Exercise radio/PTT/PA, CCTV/bodycams/TV/map, generators/doors, flood/infection/SCPs, drag/cart/wheelchair/bed/prone, crafting/trading/rewards and persistence. Compare cold/opening spikes and steady-state work.',
 'Run a long-session soak with reconnects, character changes, new/deleted entities and map cleanup; check growth in timers, callbacks, client models, emitters, HTML panels, pending requests and retained entity tables.',
 'Simulate or otherwise test controlled latency/jitter/stalls in a staging environment. Verify request deduplication, cancellations, UI recovery, weapon selection and permission revocation; avoid uncontrolled live disruption.',
 'A/B one change family at a time against the same baseline. Keep each patch reversible and run meaningful existing tests plus live regression scenarios. Mocked tests do not measure real engine performance.',
]
constraints=[
 'Scope: every loadable Helix/schema plugin, single-file plugin, core/shared library, scripted entity/weapon, inventory/character/persistence path, bundled addon and its cross-system interactions.',
 'All Lua files in the six inventory roots were read and normalized-parsed. This is exhaustive structural coverage, not a claim that every line had a complete semantic review or that every runtime path was executed.',
 'Priorities are provisional. Source-confirmed repeated work is different from measured live cost; no FPS gain or player capacity is promised.',
 'No gamemode runtime files, installed game copy, Workshop content, server settings or remote deployment were changed by this audit.',
 'External Workshop implementations, Linux native modules, map visibility/physics and server configuration remain runtime/dependency audit items. ARC9 had a targeted inspection, not an exhaustive audit of every installed addon.',
 'Optimize without losing gameplay, persistence, authorization, established animation compatibility or medical behavior. Changes to ballistics, visual quality or population caps require an explicit selected option.',
]
comparison_path=OUT/'local-copy-comparison.json'
comparison=json.loads(comparison_path.read_text(encoding='utf-8')) if comparison_path.exists() else None
report=dict(generatedAt=inventory['generatedAt'],scope=constraints,files=inventory['files'],lines=inventory['lines'],loadablePlugins=len(plugins),
            pluginCounts=dict(collections.Counter(p.split('/')[0] for p in plugins)),findings=findings,coverage=coverage,measurementPlan=measurement,localCopy= comparison)
implementation_path=OUT/'implementation.json'
implementation=json.loads(implementation_path.read_text(encoding='utf-8')) if implementation_path.exists() else None
report['implementation']=implementation
(OUT/'review.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
e=html.escape
cards=[]
for f in findings:
    refs=''.join(f'<li><code>{e(r)}</code></li>' for r in f['refs'])
    state=(implementation or {}).get('findings',{}).get(f['id'])
    progress=f"<p class='notice'><strong>{e(state['status'])}:</strong> {e(state['detail'])}</p>" if state else ''
    cards.append(f'''<article class="finding" data-search="{e((f['title']+' '+f['domain']+' '+f['evidence']).lower())}" data-priority="{f['priority']}">
    <div class="meta">{f['id']} · {f['priority']} · {e(f['domain'])}</div><h3>{e(f['title'])}</h3>
    {progress}<p class="confidence">{e(f['confidence'])}</p><p>{e(f['evidence'])}</p>
    <p><strong>Change:</strong> {e(f['change'])}</p><p><strong>Preserve / verify:</strong> {e(f['guard'])}</p>
    <details><summary>Baseline source locations (lines may shift after implementation)</summary><ul>{refs}</ul></details></article>''')
rows=[]
for c in coverage:
    paths=''.join(f'<li><code>{e(p)}</code></li>' for p in c['paths'])
    signals=', '.join(f'{k}: {v}' for k,v in c['signals'].items()) or 'No selected lexical signals'
    rows.append(f'''<tr class="coverage" data-search="{e((c['name']+' '+c['family']+' '+' '.join(c['findings'])).lower())}"><td><code>{e(c['name'])}</code><div class="muted">{e(c['family'])}</div></td>
    <td>{c['files']} / {c['lines']:,}</td><td>{e(c['status'])}<div><b>{', '.join(c['findings']) or 'No isolated finding'}</b></div>
    <details><summary>Inventory and review scope</summary><p>{e(signals)}</p><p>{e(c['followUp'])}</p><ul>{paths}</ul></details></td></tr>''')
html_doc='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>HL2RP full-scope performance audit</title><style>
:root{color-scheme:dark;font-family:system-ui,sans-serif;background:#10151c;color:#e4eaf1}body{max-width:1160px;margin:auto;padding:36px 24px;line-height:1.6}h1,h2,h3{line-height:1.25}h1{font-size:36px}h2{margin-top:42px}h3{font-size:20px}a{color:#84c9ff}.muted,.confidence{color:#a9b9ca}.confidence{font-size:13px}.metrics{display:flex;gap:16px;flex-wrap:wrap}.metric,.finding{background:#19222d;border:1px solid #354357;border-radius:10px;padding:20px}.metric b{display:block;font-size:28px}.metric{flex:1;min-width:140px}.finding{margin:16px 0}.meta{color:#91d9c4;font-size:13px;font-weight:700}input,select{font:inherit;padding:10px;background:#19222d;color:inherit;border:1px solid #516177;border-radius:6px}input{width:min(650px,85%)}table{width:100%;border-collapse:collapse}th,td{text-align:left;vertical-align:top;padding:14px 10px;border-bottom:1px solid #354357}code{overflow-wrap:anywhere;font-size:12px}summary{cursor:pointer;color:#9acbff}li{margin:6px 0}.notice{border-left:4px solid #e5ba6b;padding:12px 18px;background:#25251f}nav{display:flex;gap:20px;margin:24px 0;flex-wrap:wrap}.hidden{display:none}@media(max-width:700px){body{padding:20px 12px}th,td{padding:10px 5px;font-size:13px}}
</style><body><div class="meta">BASELINE SOURCE AUDIT · 17 OCTOBER 2026</div><h1>Whole-gamemode performance review</h1>
IMPLEMENTATION
<p>Coverage includes every loadable plugin in this checkout, core systems, scripted entities and bundled dependencies. Findings below separate repeated source work from cases requiring live measurement.</p>
<div class="metrics">METRICS</div><nav><a href="#findings">Findings</a><a href="#coverage">Every plugin / source group</a><a href="#measure">Measurement plan</a><a href="#options">Options</a></nav>
<div class="notice"><strong>Coverage is not a benchmark.</strong> Every Lua file was structurally scanned. Targeted semantic review is identified per source group; neither that nor a syntax pass proves runtime correctness or a measured performance gain. Remote Linux settings and enabled plugins have not been verified.</div>
<h2>Scope and boundaries</h2><ul>CONSTRAINTS</ul><p>LOCALCOPY</p>
<h2 id="findings">Prioritized findings</h2><p>“First” means an early investigation/fix candidate, not a measured ranking of CPU or GPU cost.</p>
<input id="searchFindings" aria-label="Search findings" placeholder="Search findings: blood, voice, database, power…"> <select id="priority" aria-label="Priority"><option>All priorities</option><option>First</option><option>Next</option><option>Measure</option><option>Optional</option></select><p id="findingCount" class="muted"></p>FINDINGS
<h2 id="coverage">Coverage ledger</h2><p>All 185 loadable plugins are present. Additional rows cover core, schema, entities, bundled addons, legacy code and base/other gamemodes. “No isolated finding” is not a performance certification. Signal counts are lexical candidates and may include comments or overlapping nested functions.</p>
<input id="searchCoverage" aria-label="Search coverage" placeholder="Find a plugin or system…"><p id="coverageCount" class="muted"></p><table><thead><tr><th>Source group / system family</th><th>Files / lines</th><th>Review status</th></tr></thead><tbody>ROWS</tbody></table>
<h2 id="measure">Live measurement and regression plan</h2><ol>MEASURE</ol>
<h2 id="options">Implementation choices</h2><ol><li><strong>Preserve features:</strong> change-only writes and synchronization, active registries, cached discovery, correct scheduling, request deduplication and error fixes.</li><li><strong>Balanced, recommended:</strong> the first option plus frame-independent particles and measured distance/visibility budgets for secondary weapon models, bone work, lighting and screens.</li><li><strong>Large-session preset:</strong> explicit optional reductions to ordinary bullet physics, remote effects, AI populations and physics loads. Verify gameplay tradeoffs before adopting.</li></ol>
<p>Implement in reversible batches: baseline → persistence/voice/network → bleeding/weapon/lighting rendering → zones/power/physics → remaining measured hotspots → latency/soak regression. Preserve already useful budgets instead of removing entire systems.</p>
<h2>References and reproduction</h2><p>Client entity scheduling: <a href="https://wiki.facepunch.com/gmod/Entity:NextThink">NextThink</a> and <a href="https://wiki.facepunch.com/gmod/Entity:SetNextClientThink">SetNextClientThink</a>. Their distinction supports F19. Performance and workload findings otherwise cite the local sources.</p>
<p>Regenerate with <code>node tools/performance-inventory.cjs</code> then <code>python tools/performance-report.py</code> from the repository. <a href="inventory.json">Full per-file inventory and SHA-256</a> · <a href="review.json">Structured review</a> · <a href="local-copy-comparison.json">Local installed-copy comparison</a>.</p>
<script>
function filterFindings(){const q=document.getElementById('searchFindings').value.toLowerCase(),p=document.getElementById('priority').value;let n=0;for(const row of document.querySelectorAll('.finding')){const show=row.dataset.search.includes(q)&&(p==='All priorities'||row.dataset.priority===p);row.classList.toggle('hidden',!show);if(show)n++}document.getElementById('findingCount').textContent=n+' findings shown'}
function filterCoverage(){const q=document.getElementById('searchCoverage').value.toLowerCase();let n=0;for(const row of document.querySelectorAll('.coverage')){const show=row.dataset.search.includes(q);row.classList.toggle('hidden',!show);if(show)n++}document.getElementById('coverageCount').textContent=n+' source groups shown'}
document.getElementById('searchFindings').addEventListener('input',filterFindings);document.getElementById('priority').addEventListener('change',filterFindings);document.getElementById('searchCoverage').addEventListener('input',filterCoverage);filterFindings();filterCoverage();
</script></body></html>'''
metrics=''.join(f'<div class="metric"><b>{n:,}</b>{label}</div>' for n,label in [(inventory['files'],'Lua files scanned'),(inventory['lines'],'source lines'),(len(plugins),'loadable plugins'),(len(findings),'findings / options')])
local_text='Local copy was not compared.'
if comparison:
    local_text=f"Local game copy: {comparison['same']:,} active-tree Lua files match; {len(comparison['different'])} differ; {len(comparison['missing'])} are missing. The differing files are the intro and ending slides. They were preserved. This is not a comparison with the remote server."
for key,value in dict(METRICS=metrics,CONSTRAINTS=''.join('<li>'+e(x)+'</li>' for x in constraints),LOCALCOPY=e(local_text),FINDINGS=''.join(cards),ROWS=''.join(rows),MEASURE=''.join('<li>'+e(x)+'</li>' for x in measurement)).items():
    html_doc=html_doc.replace(key,value)
progress_html=''
if implementation:
    prefix=implementation.get('artifactPrefix') or ('overall' if implementation.get('batch',1)>1 else 'batch1')
    progress_html=f"<div class='notice'><strong>Implementation update — {e(implementation['updated'])}</strong><p>{e(implementation['summary'])}</p><p><a href='{prefix}.md'>Changes and capture commands</a> · <a href='{prefix}-regression-tests.log' >Test results</a> · <a href='{prefix}-delivery.json'>Local deployment verification</a> · <a href='optimization-{prefix}-gamemodes.zip'>Cumulative server patch archive</a></p><p>The counts and source evidence below describe the original audit snapshot. Applied changes and retained paths are marked on every finding. The current rescan and per-system coverage are linked in the change notes.</p></div>"
html_doc=html_doc.replace('IMPLEMENTATION',progress_html)
(OUT/'report.html').write_text(html_doc,encoding='utf-8')
print(json.dumps({'findings':len(findings),'coverageGroups':len(coverage),'loadablePlugins':len(plugins),'unclassifiedPlugins':unclassified,'sourceReferences':'all paths and line bounds verified','report':str(OUT/'report.html')},indent=2))
