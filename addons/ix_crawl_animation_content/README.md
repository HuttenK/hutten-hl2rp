# HL2RP Cellar + Prone animation bridge

Standalone Prone Mod runtime and original animation data by George
"Stalker" Petrou and the upstream contributors (Stiffy360 animations,
port to HL2 by Stalker). This is a local server deployment copy, not original
HL2RP animation work or a new Workshop publication.

Source: https://github.com/gspetrou/Prone-Mod
Commit: 1aef0e70ee49ddfdaa323157ae5136fb58bf5598
Workshop: https://steamcommunity.com/sharedfiles/filedetails/?id=1100368137

The shared MDL include tables are modified to also include Cellar animations.
Original bones, sequence data and compressed animation blocks are preserved.
Cellar dependencies use models/ix_cellar/ paths to isolate them from other
installed Cellar versions. No character meshes, textures or skins are replaced.

Cellar sources: installed IX Extended Animations (Workshop 1773817848), and
the Combine library from Legends | Essential Materials (3743836507).
See cellar-sources.json for original asset hashes and attribution. This local
integration is not a new public Workshop release.

Install this directory under garrysmod/addons on BOTH server and every client,
replacing the previous ix_crawl_animation_content folder. Restart both fully.
The original Prone Workshop item alone does not contain these modified files.
Do not mount another standalone Prone/wOS/base-animation replacement over
this bridge. Large content packs can be retained, but conflicting shared MDLs
must resolve to this combined addon. Use ix_cellar_status / ix_cellar_status_cl
to verify the server and client both see the Cellar sequences.

Known stock families: male/female citizens and rebels (humans and player
Group variants), NPC-style Metropolice and Combine soldiers. Other models
which include the patched libraries gain sequences, but their animation class
is not forcibly changed. Nonhuman skeletons are not supported by this bridge.

Build: node tools/build-cellar-bridge.cjs WORKSHOP_ROOT ORIGINAL_PRONE_ROOT OUTPUT_ADDON
Requires the original two installed Workshop archives and original Prone files.
Offline checks verify include graphs, ANI ranges, crawl sequences and class
selection. Engine playback and multiplayer appearance still need in-game checks.
