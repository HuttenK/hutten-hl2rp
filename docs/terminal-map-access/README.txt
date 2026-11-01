Terminal-only map access

Merge the ixhl2rp folder into the existing garrysmod/gamemodes directory.
This archive contains two changed/new files, not a complete gamemode.
Restart the game/server and reconnect clients.

The standalone Dynamic 3D Map window is disabled through its Open entry point.
M, a remapped keyboard/mouse button, dm_map and the addon spawnmenu button
can no longer open it. An already open standalone window is closed when
the adapter installs. The authenticated terminal map, its renderer, controls
and settings remain available. No Workshop source files are modified.

23 targeted checks passed using the supplied addon source, which matches the
installed Workshop fullscreen source. Tests cover actual native keyboard and
command entry points, load order, reload, cleanup, terminal geometry and
height/label controls. Engine UI appearance has not been tested live.
