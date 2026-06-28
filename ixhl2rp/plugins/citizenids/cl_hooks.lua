function Schema:CreateCharacterInfo(panel)
	if IsValid(panel) then
		panel.cid = panel:Add("ixListRow")
		panel.cid:SetList(panel.list)
		panel.cid:Dock(TOP)
		panel.cid:DockMargin(0, 0, 0, 8)
	end
end

function Schema:UpdateCharacterInfo(panel)
	local card = LocalPlayer():GetIDCard()

	if IsValid(panel) and panel.cid then
		panel.cid:SetLabelText(L("citizenid"))
		panel.cid:SetText(string.format("##%s", card and card:GetData("cid") or "Н/Д"))
		panel.cid:SizeToContents()
	end
end

netstream.Hook("ixCitizenIDEdit", function(id, data)
	if IsValid(ix.gui.idEditor) then
		ix.gui.idEditor:Remove()
	end

	ix.gui.idEditorItemID = id
	ix.gui.idEditorItem = data
	ix.gui.idEditor = vgui.Create("ixIDEditor")
end)

-- Сервер просит собрать текст физописания (L() доступна только на клиенте) и вернуть
net.Receive("ixCardImprintDescReq", function(len)
	local itemID = net.ReadUInt(32)
	local char   = LocalPlayer():GetCharacter()
	if !char then return end

	local desc = ""
	local ok, res = pcall(function()
		local g = char:Genetic()
		return g and g.GetDesc and g:GetDesc() or ""
	end)
	if ok and isstring(res) then desc = res end

	net.Start("ixCardImprintDescResp")
		net.WriteUInt(itemID, 32)
		net.WriteString(desc)
	net.SendToServer()
end)