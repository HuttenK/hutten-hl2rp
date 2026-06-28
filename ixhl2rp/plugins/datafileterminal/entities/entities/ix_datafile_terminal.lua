ENT.Type        = "anim"
ENT.PrintName   = "Datafile Terminal"
ENT.Category    = "HL2 RP"
ENT.Spawnable   = true
ENT.AdminOnly   = true
ENT.Model       = Model("models/hls/alyxports/monitor_medium.mdl")
ENT.bNoPersist  = true

if SERVER then
	function ENT:SpawnFunction(client, trace, class)
		if !trace.Hit then return end

		local entity = ents.Create(class)
		entity:SetPos(trace.HitPos + trace.HitNormal * 2)

		local yaw = (client:GetPos() - trace.HitPos):Angle().y + 180
		entity:SetAngles(Angle(0, yaw, 0))
		entity:Spawn()

		local p = ix.plugin.list["datafileterminal"]
		if p then p:SaveData() end

		return entity
	end

	function ENT:Initialize()
		self:SetModel(self.Model)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableMotion(false)
		end
	end

	function ENT:Use(activator, caller)
		if !IsValid(activator) or !activator:IsPlayer() then return end
		if (activator.ixNextDfTerminal or 0) > CurTime() then return end
		activator.ixNextDfTerminal = CurTime() + 0.6

		local p = ix.plugin.list["datafileterminal"]
		if p then
			p:OpenBrowser(activator, self)
		end
	end

	function ENT:OnRemove()
		timer.Simple(0, function()
			local p = ix.plugin.list["datafileterminal"]
			if p then p:SaveData() end
		end)
	end
else
	function ENT:Initialize()
		self.nextPrompt = 0
	end

	function ENT:Draw()
		self:DrawModel()
	end

	-- Небольшая подсказка "[E] Просмотр досье" при взгляде вблизи
	function ENT:Think()
		self:SetNextClientThink(CurTime() + 0.1)
		return true
	end
end

-- Подсказка при наведении (через HUD)
if CLIENT then
	hook.Add("HUDPaint", "ixDatafileTerminalPrompt", function()
		local ply = LocalPlayer()
		if !IsValid(ply) or !ply:Alive() then return end

		local tr = ply:GetEyeTrace()
		local ent = tr.Entity

		if !IsValid(ent) or ent:GetClass() != "ix_datafile_terminal" then return end
		if ply:GetPos():DistToSqr(ent:GetPos()) > (140 * 140) then return end

		draw.SimpleTextOutlined("[E] Просмотр базы досье", "ixGenericFont",
			ScrW() * 0.5, ScrH() * 0.62, Color(220, 220, 220),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 220))
	end)
end
