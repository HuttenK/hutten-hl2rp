local PLUGIN = PLUGIN

PLUGIN.name = "Транквилизатор"
PLUGIN.author = "Claude"
PLUGIN.description = "Нейротоксин из Зен-флоры: дротомёт (дальний) и инъектор (контактный). Цель падает (ragdoll) на 2 минуты, всё видит и слышит, но не может двигаться."

-- Длительность паралича по умолчанию (сек). Используется и дротомётом, и инъектором.
PLUGIN.tranqTime = 120

-- Слоты снаряжения, любой предмет в которых останавливает дротик.
local DART_PROOF_SLOTS = {"vest", "legprotection"}

local function GetSlotItem(client, slotType)
	local inventory = client:GetInventory(slotType)
	if (!inventory) then return end

	return inventory:GetItems()[1]
end

-- Защищена ли цель от ДАЛЬНЕГО дротика. Броня останавливает иглу; контактный
-- инъектор (tranq_injector) этой проверке не подчиняется — его втыкают вручную.
--
-- Считаем бронёй: бронежилет, защиту ног, а также цельные костюмы, которые сами
-- запрещают надевать жилет (форма ГО/OTA — isMPF, костюмы хим-защиты — blocksVest).
function PLUGIN:IsDartProof(victim)
	if (!IsValid(victim) or !victim:IsPlayer()) then return false end

	for _, slotType in ipairs(DART_PROOF_SLOTS) do
		if (GetSlotItem(victim, slotType)) then return true end
	end

	local torso = GetSlotItem(victim, "torso")

	return torso != nil and (torso.isMPF or torso.blocksVest) or false
end

if (SERVER) then
	-- Единая точка применения эффекта нейротоксина. Вызывается и оружием
	-- (weapon_ix_transvil), и контактным предметом (tranq_injector), чтобы
	-- эффект и сообщения жертве были одинаковыми.
	function PLUGIN:ApplyTranquilizer(victim, attacker, time)
		if (!IsValid(victim) or !victim:IsPlayer()) then return false end
		if (!victim.SetRagdolled) then return false end       -- метод даёт система здоровья
		if (!victim:Alive()) then return false end
		if (IsValid(victim.ixRagdoll)) then return false end  -- уже лежит — не накладываем повторно

		time = time or self.tranqTime

		-- Транквилизатор — это «сознательный паралич»: вид от первого лица, без
		-- размытия и без анимации смерти. Флаги ставим ДО SetRagdolled, чтобы
		-- мост анимаций смерти (OnCharacterFallover) пропустил этот рэгдолл.
		victim.ixNoDeathAnim = true
		victim:SetNetVar("ixTranq", true)

		victim:SetRagdolled(true, time)

		-- Убираем «грогги»-блюр, который SetRagdolled включает по умолчанию.
		victim:SetLocalVar("blur", nil)

		victim:EmitSound("vo/npc/male01/pain0" .. math.random(1, 6) .. ".wav")

		local fx = EffectData()
		fx:SetOrigin(victim:WorldSpaceCenter())
		fx:SetEntity(victim)
		util.Effect("BloodImpact", fx)

		-- === Сообщения жертве, чтобы она понимала своё состояние ===
		victim:Notify("Резкий укол — по телу мгновенно разливается жжение.")
		victim:Notify("Нейротоксин Зен-флоры парализовал вас: тело не слушается, но вы в сознании, всё видите и слышите.")

		-- Середина действия — напоминаем, что это пройдёт.
		timer.Simple(time * 0.5, function()
			if (IsValid(victim) and IsValid(victim.ixRagdoll)) then
				victim:Notify("Паралич держится. Двигаться невозможно — остаётся только ждать, пока токсин ослабнет.")
			end
		end)

		-- Почти отпустило.
		timer.Simple(math.max(1, time - 12), function()
			if (IsValid(victim) and IsValid(victim.ixRagdoll)) then
				victim:Notify("Чувствительность медленно возвращается в конечности — скоро вы сможете двигаться.")
			end
		end)

		-- Отпустило.
		timer.Simple(time, function()
			if (IsValid(victim)) then
				victim.ixNoDeathAnim = nil
				victim:SetNetVar("ixTranq", nil)

				if (victim:Alive()) then
					victim:Notify("Действие нейротоксина прошло. Вы снова можете двигаться.")
				end
			end
		end)

		if (IsValid(attacker) and attacker:IsPlayer() and attacker != victim) then
			attacker:Notify("Цель обездвижена нейротоксином.")
		end

		return true
	end

	-- Пункт радиального меню «Уколоть транквилизатором» (ix.menu.NetworkChoice
	-- → OnPlayerOptionSelected). Запускаем штатное применение инъектора из
	-- инвентаря: оно трассирует взгляд (после закрытия меню взгляд всё ещё на
	-- цели), требует контактного удержания и расходует предмет.
	function PLUGIN:OnPlayerOptionSelected(target, client, option)
		if (option != "TranqInject") then return end
		if (!IsValid(client) or !client:IsPlayer()) then return end

		local inv = client:GetInventory("main")
		if (!inv) then return end

		local has, item = inv:HasItem("tranq_injector")

		if (!has or !item) then
			client:Notify("У вас нет транквилизаторного инъектора.")
			return
		end

		ix.Item:PerformInventoryAction(client, item, inv.id, "Use", nil, 1)
	end
end

if (CLIENT) then
	-- Вид от первого лица, пока действует транквилизатор (глаза рэгдолла).
	-- Возвращаем значение из CalcView — это переопределяет вид гейммода.
	hook.Add("CalcView", "ixTranqFirstPerson", function(client, origin, angles, fov)
		if (client != LocalPlayer()) then return end
		if (!client:GetNetVar("ixTranq")) then return end

		local rag = Entity(client:GetLocalVar("ragdoll", 0))
		if (!IsValid(rag) or !rag:IsRagdoll()) then return end

		local idx = rag:LookupAttachment("eyes")
		if (idx and idx > 0) then
			local data = rag:GetAttachment(idx)
			if (data) then
				return {
					origin = data.Pos,
					angles = data.Ang,
					fov = fov,
					drawviewer = false
				}
			end
		end
	end)
end
