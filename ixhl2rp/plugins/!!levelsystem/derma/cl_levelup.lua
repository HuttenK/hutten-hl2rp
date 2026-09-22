local PANEL = {}
local function Theme() return ix.Legends, ix.Legends.Scale, ix.Legends.T end
function PANEL:Init()
 if IsValid(ix.gui.levelup) then ix.gui.levelup:Remove() end
 ix.gui.levelup=self
 local client=LocalPlayer()
 self.character=IsValid(client) and client.GetCharacter and client:GetCharacter()
 if not self.character then self:Remove(); return end
 self.points=self.character:GetSkillPoints(); self.remaining=self.points; self.pending={}; self.spent=0
 self:SetSize(ScrW(),ScrH()); self:MakePopup()
 local U,S,T=Theme()
 self:DockPadding(S(48),S(130),S(48),S(38))
 local footer=self:Add("Panel"); footer:Dock(BOTTOM); footer:SetTall(S(54)); footer:DockMargin(0,S(20),0,0)
 local cancel=U.Button(footer,T("Cancel","Отмена"),function() self:Remove() end); cancel:Dock(LEFT); cancel:SetWide(S(170))
 local reset=U.Button(footer,T("Reset changes","Сбросить изменения"),function() self.pending={}; self.spent=0; self.remaining=self.points end)
 reset:Dock(LEFT); reset:SetWide(S(230)); reset:DockMargin(S(12),0,0,0)
 self.apply=U.Button(footer,T("Confirm changes","Подтвердить изменения"),function() self:Submit() end,true)
 self.apply:Dock(RIGHT); self.apply:SetWide(S(290))
 local details=U.Scroll(self); details:Dock(RIGHT); details:SetWide(math.min(S(420),ScrW()*0.32)); details:DockMargin(S(36),0,0,0)
 U.Label(details,T("ALLOCATION PREVIEW","ПЛАН РАЗВИТИЯ"),"Mono",U.accent)
 self.balance=U.Label(details,"","Title")
 U.Label(details,self.points<0 and T("Remove attribute ranks to settle the point deficit.","Уменьшите характеристики, чтобы погасить дефицит очков.") or T("Primary attributes cost 1 point per rank. Other attributes cost 4.","Основные характеристики: 1 очко за ранг. Остальные: 4 очка."),"Body",U.muted)
 self.detailTitle=U.Label(details,"","Heading")
 self.description=U.Label(details,"","Body",U.muted)
 local list=U.Scroll(self); list:Dock(FILL)
 for key,definition in SortedPairsByMemberValue(ix.specials.list,"weight") do
  local id,stat=key,definition
  local row=list:Add("Panel"); row:Dock(TOP); row:SetTall(S(104)); row:DockMargin(0,0,S(12),S(10))
  local primary=self.character:GetPrimaryStat(id); local cost=primary and 1 or 4
  row.Paint=function(_,w,h)
   U.Plate(0,0,w,h,U.panel,U.line)
   U.Text(L(stat.name),"Heading",S(18),S(14),U.ink)
   U.Text((primary and T("PRIMARY","ОСНОВНАЯ") or T("SECONDARY","ВТОРИЧНАЯ")).." / "..cost..T(" PT / RANK"," ОЧК. / РАНГ"),"Mono",S(18),S(47),U.muted)
   local base=1+math.floor((self.character:GetSpecials()[id] or 0)/cost)
   local change=(self.pending[id] or 0)/cost
   U.Text(base..(change~=0 and (" → "..(base+change)) or ""),"Body",w-S(150),S(76),change~=0 and U.accent or U.muted,TEXT_ALIGN_RIGHT)
  end
  local inspect=U.Button(row,T("Details","Подробнее"),function() self.detailTitle:SetText(L(stat.name)); self.description:SetText(L(stat.description)) end)
  local minus=U.Button(row,"−",function() self:Adjust(id,-1) end)
  local plus=U.Button(row,"+",function() self:Adjust(id,1) end)
  row.PerformLayout=function(_,w,h)
   inspect:SetPos(S(18),h-S(34)); inspect:SetSize(S(130),S(28))
   minus:SetPos(w-S(118),S(22)); minus:SetSize(S(44),S(44))
   plus:SetPos(w-S(62),S(22)); plus:SetSize(S(44),S(44))
  end
  row.Think=function() minus:SetDisabled(not self:CanAdjust(id,-1)); plus:SetDisabled(not self:CanAdjust(id,1)) end
  if not self.firstStat then self.firstStat=id; self.detailTitle:SetText(L(stat.name)); self.description:SetText(L(stat.description)) end
 end
end
function PANEL:CanAdjust(id,direction)
 if self.sent or not self.character or not ix.specials.list[id] then return false end
 local cost=self.character:GetPrimaryStat(id) and 1 or 4
 local nextValue=(self.pending[id] or 0)+direction*cost
 local remaining=self.remaining-direction*cost
 local raw=(self.character:GetSpecials()[id] or 0)+nextValue
 if raw<0 then return false end
 if self.points>=0 then return nextValue>=0 and remaining>=0 end
 return nextValue<=0 and remaining<=0
end
function PANEL:Adjust(id,direction)
 if not self:CanAdjust(id,direction) then return end
 local cost=self.character:GetPrimaryStat(id) and 1 or 4
 self.pending[id]=(self.pending[id] or 0)+direction*cost
 self.spent=self.spent+direction*cost; self.remaining=self.points-self.spent
end
function PANEL:Submit()
 if self.sent or self.spent==0 or self.spent>511 or self.spent< -512 then return end
 if self.character:GetSkillPoints()~=self.points then self:Remove(); return end
 local payload={}; for key,value in pairs(self.pending) do if value~=0 then payload[key]=value end end
 self.sent=true
 net.Start("ixLevelUp"); net.WriteInt(self.spent,10); net.WriteTable(payload); net.SendToServer()
 self:Remove()
end
function PANEL:Think()
 local client=LocalPlayer()
 if not IsValid(client) or not client.GetCharacter or client:GetCharacter()~=self.character then self:Remove(); return end
 local U,S,T=Theme()
 self.balance:SetText(self.remaining..T(" points remaining"," очков осталось"))
 self.apply:SetDisabled(self.spent==0 or self.spent>511 or self.spent< -512)
end
function PANEL:Paint(w,h)
 local U,S,T=Theme(); U.Backdrop(w,h)
 U.Text(T("ATTRIBUTE DEVELOPMENT","РАЗВИТИЕ ХАРАКТЕРИСТИК"),"Title",S(48),S(38))
 U.Text(T("Review changes before confirming","Проверьте изменения перед подтверждением"),"Mono",S(48),S(94),U.muted)
end
function PANEL:OnKeyCodePressed(key) if key==KEY_ESCAPE then self:Remove() end end
function PANEL:OnRemove() if ix.gui.levelup==self then ix.gui.levelup=nil end end
vgui.Register("autonomous.levelup",PANEL,"EditablePanel")
net.Receive("ixLevelUp",function() vgui.Create("autonomous.levelup") end)
