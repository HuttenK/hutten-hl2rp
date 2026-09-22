local M=ix.Medicine
local red=Color(246,83,99)
local text=Color(232,216,214)
local PANEL={}
function PANEL:Init()
 self:SetSize(math.min(ScrW()-48,1000),math.min(ScrH()-48,780))
 self:SetTitle(""); self:ShowCloseButton(false); self:SetDraggable(false); self:MakePopup()
 self:SetAlpha(0); self:AlphaTo(255,.2,0)
 self.started=CurTime()
 self.close=self:Add("DButton"); self.close:SetText("НАЗАД / ESC")
 self.close:SetFont("ixRadialSmall"); self.close:SetTextColor(text)
 self.close.Paint=function(p,w,h)
  surface.SetDrawColor(p:IsHovered() and Color(64,15,29) or Color(28,13,21)); surface.DrawRect(0,0,w,h)
  surface.SetDrawColor(red); surface.DrawRect(0,h-1,w,1)
 end
 self.close.DoClick=function() self:Remove(); RunConsoleCommand("ix_radial") end
 self.info=self:Add("DLabel"); self.info:SetFont("ixRadialLabel"); self.info:SetTextColor(text)
 self.info:SetWrap(true); self.info:SetContentAlignment(7); self.info:SetText("Наведите курсор на часть тела.")
 self:Center()
end
function PANEL:PerformLayout(w,h)
 -- DFrame can invalidate layout while Init is still constructing its children.
 if IsValid(self.close) then self.close:SetPos(w-174,18); self.close:SetSize(150,34) end
 if IsValid(self.info) then self.info:SetPos(w*.51,120); self.info:SetSize(w*.44,h-180) end
end
function PANEL:BodyRect() return 36,100,self:GetWide()*.42,self:GetTall()-164 end
function PANEL:Think()
 local client=LocalPlayer()
 if not IsValid(self.patient) or not self.patient:GetCharacter() or self.patient:GetCharacter():GetID()~=self.characterID
  or not client:Alive() or client:GetCharacter()~=self.viewerCharacter or input.IsKeyDown(KEY_ESCAPE) then self:Remove(); return end
 if (self.nextRequest or 0)<CurTime() then
  self.nextRequest=CurTime()+.8
  net.Start("ixMedicalExamine"); net.WriteEntity(self.patient); net.SendToServer()
 end
 if self.received and CurTime()-self.received>2 then self.state=nil end
 local x,y,w,h=self:BodyRect()
 local mx,my=self:CursorPos()
 self.hover=ix.Anatomy and ix.Anatomy.HitTest(mx,my,x,y,w,h,self.state)
 if self.hover then self.selected=self.hover end
 if not self.state then self.selected=nil end
 local part=self.selected
 local info=part and ((L(part.name) or part.name).."\n\n"..(#part.injuries>0 and table.concat(part.injuries,"\n\n") or "Видимых травм нет").."\n\nПКМ на части тела — выбрать медикамент.")
  or (self.state and "Наведите курсор на часть тела.\n\nПКМ — выбрать подходящий медикамент." or ((self.received or CurTime()-self.started>2) and "Осмотр недоступен. Подойдите ближе к пациенту." or "Получение данных осмотра…"))
 if self.lastInfo~=info then self.info:SetText(info); self.lastInfo=info end
end
function PANEL:Paint(w,h)
 surface.SetDrawColor(9,7,11,245); surface.DrawRect(0,0,w,h)
 surface.SetDrawColor(106,35,49); surface.DrawOutlinedRect(0,0,w,h)
 draw.SimpleText("ОСМОТР / СОСТОЯНИЕ ТЕЛА","ixRadialLabel",28,28,red)
 draw.SimpleText(self.patient==LocalPlayer() and "СОБСТВЕННОЕ СОСТОЯНИЕ" or "ПОМОЩЬ ПАЦИЕНТУ","ixRadialSmall",28,59,text)
 if ix.Anatomy and self.state then
  local x,y,bw,bh=self:BodyRect()
  ix.Anatomy.Draw(x,y,bw,bh,self.state,self.selected and self.selected.id)
  draw.SimpleText("КРОВЬ  /  "..math.Round(self.state.blood*100).."%","ixRadialSmall",w*.51,86,red)
  surface.SetDrawColor(65,30,39); surface.DrawRect(w*.51,109,w*.4,2)
  surface.SetDrawColor(red); surface.DrawRect(w*.51,109,w*.4*self.state.blood,2)
 end
 draw.SimpleText("НАВЕДЕНИЕ — ТРАВМЫ     /     ПКМ — ЛЕЧЕНИЕ","ixRadialSmall",28,h-32,text)
end
function PANEL:OnMousePressed(code)
 if code~=MOUSE_RIGHT or not self.hover or not self.state or not self.received or CurTime()-self.received>2 then return end
 local part=self.hover
 local available={}; for _,id in ipairs(part.medicines) do available[id]=true end
 local items={}
 for _,item in pairs(LocalPlayer():GetItems()) do if available[item.id] then items[#items+1]=item end end
 table.sort(items,function(a,b) return a:GetName()<b:GetName() end)
 local menu=DermaMenu()
 menu.Paint=function(_,w,h) surface.SetDrawColor(20,10,16,250); surface.DrawRect(0,0,w,h); surface.SetDrawColor(red); surface.DrawOutlinedRect(0,0,w,h) end
 for _,item in ipairs(items) do
  local option=menu:AddOption(item:GetName().." / "..item:GetResourceText(),function()
   if not IsValid(self.patient) then return end
   local key=self.patient==LocalPlayer() and "use" or "inject"
   local action=item.functions[key]
   if not action or not action.index then return end
   net.Start("item.action"); net.WriteUInt(item.id,32); net.WriteUInt(item.inventory_id or 0,32)
   net.WriteUInt(action.index,item.functions_bits); net.WriteTable({target=self.patient,limb=part.hitgroup}); net.WriteBool(false); net.SendToServer()
   surface.PlaySound("ix/ui/radial_select.wav"); self:Remove()
  end)
  option:SetTextColor(text); option:SetFont("ixRadialLabel")
  option.Paint=function(p,w,h)
   if p:IsHovered() then surface.SetDrawColor(80,20,35); surface.DrawRect(0,0,w,h); surface.SetDrawColor(red); surface.DrawRect(0,0,2,h) end
  end
 end
 if #items==0 then local option=menu:AddOption("Нет подходящих медикаментов"); option:SetEnabled(false) end
 menu:Open(); self.medicineMenu=menu
 surface.PlaySound("ix/ui/radial_open.wav")
end
function PANEL:OnRemove()
 if IsValid(self.medicineMenu) then self.medicineMenu:Remove() end
 if M.examination==self then M.examination=nil end
end
vgui.Register("ixMedicalExamination",PANEL,"DFrame")
function M.OpenExamination(patient)
 if not IsValid(patient) or not patient:GetCharacter() then return end
 if IsValid(M.examination) then M.examination:Remove() end
 local p=vgui.Create("ixMedicalExamination")
 p.patient=patient; p.characterID=patient:GetCharacter():GetID(); p.viewerCharacter=LocalPlayer():GetCharacter()
 M.examination=p
end
net.Receive("ixMedicalExamine",function()
 local patient,id,state=net.ReadEntity(),net.ReadUInt(32),net.ReadTable()
 local p=M.examination
 if IsValid(p) and p.patient==patient and p.characterID==id then
  local selected=p.selected and p.selected.id
  p.state=state; p.received=CurTime(); p.selected=nil
  for _,part in ipairs(state.parts or {}) do if part.id==selected then p.selected=part; break end end
 end
end)
