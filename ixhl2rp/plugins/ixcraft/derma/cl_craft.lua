local PANEL = {}
local scale = ix.UI.Scale

PANEL.isMini = true

ix.gui.can_craft = nil

function PANEL:CacheRecipeNeeds(stationID, stationInventory)
	local client = LocalPlayer()

	if !ix.gui.can_craft then
		ix.gui.can_craft = {}

		for _, recipe in pairs(ix.Craft.recipes) do
			local canCraft = true

			-- The Combine fabrication terminal is a master station: it can craft anything.
			if recipe.station and stationID != "station_combine" then
				if istable(recipe.station) then
					canCraft = false

					for k, v in ipairs(recipe.station) do
						if stationID and stationID == v then
							canCraft = true
							break
						end
					end
				else
					if (!stationID or stationID != recipe.station) then
						canCraft = false
					end
				end
			end

			if canCraft then
				for k, itemID in ipairs(recipe.tools or {}) do
					if !ix.Craft:HasTool(client,itemID) and not (stationInventory and stationInventory:HasItem(itemID)) then
						canCraft = false
						break
					end
				end

				if recipe.isBreakdown then
					local hasInInv = client:HasItem(recipe.requirements, "main")
					local hasInStash = (stationID and stationInventory:HasItem(recipe.requirements) or false)
					
					canCraft = hasInStash or hasInInv
				else
					for uniqueID, amount in pairs(recipe.requirements or {}) do
						local count = 0
						local stored = ix.Item:Get(uniqueID)

						if not stored then continue end -- item not registered on client yet

						if stored.stackable_legacy then
							for k, v in ipairs(client:GetInventory("main"):GetItems()) do
								if v.uniqueID == uniqueID then
									count = count + v:GetValue()
								end
							end

							if stationID then
								for k, v in ipairs(stationInventory:GetItems()) do
									if v.uniqueID == uniqueID then
										count = count + v:GetValue()
									end
								end
							end

							if count < amount then
								canCraft = false
								break
							end
						else
							count = count + client:GetInventory("main"):GetItemsCount(uniqueID)

							if stationID then
								count = count + stationInventory:GetItemsCount(uniqueID)
							end

							if recipe.any and recipe.any[uniqueID] then
								for k, v in pairs(recipe.any[uniqueID]) do
									count = count + client:GetInventory("main"):GetItemsCount(k)

									if stationID then
										count = count + stationInventory:GetItemsCount(k)
									end
								end
							end

							if count < amount then
								canCraft = false
								break
							end
						end
					end
				end
			end

			ix.gui.can_craft[recipe.uniqueID] = canCraft
		end
	end
end

function PANEL:Paint(w, h)
	if !ix.gui.can_craft then
		self:CacheRecipeNeeds(self.station and self.station.uniqueID, self.station and ix.Inventory:Get(self.inventoryID))
	end

	if !self.isMini then
		surface.SetDrawColor(30, 12, 20, 255 * 0.9)
		surface.DrawRect(0, 0, w, h)

		surface.SetDrawColor(210 * 0.5, 48 * 0.5, 72 * 0.5, 255 * 0.5)
		surface.DrawOutlinedRect(0, 0, w, h)
	end
end

