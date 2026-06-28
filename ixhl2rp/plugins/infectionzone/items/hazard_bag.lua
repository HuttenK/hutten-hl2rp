-- Контейнер для сбора заражённой флоры. Пока он лежит в инвентаре, игрок может
-- собирать флору в зонах заражения (нажатие E по пропу — см. sv_plugin.lua).
-- Имеет ограниченное число зарядов: каждый сбор расходует один, на нуле контейнер
-- исчезает.
ITEM.name = "Контейнер для биоматериала"
ITEM.description = "Прочный мешок для сбора заражённой флоры (10 зарядов). Держите его при себе и нажимайте E на флоре в зоне заражения."
ITEM.model = Model("models/hlvr/combine_hazardprops/combinehazardprops_clothe.mdl")
ITEM.width = 2
ITEM.height = 2
ITEM.category = "Снаряжение"
ITEM.uses = 10 -- сколько сборов выдерживает контейнер, прежде чем израсходуется

-- ВАЖНО: data-ключ нужно зарегистрировать, иначе item:SetData("uses", ...) молча
-- ничего не делает (см. ITEM:SetData — выходит, если ключ не в self.vars).
-- Transmit = owner: значение синхронизируется владельцу (для тултипа).
ITEM:AddData("uses", {
	Transmit = ix.transmit.owner,
})

-- Сколько зарядов осталось (по умолчанию — полный запас).
function ITEM:GetUses()
	return self:GetData("uses", self.uses)
end

-- При создании нового контейнера выдаём полный запас зарядов.
function ITEM:OnInstanced(isCreated)
	if (isCreated) then
		self:SetData("uses", self.uses)
	end
end

if (CLIENT) then
	function ITEM:PopulateTooltip(tooltip)
		if (!self:GetEntity()) then
			local row = tooltip:AddRowAfter("name")
			row:SetBackgroundColor(derma.GetColor("Success", tooltip))
			row:SetText("Зарядов: " .. self:GetUses() .. " / " .. self.uses)
		end
	end
end
