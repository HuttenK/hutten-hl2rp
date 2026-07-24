local PLUGIN = PLUGIN
local Amputation = ix.Amputation

-- Применение к произвольной сущности (игрок, обморочный рэгдолл, труп).
function Amputation.ApplyToEntity(entity, key)
	if !IsValid(entity) then return end

	local limb = Amputation.limbs[key]
	if !limb then return end

	local bones = Amputation.CollectBones(entity, limb)
	if !bones then return end

	-- Только масштаб. Любое смещение костей (ManipulateBonePosition) даёт артефакты:
	-- сдвиг корня растягивает вершины у сустава в полосы кожи, а попытка стянуть
	-- кисть и пальцы к локтю уносит кости в мир — система координат смещения не
	-- совпадает с локальной позицией кости. Подробности в комментарии в sh_plugin.
	for _, bone in ipairs(bones) do
		if entity:GetManipulateBoneScale(bone) != Amputation.scale then
			entity:ManipulateBoneScale(bone, Amputation.scale)
		end

		if entity:GetManipulateBonePosition(bone) != Amputation.noOffset then
			entity:ManipulateBonePosition(bone, Amputation.noOffset)
		end
	end
end

-- Снимает ВСЕ манипуляции костей, а не только по именам конечностей.
--
-- Манипуляции хранятся по ИНДЕКСУ кости и переживают SetModel. После смены
-- модели (форма ГО, костюм химзащиты, другая модель гражданина) старые индексы
-- указывают уже на другие кости — так на модели остаются обнулённые пальцы
-- второй руки и случайные смещения. Поэтому чистим весь скелет целиком.
function Amputation.ClearEntity(entity)
	if !IsValid(entity) then return end

	for bone = 0, entity:GetBoneCount() - 1 do
		if entity:GetManipulateBoneScale(bone) != Amputation.normal then
			entity:ManipulateBoneScale(bone, Amputation.normal)
		end

		if entity:GetManipulateBonePosition(bone) != Amputation.noOffset then
			entity:ManipulateBonePosition(bone, Amputation.noOffset)
		end
	end
end

-- Единая точка повторного применения. Смена модели (костюм химзащиты, форма ГО)
-- и респавн сбрасывают позу, поэтому её дёргает и таймер-сторож.
function Amputation.Refresh(client)
	if !IsValid(client) then return end

	local character = client:GetCharacter()
	if !character then return end

	local key = Amputation.Get(character)
	local model = client:GetModel()

	-- Манипуляции привязаны к индексам костей и НЕ сбрасываются при SetModel.
	-- У новой модели те же индексы — это уже другие кости, поэтому при смене
	-- модели сначала чистим скелет полностью, а затем применяем заново по именам.
	if client.ixAmputationModel != model then
		client.ixAmputationModel = model

		Amputation.ClearEntity(client)
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

		if item.Unequip then
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

	-- Одна конечность на персонажа.
	if Amputation.Get(character) then return false end

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

-- ОБКАТКА: урон по конечности НЕ отнимает её. Единственные пути — команда
-- администратора и ампутация холодным оружием (см. ниже). Автоматический хук по
-- OnHediffAdded намеренно не подключён.

util.AddNetworkString("ixAmputationRequest")
util.AddNetworkString("ixAmputationConsent")

-- Незавершённые запросы согласия: pending[target] = {...}
local pending = {}

-- Общий «прогресс-бар» для операций: тик 0.5с, проверка условий на каждом тике,
-- сообщения жертве по ходу дела. Тот же приём, что и в базе medical.
local function RunOperation(id, surgeon, target, time, onTick, onFinish)
	local timerName = "ixAmputation" .. id .. surgeon:UniqueID()
	local ticks = math.ceil(time / 0.5)
	local tick = 0

	timer.Create(timerName, 0.5, ticks, function()
		tick = tick + 1

		local ok = IsValid(surgeon) and IsValid(target) and surgeon:Alive() and target:Alive()
			and surgeon:GetPos():Distance(target:GetPos()) <= ix.Amputation.range * 1.5
			and !surgeon:KeyDown(IN_RELOAD)

		if !ok then
			timer.Remove(timerName)

			if IsValid(surgeon) then
				surgeon:SetAction()
				surgeon:NotifyLocalized("amputation.interrupted")
			end

			if IsValid(target) then
				target:SetAction()
				target:NotifyLocalized("amputation.interrupted")
			end

			return
		end

		if onTick then
			onTick(tick, ticks)
		end

		if timer.RepsLeft(timerName) == 0 then
			onFinish()
		end
	end)
