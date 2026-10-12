local PANEL={}
function PANEL:Init()
 local U=ix.InterfaceOS
 self:SetSize(math.min(920,ScrW()-40),math.min(720,ScrH()-40)); self:Center(); self:MakePopup()
 self:SetTitle(""); self:ShowCloseButton(false); self:SetScreenLock(true); self:DockPadding(24,98,24,24)
 self:SetAlpha(0); self:AlphaTo(255,.18)
 self.Paint=function(_,w,h)
  U.Plate(0,0,w,h,U.panel,U.accent)
  U.Text("SCiPNet / PERSONNEL ARCHIVE","Mono",24,20,U.muted)
  U.Text("ЛИЧНОЕ ДЕЛО","Title",24,44)
  U.Rect(24,83,w-48,1,U.line)
 end
 local close=U.Button(self,"ЗАКРЫТЬ",function() self:Close() end); close:SetSize(134,36); close:SetPos(self:GetWide()-158,28)
 self.body=U.Scroll(self); self.body:Dock(FILL)
end
function PANEL:FieldPair(left,right)
 return vgui.GetControlTable("ixDatafileBrowser").FieldPair(self,left,right)
end
function PANEL:SetData(d)
 local U=ix.InterfaceOS; self.body:Clear(); self.detail=self.body
 if d.credential then vgui.GetControlTable("ixDatafileBrowser").CredentialDetails(self,d.credential) end
 U.Label(self.body,d.name or "Без имени","Title")
 U.Label(self.body,"ТАБЕЛЬНЫЙ НОМЕР / "..(d.cid or "—").."     ДЕЛО / "..tostring(d.id or "—"),"Mono",U.muted)
 U.Label(self.body,d.bol and "ВНИМАНИЕ / РАЗЫСКИВАЕТСЯ" or d.restricted and "ДОСТУП ОГРАНИЧЕН" or "АРХИВНАЯ ЗАПИСЬ","Heading",U.accent)
 if d.bol and d.bolReason~="" then U.Label(self.body,d.bolReason or "","Body") end
 if d.genetic and d.genetic~="" then U.Label(self.body,d.genetic,"Body",U.muted) end
 U.Label(self.body,"ЖУРНАЛ СОБЫТИЙ","Heading")
 local categories={union="СЛУЖЕБНАЯ ЗАПИСЬ",civil="ПРОИСШЕСТВИЕ",med="МЕДИЦИНА",reg="РЕГИСТРАЦИЯ"}
 for _,record in ipairs(d.records or {}) do
  U.Label(self.body,(categories[record.category] or "ЗАПИСЬ").." / "..os.date("%d.%m.%Y %H:%M",tonumber(record.unix_time) or 0),"Mono",U.muted)
  U.Label(self.body,record.text or "","Body")
  U.Label(self.body,"Автор: "..(record.poster_name or "Не указан"),"Small",U.muted)
 end
 if #(d.records or {})==0 then U.Label(self.body,"Записей пока нет.","Body",U.muted) end
end
vgui.Register("ixDatafileView",PANEL,"DFrame")
