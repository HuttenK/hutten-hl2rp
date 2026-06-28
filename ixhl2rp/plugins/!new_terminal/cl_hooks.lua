local PLUGIN = PLUGIN or {}

netstream.Hook("civil.terminal.open", function(name, cid, house, job, money, socialCredits, civilStatus, data)
	local info = {}
	
	info.name = name
	info.cid = cid
	info.house = house
	info.job = job
	info.money = tonumber(money)
	info.points = tonumber(socialCredits)
	info.loyalty = tonumber(civilStatus)
	info.data = data

	ix.Datafile:Setup(info)

	local terminal = ix.gui.civilTerminal

	if IsValid(terminal) then
		terminal:SwitchPage("Logged")

		surface.PlaySound("combine_tech/civic_station/station_menu_appear.mp3")
	end
end)

-- Энтити попросил открыть терминал у этого игрока
net.Receive("civil.terminal.show", function()
	local ent = net.ReadEntity()

	if IsValid(ix.gui.civilTerminal) then
		ix.gui.civilTerminal:Remove()
	end

	local panel = vgui.Create("terminal.civil")
	if !IsValid(panel) then return end

	panel.entity = ent
	panel:SetPaintedManually(false)
	panel:Center()
	panel:MakePopup()

	-- кнопка закрытия
	local close = vgui.Create("DButton", panel)
	close:SetText("")
	close:SetSize(22, 22)
	close:SetPos(panel:GetWide() - 30, 7)
	close:SetZPos(1000)
	close.DoClick = function()
		if IsValid(panel) then panel:Remove() end
	end
	close.Paint = function(_, w, h)
		surface.SetDrawColor(ix.Palette.combinered)
		surface.DrawOutlinedRect(0, 0, w, h)
		draw.SimpleText("X", "cmb.terminal.medium16", w * 0.5, h * 0.5, ix.Palette.combinered, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	panel.OnKeyCodePressed = function(s, key)
		if key == KEY_ESCAPE and IsValid(s) then s:Remove() end
	end

	ix.gui.civilTerminal = panel
end)

-- Сервер прислал данные страницы личного кабинета -> маршрутизируем в активную панель
netstream.Hook("civil.terminal.request", function(data)
	local page = ix.gui.civilDatafilePage
	if IsValid(page) and page.Receive then
		page:Receive(data)
	end
end)
