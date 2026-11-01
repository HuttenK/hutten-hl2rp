-- Item-backed inventories for the ARC9 state fixture. The separate integration
-- suite also exercises the production Inventory class and its transfer hooks.
hook.handlers = {}
function hook.Add(event, name, fn)
 hook.handlers[event] = hook.handlers[event] or {}
 hook.handlers[event][name] = fn
end
function hook.Remove(event, name) if hook.handlers[event] then hook.handlers[event][name] = nil end end
function hook.Run(event, ...)
 for _, fn in pairs(hook.handlers[event] or {}) do local a,b = fn(...) if a ~= nil then return a,b end end
 if event == 'InventoryItemRemoved' then
  local old,item,new = ...
  if item.OnTransfer then item:OnTransfer(new,old) end
 end
end
function util.TableToJSON(t)
 if type(t)~='table' then return tostring(t) end
 local keys={} for k in pairs(t) do keys[#keys+1]=k end
 table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
 local out={} for _,k in ipairs(keys) do out[#out+1]=tostring(k)..'='..util.TableToJSON(t[k]) end
 return '{'..table.concat(out,',')..'}'
end
ix.Inventory.stored = {}
ix.Inventory.pendingTransfers = {}
function ix.Inventory:Get(id) return self.stored[id] end
local function inventory(id,kind)
 local v={id=id,type=kind,owner=p,isEquipment=kind~='main'}
 function v:GetOwner() return self.owner end
 function v:IsWidthInfinite() return false end
 function v:IsHeightInfinite() return false end
 function v:GetItems()
  local items={} for _,item in pairs(p.items) do if item.inventory_id==self.id or (not item.isWeapon and self==inv) then items[#items+1]=item end end
  return items
 end
 function v:GetFirstAtSlot() local item=self:GetItems()[1] return item and item.id end
 function v:GetItemSize() return 1,1 end
 function v:SendDeltaTransfer() self.transfers=(self.transfers or 0)+1 end
 function v:Transfer(id,target)
  local item=ix.Item.instances[id]
  if not item or item.inventory_id~=self.id then return false,'invalidItem' end
  local ok,err=item:CanTransfer(self,target)
  if ok==false then return false,err end
  if target.isEquipment and target:GetFirstAtSlot() or target==inv and p.full then return false,'noFit' end
  item.inventory_id=target.id;item.inventory_type=target.type;item.x=1;item.y=1
  hook.Run('InventoryItemRemoved',self,item,target)
  hook.Run('InventoryItemAdded',self,target,item)
  return true
 end
 ix.Inventory.stored[id]=v
 return v
end
inv=inventory(1,'main')
p.inventories={main=inv}
for i=1,3 do p.inventories['weapon'..i]=inventory(i+1,'weapon'..i) end
function p:GetInventory(kind) return self.inventories[kind or 'main'] end
function p:GetInventories() return self.inventories end
function p:IsBot() return true end
function p:IsRestricted() return self.restricted or false end
function p:GetActiveWeapon() return self:GetWeapon(self.selected) end
function p:GetBackpack() return nil end
function p:SetNetVar(k,v) self.netvars=self.netvars or {};self.netvars[k]=v end
function p:GetNetVar(k,d) return self.netvars and self.netvars[k] or d end
local original=newWeapon
function newWeapon()
 local w=original()
 w.net={}
 function w:SetNWInt(k,v) self.net[k]=v end
 function w:GetNWInt(k,d) return self.net[k] or d end
 function w:GetNextPrimaryFire() return self.nextFire or 0 end
 function w:GetReloading() return self.reloading or false end
 function w:GetGrenadePrimed() return self.primed or false end
 return w
end
local make=newItem
function newItem(id)
 local item=make(id)
 item.weaponCategory='primary'
 item.x=1;item.y=1;item.inventory_type='main';item.equip_inv='weapon'
 function item:GetName() return 'Weapon '..self.id end
 item.GetPrintName=item.GetName
 function item:IsEquipped() return ix.WeaponSlots.Equipped(self) end
 return item
end
