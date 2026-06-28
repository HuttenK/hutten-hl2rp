-- Гражданский терминал ОТКЛЮЧЁН по запросу.
-- Энтити оставлен инертным: не спавнится из Q-меню, не создаёт VGUI-панель и
-- не использует общую 3D2D-обёртку — поэтому НИКАК не влияет на лоялист-терминал.
-- Чтобы вернуть полноценный терминал обратно — восстанови прежнюю версию файла.

ENT.Type        = "anim"
ENT.PrintName   = "Civil Terminal (disabled)"
ENT.Category    = "HL2 RP"
ENT.Spawnable   = false
ENT.AdminOnly   = true
ENT.Model       = Model("models/props/cs_office/TV_plasma.mdl")
ENT.bNoPersist  = true

if SERVER then
	function ENT:Initialize()
		self:SetModel(self.Model)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableMotion(false)
		end
	end
else
	function ENT:Draw()
		self:DrawModel()
	end
end
