ix.infoMenu = {}
ix.infoMenu.stored = {}

function ix.infoMenu.Add(text)
	table.insert(ix.infoMenu.stored, text)
end

function ix.infoMenu.GetData()
	local character = LocalPlayer():GetCharacter()
	local faction = ix.faction.indices[LocalPlayer():Team()]

	hook.Run("SetInfoMenuData", character, faction)
end

function ix.infoMenu.Display()
 if IsValid(ix.infoMenu.panel) then ix.infoMenu.Remove(); return end
 local client=LocalPlayer()
 if not IsValid(client) or not client.GetCharacter or not client:GetCharacter() then return end
	ix.infoMenu.stored = {}     
	ix.infoMenu.GetData()

	ix.infoMenu.open = true
	ix.infoMenu.panel = vgui.Create("ixInfoMenu")
end

function ix.infoMenu.Remove()
	if (IsValid(ix.infoMenu.panel)) then
		ix.infoMenu.panel:Remove()
	end

	ix.infoMenu.panel = nil
	ix.infoMenu.open = false
end 

local PANEL = {}
function PANEL:Init()
 local U=ix.Legends; local S=U.Scale
 self.character=LocalPlayer():GetCharacter()
 self.noAnchor=CurTime()+0.4; self.anchorMode=true
 self:SetSize(math.min(S(860),ScrW()-S(48)),math.min(S(650),ScrH()-S(72)))
 self:Center(); self:MakePopup()
 self:DockPadding(S(28),S(82),S(28),S(24))
 local close=U.Button(self,U.T("Close / F1","Закрыть / F1"),function() ix.infoMenu.Remove() end)
 close:SetSize(S(180),S(38)); close:SetPos(self:GetWide()-S(208),S(22))
 local diagram=self:Add("Panel"); diagram:Dock(RIGHT); diagram:SetWide(S(160)); diagram:DockMargin(S(24),0,0,0)
 diagram.Paint=function(_,w,h)
  if ix.Anatomy then ix.Anatomy.Draw(0,S(30),w,math.min(h-S(60),S(330)),ix.Anatomy.Read(self.character)) end
 end
 local content=U.Scroll(self); content:Dock(FILL)
 U.Label(content,self.character and self.character:GetName() or "","Heading")
 local faction=ix.faction.indices[LocalPlayer():Team()]
 U.Label(content,faction and L(faction.name) or "","Mono",U.accent)
 for _,text in ipairs(ix.infoMenu.stored) do U.Label(content,text,"Body",U.muted) end
 U.Label(content,U.T("QUICK ACTIONS","БЫСТРЫЕ ДЕЙСТВИЯ"),"Mono",U.accent):DockMargin(0,S(24),0,S(14))
 for _,entry in ipairs(ix.quickmenu.stored) do
  if not entry.shouldShow or entry.shouldShow()==true then
   local button=U.Button(content,entry.name,function()
    if entry.shouldShow and entry.shouldShow()~=true then return end
    ix.infoMenu.Remove()
    if entry.callback then entry.callback() end
   end)
   button:Dock(TOP); button:DockMargin(0,0,0,S(8))
  end
 end
end
function PANEL:Paint(w,h)
 local U=ix.Legends; local S=U.Scale
 U.Plate(0,0,w,h,Color(10,7,11,245),U.line)
 U.Text(U.T("PERSONAL TERMINAL","ЛИЧНЫЙ ТЕРМИНАЛ"),"Heading",S(28),S(28),U.ink)
 U.Rect(S(28),S(68),w-S(56),1,U.line)
end
function PANEL:OnKeyCodePressed(key)
 if key==KEY_F1 or key==KEY_ESCAPE then ix.infoMenu.Remove() end
end
function PANEL:Think()
 local client=LocalPlayer()
 if not IsValid(client) or not client.GetCharacter or client:GetCharacter()~=self.character then ix.infoMenu.Remove(); return end
 local held=input.IsKeyDown(KEY_F1)
 if held and CurTime()>self.noAnchor then self.anchorMode=false end
 if (not self.anchorMode and not held) or gui.IsGameUIVisible() then ix.infoMenu.Remove() end
end
function PANEL:OnRemove()
 if ix.infoMenu.panel==self then ix.infoMenu.panel=nil; ix.infoMenu.open=false end
end
vgui.Register("ixInfoMenu",PANEL,"EditablePanel")
