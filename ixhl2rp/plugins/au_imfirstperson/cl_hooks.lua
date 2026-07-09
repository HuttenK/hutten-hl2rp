local PLUGIN = PLUGIN

-- Called when the player's view needs to be calculated.
function PLUGIN:CalcView(client, origin, angles, fov)
	local view = {}
	local eyeAtt = client:GetAttachment(client:LookupAttachment("eyes"))
	local forwardVec = client:GetAimVector()
	local FT = FrameTime()
	
	if (!ix.option.Get("enableImmersiveFirstPerson", true) or !client:Alive() or client:InVehicle() or !eyeAtt) then
		return
	end

	-- Пока игрок в рэгдолле (нокдаун/усыпление/крит-удар) не трогаем вид: им займётся
	-- ядро (GM:CalcView следит за глазами рэгдолла). Иначе мы вернули бы вид без origin,
	-- и камера осталась бы там, где персонаж стоял, пока тело уже лежит на земле.
	local ragdoll = Entity(client:GetLocalVar("ragdoll", 0))

	if (IsValid(ragdoll) and ragdoll:IsRagdoll()) then
		return
	end

	-- Don't override the view if third person is active
	if (client.CanOverrideView and client:CanOverrideView()) then
		return
	end
	
	if (!CurView) then
		CurView = angles
	else
		CurView = LerpAngle(math.Clamp(FT * (35 * (1 - math.Clamp(ix.option.Get("smoothScale", 0.7), 0, 0.9))), 0, 1), CurView, angles + Angle(0, 0, eyeAtt.Ang.r * 0.1))
	end

	if (eyeAtt) then
		view.angles = CurView
		view.fov = fov
			
		return view
	end
end

-- Called when the HUD needs to be painted.
function PLUGIN:HudPaint()
	local tr, pos
	local td = {}

	if (!ix.option.Get("customCrosshair", true)) then
		return
	end

	client = LocalPlayer()

	if (!ix.option.Get("enableImmersiveFirstPerson", true) or !client:Alive()) then
		return
	end
	
	td.start = client:GetShootPos()
	td.endpos = td.start + client:GetAimVector() * 3000
	td.filter = client
	
	tr = util.TraceLine(td)
	pos = tr.HitPos:ToScreen()
		
	surface.SetDrawColor(0, 0, 0, 125)
	surface.DrawRect(pos.x - 2, pos.y - 1, 5, 5)
	
	surface.SetDrawColor(255, 255, 255, 150)
	surface.DrawRect(pos.x - 1, pos.y, 3, 3)
end
