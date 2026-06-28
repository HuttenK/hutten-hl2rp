-- ix_boombox/cl_init.lua  --  client-side entity code
local PLUGIN = PLUGIN

include("shared.lua")

function ENT:GetEntityMenu(client)
	local options  = {}
	local cassette = self:GetNetVar("boombox_cassette", "")

	if cassette != "" then
		options["Вынуть кассету (" .. cassette .. ")"] = function()
			ix.menu.NetworkChoice(self, "EjectCassette")
		end
	else
		local items = client:GetItems()
		for _, item in ipairs(items) do
			if item.isCassette then
				local customName = item:GetData("customName", "")
				local name = (customName != "" and customName) or (L and L(item.name)) or item.name or "Кассета"
				local label = name .. "  [" .. item.id .. "]"
				local capturedID = item.id
				options[label] = function()
					ix.menu.NetworkChoice(self, "InsertCassette", capturedID)
				end
			end
		end
	end

	options["Поднять плеер"] = function()
		ix.menu.NetworkChoice(self, "PickUp")
	end

	return options
end

function ENT:Draw()
	self:DrawModel()
end
