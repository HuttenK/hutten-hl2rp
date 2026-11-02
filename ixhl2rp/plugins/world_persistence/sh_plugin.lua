PLUGIN.name = "World Entity Persistence"
PLUGIN.author = "Hutten"
PLUGIN.description = "Automatic map saves for placed equipment without its own storage system."

-- Stateful equipment (carts, CCTV, facility devices, etc.) keeps its own
-- serializer. Register only independent fixtures here to avoid double spawns.
PLUGIN.classes = {ix_garbage = true}
ix.util.Include("sv_store.lua")
