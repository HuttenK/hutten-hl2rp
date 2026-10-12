-- Результат сбора одного пропа заражённой флоры. Появляется в мире на месте
-- собранной флоры; игрок подбирает её в инвентарь. Можно позже сделать сдаваемой
-- (продажа/утилизация) — пока обычный предмет.
ITEM.name = "Мешок с заражённой флорой"
ITEM.description = "Собранная заражённая флора, упакованная для утилизации."
ITEM.model = Model(util.IsValidModel("models/hlvr/combine_hazardprops/combinehazardprops_trashbag.mdl") and "models/hlvr/combine_hazardprops/combinehazardprops_trashbag.mdl" or "models/props_junk/garbage_bag001a.mdl")
ITEM.width = 2
ITEM.height = 2
ITEM.category = "Снаряжение"

-- Распаковать мешок: выпускает заражение — основной проп флоры перед игроком и
-- облако газа, через несколько секунд вокруг появляется вторая волна пропов.
-- Их можно собрать обратно обычными пустыми контейнерами (см. sv_plugin.lua).
ITEM.functions.unpack = {
	name = "Распаковать (выпустить заражение)",
	OnRun = function(item)
		local client = item.player
		if (!IsValid(client)) then return false end

		local infection = ix.plugin.list["infectionzone"]

		if infection and infection.UnpackWaste and infection:UnpackWaste(client) == true then
            item:Remove()
            return true
        end
        return false
	end,
	OnCanRun = function(item)
		-- только из инвентаря (не когда мешок лежит в мире)
		return !IsValid(item:GetEntity())
	end,
}
