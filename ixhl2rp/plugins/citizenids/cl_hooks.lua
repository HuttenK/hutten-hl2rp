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
		panel.cid:SetLabelText("Ключ-карта")
		panel.cid:SetText(string.format("##%s", card and card:GetData("cid") or "Н/Д"))
		panel.cid:SizeToContents()
	end
end

netstream.Hook("ixCitizenIDEdit", function(id, data, isKeycard)
	if IsValid(ix.gui.idEditor) then
		ix.gui.idEditor:Remove()
	end

	ix.gui.idEditorItemID = id
	ix.gui.idEditorItem = data
 ix.gui.idEditorKeycard=isKeycard
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
surface.CreateFont("ixIdentityTitle",{font="Georgia",size=26,weight=700,extended=true})
surface.CreateFont("ixIdentityValue",{font="Georgia",size=19,weight=500,extended=true})
net.Receive("ixIdentityDocument",function()
 local d=net.ReadTable()
 if IsValid(ix.gui.identityDocument) then ix.gui.identityDocument:Remove() end
 local ink=Color(35,43,48); local muted=Color(107,103,89)
 local f=vgui.Create("DFrame"); ix.gui.identityDocument=f
 f:SetSize(math.min(780,ScrW()-32),math.min(650,ScrH()-32)); f:Center(); f:MakePopup(); f:SetTitle(""); f:SetScreenLock(true)
 f:DockPadding(36,132,36,64)
 f.Paint=function(_,w,h)
  surface.SetDrawColor(232,226,207); surface.DrawRect(0,0,w,h)
  surface.SetDrawColor(118,110,80,55); surface.DrawOutlinedRect(14,14,w-28,h-28,1); surface.DrawOutlinedRect(19,19,w-38,h-38,1)
  -- Engraved guilloche-like lines and seal use primitives, with no external textures.
  surface.SetDrawColor(93,108,87,20)
  for y=24,h-24,8 do
   local last=0
   for x=20,w-20,6 do
    local yy=y+math.sin(x*.035+y*.05)*5
    if last~=0 then surface.DrawLine(x-6,last,x,yy) end
    last=yy
   end
  end
  for radius=44,60,4 do surface.DrawCircle(w-101,h-112,radius,Color(92,63,60,45)) end
  draw.SimpleText("РЕЕСТР","ixIdentityValue",w-101,h-123,Color(92,63,60,65),TEXT_ALIGN_CENTER)
  draw.SimpleText("ЛИЧНОСТИ","DermaDefault",w-101,h-99,Color(92,63,60,65),TEXT_ALIGN_CENTER)
  draw.SimpleText("РЕГИСТРАЦИОННАЯ СЛУЖБА","DermaDefaultBold",36,33,muted)
  draw.SimpleText("УДОСТОВЕРЕНИЕ ЛИЧНОСТИ","ixIdentityTitle",36,58,ink)
  draw.SimpleText("IDENTITY DOCUMENT   /   ЛИЧНЫЙ ЭКЗЕМПЛЯР","DermaDefault",36,94,muted)
  surface.SetDrawColor(85,83,65,110); surface.DrawLine(36,119,w-36,119)
  draw.SimpleText("№ "..(d.number or "—"),"DermaDefaultBold",36,h-43,ink)
  draw.SimpleText("ДОКУМЕНТ НЕ ПРЕДОСТАВЛЯЕТ ДОПУСК","DermaDefault",w-36,h-43,muted,TEXT_ALIGN_RIGHT)
 end
 local portrait=f:Add("ixCredentialPortrait"); portrait:Dock(RIGHT); portrait:SetWide(math.min(190,f:GetWide()*.28)); portrait:DockMargin(20,0,0,0); portrait:SetPortrait(d.portrait,true)
 local scroll=f:Add("DScrollPanel"); scroll:Dock(FILL)
 for _,field in ipairs({{"name","ФАМИЛИЯ И ИМЯ"},{"birthDate","ДАТА РОЖДЕНИЯ"},{"nationality","ГРАЖДАНСТВО"},{"sex","ПОЛ"},{"issued","ДАТА ВЫДАЧИ"},{"expires","ДЕЙСТВИТЕЛЕН ДО"},{"authority","КЕМ ВЫДАН"}}) do
  local row=scroll:Add("DPanel"); row:Dock(TOP); row:SetTall(55); row:DockMargin(0,0,0,3)
  row.Paint=function(_,w,h)
   draw.SimpleText(field[2],"DermaDefault",0,1,muted)
   draw.SimpleText(d[field[1]] and d[field[1]]~="" and d[field[1]] or "Не указано","ixIdentityValue",0,20,ink)
   surface.SetDrawColor(80,80,70,35); surface.DrawLine(0,h-1,w,h-1)
  end
 end
end)
