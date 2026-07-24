local PLUGIN = PLUGIN

PLUGIN.name = "Amputation"
PLUGIN.author = "Claude"
PLUGIN.description = "Разрушенная конечность отнимается навсегда: модель, ходьба и оружие."

-- Ампутация хранится в данных персонажа (character:GetData("amputation")) как
-- ключ конечности. Это источник истины: он переживает респавн, смену модели и
-- перезапуск сервера. Визуально конечность убирается сжатием кости в ноль
-- (ManipulateBoneScale) — у моделей игроков нет бодигрупп для культи.
ix.Amputation = ix.Amputation or {}

local Amputation = ix.Amputation

-- Загрузчик плагинов подключает только sh_plugin.lua — остальные файлы вручную.
-- Подключается ниже, после объявления таблицы конечностей.

-- НЕ Vector(0,0,0)! Нулевой масштаб кости даёт вырожденную (сингулярную) матрицу:
-- движок считает по ней AABB хитбокса и рендер-границ, получает inf/NaN, и границы
-- сущности становятся фактически бесконечными. Отсюда две проблемы у ампутанта —
-- «раздутый» хитбокс (пули попадают в пустоту вокруг) и застревание камеры от 3-го
-- лица (трасса упирается в гигантский объём). Крошечный ненулевой масштаб убирает
-- сингулярность, а начало кости всё равно не двигается — визуально то же самое.
Amputation.scale = Vector(0.01, 0.01, 0.01)
Amputation.normal = Vector(1, 1, 1)

Amputation.noOffset = Vector(0, 0, 0)

-- ТОЛЬКО МАСШТАБ. ManipulateBonePosition здесь не использовать — проверено дважды:
--
--  * сдвиг корня цепочки (Forearm/Calf) растягивает вершины сустава в длинные
--    полосы кожи через всё тело: они привязаны и к оставленной кости выше;
--  * сдвиг кисти и пальцев «к локтю» уносит кости в мир на десятки метров —
--    смещение задаётся не в той системе координат, в которой лежит локальная
--    позиция кости.
--
-- Обнуление масштаба схлопывает геометрию в точку САМОЙ кости, но точку не
-- двигает, поэтому у сустава остаётся небольшой плоский остаток от вершин,
-- частично привязанных к сохранённой кости. Убрать его манипуляцией костей
-- нельзя — нужна культя в самой модели (бодигруппа).

-- Модификатор скорости при потере ноги и шанс споткнуться (за одну проверку).
Amputation.legSpeed = 0.45
Amputation.stumbleChance = 0.06
Amputation.stumbleInterval = 1
Amputation.stumbleTime = 3

-- Ампутация холодным оружием.
Amputation.skill = "medicine"
Amputation.skillRequired = 5
Amputation.cutTime = 60
Amputation.reattachTime = 45
Amputation.range = 96
Amputation.consentTimeout = 30

-- Только тяжёлые клинки и ножи: перерубить кость вилкой или отвёрткой нельзя,
-- хотя формально у них тоже Info.Class == "slash". uniqueID = имя файла без
-- префикса sh_ и расширения (sh_wm_axe.lua -> wm_axe).
Amputation.tools = {
	["wm_axe"] = true,
	["wm_fireaxe"] = true,
	["wm_ice_axe"] = true,
	["wm_cleaver"] = true,
	["wm_machete"] = true,
	["wm_katana"] = true,
	["wm_modern_sword"] = true,
	["wm_kitchen_knife"] = true,
	["wm_combat_knife"] = true,
	["wm_sickle"] = true,
	["wm_razor"] = true,
}

-- Предмет-конечность, который получает хирург и которым конечность пришивают.
Amputation.limbItems = {
	larm = "limb_larm",
	rarm = "limb_rarm",
	lleg = "limb_lleg",
	rleg = "limb_rleg",
}

function Amputation.HasSkill(character)
	if !character then return false end

	return character:GetSkillModified(Amputation.skill) >= Amputation.skillRequired
end

function Amputation.IsTool(item)
	return item != nil and Amputation.tools[item.uniqueID] == true
end

-- Цель под прицелом: живой игрок либо его рэгдолл (ixPlayer), как в medical.
function Amputation.GetTarget(client)
	local data = {}
		data.start = client:GetShootPos()
		data.endpos = data.start + client:GetAimVector() * Amputation.range
		data.filter = client

	local target = util.TraceLine(data).Entity

	if IsValid(target) and IsValid(target.ixPlayer) then
		target = target.ixPlayer
	end

	if !IsValid(target) or !target:IsPlayer() then return end

	return target