function PANEL:BuildCraftPanel()
	ix.gui.craftFrame = self

	local top = self.second:Add("Panel")
	top:Dock(TOP)
	top:DockMargin(0, 0, 0, 0)

	local itemTitle = top:Add("DLabel")
	itemTitle:Dock(TOP)
	itemTitle:DockMargin(0, 10, 0, 0)
	itemTitle:SetContentAlignment(5)
	itemTitle:SetTextColor(Color(245, 95, 112))
	itemTitle:SetFont("legends.Heading")
	itemTitle:SetText("")
	itemTitle:SetVisible(false)
 itemTitle:SetTall(scale(40)); itemTitle:SetWrap(true)

	self.craftTitle = itemTitle

	local iconFrame = top:Add("Panel")
	iconFrame:Dock(TOP)
	iconFrame:SetSize(self.second:GetWide())
	iconFrame:SetVisible(false)

	local itemIcon = iconFrame:Add("craft.preview")
	itemIcon:Rebuild('uspmatch', 64)
	itemIcon:SetVisible(true)
	iconFrame:SetTall(itemIcon:GetTall() + 20)
	itemIcon:Center()

	self.iconFrame = iconFrame
	self.itemIcon = itemIcon

	local resultAmount = itemIcon:Add("DLabel")
	resultAmount:SetFont("legends.Body")
	resultAmount:SetText("")
	resultAmount:SetContentAlignment(6)
	resultAmount:SetVisible(true)
	resultAmount:SizeToContents()
	resultAmount:AlignRight(0)
	resultAmount:AlignBottom(0)

	self.itemCount = resultAmount

	local itemLevelUp = top:Add("DLabel")
	itemLevelUp:SetFont("legends.Mono")
	itemLevelUp:Dock(TOP)
	itemLevelUp:SetVisible(false)
	itemLevelUp:SetText("")
	itemLevelUp:SetContentAlignment(5)
	itemLevelUp:SetTextColor(ix.Legends.muted)
	itemLevelUp:SizeToContents()

	self.itemXP = itemLevelUp

	local skill = top:Add("DLabel")
	skill:SetFont("legends.Mono")
	skill:SetText("")
	skill:SetTextColor(Color(255, 255, 255, 255))
	skill:SetContentAlignment(5)
	skill:SetVisible(false)
	skill:Dock(TOP)
	skill:DockMargin(0, 0, 0, 32)
	skill:SizeToContents()

	self.itemSkill = skill

	local stationsPanel = top:Add("Panel")
	stationsPanel:Dock(TOP)
	stationsPanel:DockMargin(15, 0, 0, 0)
	stationsPanel:SetTall(scale(20))
	stationsPanel:SetVisible(false)
		local stationsTitle = stationsPanel:Add("DLabel")
		stationsTitle:SetFont("legends.Mono")
		stationsTitle:SetText(L("craftStationKey"))
		stationsTitle:SetTextColor(Color(245, 95, 112, 255))
		stationsTitle:Dock(LEFT)
		stationsTitle:SizeToContents()

		local station = stationsPanel:Add("DLabel")
		station:SetFont("legends.Body")
		station:SetText("")
		station:SetTextColor(Color(255, 255, 255, 255))
		station:Dock(LEFT)
		station:SizeToContents()

		self.stationsPanel = stationsPanel
		self.stations = station

	local toolsPanel = top:Add("Panel")
	toolsPanel:Dock(TOP)
	toolsPanel:DockMargin(15, 0, 0, 0)
	toolsPanel:SetTall(scale(20))
	toolsPanel:SetVisible(false)
		local toolsTitle = toolsPanel:Add("DLabel")
		toolsTitle:SetFont("legends.Mono")
		toolsTitle:SetText(L("craftToolsKey"))
		toolsTitle:SetTextColor(Color(245, 95, 112, 255))
		toolsTitle:Dock(LEFT)
		toolsTitle:SizeToContents()

		self.toolsPanel = toolsPanel

	local componentsTitle = top:Add("DLabel")
	componentsTitle:SetFont("legends.Mono")
	componentsTitle:Dock(TOP)
	componentsTitle:DockMargin(15, 10, 0, 0)
	componentsTitle:SetVisible(false)
	componentsTitle:SetText(L("craftComponentsKey"))
	componentsTitle:SetTextColor(Color(245, 95, 112, 255))
	componentsTitle:SizeToContents()

	self.componentsTitle = componentsTitle

	self.components = top:Add("DTileLayout")
	self.components:SetBaseSize(32)
	self.components:Dock(TOP)
	self.components:DockMargin(15, 5, 0, 0)
	self.components:SetSpaceY(0)
	self.components:SetSpaceX(0)

	top:InvalidateLayout(true)
	top:SizeToChildren(false, true)

	self.top = top
