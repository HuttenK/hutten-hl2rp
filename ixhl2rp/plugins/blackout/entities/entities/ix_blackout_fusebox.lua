local PLUGIN = PLUGIN
AddCSLuaFile()

ENT.Type          = "anim"
ENT.RenderGroup   = RENDERGROUP_BOTH
ENT.PrintName     = "Blackout Fusebox"
ENT.Category      = "HL2 RP"
ENT.Spawnable     = false
ENT.AdminOnly     = true
ENT.PhysgunDisable = false
ENT.bNoPersist    = true

-- Bounds measured from the stock model in its idle sequence. Its shipped PHY
-- does not follow the animated root. Use a cabinet and a separate narrow post,
-- never a full-height box of invisible collision beside the post.
local parts = {
	{Vector(-2, -11.36, 42), Vector(5.61, 12.22, 66.94)},
	{Vector(-2, -2.53, 0), Vector(3.25, 2.83, 42)}
}
-- Door vertices expressed in proxy_box.door_cntrl space, including thickness.
-- Its idle bone frame is rotated relative to the entity's cabinet axes.
local doorBounds = {Vector(0.01, -12.88, -1.07), Vector(23.10, 12.06, 2.98)}
local traceMin, traceMax = Vector(-5, -38, 0), Vector(34, 15, 70)

function ENT:DoorPitch()
	return math.Approach(self:GetDoorPitchFrom(), self:GetDoorOpen() and -140 or 0,
		math.max(CurTime() - self:GetDoorMotionAt(), 0) * 220)
end

function ENT:DoorTransform()
	local pos, ang = LocalToWorld(Vector(5.4576, -10.8753, 54.8769), Angle(0, 90, 90), self:GetPos(), self:GetAngles())
	return LocalToWorld(vector_origin, Angle(self:DoorPitch(), 0, 0), pos, ang)
