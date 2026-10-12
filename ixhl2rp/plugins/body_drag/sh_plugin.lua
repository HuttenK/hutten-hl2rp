local PLUGIN = PLUGIN
PLUGIN.name = "One-handed body dragging"
PLUGIN.author = "Hutten"
PLUGIN.description = "Drag a living casualty with the left hand while keeping the weapon available."

if ix.BodyDrag and ix.BodyDrag.Shutdown then ix.BodyDrag.Shutdown() end
ix.BodyDrag = {}
ix.util.Include("sh_drag.lua")
ix.util.Include("sh_weapons.lua")
ix.util.Include("sv_drag.lua")
ix.util.Include("cl_arms.lua")
ix.util.Include("cl_drag.lua")

ix.command.Add("BodyRelease", {
    description = "Отпустить персонажа, которого вы тащите.",
    OnRun = function(_, client)
        if SERVER then ix.BodyDrag.Stop(client) end
    end
})
