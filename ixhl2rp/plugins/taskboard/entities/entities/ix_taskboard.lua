ENT.Type        = "anim"
ENT.PrintName   = "Доска объявлений"
ENT.Category    = "HL2 RP"
ENT.Spawnable   = true
ENT.AdminOnly   = true
ENT.Model       = Model("models/props/cs_office/TV_plasma.mdl")
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.bNoPersist  = true

-- Геометрия 3D2D-экрана подобрана под модель TV_plasma (как у ГО-терминала).
local PANEL_W, PANEL_H = 600, 360
local SCALE       = 0.0933
local OFF_UP      = 35.2
local OFF_FORWARD = 6.1
local DRAW_DIST2  = 160000
local USE_RANGE   = 100

if (SERVER) then
	function ENT:SpawnFunction(client, trace, class)
		if (!trace.Hit) then return end

		local entity = ents.Create(class)
		entity:SetPos(trace.HitPos + trace.HitNormal * 2)
		entity:SetAngles(Angle(0, (client:GetPos() - trace.HitPos):Angle().y + 180, 0))
		entity:Spawn()

		local p = ix.plugin.list["taskboard"]
		if (p and p.SaveData) then p:SaveData() end

		return entity
	end

	function ENT:Initialize()
		self:SetModel(self.Model)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)

		local phys = self:GetPhysicsObject()
		if (IsValid(phys)) then phys:EnableMotion(false) end
	end

	function ENT:OnRemove()
		timer.Simple(0, function()
			local p = ix.plugin.list["taskboard"]
			if (p and p.SaveData) then p:SaveData() end
		end)
	end
else
	function ENT:Initialize()
		self.m_bInitialized = true
		self:SetSolid(SOLID_VPHYSICS)
	end

	function ENT:Think()
		if (!self.m_bInitialized) then self:Initialize() end

		local bNear = EyePos():DistToSqr(self:GetPos()) < DRAW_DIST2

		if (bNear and !IsValid(self.panel)) then
			self.panel = vgui.Create("ixTaskBoardScreen")
			self.panel:ParentToHUD()
			-- КРИТИЧНО: без этого HUD-панель рисует себя в 2D-слое (левый верхний угол
			-- экрана) каждый кадр, пока существует — виден «призрак» экрана, когда игрок
			-- в радиусе активации, но не смотрит на терминал (ENT:Draw не вызывается, а
			-- авто-отрисовка HUD — вызывается). Ручная отрисовка оставляет только 3D2D.
			self.panel:SetPaintedManually(true)
			self.panel.entity = self

			self.panel.Origin = self:GetPos()
			self.panel.Angle  = self:GetAngles()
			self.panel.Normal = self:GetForward()
			self.panel.Scale  = SCALE
		elseif (IsValid(self.panel) and !bNear) then
			self.panel:Remove()
			self.panel = nil
		end

		self:NextThink(CurTime() + 0.5)
		return true
	end

	function ENT:DrawScreen()
		if (!IsValid(self.panel)) then return end

		local up      = self:GetUp()
		local right   = self:GetRight()
		local forward = self:GetForward()

		local drawAng = self:GetAngles()
		drawAng:RotateAroundAxis(up, 90)
		drawAng:RotateAroundAxis(right, -90)

		local worldW = PANEL_W * SCALE
		local drawPos = self:GetPos()
		drawPos:Add(right * (worldW * 0.5) + up * OFF_UP + forward * OFF_FORWARD)

		local mx, my = gui.MouseX, gui.MouseY

		local ok = pcall(function()
			vgui.Start3D2D(drawPos, drawAng, SCALE)
				vgui.MaxRange3D2D(USE_RANGE)
				self.panel:Paint3D2D()
			vgui.End3D2D()
		end)

		if (!ok) then pcall(cam.End3D2D) end

		gui.MouseX = mx
		gui.MouseY = my
	end

	-- Доска внутри активной зоны затемнения обесточена: экран не горит и не
	-- принимает клики (ввод обрабатывается внутри DrawScreen).
	local function IsBlackedOut(entity)
		local blackout = ix.plugin.list["blackout"]

		return blackout and blackout:IsEntityBlackedOut(entity) or false
	end

	function ENT:Draw()
		self:DrawModel()

		if (EyePos():DistToSqr(self:GetPos()) < DRAW_DIST2 and !IsBlackedOut(self)) then
			self:DrawScreen()
		end
	end

	function ENT:OnRemove()
		if (IsValid(self.panel)) then
			self.panel:Remove()
			self.panel = nil
		end
	end
end
