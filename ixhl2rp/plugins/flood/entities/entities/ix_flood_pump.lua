ENT.Type        = "anim"
ENT.PrintName   = "Водяной насос"
ENT.Category    = "HL2 RP"
ENT.Spawnable   = true
ENT.AdminOnly   = true
ENT.Model       = Model("models/props_combine/combine_generator01.mdl")
ENT.bNoPersist  = true
ENT.Holdable    = true -- можно носить руками (ix_hands), как обычный физический предмет

-- Все действия идут через меню (TAB → ПКМ по пропу, либо E по пропу): наличие
-- GetEntityMenu отключает обычный ENT:Use (см. helix PlayerUse), поэтому кабель,
-- откачка и подъём — пункты меню.

function ENT:GetFloodZone()
	local pos = self:WorldSpaceCenter()
	local plugin = ix.plugin.list["flood"]

	for name, area in pairs(ix.area.stored or {}) do
		if (area.type == "flood") then
			-- Углы зоны могут прийти клиенту неотсортированными — нормализуем,
			-- иначе WithinAABox всегда false и насос «не видит» зону.
			local mins, maxs = plugin:GetAreaBounds(area)

			if (mins and pos:WithinAABox(mins, maxs)) then
				return name, area
			end
		end
	end
end

if (SERVER) then
	function ENT:SpawnFunction(client, trace, class)
		if (!trace.Hit) then return end

		local entity = ents.Create(class)
		entity:SetPos(trace.HitPos + trace.HitNormal * 4)
		entity:SetAngles(Angle(0, (client:GetPos() - trace.HitPos):Angle().y + 180, 0))
		entity:Spawn()

		local p = ix.plugin.list["flood"]
		if (p and p.SaveData) then p:SaveData() end

		return entity
	end

	function ENT:Initialize()
		self:SetModel(self.Model)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)

		-- Оставляем физику включённой: предмет можно толкать/перетаскивать.
		local phys = self:GetPhysicsObject()
		if (IsValid(phys)) then
			phys:EnableMotion(true)
			phys:Wake()
		end

		self:SetNetVar("linked", false)
	end

	-- Меню: соединить кабелем с ближайшим свободным баком в пределах длины кабеля.
	function ENT:OnSelectConnect(client)
		if (!IsValid(client) or !client:Alive() or !client:GetCharacter()) then return end

		local plugin = ix.plugin.list["flood"]
		if (!plugin) then return end

		if (IsValid(self.linkedTank)) then
			client:Notify("К насосу уже подключён бак.")
			return
		end

		local best, bestDist
		for _, tank in ipairs(ents.FindByClass("ix_flood_tank")) do
			if (IsValid(tank) and !IsValid(tank.linkedPump)) then
				local d = self:GetPos():Distance(tank:GetPos())
				if (d <= plugin.defaults.maxCableLength and (!bestDist or d < bestDist)) then
					best, bestDist = tank, d
				end
			end
		end

		if (!IsValid(best)) then
			client:Notify("Рядом нет свободного бака (в пределах " .. plugin.defaults.maxCableLength .. " юнитов). Поставьте бак ближе.")
			return
		end

		plugin:LinkPumpTank(self, best)
		plugin:SaveData()

		client:EmitSound("physics/metal/metal_box_impact_hard" .. math.random(1, 3) .. ".wav", 65)
		client:Notify("Насос соединён с баком кабелем.")
	end

	-- Меню: откачивать воду (если бак подключён).
	function ENT:OnSelectPump(client)
		if (!IsValid(client) or !client:Alive() or !client:GetCharacter()) then return end

		local plugin = ix.plugin.list["flood"]
		if (!plugin) then return end

		if (!IsValid(self.linkedTank)) then
			client:Notify("Сначала подключите бак кабелем.")
			return
		end

		-- Кулдаун по времени (а не «застревающий» флаг): если действие прервётся,
		-- насос всё равно разблокируется сам и не повиснет навсегда.
		if (client.ixPumpNext and CurTime() < client.ixPumpNext) then return end

		local name = self:GetFloodZone()

		if (!name) then
			client:Notify("Насос не находится в зоне затопления.")
			return
		end

		if (!plugin.level[name]) then
			client:Notify("Здесь нет воды для откачки.")
			return
		end

		client.ixPumpNext = CurTime() + plugin.defaults.pumpTime + 1
		self:EmitSound("ambient/water/water_spray1.wav", 70, math.random(95, 105))

		client:SetAction("Откачка воды...", plugin.defaults.pumpTime, function(ply)
			if (!IsValid(ply) or !ply:Alive()) then return end
			if (!IsValid(self) or !IsValid(self.linkedTank)) then return end

			if (ply:GetPos():DistToSqr(self:GetPos()) > 120 * 120) then
				ply:Notify("Вы отошли от насоса.")
				return
			end

			local zone = self:GetFloodZone()
			if (!zone) then return end

			local newLvl, drained = plugin:DrainStep(zone)

			if (!drained) then
				ply:Notify("Откачка... уровень воды Z=" .. math.Round(newLvl) .. ".")
			end
		end)
	end

	-- Меню: поднять (владелец/админ).
	function ENT:OnSelectPickUp(client)
		local p = ix.plugin.list["flood"]
		if (p and p:CanPickupDeployable(self, client)) then
			p:PickupDeployable(self, client)
		end
	end

	function ENT:OnRemove()
		local p = ix.plugin.list["flood"]
		if (p and p.UnlinkPump) then p:UnlinkPump(self) end
		if (p and p.DropDeployableItem) then p:DropDeployableItem(self) end

		timer.Simple(0, function()
			if (p and p.SaveData) then p:SaveData() end
		end)
	end
else
	function ENT:Draw()
		self:DrawModel()
	end

	function ENT:GetEntityMenu(client)
		local options = {}

		-- Откачка доступна всегда; если бак не подключён — сервер подскажет.
		options["Откачивать воду"] = function()
			ix.menu.NetworkChoice(self, "Pump")
		end

		if (!self:GetNetVar("linked", false)) then
			options["Соединить кабелем с баком"] = function()
				ix.menu.NetworkChoice(self, "Connect")
			end
		end

		local owner = self:GetNetVar("owner")
		local char  = client:GetCharacter()

		if (client:IsAdmin() or (char and owner and owner == char:GetID())) then
			options["Поднять насос"] = function()
				ix.menu.NetworkChoice(self, "PickUp")
			end
		end

		return options
	end
end
