ENT.Type        = "anim"
ENT.PrintName   = "ГО News Terminal (Editor)"
ENT.Category    = "HL2 RP"
ENT.Spawnable   = true
ENT.AdminOnly   = true
ENT.Model       = Model("models/props/cs_office/TV_plasma.mdl")
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.bNoPersist  = true

local SCALE       = 0.0933
local PANEL_W     = 600
local OFF_UP      = 35.2
local OFF_FORWARD = 6.1
local DRAW_DIST2  = 160000

if SERVER then
	function ENT:SpawnFunction(client, trace, class)
		if !trace.Hit then return end
		local entity = ents.Create(class)
		entity:SetPos(trace.HitPos + trace.HitNormal * 2)
		entity:SetAngles(Angle(0, (client:GetPos() - trace.HitPos):Angle().y + 180, 0))
		entity:Spawn()

		local p = ix.plugin.list["gonews"]
		if p and p.SaveData then p:SaveData() end
		return entity
	end

	function ENT:Initialize()
		self:SetModel(self.Model)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then phys:EnableMotion(false) end
	end

	function ENT:Use(activator)
		if !IsValid(activator) or !activator:IsPlayer() then return end
		if (activator.ixNextNewsEditor or 0) > CurTime() then return end
		activator.ixNextNewsEditor = CurTime() + 0.6

		local p = ix.plugin.list["gonews"]
		if !p or !p.CanManage then return end

		if !p.CanManage(activator) then
			activator:Notify("Доступ к редактору новостей только у Гражданской Обороны и администрации.")
			return
		end

		net.Start("gonews.openeditor")
		net.Send(activator)
	end

	function ENT:OnRemove()
		timer.Simple(0, function()
			local p = ix.plugin.list["gonews"]
			if p and p.SaveData then p:SaveData() end
		end)
	end
else
	local C = {
		bg   = Color(8, 12, 15, 255),
		panel= Color(14, 20, 24, 255),
		line = Color(0, 170, 210),
		lineD= Color(0, 90, 115),
		text = Color(196, 214, 220),
		dim  = Color(110, 140, 150),
	}

	function ENT:Initialize()
		self:SetSolid(SOLID_VPHYSICS)
	end

	-- Простой баннер без VGUI/обёртки (не трогает общий ввод 3D2D)
	function ENT:DrawScreen()
		local up      = self:GetUp()
		local right   = self:GetRight()
		local forward = self:GetForward()

		local drawAng = self:GetAngles()
		drawAng:RotateAroundAxis(up, 90)
		drawAng:RotateAroundAxis(right, -90)

		local worldW = PANEL_W * SCALE
		local drawPos = self:GetPos()
		drawPos:Add(right * (worldW * 0.5) + up * OFF_UP + forward * OFF_FORWARD)

		local W, H = 600, 360

		local ok = pcall(function()
			cam.Start3D2D(drawPos, drawAng, SCALE)
				surface.SetDrawColor(C.bg);    surface.DrawRect(0, 0, W, H)
				surface.SetDrawColor(0, 0, 0, 24)
				for y = 0, H, 3 do surface.DrawRect(0, y, W, 1) end

				surface.SetDrawColor(C.panel); surface.DrawRect(0, 0, W, 40)
				surface.SetDrawColor(C.line);  surface.DrawRect(0, 40, W, 2)
				surface.SetDrawColor(C.lineD); surface.DrawOutlinedRect(0, 0, W, H)

				draw.SimpleText("ГРАЖДАНСКАЯ ОБОРОНА", "ixNewsHead", 16, 10, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				draw.SimpleText("РЕДАКТОР НОВОСТНЫХ СВОДОК", "ixNewsTitle", W * 0.5, H * 0.42, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText("[ E ] — ОТКРЫТЬ РЕДАКТОР", "ixNewsItem", W * 0.5, H * 0.58, C.line, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText("ДОСТУП: ГО / АДМИНИСТРАЦИЯ", "ixNewsSmall", W * 0.5, H * 0.7, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			cam.End3D2D()
		end)

		if !ok then pcall(cam.End3D2D) end
	end

	function ENT:Draw()
		self:DrawModel()
		if EyePos():DistToSqr(self:GetPos()) < DRAW_DIST2 then
			self:DrawScreen()
		end
	end
end