end
local function convex(mn, mx)
	local points = {}
	for _, x in ipairs({mn.x, mx.x}) do
		for _, y in ipairs({mn.y, mx.y}) do
			for _, z in ipairs({mn.z, mx.z}) do points[#points + 1] = Vector(x, y, z) end
		end
	end
	return points
end

function ENT:TestCollision(start, delta, isBox, extents)
	self.ixColliders = self.ixColliders or {}
	local best
	local function trace(i, bounds, origin, angles, part)
		local collider = self.ixColliders[i]
		if (!collider) then collider = CreatePhysCollideBox(bounds[1], bounds[2]); self.ixColliders[i] = collider end
		local hull = isBox and extents or vector_origin
		local pos, normal, fraction = collider:TraceBox(origin, angles, start, start + delta, -hull, hull)
		if (pos and (!best or fraction < best.Fraction)) then
			best = {HitPos = pos, Normal = normal, Fraction = fraction, part = part}
		end
	end
	for i, bounds in ipairs(parts) do trace(i, bounds, self:GetPos(), self:GetAngles(), i == 1 and "cabinet" or "post") end
	local pos, ang = self:DoorTransform()
	trace(3, doorBounds, pos, ang, "door")
	return best or false
end

function ENT:InteractionTarget(client)
	local hit = self:TestCollision(client:GetShootPos(), client:GetAimVector() * 150, false, vector_origin)
	if (!hit) then return end
	if (hit.part == "door") then return "door", hit end
	if (hit.part != "cabinet" or !self:GetDoorOpen() or self:DoorPitch() > -139) then return end
	local pos = self:WorldToLocal(hit.HitPos)
	-- Only the exposed front, never the back, sides, frame or support post.
	if (pos.x > 5.5 and pos.y > -10 and pos.y < 11 and pos.z > 43 and pos.z < 66) then return "panel", hit end
end

function ENT:ClearColliders()
	for _, collider in pairs(self.ixColliders or {}) do collider:Destroy() end
	self.ixColliders = nil
end

function ENT:PanelPosition()
	return self:LocalToWorld(Vector(6, 0, 54))
end

function ENT:SetupDataTables()
	-- Broken = THIS box is out of order (red light). A zone goes dark only when ALL
	-- of its boxes are broken, and powers back on only when ALL are repaired.
	self:NetworkVar("Bool", 0, "Broken")
	self:NetworkVar("Bool", 1, "DoorOpen")
	self:NetworkVar("Bool", 2, "NoPower")
	self:NetworkVar("Float", 0, "DoorPitchFrom")
	self:NetworkVar("Float", 1, "DoorMotionAt")
end

if (SERVER) then
	function ENT:Initialize()
		self:SetModel("models/props_c17/powerbox.mdl")
		self:ResetSequence("idle")
		self:SetCycle(0)
		self:SetPlaybackRate(0)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysicsInitMultiConvex({convex(parts[1][1], parts[1][2]), convex(parts[2][1], parts[2][2])})
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:EnableCustomCollisions(true)
		-- Broad phase includes the swung leaf; TestCollision rejects empty space.
		self:SetCollisionBounds(traceMin, traceMax)
		self:SetUseType(SIMPLE_USE)

		self.ixBlackoutFusebox = true
		self.nextUse = 0

		local phys = self:GetPhysicsObject()
		if (IsValid(phys)) then
			phys:SetMass(40)
			phys:EnableMotion(false)
			phys:Sleep()
		end

		-- Запускаем фоновый разряд: сам себя перепланирует и искрит, только пока
		-- щиток сломан (см. ScheduleIdleArc).
		self:ScheduleIdleArc()
	end

	function ENT:OpenDoor(open)
		if (self.ixRepairing) then return false end
		self:SetDoorPitchFrom(self:DoorPitch())
		self:SetDoorMotionAt(CurTime())
		self:SetDoorOpen(open)
		self:EmitSound("doors/door_metal_thin_close2.wav", 55, open and 115 or 95)
		return true
	end

	-- Пока щиток выведен из строя, он периодически потрескивает: искра + электро-
	-- звук раз в ~1–2 минуты. Таймер перепланирует сам себя навсегда, а искрит лишь
	-- когда щиток сломан И его сейчас не чинят (у ремонта свои, частые искры).
	function ENT:ScheduleIdleArc()
		local id = "ixFuseboxIdle" .. self:EntIndex()

		timer.Create(id, math.Rand(60, 120), 1, function()
			if (!IsValid(self)) then return end

			if (self:GetBroken() and !self.ixRepairing) then
				local pos = self:PanelPosition()

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

			local pos = self:PanelPosition()

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
		if (!IsValid(client) or !client:IsPlayer() or !client:Alive() or !client:GetCharacter()) then return end
		local target, hit = self:InteractionTarget(client)
		if (!target) then return end
		-- Revalidate the exact aimed surface on the server, including obstructions.
		if (util.TraceLine({start = client:GetShootPos(), endpos = hit.HitPos - client:GetAimVector() * 0.1,
			filter = {client, self}, mask = MASK_SOLID}).Hit) then return end
		if (self.nextUse > CurTime()) then return end
		self.nextUse = CurTime() + 0.5
		if (self.ixRepairing) then client:Notify("С электрощитом уже работают.") return end
		if (target == "door") then self:OpenDoor(!self:GetDoorOpen()) return end

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
		self:ClearColliders()
		self:StopSparks()
		timer.Remove("ixFuseboxIdle" .. self:EntIndex())

		if (ix.shuttingDown) then return end

		if (PLUGIN and istable(PLUGIN.fuseboxes)) then
			table.RemoveByValue(PLUGIN.fuseboxes, self)
			PLUGIN:SaveFuseboxes()
		end
	end
else
	local glow = CreateMaterial("ix_powerbox_indicator_glow_v1", "UnlitGeneric", {
		["$basetexture"] = "sprites/glow04", ["$additive"] = "1",
		["$vertexcolor"] = "1", ["$vertexalpha"] = "1", ["$ignorez"] = "0"
	})
	local color_broken = Color(255, 40, 40)
	local color_fixed  = Color(40, 255, 40)
	-- Gauge face, taken from the model's idle mesh/UVs, not the cabinet bounds.
	-- The control face is at local X=1.51; only a tiny offset avoids z-fighting.
	local indicatorPosition = Vector(1.55, 6.7, 58.86)
	-- Centre of the exterior green button, transformed from the model's bind
	-- mesh into proxy_box.door_cntrl space, plus 0.04 units off its surface.
	local doorIndicatorPosition = Vector(8.5158, 5.2291, .7394)

	function ENT:Initialize()
		-- Trace shapes, not a second client physics object: the latter makes the
		-- physgun beam lag behind the server entity when it is moved.
		self:EnableCustomCollisions(true)
		self:SetCollisionBounds(traceMin, traceMax)
		self:SetRenderBounds(traceMin, traceMax)
	end

	function ENT:Think()
		local pitch = self:DoorPitch()
		local bone = self:LookupBone("proxy_box.door_cntrl")
		if (bone and self.ixAppliedPitch ~= pitch) then
			self:ManipulateBoneAngles(bone, Angle(pitch, 0, 0))
			self.ixAppliedPitch = pitch
		end
	end

	function ENT:OnRemove() self:ClearColliders() end

	function ENT:OnPopulateEntityInfo(tooltip)
		local title = tooltip:AddRow("name")
		title:SetText("Электрощит"); title:SetImportant(); title:SizeToContents()
		local status = tooltip:AddRow("status")
		status:SetText(self:GetBroken() and "НЕИСПРАВЕН — требуется ремонт" or (self:GetNoPower() and "ОБЕСТОЧЕН — питание отключено" or "ПИТАНИЕ ЕСТЬ"))
		status:SizeToContents()
		local use = string.upper(input.LookupBinding("+use") or "E")
		local help = tooltip:AddRow("help")
		local action = self:GetBroken() and "ремонт (отвёртка, Электроника 3)" or "саботаж (отвёртка, Электроника 4)"
		local target = self:InteractionTarget(LocalPlayer())
		if (target == "door") then
			help:SetText(use .. (self:GetDoorOpen() and " — закрыть дверцу" or " — открыть дверцу"))
		elseif (target == "panel") then
			help:SetText(use .. " — " .. action)
		else
			help:SetText("Наведите на дверцу или на панель внутри щитка.")
		end
		help:SizeToContents()
	end

	function ENT:Draw(flags)
		self:DrawModel(flags)
	end

	-- Do not redraw the cabinet after the world blackout pass. Only the lamp
	-- belongs in the translucent pass, where its own emission remains visible.
	function ENT:DrawTranslucent()
		local color = (self:GetNoPower() or self:GetBroken()) and color_broken or color_fixed
		render.SetMaterial(glow)
		-- Depth hides the inside lamp naturally. The exterior button follows the
		-- animated door instead of disappearing when the cabinet is closed.
		render.DrawQuadEasy(self:LocalToWorld(indicatorPosition), self:GetForward(), 3, 3, color, 0)
		local pos, ang = self:DoorTransform()
		local lamp = LocalToWorld(doorIndicatorPosition, angle_zero, pos, ang)
		render.DrawQuadEasy(lamp, ang:Up(), 2, 2, color, 0)
	end
end
