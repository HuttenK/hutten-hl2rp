local PANEL = {}
local scale = ix.UI.Scale

function PANEL:Init()
	local recipeData = self:GetParent().recipeData
	self:SetSize(self:GetParent().first:GetWide() - scale(40), scale(56))
	self:Dock(TOP)
	self.recipe = recipeData.recipe

	self.recipeButton = self:Add("DButton")

	function self.recipeButton.DoClick(spawnIcon)
		self:SetupCraft()

		surface.PlaySound("helix/ui/press.wav")
	end

	self.recipeButton:SetContentAlignment(4)

	if recipeData.recipe.category then
		self.recipeButton:SetTextInset(scale(18), 0)
	else
		self.recipeButton:SetTextInset(scale(18), 0)
	end

	self.recipeButton:SetFont("legends.Body")
	self.recipeButton:SetText("")
	self.recipeButton:Dock(FILL)
	self.recipeButton.OnCursorEntered = function()
		surface.PlaySound("helix/ui/rollover.wav")
	end
	self.recipeButton.Paint = function(panel,w,h)
  local U=ix.Legends
  local selected=ix.gui.currentCraft==self.recipe.uniqueID
  U.ButtonFace(panel,w,h,false,selected)
  U.Text(ix.Civic.Fit(self.recipe:GetName(),"Body",math.max(1,w-scale(38))),"Body",scale(18),scale(7),self:GetColor())
 end
 self:DockMargin(0,0,0,scale(6))

end

