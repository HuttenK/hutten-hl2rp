local PLUGIN = PLUGIN
local Amputation = ix.Amputation

-- Применение к произвольной сущности (игрок, обморочный рэгдолл, труп).
function Amputation.ApplyToEntity(entity, key)
    if !IsValid(entity) then return end
	if entity.ixAmputationBoneModel and entity.ixAmputationBoneModel != entity:GetModel() then
		Amputation.ClearEntity(entity)
	end
	entity.ixAmputationBoneModel = entity:GetModel()
	if entity:GetNetVar("ixAmputation") != key then entity:SetNetVar("ixAmputation", key) end

	local limb = Amputation.limbs[key]
	if !limb then return end

	local bones = Amputation.CollectBones(entity, limb)
	if !bones then return end

	-- Track only this plugin's changes so restoration preserves other addons.
	-- сдвиг корня растягивает вершины у сустава в полосы кожи, а попытка стянуть
	-- кисть и пальцы к локтю уносит кости в мир — система координат смещения не
	-- совпадает с локальной позицией кости. Подробности в комментарии в sh_plugin.
	for _, bone in ipairs(bones) do
		entity.ixAmputationBones = entity.ixAmputationBones or {}
		if !entity.ixAmputationBones[bone] then
			entity.ixAmputationBones[bone] = {scale = entity:GetManipulateBoneScale(bone), position = entity:GetManipulateBonePosition(bone)}
		end
		if entity:GetManipulateBoneScale(bone) != Amputation.scale then
			entity:ManipulateBoneScale(bone, Amputation.scale)
		end

		if entity:GetManipulateBonePosition(bone) != Amputation.noOffset then
			entity:ManipulateBonePosition(bone, Amputation.noOffset)
		end
	end
end

-- Restore only the bone indices modified by this plugin.
function Amputation.ClearEntity(entity)
	if !IsValid(entity) then return end
	local count = entity:GetBoneCount() or 0
	-- Recover pre-update amputations once, without resetting unrelated bones.
	if !entity.ixAmputationBones then
		for bone = 0, count - 1 do
			if entity:GetManipulateBoneScale(bone) == Amputation.scale then
				entity:ManipulateBoneScale(bone, Amputation.normal)
			end
		end
	end

	for bone, previous in pairs(entity.ixAmputationBones or {}) do
		if bone < count then
			-- A new model may use this index for an unrelated bone. Only undo
			-- values still owned by us; do not carry the old model's offsets over.
			local sameModel = entity.ixAmputationBoneModel == entity:GetModel()
			if entity:GetManipulateBoneScale(bone) == Amputation.scale then
				entity:ManipulateBoneScale(bone, sameModel and previous.scale or Amputation.normal)
			end
			if sameModel and entity:GetManipulateBonePosition(bone) == Amputation.noOffset then
				entity:ManipulateBonePosition(bone, previous.position)
			end
		end
	end
	entity.ixAmputationBones = nil
	entity.ixAmputationBoneModel = nil
	if entity:GetNetVar("ixAmputation") != nil then entity:SetNetVar("ixAmputation", nil) end
end

-- Единая точка повторного применения. Смена модели (костюм химзащиты, форма ГО)
-- и респавн сбрасывают позу, поэтому её дёргает и таймер-сторож.
function Amputation.Refresh(client)
	if !IsValid(client) then return end

	local character = client:GetCharacter()
	local key = Amputation.Get(character)
	local model = client:GetModel()

	-- Манипуляции привязаны к индексам костей и НЕ сбрасываются при SetModel.
	-- У новой модели те же индексы — это уже другие кости, поэтому при смене
	-- модели сначала чистим скелет полностью, а затем применяем заново по именам.
	if client.ixAmputationModel != model or client.ixAmputationCharacter != character or client.ixAmputationKey != key then
		client.ixAmputationModel = model
		client.ixAmputationCharacter = character
		client.ixAmputationKey = key

		Amputation.ClearEntity(client)
		Amputation.ClearEntity(client.ixRagdoll)
	end

	if !key then return end

	Amputation.ApplyToEntity(client, key)

	if IsValid(client.ixRagdoll) then
		Amputation.ApplyToEntity(client.ixRagdoll, key)
	end
end

