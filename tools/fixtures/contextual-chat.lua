CAMI={RegisterPrivilege=function() end}
commands={}; ix.command={Add=function(name,data) commands[name:lower()]=data end}
ix.type={player=1,text=2}; Color=function(...) return {...} end
ix.config.Get=function(key,default) if key=='chatMax' then return 1024 end return default end
string.utf8len=utf8.len
function string.utf8sub(s,first,last)
 first=math.max(first,1)
 return s:sub(utf8.offset(s,first) or (#s+1),(utf8.offset(s,last+1) or (#s+1))-1)
end
function hook.Run(event,...)
 for _,fn in pairs(hooks[event] or {}) do local result=fn(...); if result~=nil then return result end end
end
function hook.Remove(event,name) if hooks[event] then hooks[event][name]=nil end end
packets={}; warnings={}
function ErrorNoHalt(text) warnings[#warnings+1]=text end
function net.Start(name) packet={name=name,strings={}} end
function net.WriteEntity(value) packet.speaker=value end
function net.WriteString(value) packet.strings[#packet.strings+1]=value end
function net.WriteBool(value) packet.anonymous=value end
function net.WriteTable(value) packet.data=value end
function net.Send(receivers)
 if packet.name=='ixChatMessage' then packet.receivers=receivers; packets[#packets+1]=packet end
end
function net.Broadcast() error('Unexpected chat broadcast') end
function newChatter(distance,admin)
 local p=newMedic(); p.distance=distance or 0; p.admin=admin
 function p:IsAdmin() return self.admin==true end
 function p:Name() return 'Secret identity' end
 function p:NotifyLocalized(text) self:Notify(text) end
 function p:GetPos()
  return setmetatable({x=self.distance},{__sub=function(a,b)
   return {LengthSqr=function() return (a.x-b.x)^2 end}
  end})
 end
 return p
end
function initNearbyChat()
 ix.chat.Register('me',{CanHear=280})
 local actor,nearby,far=newChatter(0),newChatter(200),newChatter(500)
 allPlayers={actor,nearby,far}
 return actor,nearby,far
end
ix.transmit={owner=1,none=0}
ix.Reagents={holder={injectable=1,open=2}}
function ix.Reagents:Consume(holder,amount,client)
 holder.volume=holder.volume-amount
 return amount,amount/2
end
ix.meta.ItemReagentContainer={Init=function(self) self.functions={} end}
function implements(base,name)
 setmetatable(ix.meta[name],{__index=ix.meta[base]})
end
function newConsumable(p,kind,volume,name)
 local base=kind=='food' and ix.meta.ItemFood or ix.meta.ItemDrink
 local item=setmetatable({player=p,reagents={volume=volume},data={},name=name},{__index=base})
 function item:AddData() end
 function item:GetData(key,default) if self.data[key]~=nil then return self.data[key] end return default end
 function item:SetData(key,value) self.data[key]=value end
 function item:GetEntity() end
 function item:GetName() assert(not self.depleted,'Name requested after item deletion'); return self.name end
 function item:OnDepleted() self.depleted=true; self.reagents.volume=0 end
 function item.reagents:Clear() self.volume=0 end
 function p.character:UpdateNeeds(thirst,hunger) self.thirst=thirst; self.hunger=hunger end
 item:Init()
 return item
end
