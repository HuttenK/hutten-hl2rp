-- Native input/render boundaries for the contextual equipment tests/previews.
CLIENT=true;SERVER=false;MASK_SOLID=1;IN_USE=32;IN_WALK=262144;IN_ATTACK=1
ix.Facility=ix.Facility or {};ix.water=ix.water or {};ix.gui=ix.gui or {};ix.bar={actionEnd=0}
ix.util={Include=function() end};ix.command={Add=function() end};ix.config.Add=function() end
ix.Reagents={IsRefillable=function(_,item) return not item.closed end}
function string.utf8sub(s,a,b)
 local n=utf8.len(s);b=b or n;if b<a then return '' end
 return s:sub(utf8.offset(s,a) or #s+1,(utf8.offset(s,b+1) or #s+1)-1)
end
p=admin();p.items={}
function p:GetNetVar(k,d) if self[k]~=nil then return self[k] end;return d end
function p:GetInventory() return {GetItems=function() return self.items end} end
function LocalPlayer() return p end
function p:GetAimVector() return Vector(1,0,0) end
function p:GetShootPos() return self.pos end
function p:IsPlayer() return true end
function ScrW() return screenW or 1280 end;function ScrH() return screenH or 720 end
function RealTime() return clock end
input={LookupBinding=function(command) return ({['+use']='f',['invprev']='mwheelup',['invnext']='mwheeldown'})[command] end,
 GetKeyCode=function(key) return key=='f' and 16 or 0 end,IsButtonDown=function(key) return physicalDown==true end,
 IsKeyTrapping=function() return trapping==true end,IsMouseDown=function() return false end}
gui={IsGameUIVisible=function() return gameMenu==true end,IsConsoleVisible=function() return consoleOpen==true end}
vgui.CursorVisible=function() return cursor==true end;vgui.GetKeyboardFocus=function() return focus end
ix.menu={IsOpen=function() return mainMenu==true end}
local nativeCreate=vgui.Create
panelsCreated=0;vgui.Create=function(...) panelsCreated=panelsCreated+1;return nativeCreate(...) end
util.TraceLine=function(data)
 traceData=data
 if data.mask==MASK_VISIBLE then return {Hit=wall==true} end
 return {Entity=aimed,Hit=IsValid(aimed),HitPos=IsValid(aimed) and aimed:GetPos() or Vector()}
end
function fixture(kind,id)
 local e=entity(id or 700,'',Vector(40,0,0));e.FacilityKind=kind;e.PrintName='Оборудование'
 e.class=(kind=='sink' and 'ix_sink_trigger' or kind=='toilet' and 'ix_toilet_trigger' or 'ix_facility_'..kind)
 function e:NearestPoint() return self.pos end
 function e:GetNW2Int(k,d) return self[k] or d end
 function e:GetNW2Entity(k) return self[k] end
 e.ixFacilityID=id or 700
 return e
end
function bottle(id,name)
 local item={id=id,uniqueID='empty_can',owner=p,isReagentHolder=true,reagents={volume=20,max_volume=600,reagents={}}}
 function item:GetOwner() return self.owner end;function item:GetName() return name or 'Фляга' end
 p.items[id]=item;return item
end
function command(down,walk)
 local cmd={keys={[IN_USE]=down==true,[IN_WALK]=walk==true,[IN_ATTACK]=true}}
 function cmd:KeyDown(key) return self.keys[key]==true end
 function cmd:RemoveKey(key) self.keys[key]=false end
 return cmd
end
painted={}
local nativeText=draw.SimpleText
function draw.SimpleTextOutlined(text,font,x,y,color,align,vertical,outline,outlineColor)
 painted[#painted+1]={text=text,font=font,x=x,y=y,color=color}
 nativeText(text,font,x,y,color,align,vertical)
end
net.handlers=net.handlers or {};local oldReceive=net.Receive
net.Receive=function(name,fn) net.handlers[name]=fn;oldReceive(name,fn) end
net.WriteEntity=function(value) net.packet.entity=value end
net.WriteBool=function(value) net.packet.boolean=value end
net.WriteUInt=function(value,bits) net.packet.integers=net.packet.integers or {};table.insert(net.packet.integers,value) end
surface.PlaySound=function() end
hook.Remove=hook.Remove or function() end
