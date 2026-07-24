local PLUGIN = PLUGIN
AddCSLuaFile()

ENT.Type          = "anim"
ENT.PrintName     = "Blackout Fusebox"
ENT.Category      = "HL2 RP"
ENT.Spawnable     = false
ENT.AdminOnly     = true
ENT.PhysgunDisable = true
ENT.bNoPersist    = true

function ENT:SetupDataTables()
	-- Broken = THIS box is out of order (red light). A zone goes dark only when ALL
	-- of its boxes are broken, and powers back on only when ALL are repaired.
	self:NetworkVar("Bool", 0, "Broken")
end

if (SERVER) then
	function ENT:Initialize()
		self:SetModel("models/props_se/propper/power_box_2.mdl")
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		self.ixBlackoutFusebox = true
		self.nextUse = 0

		local phys = self:GetPhysicsObject()
		if (IsValid(phys)) then
			phys:EnableMotion(false)
			phys:Sleep()
		end

		-- Запускаем фоновый разряд: сам себя перепланирует и искрит, только пока
		-- щиток сломан (см. ScheduleIdleArc).
		self:ScheduleIdleArc()
	end

	-- Пока щиток выведен из строя, он периодически потрескивает: искра + электро-
	-- звук раз в ~1–2 минуты. Таймер перепланирует сам себя навсегда, а искрит лишь
	-- когда щиток сломан И его сейчас не чинят (у ремонта свои, частые искры).
	function ENT:ScheduleIdleArc()
		local id = "ixFuseboxIdle" .. self:EntIndex()

		timer.Create(id, math.Rand(60, 120), 1, function()
			if (!IsValid(self)) then return end

			if (self:GetBroken() and !self.ixRepairing) then
				local pos = self:LocalToWorld(self:OBBCenter()) + self:GetUp() * 4

				local ed = EffectData()
					ed:SetOrigin(pos)
					ed:SetNormal(self:GetForward())
					ed:SetMagnitude(3)
					ed:SetScale(2)
					ed:SetRadius(6)
				util.Effect("Sparks", ed)

				self:EmitSound("ambient/energy/zap" .. math.random(1, 3) .. ".wav", 72, math.random(90, 110))
			end

			self:ScheduleIdleArc() -- назначаем следующий разряд
		end)
	end

	-- Repeating spark burst while the box is being repaired.
	function ENT:StartSparks(duration)
		local id = "ixFuseboxSpark" .. self:EntIndex()

		timer.Create(id, 0.35, math.ceil((duration or 30) / 0.35), function()
			if (!IsValid(self)) then
				timer.Remove(id)
				return
			end

			local pos = self:LocalToWorld(self:OBBCenter()) + self:GetUp() * 4

			local ed = EffectData()
				ed:SetOrigin(pos)
				ed:SetNormal(self:GetForward())
				ed:SetMagnitude(2)
				ed:SetScale(1)
				ed:SetRadius(2)
			util.Effect("Sparks", ed)

			self:EmitSound("ambient/energy/spark" .. math.random(1, 6) .. ".wav", 65, math.random(90, 110))
		end)
	end

	function ENT:StopSparks()
		timer.Remove("ixFuseboxSpark" .. self:EntIndex())
	end

	function ENT:Use(client)
		if (self.nextUse > CurTime()) then return end
		self.nextUse = CurTime() + 1

		if (PLUGIN) then
			-- Сломанный щиток — чиним; рабочий — выводим из строя отвёрткой.
			if (self:GetBroken()) then
				PLUGIN:TryRepair(client, self)
			else
				PLUGIN:TryBreakScrewdriver(client, self)
			end
		end
	end

	function ENT:OnRemove()
		self:StopSparks()
		timer.Remove("ixFuseboxIdle" .. self:EntIndex())

		if (ix.shuttingDown) then return end

		if (PLUGIN and istable(PLUGIN.fuseboxes)) then
			table.RemoveByValue(PLUGIN.fuseboxes, self)
			PLUGIN:SaveFuseboxes()
		end
	end
else
	local glow = ix.util.GetMaterial("sprites/glow04_noz")
	local color_broken = Color(255, 40, 40)
	local color_fixed  = Color(40, 255, 40)

	function ENT:Draw()
		self:DrawModel()

		-- Приподнимаем индикатор над центром щитка и выносим вперёд, чтобы он не
		-- утопал в самой модели.
		local pos = self:LocalToWorld(self:OBBCenter()) + self:GetForward() * 22 + self:GetUp() * 14

		render.SetMaterial(glow)
		render.DrawSprite(pos, 8, 8, self:GetBroken() and color_broken or color_fixed)
	end
end
