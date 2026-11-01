-- Engine boundaries only; tests load the real bodycam/CCTV integration code.
bodyPlugin={}
ix.bodycams={};ix.Item={stored={},instances={},next=1000};ix.transmit={owner=1}
MOVETYPE_WALK=2;MOVETYPE_NOCLIP=8;MOVETYPE_OBSERVER=10
local itemMeta={}
function itemMeta:AddData(key,info) self.vars[key]=info end
function itemMeta:GetData(key,default) return self.data[key] or default end
function itemMeta:SetData(key,value) assert(self.vars[key],'Unregistered item data: '..key);self.data[key]=value end
function itemMeta:GetEntity() return self.entity end
function itemMeta:IsEquipped() return self.inventory_type==self.equip_inv end
function itemMeta:Remove()
 if self.failRemove then return false end
 self.removed=true;ix.Item.instances[self.id]=nil
 if self.owner then self.owner.items[self.id]=nil;if self.owner.head==self.id then self.owner.head=nil end end
 return true
end
function itemDefinition(id,head)
 local i=setmetatable({uniqueID=id,vars={},data={},functions={},equip_inv=head and 'head' or nil},{__index=itemMeta})
 ix.Item.stored[id]=i;return i
end
function ix.Item:Register(id,item)
 self.stored[id]=item;item.registrations=(item.registrations or 0)+1
 item.functions_id={};for key in pairs(item.functions) do item.functions_id[#item.functions_id+1]=key end
 table.sort(item.functions_id)
end
function ix.Item:Instance(id,data)
 if self.failInstance then return end
 local base=self.stored[id];assert(base)
 self.next=self.next+1;local item=setmetatable({id=self.next,data=data or {}},{__index=base})
 self.instances[item.id]=item;return item
end
itemDefinition('helmet_bodycam');itemDefinition('head_helmet_tier4',true);itemDefinition('head_helmet_tier5',true)
itemDefinition('helmet_construction',true);itemDefinition('baseball_cap',true);itemDefinition('custom_helmet',true).bodycamMount=true
local nextPlayer=500
function wearer(name)
 local p=admin();nextPlayer=nextPlayer+1;p.id=nextPlayer;p.name=name or 'Test wearer';p.items={};p.vars={};p.move=MOVETYPE_WALK
 entities[p.id]=p
 function p:EntIndex() return self.id end
 function p:Name() return self.name end
 function p:GetNoDraw() return self.hidden==true end
 function p:GetMoveType() return self.move end
 function p:GetLocalVar(k,d) if self.vars[k]~=nil then return self.vars[k] end return d end
 function p:IsRestricted() return self.restricted==true end
 function p:InCriticalState() return self.critical==true end
 function p:IsDormant() return self.dormant==true end
 function p:GetModelScale() return 1 end
 function p:SetupBones() end
 function p:LookupBone() return 6 end
 function p:GetBoneMatrix()
  local matrix=Matrix();matrix:SetTranslation(self:GetPos()+Vector(0,0,64));matrix:SetAngles(self.headAngle or Angle());return matrix
 end
 function p:LookupAttachment() return 1 end
 function p:GetAttachment() return {Pos=self:GetPos()+Vector(0,0,64),Ang=self.headAngle or Angle()} end
 function p:GetInventory(kind) if self.unloaded then return end;return kind=='head' and {type='head'} or {type='main'} end
 function p:GetFirstAtSlot() return self.head end
 function p:HasItemByID(id) return self.items[id]~=nil end
 function p:GetItems() local out={};for _,i in pairs(self.items) do out[#out+1]=i end;return out end
 function p:AddItem(i)
  if self.full then return false end
  self.items[i.id]=i;i.owner=self;i.inventory_type='main';return true
 end
 function p:SetNW2Int(k,v) self.vars[k]=v end
 function p:GetNW2Int(k,d) if self.vars[k]~=nil then return self.vars[k] end;return d end
 function p:SetNW2Bool(k,v) self.vars[k]=v end
 function p:GetNW2Bool(k,d) if self.vars[k]~=nil then return self.vars[k] end;return d end
 function p:SetAngles() error('must not set wearer angles') end
 function p:Remove() error('must not remove wearer') end
 return p
end
function giveHelmet(p,id)
 local h=ix.Item:Instance(id or 'head_helmet_tier4');p:AddItem(h);h.inventory_type='head';p.head=h.id;return h
end
function tick() clock=clock+.4 end
function attachCamera(p,h,on)
 p:AddItem(ix.Item:Instance('helmet_bodycam'));tick();assert(ix.bodycams.Change(p,h,'attach'))
 if on then tick();assert(ix.bodycams.Change(p,h,'on')) end
 return ix.bodycams.records[p]
end
