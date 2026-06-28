local PLUGIN = PLUGIN

util.AddNetworkString("ixBlackoutSync")

PLUGIN.zones   = PLUGIN.zones   or {} -- [name] = { min = Vector, max = Vector, active = bool }
PLUGIN.staging = PLUGIN.staging or {} -- [client] = { corner1, corner2 }

-- Switchable / dynamic light entities we can actually control at runtime.
-- NOTE: baked (unnamed) lights are removed after map load and CANNOT be
-- toggled — those are covered by the client-side darkening layer instead.
local LIGHT_CLASSES = {
	["light"]                = true,
	["light_spot"]           = true,
	["light_dynamic"]        = true,
	["point_spotlight"]      = true,
	["env_projectedtexture"] = true,
	["env_lightglow"]        = true,
}

local function OrderBox(a, b)
	return Vector(math.min(a.x, b.x), math.min(a.y, b.y), math.min(a.z, b.z)),
	       Vector(math.max(a.x, b.x), math.max(a.y, b.y), math.max(a.z, b.z))
end

-- Turn switchable lights inside a zone off (bOn = false) or on (bOn = true).
function PLUGIN:SetZoneLights(zone, bOn)
	for _, e in ipairs(ents.FindInBox(zone.min, zone.max)) do
		if LIGHT_CLASSES[e:GetClass()] then
			e:Fire(bOn and "TurnOn" or "TurnOff")
		end
	end
end

-- Send the currently-active zone volumes to client(s) for screen darkening.
function PLUGIN:NetworkZones(receiver)
	local active = {}

	for _, z in pairs(self.zones) do
		if z.active then
			active[#active + 1] = z
		end
	end

	net.Start("ixBlackoutSync")
		net.WriteUInt(#active, 8)
		for _, z in ipairs(active) do
			net.WriteVector(z.min)
			net.WriteVector(z.max)
		end
	if IsValid(receiver) then
		net.Send(receiver)
	else
		net.Broadcast()
	end
end

function PLUGIN:SaveData()
	local out = {}

	for name, z in pairs(self.zones) do
		out[name] = { min = z.min, max = z.max, active = z.active }
	end

	ix.data.Set("blackout", out)
end

function PLUGIN:LoadData()
	self.zones = ix.data.Get("blackout") or {}

	-- Re-assert active blackouts once map entities exist (switchable lights
	-- spawn enabled by default after a map load).
	timer.Simple(1, function()
		for _, z in pairs(self.zones) do
			if z.active then
				self:SetZoneLights(z, false)
			end
		end

		self:NetworkZones()
	end)
end

-- Make sure late-joiners receive the active zones.
function PLUGIN:PlayerLoadedCharacter(client)
	timer.Simple(1, function()
		if IsValid(client) then
			self:NetworkZones(client)
		end
	end)
end

--
-- Command logic (called from the shared command layer; runs server-side only).
--

function PLUGIN:MarkCorner(client)
	local pos = client:GetEyeTrace().HitPos
	local s = self.staging[client] or {}

	if not s[1] then
		s[1] = pos
	else
		s[2] = pos
	end

	self.staging[client] = s

	if s[1] and s[2] then
		return "Both corners marked. Use /BlackoutCreate <name> [height]."
	end

	return "First corner marked. Look at the opposite corner and run this again."
end

function PLUGIN:CreateZone(client, name, height)
	local s = self.staging[client]

	if not (s and s[1] and s[2]) then
		return "Mark two corners first with /BlackoutCorner."
	end

	if self.zones[name] then
		return "A blackout zone named '" .. name .. "' already exists."
	end

	height = math.max(tonumber(height) or 512, 0)

	local mn, mx = OrderBox(s[1], s[2])
	mn = mn - Vector(0, 0, 32)     -- small floor margin
	mx = mx + Vector(0, 0, height) -- extend up to cover the building

	local zone = { min = mn, max = mx, active = true }
	self.zones[name] = zone
	self.staging[client] = nil

	self:SetZoneLights(zone, false)
	self:NetworkZones()
	self:SaveData()

	return "Blackout zone '" .. name .. "' created and activated."
end

function PLUGIN:ToggleZone(name)
	local zone = self.zones[name]

	if not zone then
		return "No blackout zone named '" .. name .. "'."
	end

	zone.active = not zone.active
	self:SetZoneLights(zone, not zone.active) -- active -> lights off
	self:NetworkZones()
	self:SaveData()

	return "Blackout zone '" .. name .. "' is now " .. (zone.active and "ON" or "OFF") .. "."
end

function PLUGIN:RemoveZone(name)
	local zone = self.zones[name]

	if not zone then
		return "No blackout zone named '" .. name .. "'."
	end

	self:SetZoneLights(zone, true) -- restore lights
	self.zones[name] = nil
	self:NetworkZones()
	self:SaveData()

	return "Blackout zone '" .. name .. "' removed."
end

function PLUGIN:ListZones(client)
	local any = false

	for name, z in pairs(self.zones) do
		any = true
		client:ChatPrint(string.format("%s — %s", name, z.active and "ON" or "OFF"))
	end

	if not any then
		return "No blackout zones defined."
	end
end

-- Clean up staging if an admin disconnects mid-selection.
function PLUGIN:PlayerDisconnected(client)
	self.staging[client] = nil
end