end

-- Корень цепочки — первая удаляемая кость. Рука отнимается по локоть, нога — по
-- колено: плечо (UpperArm, вместе с дельтой) и бедро (Thigh) остаются на месте,
-- иначе сустав срезается вместе с конечностью и плечо выглядит рубленым.
--
-- ВАЖНО: ManipulateBoneScale НЕ наследуется дочерними костями — каждую кость
-- нужно сжимать отдельно. Поэтому список костей собирается по скелету во время
-- выполнения (см. Amputation.CollectBones): корень + все его потомки. Иначе
-- останутся висеть пальцы и фаланги.
Amputation.limbs = {
	larm = {
		hitgroup = HITGROUP_LEFTARM,
		kind = "arm",
		phrase = "amputation.larm",
		root = "ValveBiped.Bip01_L_Forearm"
	},
	rarm = {
		hitgroup = HITGROUP_RIGHTARM,
		kind = "arm",
		phrase = "amputation.rarm",
		root = "ValveBiped.Bip01_R_Forearm"
	},
	lleg = {
		hitgroup = HITGROUP_LEFTLEG,
		kind = "leg",
		phrase = "amputation.lleg",
		root = "ValveBiped.Bip01_L_Calf"
	},
	rleg = {
		hitgroup = HITGROUP_RIGHTLEG,
		kind = "leg",
		phrase = "amputation.rleg",
		root = "ValveBiped.Bip01_R_Calf"
	},
}

