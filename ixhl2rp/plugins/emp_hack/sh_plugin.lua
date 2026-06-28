local PLUGIN = PLUGIN

PLUGIN.name = "ЭМИ-взлом"
PLUGIN.author = "Claude"
PLUGIN.description = "ЭМИ-инструмент: временно отключает комбайновские замки, силовые поля, сканеры контрабанды и обезвреживает мины."

-- На сколько секунд цель «вырубается» (потом восстанавливается сама).
PLUGIN.disableTime = 30

if (SERVER) then
	ix.util.Include("sv_plugin.lua")
end
