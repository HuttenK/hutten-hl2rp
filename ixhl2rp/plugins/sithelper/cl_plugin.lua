local PLUGIN = PLUGIN

local bShowPreview = false
local sitAngle = Angle(0, 0, 0)
local sitPreview = NULL
local sitOption = 1
local sitHeight = 0
local choices = {}
local choiceIndex = 1
local previewModel
local placementReason
local placementValid = false

local requesting=false
local requestToken=0
local preferredOption
local clickPlacement=false
function PLUGIN:IsPlacingPose() return bShowPreview or requesting end
local function OpenPreview(player,serverChoices)
 choices={}
 for _,option in ipairs(serverChoices) do
  if PLUGIN:ResolvePose(player,option) then choices[#choices+1]=option end
 end
 if #choices==0 then
  player:Notify("Нет общих поз для клиента и сервера. Проверьте, что модели SD и их анимации установлены на сервере.")
  return
 end
 placementReason=nil; placementValid=false; choiceIndex=1; sitHeight=0
 if preferredOption then
  local found=false
  for i,option in ipairs(choices) do if option==preferredOption then choiceIndex=i; found=true; break end end
  if not found then player:Notify("Выбранная поза недоступна для этой модели."); return end
 end
 sitOption=choices[choiceIndex]; previewModel=player:GetModel(); bShowPreview=true
 sitAngle=Angle(0,player:EyeAngles().y+180,0)
 sitPreview=ClientsideModel(previewModel,RENDERGROUP_OPAQUE)
 if not IsValid(sitPreview) then bShowPreview=false; return end
 sitPreview:SetNoDraw(true)
end
local function RequestPreview(player,option,manual)
 SafeRemoveEntity(sitPreview); bShowPreview=false; choices={}
 preferredOption=option; clickPlacement=manual==true
 requestToken=(requestToken+1)%65536; requesting=true
 local token=requestToken
 net.Start("ixSitCapabilities"); net.WriteUInt(token,16); net.SendToServer()
 timer.Simple(3,function()
  if requesting and requestToken==token then
   requesting=false
   if IsValid(player) then player:Notify("Сервер не ответил на проверку поз. Обновите sithelper на сервере и попробуйте снова.") end
  end
 end)
end
concommand.Add("+sit",function(player) RequestPreview(player) end)
function PLUGIN:OpenPosePlacement(option)
 if ix.PoseStudio and ix.PoseStudio.OpenPlacement then ix.PoseStudio.OpenPlacement({kind="sit",id=option},"Размещение позы"); return end
 if ix.StopAutoWalk then ix.StopAutoWalk() end
 RequestPreview(LocalPlayer(),option,true)
end
net.Receive("ixSitCapabilities",function()
 local token=net.ReadUInt(16); local model=net.ReadString(); local count=net.ReadUInt(5)
 local serverChoices={}
 for i=1,count do serverChoices[i]=net.ReadUInt(5) end
 if not requesting or token~=requestToken then return end
 requesting=false
 local player=LocalPlayer()
 if not IsValid(player) or player:GetModel()~=model then return end
 OpenPreview(player,serverChoices)
end)

local function PlacePreview(player)
 requesting=false
	if not bShowPreview then return end
	bShowPreview = false
	SafeRemoveEntity(sitPreview)

	local localPlayer = LocalPlayer()
	if localPlayer:GetModel() ~= previewModel or not PLUGIN:ResolvePose(localPlayer, sitOption) then return end
	local eyePos = localPlayer:EyePos()
	local obb = PLUGIN.OBB[sitOption] or PLUGIN.OBB[0]

	local character = localPlayer:GetCharacter()
	if character and character:GetGender() == GENDER_FEMALE then
		obb = PLUGIN.OBBF[sitOption] or obb
	end

	local sitTrace = util.TraceHull({
		start = eyePos,
		endpos = eyePos + localPlayer:EyeAngles():Forward() * 60,
		filter = localPlayer,
		mins = obb[1],
		maxs = obb[2]
	})

	local downTrace = util.TraceHull({
		start = sitTrace.HitPos,
		endpos = sitTrace.HitPos - Vector(0, 0, 100),
		filter = localPlayer,
		mins = obb[1],
		maxs = obb[2]
	});

	-- Trying to sit too far away or something is blocking us from sitting, deny it
	if (!downTrace.Hit or downTrace.AllSolid or downTrace.HitNormal.z <= 0.75) then
		return
	end

	net.Start("ixPlayerSit")
		net.WriteVector(downTrace.HitPos)
		net.WriteAngle(sitAngle)
		net.WriteUInt(sitOption, 5)
		net.WriteFloat(sitHeight)
	net.SendToServer()
end
concommand.Add("-sit",function(player) if not clickPlacement then PlacePreview(player) end end)

do
	local mat = Material("debug/debugdrawflat")

	function PLUGIN:PostDrawTranslucentRenderables()
		if (!bShowPreview) then
			return
		end

		if (!IsValid(sitPreview)) then
			return
		end

		if LocalPlayer():GetModel() ~= previewModel then
			bShowPreview = false SafeRemoveEntity(sitPreview) return
		end
		local _, anim, sharedPose = self:ResolvePose(sitPreview, sitOption)

		if (anim == nil) then
			return
		end

		local localPlayer = LocalPlayer()
		local eyePos = localPlayer:EyePos()
		local obb = self.OBB[sitOption] or self.OBB[0]

		local character = localPlayer:GetCharacter()
		if character and character:GetGender() == GENDER_FEMALE then
			obb = self.OBBF[sitOption] or obb
		end

		local sitTrace = util.TraceHull({
			start = eyePos,
			endpos = eyePos + localPlayer:EyeAngles():Forward() * 60,
			filter = localPlayer,
			mins = obb[1],
			maxs = obb[2]
		})

		local downTrace = util.TraceHull({
			start = sitTrace.HitPos,
			endpos = sitTrace.HitPos - Vector(0, 0, 100),
			filter = localPlayer,
			mins = obb[1],
			maxs = obb[2]
		})

		local bCanSit, reason = self:CanSit(localPlayer, downTrace.HitPos, sitOption, character)

		if (!downTrace.Hit or downTrace.AllSolid or downTrace.StartSolid or downTrace.HitNormal.z <= 0.75) then
			bCanSit = false
			reason = "Нет ровной свободной опоры"
		end
		if bCanSit and ix.PoseStudio and ix.PoseStudio.CheckPlacement then
   bCanSit,reason=ix.PoseStudio.CheckPlacement(localPlayer,downTrace.HitPos,sitAngle.y,sitHeight,self:GetPoseOffset(localPlayer,sitOption,character))
  end
  placementValid = bCanSit
		placementReason = reason

		render.MaterialOverride(mat)

		local sitOffset = self:GetPoseOffset(localPlayer, sitOption, character)

		local forwardOffset = sitOffset.x
		local previewPos = (downTrace.Hit and downTrace.HitPos or sitTrace.HitPos)
		local previewOffsetPos = previewPos + sitAngle:Forward() * forwardOffset + Vector(0, 0, sitOffset.z + sitHeight)

		local oldBlend = render.GetBlend()
		local oldR, oldG, oldB = render.GetColorModulation()
		render.SetColorModulation(bCanSit and 0 or 1, bCanSit and 1 or 0, 0, 1)
		render.SetBlend(0.2)
		sitPreview:SetPos(previewOffsetPos)
		sitPreview:SetAngles(sitAngle)
		sitPreview:SetSequence(anim)
		if ix.sharedPoses then
			if sharedPose then ix.sharedPoses.Apply(sitPreview,sharedPose) else ix.sharedPoses.Clear(sitPreview) end
		end
		sitPreview:SetupBones()
		sitPreview:DrawModel()

		render.MaterialOverride(nil)
		render.SetBlend(oldBlend)
		render.SetColorModulation(oldR, oldG, oldB)
	end
end

function PLUGIN:PlayerBindPress(player, bind, bPressed)
	if (!bShowPreview or !IsValid(sitPreview)) then return end
	bind = bind:lower()
	if clickPlacement and bPressed then
		if bind:find("+attack2",1,true) then
			requesting=false; bShowPreview=false; SafeRemoveEntity(sitPreview); return true
		elseif bind:find("+attack",1,true) then
			PlacePreview(player); return true
		end
	end

	if (bind:find("invnext") or bind:find("invprev")) then
		return true
	elseif (bind:find("+attack2") and bPressed) then
		choiceIndex = (choiceIndex - 2) % #choices + 1
		sitOption = choices[choiceIndex]
		return true
	elseif (bind:find("+attack") and bPressed) then
		choiceIndex = choiceIndex % #choices + 1
		sitOption = choices[choiceIndex]
		return true
	end
end

function PLUGIN:InputMouseApply(cmd)
	if (!bShowPreview or !IsValid(sitPreview)) then return end
	local scrollDelta = cmd:GetMouseWheel()

	if (scrollDelta == 0) then return end

	local bPos = cmd:GetMouseWheel() > 0

	if input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT) then
  sitHeight=math.Clamp(sitHeight+(bPos and 2 or -2),-24,48)
 else sitAngle.y = math.NormalizeAngle(sitAngle.y + (bPos and 4 or -4)) end
end

-- Red describes placement, not whether the model contains the animation.
function PLUGIN:HUDPaint()
 if not bShowPreview or not IsValid(sitPreview) then return end
 local names = {[22] = "На земле", [23] = "На сиденье", [24] = "На сиденье: руки вперёд"}
 local title = string.format("%s  [%d/%d]", names[sitOption] or "Поза", choiceIndex, #choices)
 local status = placementValid and (clickPlacement and "ЛКМ — разместить позу" or "Отпустите клавишу, чтобы сесть") or (placementReason or "Выберите место")
 title=title..string.format(" · Высота %+.0f",sitHeight)
 draw.SimpleTextOutlined(title, "DermaDefaultBold", ScrW() / 2, ScrH() * 0.78, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
 draw.SimpleTextOutlined(status, "DermaDefault", ScrW() / 2, ScrH() * 0.78 + 22, placementValid and Color(120, 240, 170) or Color(255, 170, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
 draw.SimpleTextOutlined(clickPlacement and "ЛКМ: разместить • ПКМ: отменить • Колесо: повернуть • Shift + колесо: высота" or "ЛКМ / ПКМ: сменить позу • Колесо: повернуть", "DermaDefault", ScrW() / 2, ScrH() * 0.78 + 42, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
end
