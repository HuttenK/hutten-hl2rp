ENT.Type       = "anim"
ENT.PrintName  = "Накопительный бак"
ENT.Category   = "HL2 RP"
ENT.Spawnable  = true
ENT.AdminOnly  = true
ENT.Model      = Model("models/props_c3/barrels/barrel_a.mdl")
ENT.bNoPersist = true
ENT.Holdable   = true -- можно носить руками (ix_hands)

-- Действия через меню (TAB → ПКМ, либо E по пропу), т.к. GetEntityMenu отключает ENT:Use.

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

		-- Физика включена: бак можно толкать/перетаскивать.
		local phys = self:GetPhysicsObject()
		if (IsValid(phys)) then
			phys:EnableMotion(true)
			phys:Wake()
		end

		self:SetNetVar("linked", false)
	end

	-- Меню: соединить кабелем с ближайшим свободным насосом в пределах длины кабеля.
	function ENT:OnSelectConnect(client)
		if (!IsValid(client) or !client:Alive() or !client:GetCharacter()) then return end

		local plugin = ix.plugin.list["flood"]
		if (!plugin) then return end

		if (IsValid(self.linkedPump)) then
			client:Notify("К баку уже подключён насос.")
			return
		end

		local best, bestDist
		for _, pump in ipairs(ents.FindByClass("ix_flood_pump")) do
			if (IsValid(pump) and !IsValid(pump.linkedTank)) then
				local d = self:GetPos():Distance(pump:GetPos())
				if (d <= plugin.defaults.maxCableLength and (!bestDist or d < bestDist)) then
					best, bestDist = pump, d
				end
			end
		end

		if (!IsValid(best)) then
			client:Notify("Рядом нет свободного насоса (в пределах " .. plugin.defaults.maxCableLength .. " юнитов). Поставьте насос ближе.")
			return
		end

		plugin:LinkPumpTank(best, self)
		plugin:SaveData()

		client:EmitSound("physics/metal/metal_box_impact_hard" .. math.random(1, 3) .. ".wav", 65)
		client:Notify("Бак соединён с насосом кабелем.")
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

		if (p and p.UnlinkPump and IsValid(self.linkedPump)) then
			p:UnlinkPump(self.linkedPump)
		end

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

		if (!self:GetNetVar("linked", false)) then
			options["Соединить кабелем с насосом"] = function()
				ix.menu.NetworkChoice(self, "Connect")
			end
		end

		local owner = self:GetNetVar("owner")
		local char  = client:GetCharacter()

		if (client:IsAdmin() or (char and owner and owner == char:GetID())) then
			options["Поднять бак"] = function()
				ix.menu.NetworkChoice(self, "PickUp")
			end
		end

		return options
	end
end