end

-- Хирург режет цель. Вызывается только после явного согласия жертвы.
function Amputation.BeginCut(surgeon, target, key, item)
	local limb = Amputation.limbs[key]
	if !limb then return end

	surgeon:SetAction("@amputation.cutting", Amputation.cutTime)
	target:SetAction("@amputation.beingCut", Amputation.cutTime)

	surgeon.ixAmputationBusy = true
	target.ixAmputationBusy = true

	local nextPain = 0

	RunOperation("cut", surgeon, target, Amputation.cutTime, function(tick, ticks)
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

		-- Хирург забирает отрезанную конечность.
		local itemID = Amputation.limbItems[key]

		if itemID then
			local instance = ix.Item:Instance(itemID)

			if instance then
				-- Если инвентарь полон, конечность падает под ноги хирурга.
				if !surgeon:AddItem(instance) then
					ix.Item:DropItem(surgeon, instance.id)
				end
			end
		end

		surgeon:NotifyLocalized("amputation.cutDone")
	end)
end

-- Запрос согласия. Жертва может отказаться — тогда ничего не происходит.
function Amputation.RequestCut(surgeon, target, key, item)
	local limb = Amputation.limbs[key]
	if !limb then return end

	if pending[target] or target.ixAmputationBusy or surgeon.ixAmputationBusy then
		surgeon:NotifyLocalized("amputation.busy")
		return
	end

	pending[target] = {
		surgeon = surgeon,
		key = key,
		item = item,
		expires = CurTime() + Amputation.consentTimeout
	}

	surgeon:NotifyLocalized("amputation.requestSent")

	net.Start("ixAmputationRequest")
		net.WriteString(surgeon:Name())
		net.WriteString(key)
	net.Send(target)
end

net.Receive("ixAmputationConsent", function(_, target)
	local request = pending[target]
	if !request then return end

	pending[target] = nil

	local consent = net.ReadBool()
	local surgeon = request.surgeon

	if !IsValid(surgeon) or CurTime() > request.expires then return end

	if !consent then
		surgeon:NotifyLocalized("amputation.denied")
		target:NotifyLocalized("amputation.deniedSelf")
		return
	end

	-- Условия перепроверяются: за время раздумий всё могло измениться.
	if !target:Alive() or !surgeon:Alive() then return end
	if Amputation.Get(target:GetCharacter()) then return end
	if !Amputation.HasSkill(surgeon:GetCharacter()) then return end
	if surgeon:GetPos():Distance(target:GetPos()) > Amputation.range * 1.5 then return end

	Amputation.BeginCut(surgeon, target, request.key, request.item)
end)

-- Пришивание: нужен навык, нужная конечность у предмета и её отсутствие у цели.
function Amputation.BeginReattach(surgeon, target, item)
	local key = Amputation.Get(target:GetCharacter())

	surgeon:SetAction("@amputation.reattaching", Amputation.reattachTime)
	target:SetAction("@amputation.beingReattached", Amputation.reattachTime)

	surgeon.ixAmputationBusy = true
	target.ixAmputationBusy = true

	RunOperation("fix", surgeon, target, Amputation.reattachTime, nil, function()
		surgeon.ixAmputationBusy = nil
		target.ixAmputationBusy = nil

		surgeon:SetAction()

		-- Предмет мог быть выброшен, а цель — вылечена за время операции.
		if !ix.Item.instances[item.id] then return end
		if Amputation.Get(target:GetCharacter()) != key then return end

		Amputation.Restore(target)

		item:Remove()

		surgeon:NotifyLocalized("amputation.reattachDone")
		target:NotifyLocalized("amputation.restored")
	end)
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

