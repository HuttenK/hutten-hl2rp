-- Derma base adapter; production generic.menu.lua owns menu construction,
-- option layout, colors and Paint. This does not replace that Lua source.
ix.UI={Scale=function(n) return n end}
function AccessorFunc(t,key,name)
 t['Set'..name]=function(self,value) self[key]=value end
 t['Get'..name]=function(self) return self[key] end
end
function ColorAlpha(c,a) return Color(c.r,c.g,c.b,a) end
function string.utf8upper(s)
 local out={};for _,code in utf8.codes(s) do
  if code>=1072 and code<=1103 then code=code-32 elseif code==1105 then code=1025 elseif code>=97 and code<=122 then code=code-32 end
  out[#out+1]=utf8.char(code)
 end;return table.concat(out)
end
math.ease={OutCubic=function(n) return 1-(1-n)^3 end}
function math.Approach(n,target,step) return n<target and math.min(target,n+step) or math.max(target,n-step) end
render=render or {};render.OverrideBlend=function() end
derma={SkinHook=function() end}
DButton={PerformLayout=function() end};DScrollPanel={PerformLayout=function() end}
local menus={};function RegisterDermaMenuForClose(menu) menus[menu]=true end
function CloseDermaMenus() for menu in pairs(menus) do if IsValid(menu) then menu:Remove() end end end
function gui.MouseX() return 0 end;function gui.MouseY() return 0 end
local classes={};local oldRegister,oldCreate=vgui.Register,vgui.Create
function vgui.Register(name,definition,baseClass)
 if name=='simple.option' or name=='simple.option.button' then classes[name]=definition else oldRegister(name,definition,baseClass) end
end
local methods={}
local function nop() end
methods.SetIsMenu=nop;methods.SetPaintBackground=nop;methods.SetDrawOnTop=nop;methods.SetPadding=nop
methods.SetContentAlignment=nop;methods.SetKeyboardInputEnabled=nop
function methods:SetTextInset(x,y) self.inset=x end
function methods:SetEnabled(value) self.enabled=value end
function methods:SetTooltip(value) self.tooltip=value end
function methods:IsEnabled() return self.enabled~=false end
function methods:IsModal() return false end
function methods:MakePopup() cursor=true end
function methods:GetCanvas() return self.canvas or self end
function methods:GetChildren()
 local children={};for _,child in ipairs(self.children) do if IsValid(child) then children[#children+1]=child end end
 return children
end
function methods:GetText() return self.text end
function methods:SetImage(value) self.image=value;self.ActualWidth=16;self.ActualHeight=16 end
function methods:SizeToContents()
 if self.class=='DImage' then self.w=16;self.h=16;return end
 surface.SetFont(self.font);self.w,self.h=surface.GetTextSize(self.text);self.w=self.w+(self.inset or 0)
end
function methods:AddItem(child)
 if child.parent~=self.canvas then
  for i,p in ipairs(child.parent.children) do if p==child then table.remove(child.parent.children,i);break end end
  child.parent=self.canvas;self.canvas.children[#self.canvas.children+1]=child
 end
end
function methods:Add(name)
 local child=oldCreate(name,self)
 if name=='DImage' then child.SetImage=methods.SetImage;child.SizeToContents=methods.SizeToContents end
 return child
end
function methods:InvalidateLayout()
 if self.layingOut or not self.PerformLayout then return end
 self.layingOut=true;self:PerformLayout(self.w,self.h);self.layingOut=nil
 if self.canvas then self.canvas:SetSize(self.w,self.h) end
end
function vgui.Create(name,parent)
 local definition=classes[name]
 if not definition then return oldCreate(name,parent) end
 local p=oldCreate(name=='simple.option' and 'DScrollPanel' or 'DButton',parent)
 local oldIndex=getmetatable(p).__index
 setmetatable(p,{__index=function(self,key) return definition[key] or methods[key] or oldIndex(self,key) end})
 p.class=name
 if p.canvas then
  local getChildren=p.canvas.GetChildren
  p.canvas.GetChildren=function(canvas) local result={};for _,child in ipairs(getChildren(canvas)) do if IsValid(child) then result[#result+1]=child end end;return result end
 end
 local oldRemove=p.Remove
 p.Remove=function(self) oldRemove(self);if name=='simple.option' then cursor=false end end
 if name=='simple.option.button' then
  p.PaintOver=function(self,w,h) draw.SimpleText(self.text,self.font,w/2+(self.inset or 0)/2,h/2,self.enabled==false and Color(120,90,90) or self.ink,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER) end
 end
 p:Init()
 return p
end
function menuOption(menu,label)
 for _,option in ipairs(menu:GetCanvas():GetChildren()) do if option.text==string.utf8upper(label) then return option end end
 error('Menu option missing: '..label)
end
