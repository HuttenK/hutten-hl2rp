local PANEL = {}
local scale = ix.UI.Scale

local categories = {}
local recipesList = {}

local function DrawCorners(x, y, w, h)
	surface.SetDrawColor(8, 32, 48, 128)
	surface.DrawRect(x, y, w, h)
	
	local size = ix.UI.Scale( (h / 4) * 0.1 )

	surface.SetDrawColor(0, 190, 255, 255)
	surface.DrawLine(x, y, x + size, y)
	surface.DrawLine(x, y, x, y + size)

	x, y = w - 1, y

	surface.DrawLine(x, y, x - size, y)
	surface.DrawLine(x, y, x, y + size)

	x, y = 0, h - 1

	surface.DrawLine(x, y, x + size, y)
	surface.DrawLine(x, y, x, y - size)

	x, y = w - 1, h - 1

	surface.DrawLine(x, y, x - size, y)
	surface.DrawLine(x, y, x, y - size)


	surface.SetDrawColor(0, 190, 255, 255 * 0.25)

	local halfW, halfH = w / 2, h /2
	local halfSize = size / 2

	x, y = halfW - size, 0
	surface.DrawLine(x, y, x + size * 2, y)
	y = h - 1
	surface.DrawLine(x, y, x + size * 2, y)
	x, y = 0, halfH - size
	surface.DrawLine(x, y, x, y + size * 2)
	x = w - 1
	surface.DrawLine(x, y, x, y + size * 2)
end

local function SortByLevel(recipe)
	local TableMemberSort = function(a, b, MemberName, bReverse)
		if !istable(a) then return !bReverse end
		if !istable(b) then return bReverse end
		if !a.skill[2] then return !bReverse end
		if !b.skill[2] then return bReverse end

		return a.skill[2] < b.skill[2]
	end

	table.sort(recipe, function(a, b) return TableMemberSort(a, b, memberName, true) end)
end

local sortFuncCat = function(a, b)
	return a.category < b.category
end

