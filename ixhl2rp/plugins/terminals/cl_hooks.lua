local PLUGIN = PLUGIN

PLUGIN.nName = "N/A"
PLUGIN.aparts = "N/A"
PLUGIN.nRecords = 0
PLUGIN.cRecords = 0
PLUGIN.mRecords = 0
PLUGIN.status = "N/A"
PLUGIN.points = 0
PLUGIN.civilStatus = 1
PLUGIN.ownerModel  = ""
PLUGIN.ownerSkin   = 0
PLUGIN.geneticDesc = ""

PLUGIN.photoRT    = GetRenderTarget("ixTerminalPhoto", 256, 512)
PLUGIN.photoMat   = CreateMaterial("__ixTerminalPhotoMat", "UnlitGeneric", {
	["$basetexture"] = "ixTerminalPhoto",
	["$noclamp"]     = "1",
	["$ignorez"]     = "1",
})
PLUGIN.photoReady         = false
PLUGIN.photoEnt           = nil
PLUGIN.shouldCapturePhoto = false

local PHOTO_MODEL_POS = Vector(0, 0, -16000)
local PHOTO_CAM_POS   = PHOTO_MODEL_POS + Vector(0, 38, 55)
local PHOTO_CAM_ANG   = Angle(0, 270, 0)

function PLUGIN:StartPhotoCapture()
	self.photoReady         = false
	self.shouldCapturePhoto = false

	if IsValid(self.photoEnt) then
		self.photoEnt:Remove()
		self.photoEnt = nil
	end

	local model = (PLUGIN.ownerModel ~= "") and PLUGIN.ownerModel
		or "models/player/kleiner.mdl"

	local ent = ClientsideModel(model, RENDERGROUP_OPAQUE)
	ent:SetPos(PHOTO_MODEL_POS)
	ent:SetAngles(Angle(0, 90, 0))
	ent:SetNoDraw(true)

	ent:SetSkin(PLUGIN.ownerSkin)

	for i = 0, ent:GetNumBodyGroups() - 1 do
		ent:SetBodygroup(i, 0)
	end

	-- SelectWeightedSequence(ACT_IDLE) выбирает правильную позу для любой модели
	local idleSeq = ent:SelectWeightedSequence(ACT_IDLE)
	if !idleSeq or idleSeq < 0 then
		-- fallback: ищем по имени
		idleSeq = ent:LookupSequence("idle_all_2pistols")
		if idleSeq < 0 then idleSeq = ent:LookupSequence("idle_all_01") end
		if idleSeq < 0 then idleSeq = ent:LookupSequence("idle") end
		if idleSeq < 0 then idleSeq = 0 end
	end
	ent:SetSequence(idleSeq)
	ent:SetCycle(0.0)

	self.photoEnt = ent

	timer.Simple(0.3, function()
		PLUGIN.shouldCapturePhoto = true
	end)
end

hook.Add("PostRender", "ixTerminalPhotoCapture", function()
	if !PLUGIN.shouldCapturePhoto then return end
	if !IsValid(PLUGIN.photoEnt) then
		PLUGIN.shouldCapturePhoto = false
		return
	end

	PLUGIN.shouldCapturePhoto = false

	render.PushRenderTarget(PLUGIN.photoRT)
		render.Clear(18, 42, 55, 255, true, true)

		cam.Start3D(PHOTO_CAM_POS, PHOTO_CAM_ANG, 30, 0, 0, 256, 512)
			render.SuppressEngineLighting(true)
			render.SetColorModulation(0.82, 0.88, 0.92)
			render.SetBlend(1)
			PLUGIN.photoEnt:SetupBones()
			PLUGIN.photoEnt:DrawModel()
			render.SuppressEngineLighting(false)
		cam.End3D()
	render.PopRenderTarget()

	if IsValid(PLUGIN.photoEnt) then
		PLUGIN.photoEnt:Remove()
		PLUGIN.photoEnt = nil
	end

	PLUGIN.photoReady = true
end)

net.Receive("ixTerminalResponse", function(len)
	local name        = net.ReadString()
	local aparts      = net.ReadString()
	local status      = net.ReadString()
	local points      = net.ReadInt(16)
	local civilStatus = net.ReadUInt(8)
	local ownerModel  = net.ReadString()
	local ownerSkin   = net.ReadUInt(8)

	if isstring(name)        then PLUGIN.nName       = name                       end
	if isstring(aparts)      then PLUGIN.aparts       = aparts                    end
	if isstring(status)      then PLUGIN.status       = status                    end
	if isnumber(points)      then PLUGIN.points       = points                    end
	if isnumber(civilStatus) then PLUGIN.civilStatus  = math.max(1, civilStatus)  end
	if isstring(ownerModel)  then PLUGIN.ownerModel   = ownerModel                end
	if isnumber(ownerSkin)   then PLUGIN.ownerSkin    = ownerSkin                 end
	-- geneticDesc не строится на сервере (L() там требует клиент).
	-- Читаем пустышку для совместимости формата, затем строим сами.
	net.ReadString() -- пустая строка с сервера

	PLUGIN.geneticDesc = ""
	local card = LocalPlayer().GetIDCard and LocalPlayer():GetIDCard()
	if card then
		local dID = tonumber(card:GetData("datafileID"))
		if dID then
			for _, ply in ipairs(player.GetAll()) do
				local char = ply:GetCharacter()
				if char and char:GetID() == dID then
					local ok, desc = pcall(function()
						local g = char:Genetic()
						return g and g.GetDesc and g:GetDesc() or ""
					end)
					if ok and isstring(desc) then PLUGIN.geneticDesc = desc end
					break
				end
			end
		end
	end

	-- Запускаем захват фото ПОСЛЕ получения модели с сервера
	PLUGIN:StartPhotoCapture()
end)
