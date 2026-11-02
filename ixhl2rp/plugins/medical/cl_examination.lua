local M=ix.Medicine
local red=ix.Legends.accent
local text=ix.Legends.ink
local panelMeta=FindMetaTable("Panel")
-- Engine removal is deferred, and popup children can outlive the parent for a
-- frame. Release only this window's controls before queuing their deletion.
local function ReleaseInput(panel)
 if not IsValid(panel) then return end
 for _,child in ipairs(panel:GetChildren()) do ReleaseInput(child) end
 panel:MouseCapture(false)
 panel:SetMouseInputEnabled(false); panel:SetKeyboardInputEnabled(false)
 panel:KillFocus(); panel:SetVisible(false)
end
function M.CloseExamination(panel)
 panel=panel or M.examination
 if not IsValid(panel) or panel.ixExaminationClosing then return end
 panel.ixExaminationClosing=true
 if M.examination==panel then M.examination=nil end
 local menu=panel.medicineMenu; panel.medicineMenu=nil
 if IsValid(menu) then ReleaseInput(menu); panelMeta.Remove(menu) end
 ReleaseInput(panel)
 panelMeta.Remove(panel)
end
-- A client Lua refresh must also release an already-open old panel instance.
M.CloseExamination()
local PANEL={}
function PANEL:Init()
 self:SetSize(math.min(ScrW()-48,1000),math.min(ScrH()-48,780))
 self:SetTitle(""); self:ShowCloseButton(false); self:SetDraggable(false); self:MakePopup()
 self:SetAlpha(0); self:AlphaTo(255,.2,0)
 self.started=CurTime()
 self.close=self:Add("DButton"); self.close:SetText("ЗАКРЫТЬ / ESC")
 self.close:SetFont("ixRadialSmall"); self.close:SetTextColor(text)
 self.close.Paint=function(p,w,h)
  surface.SetDrawColor(p:IsHovered() and Color(59,49,29) or Color(23,23,18)); surface.DrawRect(0,0,w,h)
  surface.SetDrawColor(red); surface.DrawRect(0,h-1,w,1)
 end
 self.close.DoClick=function() self:Close() end
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
 if self.ixExaminationClosing then return end
 local client=LocalPlayer()
 if not IsValid(self.patient) or not self.patient:GetCharacter() or self.patient:GetCharacter():GetID()~=self.characterID
  or not IsValid(client) or not client:Alive() or client:GetCharacter()~=self.viewerCharacter
  or input.IsKeyDown(KEY_ESCAPE) or gui.IsGameUIVisible() then self:Close(); return end
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
 if self.ixExaminationClosing then return end
 ix.Legends.Plate(0,0,w,h)
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
 if self.ixExaminationClosing or code~=MOUSE_RIGHT or not self.hover or not self.state or not self.received or CurTime()-self.received>2 then return end
 local part=self.hover
 local available={}; for _,id in ipairs(part.medicines) do available[id]=true end
 local items={}
 for _,item in pairs(LocalPlayer():GetItems()) do if available[item.id] then items[#items+1]=item end end
 table.sort(items,function(a,b) return a:GetName()<b:GetName() end)
 if IsValid(self.medicineMenu) then ReleaseInput(self.medicineMenu); panelMeta.Remove(self.medicineMenu) end
 local menu=DermaMenu()
 menu.Paint=function(_,w,h) surface.SetDrawColor(20,20,16,250); surface.DrawRect(0,0,w,h); surface.SetDrawColor(red); surface.DrawOutlinedRect(0,0,w,h) end
 for _,item in ipairs(items) do
  local option=menu:AddOption(item:GetName().." / "..item:GetResourceText(),function()
   if self.ixExaminationClosing or not IsValid(self.patient) then return end
   local key=self.patient==LocalPlayer() and "use" or "inject"
   local action=item.functions[key]
   if not action or not action.index then return end
   net.Start("item.action"); net.WriteUInt(item.id,32); net.WriteUInt(item.inventory_id or 0,32)
   net.WriteUInt(action.index,item.functions_bits); net.WriteTable({target=self.patient,limb=part.hitgroup}); net.WriteBool(false); net.SendToServer()
   ix.Legends.PlayUISound("click"); self:Close()
  end)
  option:SetTextColor(text); option:SetFont("ixRadialLabel")
  option.Paint=function(p,w,h)
   if p:IsHovered() then surface.SetDrawColor(67,55,31); surface.DrawRect(0,0,w,h); surface.SetDrawColor(red); surface.DrawRect(0,0,2,h) end
  end
 end
 if #items==0 then local option=menu:AddOption("Нет подходящих медикаментов"); option:SetEnabled(false) end
 menu:Open(); self.medicineMenu=menu

end
function PANEL:Close() M.CloseExamination(self) end
function PANEL:Remove() M.CloseExamination(self) end
function PANEL:OnKeyCodePressed(code)
 if code==KEY_ESCAPE then self:Close() end
end
function PANEL:OnRemove()
 self.ixExaminationClosing=true
 local menu=self.medicineMenu; self.medicineMenu=nil
 if IsValid(menu) then ReleaseInput(menu); panelMeta.Remove(menu) end
 ReleaseInput(self)
 if M.examination==self then M.examination=nil end
end
vgui.Register("ixMedicalExamination",PANEL,"DFrame")
function M.OpenExamination(patient)
 local client=LocalPlayer()
 if not IsValid(client) or not client:Alive() or not client:GetCharacter()
  or not IsValid(patient) or not patient:GetCharacter() then return end
 M.CloseExamination()
 local p=vgui.Create("ixMedicalExamination")
 p.patient=patient; p.characterID=patient:GetCharacter():GetID(); p.viewerCharacter=client:GetCharacter()
 M.examination=p
end
net.Receive("ixMedicalExamine",function()
 local patient,id,state=net.ReadEntity(),net.ReadUInt(32),net.ReadTable()
 local p=M.examination
 if IsValid(p) and not p.ixExaminationClosing and p.patient==patient and p.characterID==id then
  local selected=p.selected and p.selected.id
  p.state=state; p.received=CurTime(); p.selected=nil
  for _,part in ipairs(state.parts or {}) do if part.id==selected then p.selected=part; break end end
 end
end)
