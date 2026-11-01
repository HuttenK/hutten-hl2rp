local PLAYER = FindMetaTable('Player')
ix.util={Include=function() end}
ix.command={Add=function() end}
ix.Item={stored={pistolammo={ammo='pistol',max_stack=30},shells={ammo='buckshot',max_stack=16},launcher={ammo='smg1_grenade',max_stack=4}},instances={}}
function SortedPairs(t)
 local keys={} for key in pairs(t) do keys[#keys+1]=key end table.sort(keys)
 local i=0 return function() i=i+1 local key=keys[i] if key then return key,t[key] end end
end
local ids={pistol=0,buckshot=1,smg1_grenade=2}
game={GetAmmoID=function(name) return ids[name:lower()] or -1 end}
timers={}; timer.Simple=function(delay,fn) timers[#timers+1]=fn end
function flush() local pending=timers; timers={} for _,fn in ipairs(pending) do fn() end end
function ammoItem(name,count)
 local item={ammo=name,data={stack=count}}
 function item:GetValue() return self.data.stack end
 function item:GetData(k,d) local v=self.data[k] if v==nil then return d end return v end
 function item:SetData(k,v) self.data[k]=v end
 function item:Remove() for k,v in pairs(p.items) do if v==self then p.items[k]=nil end end; PLUGIN:InventoryItemRemoved(inv,self) end
 return item
end
function ix.Item:Instance(id) return ammoItem(self.stored[id].ammo,0) end
function ix.Item:Spawn(client,_,item) dropped[#dropped+1]=item end
dropped={}
p=setmetatable({valid=true,items={},reserve={},weapons={},carryWeapons={},notices={}}, {__index=PLAYER})
inv={owner=p,GetItems=function() return p.items end,GetOwner=function() return p end}
function p:GetInventory() return inv end
function p:GetCharacter() return self.character end
p.character={GetID=function() return 1 end}
function p:Alive() return not self.dead end
function p:IsPlayer() return true end
function p:GetItems() return self.items end
function p:GetWeapons() return self.weapons end
function p:GetAmmoCount(id) if isstring(id) then id=game.GetAmmoID(id) end return self.reserve[id] or 0 end
function p:SetAmmo(n,id) if isstring(id) then id=game.GetAmmoID(id) end self.reserve[id]=n end
function p:AddItem(item) if self.full then return false end table.insert(self.items,item); PLUGIN:InventoryItemAdded(nil,inv,item); return true end
function p:Notify(msg) self.notices[#self.notices+1]=msg end
p.NotifyLocalized=p.Notify
function p:EmitSound() end
function p:SelectWeapon(name) self.selected=name end
function p:GetWeapon(class) for _,w in ipairs(self.weapons) do if w.valid and w.class==class then return w end end end
function p:StripWeapon(class) local w=self:GetWeapon(class) if w then w:Remove() end self.reserve={} end
weapons={GetStored=function(class) if class=='arc9_eft_glock17' then return {Base='arc9_eft_base'} elseif class=='arc9_eft_base' then return {Base='arc9_base'} elseif class=='legacy' then return {Base='arccw_base'} end end}
function newWeapon()
 local w={valid=true,ARC9=true,class='arc9_eft_glock17',clip=17,clip2=1,Attachments={{Installed='default'}},values={Ammo='pistol',UBGLAmmo='smg1_grenade',ClipSize=17,UBGLClipSize=1,UBGL=true}}
 function w:GetClass() return self.class end
 function w:GetOwner() return p end
 function w:GetValue(k) return self.values[k] end
 w.GetProcessedValue=w.GetValue
 function w:GetCapacity(secondary) return secondary and (self.values.UBGL and self.values.UBGLClipSize or 0) or self.values.ClipSize end
 function w:TakeAmmo() self.clip=math.max(0,self.clip-1) end
 function w:Clip1() return self.clip end
 function w:Clip2() return self.clip2 end
 function w:SetClip1(n) self.clip=n end
 function w:SetClip2(n) self.clip2=n end
 function w:SetLoadedRounds(n) self.loaded=n end
 function w:BuildSubAttachments(t) self.Attachments=t end
 function w:DoInvalidateCache() end
 function w:PruneAttachments() end
 function w:FillIntegralSlots() end
 function w:SetBaseSettings() end
 function w:SendWeapon() self.sent=true end
 function w:CancelReload() end
 function w:PostModify() timer.Simple(0,function() if not self.AlreadyGaveAmmo then self:SetClip1(17) end end) end
 function w:Remove() self.valid=false end
 return w
end
function p:Give(class,noAmmo) eq(noAmmo,true) if self.failGive then return end local w=newWeapon(); w.class=class; self.weapons[#self.weapons+1]=w; return w end
function newItem(id)
 local item=setmetatable({id=id or 1,class='arc9_eft_glock17',weaponCategory='sidearm',isWeapon=true,data={ammo=7,ammo2=1},useSound='test'}, {__index=Item})
 function item:GetData(k,d) local v=self.data[k] if v==nil then return d end return v end
 function item:SetData(k,v) self.data[k]=v end
 function item:GetOwner() return p end
 function item:Remove() self:OnRemoved(); ix.Item.instances[self.id]=nil; for k,v in pairs(p.items) do if v==self then p.items[k]=nil end end end
 item.inventory_id=1
 ix.Item.instances[item.id]=item; table.insert(p.items,item)
 return item
end
ix.Inventory={Get=function() return inv end}