function PANEL:SetupCraft()
	ix.gui.currentCraft = self.recipe.uniqueID
	local parent = ix.gui.craftFrame
	if not parent or not IsValid(parent.itemIcon) then return end -- craftFrame not ready
 if IsValid(parent.emptyHint) then parent.emptyHint:SetVisible(false) end
	if IsValid(parent.button) then parent.button:SetDisabled(false) end

	-- Замыкания ниже вешаются на долгоживущие панели (parent.itemIcon), а сама
	-- строка рецепта может быть удалена (например, при фильтрации поиском).
	-- Индексирование удалённой панели даёт nil, поэтому держим рецепт по значению.
	local recipe = self.recipe

	local title = string.utf8upper(self.recipe:GetName())
	parent.craftTitle:SetText((self.recipe.isBreakdown and L("craftDisassemblePrefix") or "") .. title)
	parent.craftTitle:SetVisible(true)

	if self.recipe.isBreakdown then
		parent.button:SetText(L("craftDisassemble"))

		local client = LocalPlayer()
		parent.itemIcon:Rebuild(self.recipe.requirements, 64)
		parent.itemIcon.Think = function(_, w, h)
			if ix.gui.can_craft then
				_.hasItem = ix.gui.can_craft[recipe.uniqueID]
			end
		end
		parent.itemIcon.PaintOver = function(_, w, h)
			if !_.hasItem then 
				surface.SetDrawColor(96, 60, 60)
				surface.DrawRect(1, 1, w - 1, h - 1)

				_.mdl:PaintManual()

				surface.SetDrawColor(0, 0, 0, 64)
				surface.DrawRect(1, 1, w - 1, h - 1)

				render.OverrideBlend(true, 4, 6, BLENDFUNC_MIN, 4, 1, BLENDFUNC_ADD)
					draw.RoundedBox(0, 1, 1, w - 1, h - 1, Color(255, 0, 0, 255))
				render.OverrideBlend(false)

				surface.SetDrawColor(255, 32, 32, 128)
				surface.DrawOutlinedRect(1, 1, w - 1, h - 1)
			end
		end
	else
		parent.button:SetText(L("craftCreate"))

		parent.itemIcon.Think = nil
		parent.itemIcon.PaintOver = nil

		for item, count in pairs(self.recipe.results) do
			-- Количество результата может быть диапазоном {min, max} (см. OnCraft:
			-- math.random(amount[1], amount[2])). GetTextSize/DrawText принимают только
			-- строку, поэтому приводим к строке: диапазон -> "min-max", число -> tostring.
			local countText = istable(count) and (count[1] .. "-" .. count[2]) or tostring(count)

			parent.itemIcon:Rebuild(item, 64, self.recipe.preview)
			parent.itemIcon.PaintOver = function(_, w, h)
				surface.SetFont("craft.component.count")
				local x, z = surface.GetTextSize(countText)
				surface.SetTextColor(255, 255, 255, 255)
				surface.SetTextPos(w - x - 2, h - z)
				surface.DrawText(countText)
			end

			break
		end
	end

	parent.iconFrame:SetVisible(true)
	parent.iconFrame:SetTall(parent.itemIcon:GetTall() + 20)
	parent.itemIcon:Center()


	if self.recipe.station then
		local info = ix.Craft.stations[self.recipe.station]

		local name = ""
		local clr = Color(128, 128, 128, 255)
		if istable(self.recipe.station) then
			for k, v in ipairs(self.recipe.station) do
				local x = ix.Craft.stations[v]

				name = name .. L(x.name) .. ((k != #self.recipe.station) and " / " or "")
			end
		else
			name = L(info.name)
			local atStation = (parent.station or {}).uniqueID
			-- Stations must match the recipe.
			local satisfied = self.recipe.station == atStation
			clr = satisfied and Color(255, 255, 255, 255) or Color(255, 72, 72, 255)
		end

		parent.stationsPanel:SetVisible(true)
		parent.stations:SetText(name)
		parent.stations:SizeToContents()
		parent.stations:SetTextColor(clr)
	else
		parent.stationsPanel:SetVisible(false)
	end
	
	if self.recipe.tools and #self.recipe.tools > 0 then
		parent.toolsPanel:SetVisible(true)

		for k, v in pairs(parent.toolsPanel:GetChildren()) do
			if v.tool then
				v:Remove()
			end
		end

		local tools = ""
		for k, itemID in ipairs(self.recipe.tools) do
			local data = ix.Item.stored[itemID]

			if data then
				local itemName = L(data.name)
				tools = tools .. itemName .. " "

				local tools = parent.toolsPanel:Add("DLabel")
				tools:SetFont("legends.Body")
				tools:SetText(k > 1 and string.utf8lower(itemName) or itemName)
				tools:SetTextColor(ix.Craft:HasTool(LocalPlayer(),data.uniqueID) and Color(255, 255, 255, 255) or Color(255, 72, 72, 255))
				tools:Dock(LEFT)
				tools:SizeToContents()
				tools.tool = true

				if #self.recipe.tools > 1 and k < #self.recipe.tools then
					local tools = parent.toolsPanel:Add("DLabel")
					tools:SetFont("legends.Body")
					tools:SetText(", ")
					tools:SetTextColor(color_white)
					tools:Dock(LEFT)
					tools:SizeToContents()
					tools.tool = true
				end
			end
		end
	else
		parent.toolsPanel:SetVisible(false)
	end

	if self.recipe.isBreakdown then
		parent.componentsTitle:SetVisible(false)
		parent.componentsTitle:SetText(L("craftWillReceive"))
	else
		parent.componentsTitle:SetText(L("craftComponents"))
	end
	
	parent.componentsTitle:SetVisible(false)
	parent.components:Clear()

	local client = LocalPlayer()
	for k, v in pairs(self.recipe.isBreakdown and self.recipe.results or self.recipe.requirements) do
		local stored = ix.Item:Get(k)
		local v = istable(v) and (v[1] .. " - " .. v[2]) or v

		parent.componentsTitle:SetVisible(true)

		local itemIcon = parent.components:Add("craft.preview")
		itemIcon:Rebuild(k, 64)
		if !self.recipe.isBreakdown then
			if stored.stackable_legacy then
				itemIcon.Think = function(_, w, h)
					_.hasItem = false

					local count = 0
					for k, v in ipairs(client:GetInventory('main'):FindItems(k)) do
						count = count + v:GetValue()
					end

					if count >= v then
						_.hasItem = true
					end
				end
			else
				itemIcon.Think = function(_, w, h)
					_.hasItem = false

					if client:GetItemsCount(k, "main") >= v then
						_.hasItem = true
					end
				end
			end
			itemIcon.PaintOver = function(_, w, h)
				if !_.hasItem then 
					surface.SetDrawColor(96, 60, 60)
					surface.DrawRect(1, 1, w - 1, h - 1)

					_.mdl:PaintManual()

					surface.SetDrawColor(0, 0, 0, 64)
					surface.DrawRect(1, 1, w - 1, h - 1)

					render.OverrideBlend(true, 4, 6, BLENDFUNC_MIN, 4, 1, BLENDFUNC_ADD)
						draw.RoundedBox(0, 1, 1, w - 1, h - 1, Color(255, 0, 0, 255))
					render.OverrideBlend(false)

					surface.SetDrawColor(255, 32, 32, 128)
					surface.DrawOutlinedRect(1, 1, w - 1, h - 1)
				end

				surface.SetFont("craft.component.count")
				local x, z = surface.GetTextSize(v)
				if _.hasItem then
					surface.SetTextColor(255, 255, 255, 255)
				else
					surface.SetTextColor(255, 32, 0, 255)
				end
				surface.SetTextPos(w - x - 2, h - z)
				surface.DrawText(v)
			end
		else
			itemIcon.PaintOver = function(_, w, h)
				surface.SetFont("craft.component.count")
				local x, z = surface.GetTextSize(v)
				surface.SetTextColor(255, 255, 255, 255)
				surface.SetTextPos(w - x - 2, h - z)
				surface.DrawText(v)
			end
		end
	end

	if IsValid(parent.requirementText) then parent.requirementText:Remove() end
 local lines={}
 local entries=self.recipe.isBreakdown and self.recipe.results or self.recipe.requirements
 if istable(entries) then
  for id,amount in SortedPairs(entries) do
   local item=ix.Item:Get(id)
   local count=istable(amount) and (tostring(amount[1]).."–"..tostring(amount[2])) or tostring(amount)
   lines[#lines+1]=(item and L(item.name) or tostring(id)).."  × "..count
  end
 end
 local label=parent.top:Add("DLabel"); label:Dock(TOP); label:DockMargin(scale(15),scale(16),scale(15),scale(16))
 label:SetFont("legends.Body"); label:SetTextColor(ix.Legends.muted); label:SetWrap(true); label:SetAutoStretchVertical(true)
 label:SetText(table.concat(lines,"\n")); parent.requirementText=label
 parent.components:InvalidateLayout(true)
	parent.top:InvalidateLayout(true)
	parent.top:SizeToChildren(false, true)
end

local color_error = Color(255, 64, 64, 255)
local color = Color(100, 100, 100, 255)
function PANEL:GetColor()
 if not ix.gui.can_craft or not ix.gui.can_craft[self.recipe.uniqueID] then return color_error end
 return ix.Legends.ink
end

function PANEL:Paint() end

function PANEL:Think()
	if (self.nextColorCheck or 0) > RealTime() then return end
	self.nextColorCheck = RealTime() + .1
	local color = self:GetColor()
	if self.lastRecipeColor == color then return end
	self.lastRecipeColor = color
	self.recipeButton:SetTextColor(color)


end

vgui.Register("ui.craft.item", PANEL, "DPanel")