-- Оружие, которое нельзя удержать одной рукой, падает на землю.
local function DropTwoHandedWeapons(client)
	for _, item in ipairs(client:GetItems()) do
		if !item.isWeapon then continue end
		if !item:GetData("equip") then continue end
		if !Amputation.IsTwoHanded(item) then continue end

		if ix.WeaponSlots then
            ix.WeaponSlots.Suspend(client, item)
        elseif item.Unequip then
			item:Unequip(client, false)
		end

		ix.Item:DropItem(client, item.id)
	end
end

function Amputation.Amputate(client, key, bSilent)
	if !IsValid(client) then return false end

	local limb = Amputation.limbs[key]
	if !limb then return false end

	local character = client:GetCharacter()
	if !character then return false end
	if !client:Alive() then return false end

	-- Одна конечность на персонажа.
	if Amputation.Get(character) then return false end
	if Amputation.CancelOperation then Amputation.CancelOperation(client) end

	character:SetData("amputation", key)

	-- Сбрасывает cachedMovement, из которого sh_movement считает штраф скорости.
	local health = character:Health()

	if health then
		health:OnUpdateDiffs()
	end

	Amputation.Refresh(client)

	if limb.kind == "arm" then
		DropTwoHandedWeapons(client)
	end

	if !bSilent then
		client:NotifyLocalized("amputation.lost", L(limb.phrase, client))
		client:EmitSound("physics/flesh/flesh_bloody_break.wav", 75, 100)

		local effect = EffectData()
		effect:SetOrigin(client:GetPos() + client:OBBCenter())
		effect:SetMagnitude(8)
		util.Effect("BloodImpact", effect)
	end

	return true
end

function Amputation.Restore(client)
	if !IsValid(client) then return false end

	local character = client:GetCharacter()
	if !character or !Amputation.Get(character) then return false end

	character:SetData("amputation", nil)

	local health = character:Health()

	if health then
		health:OnUpdateDiffs()
	end

	Amputation.ClearEntity(client)
	Amputation.ClearEntity(client.ixRagdoll)

	return true
end

-- Combat uses a single resolved melee hit (sv_melee), never individual wound
-- callbacks: armor and fractures can add several wounds for the same hit.

function Amputation.GiveRemains(client, key, onGround)
	local id = Amputation.limbItems[key]
	if !id or !IsValid(client) then return end
	local item = ix.Item:Instance(id)
	if !item then return end
	if onGround or !client:AddItem(item) then
		-- This instance has never belonged to an inventory. DropItem would try
		-- to remove it from a nil inventory before spawning it.
		ix.Item:Spawn(client, nil, item)
	end
	return item
end

util.AddNetworkString("ixAmputationRequest")
util.AddNetworkString("ixAmputationConsent")

-- Незавершённые запросы согласия: pending[target] = {...}
local pending = {}
local requestSerial = 0

local function OwnsItem(client, item)
	if !item or ix.Item.instances[item.id] != item then return false end
	for _, owned in ipairs(client:GetItems()) do
		if owned == item then return true end
	end
	return false
end

local function CanOperate(surgeon, target, item)
	if !IsValid(surgeon) or !IsValid(target) or surgeon == target then return false end
	if !surgeon:Alive() or !target:Alive() or !target:GetCharacter() then return false end
	if !Amputation.CanOperate(surgeon:GetCharacter()) or !OwnsItem(surgeon, item) then return false end
	if Amputation.MedicallyBusy(surgeon) or Amputation.MedicallyBusy(target) then return false end
	if IsValid(surgeon.ixRagdoll) or surgeon:GetNetVar("crit", false) or surgeon:GetNetVar("restricted", false) then return false end
	return Amputation.GetTarget(surgeon) == target
end

function Amputation.MedicallyBusy(client)
	if client.bUsingMedical or client.ixMedicalSession or client.ixMedicalCleanup then return true end
	for _, session in pairs(ix.Medicine and ix.Medicine.activeSessions or {}) do
		if session.target == client then return true end
	end
	return false
end

function Amputation.CancelOperation(client)
	local operation = IsValid(client) and client.ixAmputationBusy
	if istable(operation) and operation.finish then operation.finish(false) end
end

