local PLUGIN = PLUGIN

PLUGIN.name        = "Screen Effects"
PLUGIN.description = "Набор пост-процессинговых и 2D-эффектов экрана. Каждый эффект включается отдельно и может ограничиваться произвольной областью экрана."
PLUGIN.author      = "custom"

if SERVER then
    util.AddNetworkString("ix.screeneffect.set")
    util.AddNetworkString("ix.screeneffect.flash")
    util.AddNetworkString("ix.screeneffect.reset")
end

ix.util.Include("sh_commands.lua")   -- команды (shared)
ix.util.Include("cl_init.lua")       -- клиентский рендеринг
ix.util.Include("derma/cl_panel.lua") -- UI панель
