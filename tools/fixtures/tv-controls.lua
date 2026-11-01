-- Native-panel construction and interaction fixture; not an engine renderer.
function ScrW() return 1920 end
TOP=1;BOTTOM=2;LEFT=3;FILL=4;RIGHT=5;TEXT_ALIGN_LEFT=0;TEXT_ALIGN_CENTER=1;TEXT_ALIGN_RIGHT=2
KEY_ESCAPE=70;KEY_R=19;KEY_LSHIFT=79;KEY_RSHIFT=80;MOUSE_LEFT=107;MOUSE_RIGHT=108
function math.Round(v,decimals) local scale=10^(decimals or 0);return math.floor(v*scale+.5)/scale end
IN_ATTACK=1;IN_ATTACK2=2;IN_RELOAD=4
function string.utf8sub(s,a,b) return s:sub(utf8.offset(s,a),b and ((utf8.offset(s,b+1) or (#s+1))-1) or #s) end
local methods={};methods.__index=methods
uiPanels={}
local function panel(kind,parent)
 local p=setmetatable({valid=true,kind=kind,children={},parent=parent,enabled=true,w=640,h=38},methods)
 uiPanels[#uiPanels+1]=p
 if parent then parent.children[#parent.children+1]=p end
 if kind=='DNumSlider' then p.Label=panel('DLabel',p) end
 return p
end
local htmlCreate=vgui.Create
function vgui.Create(kind) if kind=='DHTML' then return htmlCreate(kind) end;return panel(kind) end
function methods:Add(kind) return panel(kind,self) end
function methods:Remove() self.valid=false;if self.OnRemove then self:OnRemove() end;for _,c in ipairs(self.children) do c:Remove() end end
function methods:Clear() for _,c in ipairs(self.children) do c:Remove() end;self.children={} end
function methods:SetSize(w,h) self.w=w;self.h=h end
function methods:SetTall(h) self.h=h end
function methods:SetWide(w) self.w=w end
function methods:SetText(v) self.text=v;self.value=v end
function methods:SetTooltip(v) self.initialTooltip=self.initialTooltip or v;self.tooltip=v end
function methods:SetValue(v)
 if self.kind=='DNumSlider' and self.min and self.max then v=math.Clamp(tonumber(v) or 0,self.min,self.max) end
 self.value=v;if self.OnValueChanged then self:OnValueChanged(v) end
end
function methods:SetMinMax(low,high) self.min=low;self.max=high;self:SetValue(self.value or 0) end
function methods:GetMin() return self.min end
function methods:GetMax() return self.max end
function methods:GetValue() return self.value end
function methods:GetChecked() return self.value==true end
function methods:AddChoice(text,id,selected) self.choices=self.choices or {};self.choices[id]=text;if selected then self.value=id end end
function methods:SetEnabled(v) self.enabled=v end
function methods:IsEnabled() return self.enabled end
function methods:IsHovered() return false end
function methods:IsDown() return false end
function methods:HasFocus() return false end
for _,key in ipairs({'Dock','DockMargin','SetFont','SetTextColor','SetWrap','SetPlaceholderText','SetCursorColor','DrawTextEntryText','SetPos','Center','SetTitle','ShowCloseButton','SetDraggable','MakePopup','DockPadding','SizeToContents','SetDecimals','SetMin','SetMax'}) do methods[key]=function() end end
function uiFind(kind,text)
 for i=#uiPanels,1,-1 do local p=uiPanels[i];if p.valid and p.kind==kind and (p.text==text or p.tooltip==text or p.initialTooltip==text) then return p end end
 error('Missing panel '..kind..' / '..text)
end
surface.SetFont=function() end;surface.GetTextSize=function(text) return utf8.len(text)*9,17 end
surface.SetDrawColor=function() end;surface.DrawRect=function() end;surface.DrawOutlinedRect=function() end;surface.DrawLine=function() end
draw={RoundedBox=function() end,SimpleText=function() end}
gui={IsGameUIVisible=function() return false end}
keys={};mouse={};input={IsKeyDown=function(k) return keys[k] or false end,IsMouseDown=function(k) return mouse[k] or false end}
Derma_Query=function(_,_,_,fn) confirm=fn end
Derma_StringRequest=function(_,_,_,fn) prompt=fn end