-- One session owns both players and its tool. Every exit releases exactly
-- those locks, including death, a character switch and disconnect.
local function RunOperation(id, surgeon, target, time, item, onTick, onFinish)
	local timerName = "ixAmputation" .. id .. surgeon:UniqueID()
	local ticks = math.ceil(time / 0.5)
	local tick = 0
	local surgeonCharacter, targetCharacter = surgeon:GetCharacter(), target:GetCharacter()
	local operation = {surgeon = surgeon, target = target, item = item}
	surgeon.ixAmputationBusy, target.ixAmputationBusy = operation, operation
	item.ixAmputationOperation, item.inUse = operation, surgeon
	function operation.finish(success)
		if operation.finished then return end
		operation.finished = true
		timer.Remove(timerName)
		if item.ixAmputationOperation == operation then
			item.ixAmputationOperation = nil
			if item.inUse == surgeon then item.inUse = nil end
		end
		for _, client in ipairs({surgeon, target}) do
			if IsValid(client) and client.ixAmputationBusy == operation then
				client.ixAmputationBusy = nil
				client:SetAction()
				if !success then client:NotifyLocalized("amputation.interrupted") end
			end
		end
		if success then onFinish() end
	end

	timer.Create(timerName, 0.5, ticks, function()
		tick = tick + 1

		local ok = CanOperate(surgeon, target, item)
			and surgeon:GetCharacter() == surgeonCharacter and target:GetCharacter() == targetCharacter
			and surgeon.ixAmputationBusy == operation and target.ixAmputationBusy == operation
			and item.ixAmputationOperation == operation and item.inUse == surgeon
			and !Amputation.Get(targetCharacter)
			and !surgeon:KeyDown(IN_RELOAD) and !target:KeyDown(IN_RELOAD)

		if !ok then
			operation.finish(false)
			return
		end

		if onTick then
			onTick(tick, ticks)
		end

		if timer.RepsLeft(timerName) == 0 then
			operation.finish(true)
		end
	end)
end