function PANEL:Setup(isMini, inventoryID)
	local parent = self:GetParent()
	local stationID = parent.station and parent.station.uniqueID or nil
	local oneSize = parent:GetWide() / (isMini and 2 or 3)
	local margin = scale(20)

	local first = parent:Add("Panel")
	first:Dock(LEFT)
	first:DockMargin(!isMini and margin or 0, !isMini and margin or 0, margin, !isMini and margin or 0)
	first:SetSize(oneSize * 0.95, parent:GetTall())
	first.Paint = function(panel, w, h)
		DrawCorners(0, 0, w, h)
	end
	
	local firstTitle = first:Add("DLabel")
	firstTitle:Dock(TOP)
	firstTitle:DockMargin(0, 10, 0, 0)
	firstTitle:SetContentAlignment(5)
	firstTitle:SetTextColor(Color(0, 225, 255))
	firstTitle:SetFont("craft.item.title")
	firstTitle:SetText(L("craftRecipesTitle"))

	local search = first:Add("DTextEntry")
	search:Dock(TOP)
	search:DockMargin(scale(10), scale(8), scale(10), 0)
	search:SetTall(scale(22))
	search:SetFont("ui.craft.large")
	search:SetUpdateOnType(true)
	search:SetPaintBackground(false)
	search.Paint = function(panel, w, h)
		surface.SetDrawColor(8, 32, 48, 200)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(0, 190, 255, 120)
		surface.DrawOutlinedRect(0, 0, w, h)

		panel:DrawTextEntryText(Color(0, 225, 255), Color(0, 120, 200), Color(0, 225, 255))

		if panel:GetText() == "" and !panel:IsEditing() then
			surface.SetFont("ui.craft.large")
			surface.SetTextColor(0, 150, 190, 160)

			local _, ty = surface.GetTextSize("A")

			surface.SetTextPos(scale(4), h * 0.5 - ty * 0.5)
			surface.DrawText(L("craftSearch"))
		end
	end

	parent.first = first:Add("DScrollPanel")
	parent.first:Dock(FILL)
	parent.first:SetSize(first:GetWide(), first:GetTall())
	parent.first:DockMargin(margin * 0.5, margin, margin * 0.5, margin)
	
	local buttonHeight = scale(20)
	local iconOffset, sizeIcon = scale(5), scale(15)

	self:GetParent():CacheRecipeNeeds()

	local categories = {}
	local recipesList = {}
	local flatRecipes = {} -- плоский список всех доступных здесь рецептов, для поиска

	for _, recipe in pairs(ix.Craft.recipes) do
		if recipe.skill then
			local skill = recipe.skill[1]
			local level = recipe.skill[2]

			local currentLevel = LocalPlayer():GetCharacter():GetSkillModified(skill)

			if level > currentLevel then
				continue
			end
		end

		if recipe.blueprint then
			local learned = LocalPlayer():GetCharacter():GetData("craftLearned", {})

			if !learned[recipe.uniqueID] then
				continue
			end
		end

		-- Station filter (additive): the combine terminal is a master station and
		-- shows everything. Station-less recipes (basics) show everywhere — at any
		-- bench and in the F1 menu. Bench-bound recipes only show at their bench.
		if stationID != "station_combine" and recipe.station then
			local match = false

			if istable(recipe.station) then
				for _, v in ipairs(recipe.station) do
					if v == stationID then
						match = true
						break
					end
				end
			else
				match = recipe.station == stationID
			end

			if !match then
				continue
			end
		end

		if recipe.mainCategory then
			flatRecipes[#flatRecipes + 1] = recipe

			local list = recipesList[recipe.mainCategory] or {recipes = {}, subcategories = {}, noSkill = true}

			if recipe.category then
				list.subcategories[recipe.category] = list.subcategories[recipe.category] or {}
				
				table.insert(list.subcategories[recipe.category], recipe)
			else
				list.recipes[#list.recipes + 1] = recipe
			end

			recipesList[recipe.mainCategory] = list
		else
			if !recipe.skill then continue end

			flatRecipes[#flatRecipes + 1] = recipe

			local list = recipesList[recipe.skill[1]] or {recipes = {}, subcategories = {}}

			if recipe.category then
				list.subcategories[recipe.category] = list.subcategories[recipe.category] or {}
				
				table.insert(list.subcategories[recipe.category], recipe)
			else
				list.recipes[#list.recipes + 1] = recipe
			end

			recipesList[recipe.skill[1]] = list
		end
	end

	for category, recipeList in pairs(recipesList) do
		categories[#categories + 1] = {
			recipesList = recipeList,
			category = category
		}

		if !recipeList.noSkill then
			SortByLevel(recipeList.recipes)
		end

		local subCategoryList = {}
		for subCategory, subCatRecipeList in pairs(recipeList.subcategories) do
			subCategoryList[#subCategoryList + 1] = {
				recipesList = subCatRecipeList,
				category = subCategory,
				noSkill = recipeList.noSkill
			}

			if !recipeList.noSkill then
				SortByLevel(subCatRecipeList)
			end
		end

		recipeList.subcategories = subCategoryList
		table.sort(recipeList.subcategories, sortFuncCat)
	end

	table.sort(categories, sortFuncCat)

	ix.gui.craft_categories = ix.gui.craft_categories or {}

	local category_style = Color(0, 225, 255)

	for k, v in ipairs(categories) do
		local noSkill = (v.recipesList or {}).noSkill
		local collapsibleCategory = parent.first:Add("DCollapsibleCategory")

		ix.gui.craft_categories[v.category] = ix.gui.craft_categories[v.category] or {false, {}}

		collapsibleCategory:Dock(TOP)
		collapsibleCategory:SetTall(buttonHeight)
		collapsibleCategory:SetZPos(k)
		if k == 1 then
			collapsibleCategory:DockMargin(0, scale(10), 0, scale(10))
		else
			collapsibleCategory:DockMargin(0, 0, 0, scale(10))
		end
		collapsibleCategory:SetLabel("")
		collapsibleCategory:SetExpanded(false)
		collapsibleCategory.Paint = function(_, w, h)
			surface.SetDrawColor(category_style)

			if collapsibleCategory:GetExpanded() then
				surface.SetMaterial(ix.util.GetMaterial("cellar/ui/minus.png"))
				surface.DrawTexturedRect(iconOffset, buttonHeight * 0.5 - sizeIcon * 0.5, sizeIcon, sizeIcon)
			else
				surface.SetMaterial(ix.util.GetMaterial("cellar/ui/plus.png"))
				surface.DrawTexturedRect(iconOffset, buttonHeight * 0.5 - sizeIcon * 0.5, sizeIcon, sizeIcon)
			end
		end
		collapsibleCategory.OnToggle = function(_, expanded)
			ix.gui.craft_categories[v.category][1] = expanded
		end
		collapsibleCategory:GetChildren()[1]:SetHeight(buttonHeight)
		
		local categoryTitle = vgui.Create("DLabel", collapsibleCategory)
		
		categoryTitle:SetText(noSkill and L(v.category) or ix.skills.list[v.category].name)
		categoryTitle:SetFont("ui.craft.large")
		categoryTitle:SetTextColor(category_style)
		categoryTitle:SizeToContents()
		categoryTitle:SetPos(iconOffset + sizeIcon * 1.75, collapsibleCategory:GetTall() * 0.5 - categoryTitle:GetTall() * 0.5)

		local categoryList = vgui.Create("DScrollPanel", collapsibleCategory)
		categoryList:Dock(FILL)

		collapsibleCategory:SetContents(categoryList)

		for _, recipe in ipairs(v.recipesList.recipes) do
			parent.recipeData = {
				recipe = recipe
			}

			categoryList:AddItem(vgui.Create("ui.craft.item", parent))
		end

		for _, v2 in ipairs(v.recipesList.subcategories) do
			local collapsibleSubCategory = vgui.Create("DCollapsibleCategory", categoryList)
			ix.gui.craft_categories[v.category][2][v2.category] = ix.gui.craft_categories[v.category][2][v2.category] or false
			collapsibleSubCategory:Dock(TOP)
			collapsibleSubCategory:SetLabel("")
			collapsibleSubCategory:DockMargin(0, scale(5), 0, 0)
			collapsibleSubCategory:SetExpanded( false )
			collapsibleSubCategory:SetTall(buttonHeight)
			collapsibleSubCategory.Paint = function(_, w, h)
				surface.SetDrawColor(category_style)

				if collapsibleSubCategory:GetExpanded() then
					surface.SetMaterial(ix.util.GetMaterial("cellar/ui/minus.png"))
					surface.DrawTexturedRect(iconOffset + iconOffset * 2, buttonHeight * 0.5 - sizeIcon * 0.5, sizeIcon, sizeIcon)
				else
					surface.SetMaterial(ix.util.GetMaterial("cellar/ui/plus.png"))
					surface.DrawTexturedRect(iconOffset + iconOffset * 2, buttonHeight * 0.5 - sizeIcon * 0.5, sizeIcon, sizeIcon)
				end
			end
			collapsibleSubCategory.OnToggle = function(_, expanded)
				ix.gui.craft_categories[v.category][2][v2.category] = expanded
			end
			
			collapsibleSubCategory.name = v2.category
			collapsibleSubCategory:GetChildren()[1]:SetHeight(buttonHeight)


			local subcategoryTitle = vgui.Create("DLabel", collapsibleSubCategory)
			subcategoryTitle:SetText(L(v2.category))
			subcategoryTitle:SetFont("ui.craft.large")
			subcategoryTitle:SetTextColor(category_style)
			subcategoryTitle:SizeToContents()
			subcategoryTitle:SetPos(iconOffset + sizeIcon * 2.75, collapsibleSubCategory:GetTall() * 0.5 - subcategoryTitle:GetTall() * 0.5 + scale(1 / 3))

			local subcategoryList = vgui.Create("DScrollPanel", collapsibleSubCategory)
			subcategoryList:Dock(FILL)
			subcategoryList.name = v2.category
			collapsibleSubCategory:SetContents(subcategoryList)

			for _, recipe in ipairs(v2.recipesList) do
				parent.recipeData = {
					recipe = recipe
				}

				subcategoryList:AddItem(vgui.Create("ui.craft.item", parent))
			end

			collapsibleSubCategory:SetExpanded(ix.gui.craft_categories[v.category][2][v2.category])
		end

		collapsibleCategory:SetExpanded(ix.gui.craft_categories[v.category][1])
	end

	-- Результаты поиска: плоский список, подменяющий дерево категорий, пока в
	-- строке поиска что-то есть. Скрытые Dock(FILL) панели пропускаются раскладкой,
	-- поэтому активной всегда остаётся ровно одна из двух.
	local searchResults = first:Add("DScrollPanel")
	searchResults:Dock(FILL)
	searchResults:DockMargin(margin * 0.5, margin, margin * 0.5, margin)
	searchResults:SetVisible(false)

	parent.searchResults = searchResults

	local function RunSearch(query)
		-- string.lower не трогает кириллицу (работает только с ASCII), поэтому
		-- «Бинт» не находился по запросу «бинт». utf8lower обрабатывает и то и другое.
		query = string.utf8lower(string.Trim(query or ""))

		if query == "" then
			searchResults:SetVisible(false)
			searchResults:Clear()
			parent.first:SetVisible(true)
			first:InvalidateLayout(true)

			return
		end

		parent.first:SetVisible(false)
		searchResults:SetVisible(true)
		searchResults:Clear()

		local matches = {}

		for _, recipe in ipairs(flatRecipes) do
			if string.find(string.utf8lower(recipe:GetName() or ""), query, 1, true) then
				matches[#matches + 1] = recipe
			end
		end

		table.sort(matches, function(a, b)
			return (a:GetName() or "") < (b:GetName() or "")
		end)

		if #matches == 0 then
			local empty = searchResults:Add("DLabel")
			empty:Dock(TOP)
			empty:DockMargin(scale(10), scale(10), 0, 0)
			empty:SetFont("ui.craft.large")
			empty:SetTextColor(Color(255, 72, 72))
			empty:SetText(L("craftSearchNoResults"))
			empty:SizeToContents()
		else
			for _, recipe in ipairs(matches) do
				parent.recipeData = {recipe = recipe}

				searchResults:AddItem(vgui.Create("ui.craft.item", parent))
			end
		end

		first:InvalidateLayout(true)
	end

	search.OnValueChange = function(panel, value)
		RunSearch(value)
	end

	local second = parent:Add("Panel")
	second:Dock(!isMini and LEFT or FILL)
	second:DockMargin(0, !isMini and margin or 0, 0, 0)
	second:InvalidateParent(true)
	if !isMini then
		second:SetSize(oneSize - margin, parent:GetTall())
	end
	
	parent.second = second:Add("DScrollPanel")
	parent.second:Dock(TOP)
	if !isMini then
		parent.second:SetSize(second:GetWide(), second:GetTall() * 0.525)
	else
		parent.second:Dock(FILL)
		//parent.second:SetSize(second:GetWide(), second:GetTall())
	end
	parent.second:DockMargin(0, 0, 0, margin)
	parent.second:InvalidateParent(true)
	parent.second.Paint = function(panel, w, h)
		DrawCorners(0, 0, w, h)
	end

	second:InvalidateParent(true)

	if !isMini then
		local inv = second:Add("Panel")
		inv:Dock(FILL)
		inv:DockMargin(0, 0, 0, 10)
		inv:InvalidateParent(true)
		inv.Paint = function(panel, w, h)
			DrawCorners(0, 0, w, h)
		end

		local firstTitle = inv:Add("DLabel")
		firstTitle:Dock(TOP)
		firstTitle:DockMargin(0, 10, 0, 0)
		firstTitle:SetContentAlignment(5)
		firstTitle:SetTextColor(Color(0, 225, 255))
		firstTitle:SetFont("craft.item.title")
		firstTitle:SetText(L("inv"))

		local panel = inv:Add('ui.inv')
		panel:SetSlotSize(64, 64)
		panel:SetInventoryID(LocalPlayer():GetInventory('main').id)
		panel:Rebuild()
		panel:SizeToContents()
		panel:Center()

		LocalPlayer():GetInventory('main').panel = panel
	end

	local button = second:Add('ui.craft.button')
	button:Dock(BOTTOM)
	button:SetText(L("craftCreate"))
	button:DockMargin(0, 0, 0, !isMini and margin or 0)
	button:SetTall(scale(40))
	button.DoClick = function()
		net.Start("ixCraftRecipe")
			net.WriteString(ix.gui.currentCraft)
		net.SendToServer()

		surface.PlaySound("helix/ui/press.wav")
	end
	
	parent.button = button

	if !isMini then
		local third = parent:Add("Panel")
		third:Dock(FILL)
		third:DockMargin(margin, margin, margin, margin)
		third:SetSize(oneSize, parent:GetTall())
		third.Paint = function(panel, w, h)
			DrawCorners(0, 0, w, h)
		end

		local stationTitle = third:Add("DLabel")
		stationTitle:Dock(TOP)
		stationTitle:DockMargin(0, 10, 0, 0)
		stationTitle:SetContentAlignment(5)
		stationTitle:SetTextColor(Color(0, 225, 255))
		stationTitle:SetFont("craft.item.title")
		stationTitle:SetText(L("craftStationTitle"))

		third:InvalidateParent(true)

		local panel = third:Add('ui.inv')
		//panel:Dock(TOP)
		panel:SetSlotSize(64, 64)
		panel:SetInventoryID(inventoryID)
		panel:Rebuild()

		ix.Inventory:Get(inventoryID).panel = panel

		panel:SizeToContents()
		panel:Center()
	end
end

vgui.Register("ui.craft.container", PANEL, "Panel")