-- Возвращает индексы корневой кости конечности и всех её потомков у данной
-- модели. Работает на любом скелете, где корень найден по имени.
function Amputation.CollectBones(entity, limb)
	if !IsValid(entity) or !limb then return end

	local root = entity:LookupBone(limb.root)
	if !root then return end

	local bones = {root}

	-- Порядок костей в модели не гарантирован, поэтому для каждой кости
	-- поднимаемся по родителям и проверяем, не встретится ли корень конечности.
	for i = 0, entity:GetBoneCount() - 1 do
		if i == root then continue end

		local parent = entity:GetBoneParent(i)
		local depth = 0

		while parent and parent >= 0 and depth < 64 do
			if parent == root then
				bones[#bones + 1] = i
				break
			end

			parent = entity:GetBoneParent(parent)
			depth = depth + 1
		end
	end

	return bones
end

Amputation.byHitgroup = {}

for key, limb in pairs(Amputation.limbs) do
	limb.key = key
	Amputation.byHitgroup[limb.hitgroup] = key
end

-- Один персонаж — одна потерянная конечность.
function Amputation.Get(character)
	if !character then return end

	local key = character:GetData("amputation")

	return key and Amputation.limbs[key] and key or nil
end

function Amputation.GetLimb(character)
	local key = Amputation.Get(character)

	return key and Amputation.limbs[key] or nil
end

function Amputation.HasKind(character, kind)
	local limb = Amputation.GetLimb(character)

	return limb != nil and limb.kind == kind
end

-- Двуручным считается основное оружие; отдельные предметы могут задать
-- ITEM.twoHanded явно (например двуручная кувалда из категории melee).
function Amputation.IsTwoHanded(item)
	if item.twoHanded != nil then
		return item.twoHanded
	end

	return item.weaponCategory == "primary"
end

ix.lang.AddTable("ru", {
	["amputation.larm"] = "левая рука",
	["amputation.rarm"] = "правая рука",
	["amputation.lleg"] = "левая нога",
	["amputation.rleg"] = "правая нога",
	["amputation.lost"] = "Вы потеряли конечность: %s!",
	["amputation.stumble"] = "Вы теряете равновесие.",
	["amputation.noTwoHanded"] = "Одной рукой это оружие не удержать.",
	["amputation.restored"] = "Конечность восстановлена.",
	["amputation.already"] = "У этого персонажа уже нет одной конечности.",
	["amputation.none"] = "У этого персонажа все конечности на месте.",
	["amputation.badLimb"] = "Неизвестная конечность. Допустимо: larm, rarm, lleg, rleg.",

	["amputation.cut"] = "Отрезать конечность",
	["amputation.reattach"] = "Пришить конечность",
	["amputation.cutting"] = "Ампутация...",
	["amputation.beingCut"] = "Вам отрезают конечность...",
	["amputation.reattaching"] = "Пришивание конечности...",
	["amputation.beingReattached"] = "Вам пришивают конечность...",
	["amputation.noSkill"] = "Нужен навык медицины 5.",
	["amputation.noTarget"] = "Перед вами нет человека.",
	["amputation.targetHasLimb"] = "У этого человека уже нет одной конечности.",
	["amputation.busy"] = "Этот человек сейчас занят.",
	["amputation.request"] = "%s хочет отрезать вам: %s. Согласиться?",
	["amputation.requestSent"] = "Вы ждёте согласия.",
	["amputation.denied"] = "Вам отказали.",
	["amputation.deniedSelf"] = "Вы отказались.",
	["amputation.interrupted"] = "Операция прервана.",
	["amputation.cutDone"] = "Конечность отделена.",
	["amputation.reattachDone"] = "Конечность пришита.",
	["amputation.wrongLimb"] = "Эта конечность сюда не подходит.",
	["amputation.notMissing"] = "У этого человека все конечности на месте.",

	-- Сообщения жертве во время операции.
	["amputation.pain1"] = "Кто-то режет вашу плоть. Боль невыносима.",
	["amputation.pain2"] = "Лезвие скребёт по кости. Вы кричите.",
	["amputation.pain3"] = "Вы чувствуете, как хрустит кость.",
	["amputation.pain4"] = "В глазах темнеет от боли.",
	["amputation.pain5"] = "Конечность повисает на лоскуте кожи.",
})
ix.lang.AddTable("en", {
	["amputation.larm"] = "left arm",
	["amputation.rarm"] = "right arm",
	["amputation.lleg"] = "left leg",
	["amputation.rleg"] = "right leg",
	["amputation.lost"] = "You have lost a limb: %s!",
	["amputation.stumble"] = "You lose your balance.",
	["amputation.noTwoHanded"] = "You cannot hold this weapon with one arm.",
	["amputation.restored"] = "The limb has been restored.",
	["amputation.already"] = "That character has already lost a limb.",
	["amputation.none"] = "That character has all their limbs.",
	["amputation.badLimb"] = "Unknown limb. Valid: larm, rarm, lleg, rleg.",

	["amputation.cut"] = "Cut off a limb",
	["amputation.reattach"] = "Reattach the limb",
	["amputation.cutting"] = "Amputating...",
	["amputation.beingCut"] = "A limb is being cut off...",
	["amputation.reattaching"] = "Reattaching a limb...",
	["amputation.beingReattached"] = "A limb is being reattached...",
	["amputation.noSkill"] = "Requires medicine skill 5.",
	["amputation.noTarget"] = "There is nobody in front of you.",
	["amputation.targetHasLimb"] = "That person has already lost a limb.",
	["amputation.busy"] = "That person is busy right now.",
	["amputation.request"] = "%s wants to cut off your %s. Do you consent?",
	["amputation.requestSent"] = "Waiting for consent.",
	["amputation.denied"] = "You were refused.",
	["amputation.deniedSelf"] = "You refused.",
	["amputation.interrupted"] = "The operation was interrupted.",
	["amputation.cutDone"] = "The limb comes free.",
	["amputation.reattachDone"] = "The limb has been reattached.",
	["amputation.wrongLimb"] = "That limb does not belong there.",
	["amputation.notMissing"] = "That person has all their limbs.",

	["amputation.pain1"] = "Someone is cutting through your flesh. The pain is enormous.",
	["amputation.pain2"] = "The blade scrapes against bone. You scream.",
	["amputation.pain3"] = "You feel the bone crack.",
	["amputation.pain4"] = "Your vision darkens from the pain.",
	["amputation.pain5"] = "The limb hangs by a flap of skin.",
})

Amputation.painPhrases = {
	"amputation.pain1",
	"amputation.pain2",
	"amputation.pain3",
	"amputation.pain4",
	"amputation.pain5",
}

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")

-- Команды регистрируются в общем файле, иначе клиент не знает о них и не
-- показывает их в автодополнении чата. Сам OnRun выполняется только на сервере.
ix.command.Add("Amputate", {
	description = "Отнять конечность у персонажа (larm, rarm, lleg, rleg).",
	adminOnly = true,
	arguments = {ix.type.player, ix.type.string},
	OnRun = function(self, client, target, limbKey)
		limbKey = string.lower(limbKey)

		if !Amputation.limbs[limbKey] then
			return "@amputation.badLimb"
		end

		local character = target:GetCharacter()
		if !character then return end

		if Amputation.Get(character) then
			return "@amputation.already"
		end

		Amputation.Amputate(target, limbKey)
	end
})

-- Диагностика: почему не видно опцию «Отрезать конечность». Проверяет по очереди
-- всё, от чего зависит её появление в меню предмета и в радиальном меню.
ix.command.Add("AmputateCheck", {
	description = "Проверить, почему не появляется опция ампутации.",
	adminOnly = true,
	OnRun = function(self, client)
		local character = client:GetCharacter()
		local lines = {}

		local skill = character:GetSkillModified(Amputation.skill)

		lines[#lines + 1] = string.format("ix.Amputation loaded: %s", tostring(ix.Amputation != nil))
		lines[#lines + 1] = string.format("skill '%s' = %s (need %d): %s",
			Amputation.skill, tostring(skill), Amputation.skillRequired,
			Amputation.HasSkill(character) and "OK" or "FAIL -- опция скрыта")

		-- Функция должна быть зарегистрирована на базе оружия при загрузке.
		local sample = ix.Item.stored["wm_axe"]
		lines[#lines + 1] = string.format("item 'wm_axe' registered: %s | has amputate function: %s",
			tostring(sample != nil),
			tostring(sample != nil and sample.functions != nil and sample.functions.amputate != nil))

		-- Какие из носимых предметов признаются инструментом.
		local found = 0

		for _, item in ipairs(client:GetItems()) do
			if !istable(item) then continue end

			if Amputation.tools[item.uniqueID] then
				found = found + 1
				lines[#lines + 1] = string.format("  tool in inventory: %s (%s)", item.uniqueID, item:GetName())
			end
		end

		if found == 0 then
			lines[#lines + 1] = "  no qualifying blade in inventory -- опция скрыта"
		end

		local target = Amputation.GetTarget(client)
		lines[#lines + 1] = string.format("target in front: %s", IsValid(target) and target:Name() or "none")

		client:PrintMessage(HUD_PRINTCONSOLE, "\n[Amputation check]\n")

		for _, line in ipairs(lines) do
			client:PrintMessage(HUD_PRINTCONSOLE, "  " .. line .. "\n")
		end

		client:Notify("Результат в консоли (~).")
	end
})

-- Диагностика: печатает скелет цели в консоль — индекс, имя, родителя, входит ли
-- кость в удаляемую цепочку и какой масштаб/смещение реально стоят на ней.
-- Так видно, какие кости остались нетронутыми (например процедурные хелперы).
ix.command.Add("AmputateDebug", {
	description = "Показать скелет и манипуляции костей цели.",
	adminOnly = true,
	arguments = {ix.type.player},
	OnRun = function(self, client, target)
		local character = target:GetCharacter()
		local key = character and Amputation.Get(character)
		local limb = key and Amputation.limbs[key]

		local inLimb = {}

		if limb then
			for _, bone in ipairs(Amputation.CollectBones(target, limb) or {}) do
				inLimb[bone] = true
			end
		end

		client:PrintMessage(HUD_PRINTCONSOLE, string.format(
			"\n[Amputation] %s | model: %s | bones: %d | limb: %s\n",
			target:Name(), target:GetModel(), target:GetBoneCount(), key or "none"))
		client:PrintMessage(HUD_PRINTCONSOLE,
			"  idx  cut  name                                     parent  scale            pos\n")

		-- Печатаем ВЕСЬ скелет: важно видеть кости вне цепочки, к которым может
		-- быть привязана геометрия кисти (вспомогательные/процедурные кости).
		for i = 0, target:GetBoneCount() - 1 do
			local scale = target:GetManipulateBoneScale(i)
			local pos = target:GetManipulateBonePosition(i)

			client:PrintMessage(HUD_PRINTCONSOLE, string.format(
				"  %3d  %3s  %-40s %6d  %-16s %s\n",
				i,
				inLimb[i] and "CUT" or " - ",
				target:GetBoneName(i) or "?",
				target:GetBoneParent(i),
				tostring(scale),
				tostring(pos)))
		end
		client:Notify("Скелет выведен в консоль (~).")
	end
})

ix.command.Add("AmputateRestore", {
	description = "Вернуть персонажу утраченную конечность.",
	adminOnly = true,
	arguments = {ix.type.player},
	OnRun = function(self, client, target)
		if !Amputation.Restore(target) then
			return "@amputation.none"
		end

		target:NotifyLocalized("amputation.restored")
	end
})
