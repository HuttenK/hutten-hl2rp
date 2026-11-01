-- Extra native-Derma boundaries for the equipment paint/interaction fixtures.
-- The production builders and paint callbacks are loaded without replacement.
local function noop() end
local original=vnew
function vnew(class,parent)
 local p=original(class,parent)
 p.ShowCloseButton=noop;p.SetDraggable=noop;p.SetScreenLock=noop;p.SetCursor=noop;p.MouseCapture=noop
 p.SetUpdateOnType=noop;p.SetTooltip=noop
 p.SetValue=function(s,v) s.text=v end
 p.AddChoice=function(s,text,value) s.choices=s.choices or {};s.choices[#s.choices+1]={text,value} end
 p.Think=noop;p.CursorPos=function() return 0,0 end
 p.SetDisabled=function(s,v) s.disabled=v end
 p.IsEnabled=function(s) return not s.disabled end
 p.IsDown=function(s) return s.down==true end
 p.Close=function(s) s:Remove() end
 p.Remove=function(s) if not s.valid then return end;s.valid=false;s.visible=false;if s.OnRemove then s:OnRemove() end end
 return p
end
vgui.Create=vnew
function string.utf8sub(s,a,b)
 local n=utf8.len(s);a=a<0 and n+a+1 or a;b=b and (b<0 and n+b+1 or b) or n
 if b<a then return '' end
 return s:sub(utf8.offset(s,a) or #s+1,(utf8.offset(s,b+1) or #s+1)-1)
end
function ScrW() return screenW or 1920 end
function ScrH() return screenH or 1080 end
function RealTime() return clock end
KEY_ESCAPE=70;MOUSE_LEFT=107;MASK_SOLID=1
ix.field={};ix.water={Near=function() return nearWater~=false end};ix.util={Include=noop}
net.handlers={};net.Receive=function(name,fn) net.handlers[name]=fn end
function net.Start(name) net.packet={name=name,values={}} end
function net.WriteEntity(v) table.insert(net.packet.values,v) end
function net.WriteUInt(v,bits) table.insert(net.packet.values,{v,bits}) end
function net.WriteBool(v) table.insert(net.packet.values,v) end
function net.WriteString(v) table.insert(net.packet.values,v) end
function net.SendToServer() sent[#sent+1]=net.packet end
local reads={}
function read(values) reads=values end
local function nextValue() return table.remove(reads,1) end
net.ReadEntity=nextValue;net.ReadUInt=nextValue;net.ReadBool=nextValue;net.ReadFloat=nextValue;net.ReadString=nextValue
sent={};hooks={};hook.Add=function(event,name,fn) hooks[name]=fn end
input={LookupBinding=function() return 'e' end};gui={IsGameUIVisible=function() return gameMenu==true end}
playerMock={valid=true,character={},pos=Vector()}
function playerMock:GetCharacter() return self.character end
function playerMock:Alive() return not self.dead end
function playerMock:IsAdmin() return self.admin==true end
function playerMock:GetShootPos() return self.pos end
function playerMock:GetAimVector() return Vector(1,0,0) end
function LocalPlayer() return playerMock end
function EyePos() return playerMock.pos end
function equipment(kind)
 local e={valid=true,FacilityKind=kind,PrintName='Датчик биологической опасности',state={},pos=Vector(20,0,0),draws=0}
 function e:GetNW2Bool(k,d) if self.state[k]~=nil then return self.state[k] end;return d end
 function e:GetNW2String(k,d) return self.state[k] or d end
 function e:GetNW2Entity(k) return self.state[k] end
 function e:GetPos() return self.pos end
 function e:DrawModel() self.draws=self.draws+1 end
 return e
end
function buttons(root)
 local out={}
 local function visit(p) for _,c in ipairs(p.children) do if c.class=='DButton' then out[#out+1]=c end;visit(c) end end
 visit(root);return out
end
function texts(root)
 local out={};local function visit(p) if p.text and p.text~='' then out[#out+1]=p.text end;for _,c in ipairs(p.children) do visit(c) end end
 visit(root);return table.concat(out,' | ')
end
function SortedPairs(t)
 local keys={};for k in pairs(t) do keys[#keys+1]=k end;table.sort(keys)
 local i=0;return function() i=i+1;local key=keys[i];if key then return key,t[key] end end
end
function plate(id,hp)
 local values={id,#hp};for _,v in ipairs(hp) do values[#values+1]=v end
 read(values);net.handlers.ixPlateInspect();return ix.gui.plateInspect
end
traced={};util.TraceLine=function(query) traced[#traced+1]=query;return {Entity=aimed} end
render={DrawLine=function() sprayLines=(sprayLines or 0)+1 end}