-- Хирург режет цель. Вызывается только после явного согласия жертвы.
function Amputation.BeginCut(surgeon, target, key, item)
	local limb = Amputation.limbs[key]
	if !limb or !Amputation.IsTool(item) or !CanOperate(surgeon, target, item) then return end
	if surgeon.ixAmputationBusy or target.ixAmputationBusy or item.inUse or Amputation.Get(target:GetCharacter()) then return end

	surgeon:SetAction("@amputation.cutting", Amputation.cutTime)
	target:SetAction("@amputation.beingCut", Amputation.cutTime)

	local nextPain = 0

	RunOperation("cut", surgeon, target, Amputation.cutTime, item, function(tick, ticks)
		-- Крик боли примерно раз в 12 секунд.
		if tick >= nextPain then
			nextPain = tick + 24

			local phrase = Amputation.painPhrases[math.random(#Amputation.painPhrases)]

			target:ChatNotifyLocalized(phrase)
			target:EmitSound("vo/npc/male01/pain0" .. math.random(1, 9) .. ".wav", 70, math.random(90, 110))

			local effect = EffectData()
			effect:SetOrigin(target:GetPos() + target:OBBCenter())
			effect:SetMagnitude(4)
			util.Effect("BloodImpact", effect)
		end
	end, function()
		surgeon.ixAmputationBusy = nil
		target.ixAmputationBusy = nil

		if !Amputation.Amputate(target, key) then
			surgeon:NotifyLocalized("amputation.interrupted")
			return
		end

		surgeon:SetAction()

		Amputation.GiveRemains(surgeon, key)

		surgeon:NotifyLocalized("amputation.cutDone")
	end)
end

-- Запрос согласия. Жертва может отказаться — тогда ничего не происходит.
function Amputation.RequestCut(surgeon, target, key, item)
	local limb = Amputation.limbs[key]
	if !limb or !Amputation.IsTool(item) or !CanOperate(surgeon, target, item) then return end

	if pending[target] or target.ixAmputationBusy or surgeon.ixAmputationBusy or item.inUse then
		surgeon:NotifyLocalized("amputation.busy")
		return
	end

	pending[target] = {
		surgeon = surgeon,
		key = key,
		item = item,
		surgeonCharacter = surgeon:GetCharacter(),
		targetCharacter = target:GetCharacter(),
		expires = CurTime() + Amputation.consentTimeout
	}
	requestSerial = (requestSerial + 1) % 4294967295
	pending[target].id = requestSerial
	local request = pending[target]
	timer.Simple(Amputation.consentTimeout, function()
		if pending[target] == request then pending[target] = nil end
	end)

	surgeon:NotifyLocalized("amputation.requestSent")

	net.Start("ixAmputationRequest")
		net.WriteUInt(requestSerial, 32)
		net.WriteString(surgeon:Name())
		net.WriteString(key)
	net.Send(target)
end

net.Receive("ixAmputationConsent", function(_, target)
	local request = pending[target]
	if !request then return end
	if net.ReadUInt(32) != request.id then return end

	pending[target] = nil

	local consent = net.ReadBool()
	local surgeon = request.surgeon

	if !IsValid(surgeon) or CurTime() > request.expires then return end
	if surgeon:GetCharacter() != request.surgeonCharacter or target:GetCharacter() != request.targetCharacter then return end

	if !consent then
		surgeon:NotifyLocalized("amputation.denied")
		target:NotifyLocalized("amputation.deniedSelf")
		return
	end

	-- Условия перепроверяются: за время раздумий всё могло измениться.
	if !target:Alive() or !surgeon:Alive() then return end
	if Amputation.Get(target:GetCharacter()) then return end
	if !Amputation.CanOperate(surgeon:GetCharacter()) then return end
	if !CanOperate(surgeon, target, request.item) then return end

	Amputation.BeginCut(surgeon, target, request.key, request.item)
end)

-- Kept as a no-op for old item callbacks. Only explicit admin restoration remains.
function Amputation.BeginReattach(surgeon, target, item)
	return false
end

local function releaseParticipant(client)
	Amputation.CancelOperation(client)
	for target, request in pairs(pending) do
		if target == client or request.surgeon == client then pending[target] = nil end
	end
end
hook.Add("PlayerDisconnected", "ixAmputationSession", releaseParticipant)
hook.Add("PlayerDeath", "ixAmputationSession", releaseParticipant)
hook.Add("PrePlayerLoadedCharacter", "ixAmputationSession", releaseParticipant)
hook.Add("CanPlayerDropItem", "ixAmputationTool", function(_, item)
	if item and item.ixAmputationOperation then return false end
end)
hook.Add("CanTransferItem", "ixAmputationTool", function(item)
	if item and item.ixAmputationOperation then return false, "notAllowed" end
end)
hook.Add("StartCommand", "ixAmputationOperation", function(client, command)
	local operation = client.ixAmputationBusy
	if istable(operation) and operation.surgeon == client then
		command:RemoveKey(IN_ATTACK)
		command:RemoveKey(IN_ATTACK2)
	end
end)

function PLUGIN:PlayerModelChanged(client)
	-- Undo old numeric indices immediately, then resolve the new skeleton.
	Amputation.Refresh(client)
	timer.Simple(0, function() Amputation.Refresh(client) end)
end

function PLUGIN:PlayerLoadedCharacter(client)
	timer.Simple(0, function()
		Amputation.Refresh(client)
	end)
end

function PLUGIN:PlayerSpawn(client)
	timer.Simple(0, function()
		Amputation.Refresh(client)
	end)
end

-- Труп создаётся отдельной сущностью prop_ragdoll, кости на него не переносятся.
function PLUGIN:OnPlayerCorpseCreated(client, entity)
	local character = client:GetCharacter()
	if !character then return end

	local key = Amputation.Get(character)
	if !key then return end

	Amputation.ApplyToEntity(entity, key)
end

function PLUGIN:OnPlayerServerRagdollCreated(client, entity)
	local key = Amputation.Get(client:GetCharacter())
	if key then Amputation.ApplyToEntity(entity, key) end
end

-- Сторож: одежда и формы меняют модель через SetModel в отложенном таймере, что
-- обнуляет манипуляции костей. Дешевле проверять раз в секунду, чем ловить
-- каждый путь смены модели.
timer.Create("ixAmputationRefresh", 1, 0, function()
	for _, client in ipairs(player.GetAll()) do
		Amputation.Refresh(client)
	end
end)

-- Потеря ноги: шанс потерять равновесие на ходу.
function PLUGIN:PlayerTick(client, mv)
	if ix.Downed and ix.Downed.Crawling and ix.Downed.Crawling(client) then return end
	local character = client:GetCharacter()
	if !character then return end

	if !Amputation.HasKind(character, "leg") then return end
	if !client:Alive() or IsValid(client.ixRagdoll) then return end
	if !client:OnGround() then return end
	if client:GetVelocity():Length2D() < 40 then return end

	local nextCheck = client.ixNextStumble or 0
	if CurTime() < nextCheck then return end

	client.ixNextStumble = CurTime() + Amputation.stumbleInterval

	if math.Rand(0, 1) > Amputation.stumbleChance then return end

	client:ChatNotifyLocalized("amputation.stumble")
	client:SetRagdolled(true, Amputation.stumbleTime, Amputation.stumbleTime)
end
