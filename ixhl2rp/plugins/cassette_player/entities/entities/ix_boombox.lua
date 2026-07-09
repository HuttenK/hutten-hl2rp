-- ix_boombox.lua
-- ВНИМАНИЕ: этот файл существует потому что GMod не даёт его удалить.
-- Он дублирует содержимое папки ix_boombox/ чтобы не затирать регистрацию сущности.
-- Настоящий источник: entities/entities/ix_boombox/ (shared/init/cl_init).

-- ===== SHARED =====
-- ix_boombox/shared.lua  --  entity properties
ENT.Type       = "anim"
ENT.PrintName  = "Кассетный плеер"
ENT.Author     = "Hutten"
ENT.Spawnable  = false
ENT.bNoPersist            = true
ENT.ShowPlayerInteraction = true  -- E-hold pickup progress bar
ENT.Holdable              = true  -- allow ix_hands RMB grab

-- ===== SERVER =====
if SERVER then
-- ix_boombox/init.lua  --  server-side entity code
local PLUGIN = PLUGIN
function ENT:Initialize()
	self:SetModel("models/props_generic/bm_batteryradio01.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:Wake()
		phys:EnableMotion(true)
		phys:SetMass(5)  -- keep under maxHoldWeight so ix_hands can grab it
	end
	self:SetNetVar("boombox_cassette", "")
	self:SetNetVar("boombox_sound",    "")
	self:SetNetVar("boombox_stime",    0)
end

function ENT:Use(activator, caller)
	if !IsValid(caller) or !caller:IsPlayer() or !caller:GetCharacter() then return end
	caller:PerformInteraction(ix.config.Get("itemPickupTime", 0.5), self, function(client)
		self:OnSelectPickUp(client)
	end)
end


function ENT:OnRemove()
	if self.bPickedUp then return end
	local pos = self:GetPos()
	if self.cassetteInstanceID then
		local item = ix.Item.instances[self.cassetteInstanceID]
		if item then ix.Item:Spawn(pos + Vector(0, 0, 5), Angle(0, 0, 0), item) end
	end
	if self.boomboxItemID then
		local item = ix.Item.instances[self.boomboxItemID]
		if item then ix.Item:Spawn(pos + Vector(0, 0, 10), Angle(0, 0, 0), item) end
	end
end

function ENT:OnSelectInsertCassette(client, data)
	local instanceID = tonumber(data)
	if not instanceID then return end
	if (self.nextUse or 0) > CurTime() then return end
	self.nextUse = CurTime() + 0.5
	if self.cassetteInstanceID then
		client:Notify("В плеере уже есть кассета.")
		return
	end
	local item = ix.Item.instances[instanceID]
	if not item or not item.isCassette then
		client:Notify("Это не кассета.")
		return
	end
	local inv = client:GetInventory("main")
	if not inv then return end
	if not inv:HasItemByID(instanceID) then
		client:Notify("У вас нет этой кассеты.")
		return
	end
	inv:TakeItemByID(instanceID)
	inv:Sync()
	-- Поддержка пустых кассет: кастомный трек и название хранятся как item data.
	local customTrack  = item:GetData("track", "")
	local trackPath    = (customTrack != "" and customTrack) or item.track or ""
	local customName   = item:GetData("customName", "")
	local cassetteName = (customName != "" and customName) or (L and L(item.name, client)) or item.name or "Кассета"
	self.cassetteInstanceID = instanceID
	self:SetNetVar("boombox_cassette", cassetteName)
	self:SetNetVar("boombox_sound",    trackPath)
	self:SetNetVar("boombox_stime",    CurTime())
	self:EmitSound("buttons/button14.wav", 70, 100)
	client:Notify("Вставлена: " .. cassetteName)
end

function ENT:OnSelectEjectCassette(client)
	if (self.nextUse or 0) > CurTime() then return end
	self.nextUse = CurTime() + 0.5
	local cassetteID = self.cassetteInstanceID
	if not cassetteID then
		client:Notify("В плеере нет кассеты.")
		return
	end
	local item = ix.Item.instances[cassetteID]
	self.cassetteInstanceID = nil
	self:SetNetVar("boombox_cassette", "")
	self:SetNetVar("boombox_sound",    "")
	self:SetNetVar("boombox_stime",    0)
	self:EmitSound("buttons/button10.wav", 70, 100)
	if not item then return end
	local inv = client:GetInventory("main")
	if inv and inv:AddItemByID(cassetteID) then
		inv:Sync()
		client:Notify("Кассета извлечена.")
	else
		ix.Item:Spawn(client:GetPos() + Vector(0, 0, 10), Angle(0, 0, 0), item)
		if inv then inv:Sync() end
		client:Notify("Инвентарь полон — кассета упала рядом.")
	end
end

function ENT:OnSelectPickUp(client)
	if (self.nextUse or 0) > CurTime() then return end
	self.nextUse = CurTime() + 0.5
	local inv = client:GetInventory("main")
	if not inv then return end

	-- Вернуть кассету игроку ДО удаления сущности. Не вызываем OnSelectEjectCassette:
	-- он отбрасывается собственным дебаунсом nextUse (мы только что его выставили),
	-- из-за чего кассета терялась при поднятии плеера.
	if self.cassetteInstanceID then
		local cassette = ix.Item.instances[self.cassetteInstanceID]
		if cassette then
			if not inv:AddItemByID(self.cassetteInstanceID) then
				-- Инвентарь полон — роняем кассету рядом, чтобы её не потерять.
				ix.Item:Spawn(self:GetPos() + Vector(0, 0, 10), Angle(0, 0, 0), cassette)
			end
		end
		self.cassetteInstanceID = nil
		self:SetNetVar("boombox_cassette", "")
		self:SetNetVar("boombox_sound",    "")
		self:SetNetVar("boombox_stime",    0)
	end
	local placed = false
	local boomboxID = self.boomboxItemID
	if boomboxID and ix.Item.instances[boomboxID] then
		if inv:AddItemByID(boomboxID) then placed = true end
	end
	if not placed then inv:GiveItem("item_boombox") end
	inv:Sync()
	client:Notify("Плеер поднят.")
	self.bPickedUp = true
	self:Remove()
end
end

-- ===== CLIENT =====
if CLIENT then
-- ix_boombox/cl_init.lua  --  client-side entity code
local PLUGIN = PLUGIN

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
end
