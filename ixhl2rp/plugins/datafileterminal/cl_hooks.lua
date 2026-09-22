netstream.Hook("ixDfBrowserOpen", function(list)
	if IsValid(ix.gui.dfBrowser) then
		ix.gui.dfBrowser:Remove()
	end

	ix.gui.dfBrowser = vgui.Create("ixDatafileBrowser")

	if IsValid(ix.gui.dfBrowser) then
		ix.gui.dfBrowser:SetList(list or {})
	end
end)

-- Полные данные одного досье -> открываем окно с фото
netstream.Hook("ixDfView", function(payload)
	if IsValid(ix.gui.dfView) then
		ix.gui.dfView:Remove()
	end

	ix.gui.dfView = vgui.Create("ixDatafileView")

	if IsValid(ix.gui.dfView) then
		ix.gui.dfView:SetData(payload or {})
	end
end)
