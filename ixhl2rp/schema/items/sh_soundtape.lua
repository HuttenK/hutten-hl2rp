-- ixhl2rp/schema/items/sh_soundtape.lua
-- Администратор задаёт путь к звуку через панель ввода.
-- После установки кассета выкладывается в мир как статичный объект
-- и воспроизводит звук для всех игроков поблизости.

ITEM.name        = "item.soundtape"
ITEM.description = "Аудиопроигрыватель. Кажется кто-то успел записать на него некое сообщение"
ITEM.model       = "models/illusion/eftcontainers/rfidreader.mdl"
ITEM.category    = "item.category.misc"
ITEM.width       = 1
ITEM.height      = 1
ITEM.rarity      = 2

-- Путь к звуку — видно всем, чтобы кнопки Play/Stop отображались у всех игроков
ITEM:AddData("sound", {
	Transmit = ix.transmit.all,
})

-- Метка/название кассеты — видно всем
ITEM:AddData("label", {
	Transmit = ix.transmit.all,
})

-- ── Кнопка: Задать звук (только администраторы) ───────────────────────────
ITEM.functions.SetSound = {
	name     = "use.setSound",
	tip      = "use.setSound.tip",
	icon     = "icon16/sound.png",

	OnRun = function(item)
		-- Открываем панель ввода на клиенте
		netstream.Start(item.player, "ixSoundTapeEdit", {
			id    = item.id,
			sound = item:GetData("sound", ""),
			label = item:GetData("label", ""),
		})
		return false
	end,

	OnCanRun = function(item)
		if IsValid(item.entity) then return false end
		return item.player:IsAdmin() or item.player:IsSuperAdmin()
	end
}

function ITEM:CanTransfer(oldInventory, newInventory)
	if newInventory and self:GetData("sound", "") != "" then
		return false
	end
end

-- Если у кассеты задан звук — запрещаем подбор через стандартный take.
-- Это скрывает UI «ВЗЯТЬ» и не даёт PerformInteraction запуститься.
-- Воспроизведение/остановка обрабатываются через Schema:PlayerUse в sv_hooks.lua.
ITEM.functions.take = ITEM.functions.take or {}
local _origTakeCanRun = ITEM.functions.take.OnCanRun
ITEM.functions.take.OnCanRun = function(item)
	if IsValid(item.entity) and item:GetData("sound", "") != "" then
		return false
	end
	return _origTakeCanRun and _origTakeCanRun(item) or true
end

-- ── Кнопка: Воспроизвести ────────────────────────────────────────────────
-- Если метка задана — она полностью заменяет название предмета в инвентаре
function ITEM:GetPrintName()
	local label = self:GetData("label", "")
	if label and label != "" then
		return label
	end
	return L(self.name or "unknown")
end

-- Удерживать E на сущности: первое нажатие — воспроизвести, второе — остановить.
-- Логика в sv_hooks.lua (hook CanPlayerTakeItem).

-- ─────────────────────────────────────────────────────────────────────────────
-- SERVER-хуки вынесены в ixhl2rp/schema/sv_hooks.lua (netstream.Hook)
-- CLIENT-хуки вынесены в ixhl2rp/schema/cl_hooks.lua (ixSoundTapeEdit)
-- ─────────────────────────────────────────────────────────────────────────────
