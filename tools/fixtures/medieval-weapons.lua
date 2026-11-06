-- Source-style SWEP doubles: no ARC9, progression or medical APIs are supplied.
local PLAYER=FindMetaTable('Player')
ix.command={Add=function() end}
ix.Item={stored={bolts={ammo='XBowBolt',max_stack=10}},instances={}}
local ids={xbowbolt=0};game={GetAmmoID=function(n) return ids[n:lower()] or -1 end,GetAmmoName=function(id) return id==0 and 'XBowBolt' or nil end}
timers={};timer.Simple=function(_,fn) timers[#timers+1]=fn end
function flush() local pending=timers;timers={} for _,fn in ipairs(pending) do fn() end end
dropped={}
p=setmetatable({valid=true,items={},reserve={},weapons={},carryWeapons={},notices={}},{__index=PLAYER})
function p:GetCharacter() return self.character end
p.character={GetID=function() return 1 end}
function p:Alive() return not self.dead end
function p:IsPlayer() return true end
function p:GetItems() return self.items end
function p:GetWeapons() local result={} for _,w in ipairs(self.weapons) do if IsValid(w) then result[#result+1]=w end end return result end
function p:GetAmmoCount(id) if isstring(id) then id=game.GetAmmoID(id) end return self.reserve[id] or 0 end
function p:SetAmmo(n,id) if isstring(id) then id=game.GetAmmoID(id) end self.reserve[id]=n end
function p:Notify(msg) self.notices[#self.notices+1]=msg end
p.NotifyLocalized=p.Notify
function p:EmitSound() end
function p:SelectWeapon(name) self.selected=name end
function p:GetWeapon(name) for _,w in ipairs(self.weapons) do if w.valid and w.class==name then return w end end end
function p:StripWeapon(name) local w=self:GetWeapon(name) if w then w:Remove() end self.reserve={} end
function newWeapon()
 local w={valid=true,class='test_crossbow',clip=1,clip2=-1}
 function w:GetClass() return self.class end
 function w:GetOwner() return p end
 function w:GetPrimaryAmmoType() return 0 end
 function w:GetSecondaryAmmoType() return -1 end
 function w:Clip1() return self.clip end
 function w:Clip2() return self.clip2 end
 function w:SetClip1(n) self.clip=n end
 function w:SetClip2(n) self.clip2=n end
 function w:Remove() self.valid=false end
 return w
end
function p:Give(name,noAmmo) eq(noAmmo,true) if self.failGive then return end local w=newWeapon();w.class=name;self.weapons[#self.weapons+1]=w;return w end
function newItem(id)
 local item=setmetatable({id=id,class='test_crossbow',weaponCategory='primary',isWeapon=true,model='crossbow.mdl',data={ammo=1,ammo2=-1}},{__index=Item})
 function item:GetData(k,d) local v=self.data[k] if v==nil then return d end return v end
 function item:SetData(k,v) self.data[k]=v end
 function item:GetOwner() return p end
 function item:Remove() self:OnRemoved();ix.Item.instances[self.id]=nil;for k,v in pairs(p.items) do if v==self then p.items[k]=nil end end end
 item.inventory_id=1;ix.Item.instances[id]=item;table.insert(p.items,item);return item
end
local ammoID=1000
function ammoItem(n)
 ammoID=ammoID+1
 local item={id=ammoID,uniqueID='bolts',ammo='XBowBolt',data={stack=n}}
 function item:GetValue() return self.data.stack end
 function item:GetData(k,d) local v=self.data[k] if v==nil then return d end return v end
 function item:SetData(k,v) self.data[k]=v end
 function item:Remove() for k,v in pairs(p.items) do if v==self then p.items[k]=nil end end PLUGIN:InventoryItemRemoved(inv,self) end
 return item
end
function ix.Item:Instance() return ammoItem(0) end
function ix.Item:Spawn(_,__,item) dropped[#dropped+1]=item end
function p:AddItem(item) if self.full then return false end table.insert(self.items,item);PLUGIN:InventoryItemAdded(nil,inv,item);return true end
ix.Inventory={}