end

function PANEL:PaintOver(w, h)
	if self.anim then
		local delta = (UnPredictedCurTime() - self.animStart) / self.animTime
		
		if delta > 1 then
			self.anim = false
		end
		
		surface.SetDrawColor(0, 0, 0, 255 * (1 - math.ease.InOutCubic(delta)))
		surface.DrawRect(0, 0, w, h)
	end
end

function PANEL:Setup()
	ix.gui.currentCraft = nil
 ix.gui.can_craft = nil
	if self.isMini then
		self:Dock(FILL)
		self:InvalidateParent(true)
	else
		self:SetSize(ScrW(), ScrH())
		self:MakePopup()

		self.anim = true
		self.animStart = UnPredictedCurTime()
		self.animTime = 0.3
	end

	local header=self:Add("Panel"); header:Dock(TOP); header:SetTall(scale(58))
 header.Paint=function(_,w,h)
  local U=ix.Legends
  U.Text(U.T("FABRICATION / RECIPE LIBRARY","ИЗГОТОВЛЕНИЕ / РЕЦЕПТЫ"),"Heading",scale(16),scale(10),U.ink)
  U.Rect(scale(16),h-scale(10),w-scale(32),1,U.line)
 end
 local container = self:Add("ui.craft.container", 1)
	container:Setup(self.isMini, self.inventoryID)

	self:BuildCraftPanel()
 self.emptyHint=self.second:Add("DLabel"); self.emptyHint:Dock(TOP)
 self.emptyHint:SetFont("legends.Body"); self.emptyHint:SetTextColor(ix.Legends.muted)
 self.emptyHint:SetWrap(true); self.emptyHint:SetAutoStretchVertical(true)
 self.emptyHint:SetText(ix.Legends.T("Select a recipe to inspect its result, station, tools and materials.","Выберите рецепт: результат, станция, инструменты и материалы появятся здесь."))

	if !self.isMini then
		local close = self:Add("DButton")
		close:SetText("")
		close:SetSize(scale(36), scale(36))
		close:SetPos(ScrW() - scale(54), scale(18))
		close:MoveToFront()
		close.Paint = function(btn, w, h)
			local hovered = btn:IsHovered()
			local clr = hovered and Color(255, 80, 80) or Color(245, 95, 112)

			surface.SetDrawColor(30, 12, 20, 230)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(clr.r, clr.g, clr.b, 255)
			surface.DrawOutlinedRect(0, 0, w, h)

			surface.DrawLine(w * 0.3, h * 0.3, w * 0.7, h * 0.7)
			surface.DrawLine(w * 0.7, h * 0.3, w * 0.3, h * 0.7)
		end
		close.DoClick = function()
			surface.PlaySound("buttons/button14.wav")
			self:Close()
		end

		self.closeButton = close

		local hint = self:Add("DLabel")
		hint:SetFont("legends.Mono")
		hint:SetText(L("craftCloseHint"))
		hint:SetTextColor(Color(245, 95, 112, 200))
		hint:SizeToContents()
		hint:SetPos(ScrW() - scale(54) - hint:GetWide() - scale(10), scale(18) + (scale(36) - hint:GetTall()) * 0.5)
		hint:MoveToFront()
	end
end

function PANEL:PerformLayout(w, h)
	if self.isMini and IsValid(self.recipeColumn) then
		self.recipeColumn:SetWide(math.max(1, (w - scale(20)) * 0.48))
	end
end

function PANEL:Close()
	if self.OnClose then
		self:OnClose()
	end

	self:Remove()
end

function PANEL:OnKeyCodePressed(key)
	if key == KEY_TAB then
		self:Close()
	end
end

vgui.Register("ui.craft", PANEL, "EditablePanel")
