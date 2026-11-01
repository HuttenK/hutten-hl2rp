-- Models scriptedpanels.lua/baseclass.lua registration semantics, including
-- baseclass.Set's in-place merge. No engine process or installed files are used.
local classes, bases = {}, {}
local function merge(destination, source)
	for key, value in pairs(source) do destination[key] = value end
end
vgui = {}
function vgui.Register(name, panel, base)
	panel.Base = base or "Panel"
	classes[name] = panel
	if bases[name] then merge(bases[name], panel) else bases[name] = panel end
end
function vgui.GetControlTable(name) return classes[name] end
function assertAcyclic(name)
	local seen = {}
	while classes[name] do
		assert(not seen[name], "Recursive panel base: " .. name)
		seen[name] = true
		name = classes[name].Base
	end
end
ix.Civic = {Scale = function(n) return n end, colors = {}}
