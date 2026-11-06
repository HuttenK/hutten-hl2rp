local PLUGIN = PLUGIN
PLUGIN.name = "Inventory Weapons"
PLUGIN.author = "Legends"
PLUGIN.description = "Inventory-owned weapons, slots and ammunition."
ix.util.Include("sh_ammo.lua")
ix.util.Include("sh_weapon_slots.lua")
local A = ix.weaponInventory
local playerMeta = FindMetaTable("Player")

local function Stack(item)
 return math.max(0, math.floor(tonumber(item.GetValue and item:GetValue() or item:GetData("stack", item.ammoAmount or 0)) or 0))
end

local function Carried(client)
 local result = {}
 for _, weapon in ipairs(client:GetWeapons()) do
  if IsValid(weapon) and weapon.ixItem and not weapon.ixItem.singleUse and weapon.ixInventoryReady then
   for _, id in ipairs({weapon:GetPrimaryAmmoType(), weapon:GetSecondaryAmmoType()}) do
    local name = id >= 0 and game.GetAmmoName(id)
    if name then result[name:lower()] = id end
   end
  end
 end
 return result
end

-- Settle reserve consumption BEFORE any inventory recount. Otherwise a pickup
-- in the same tick as a reload would restore already-spent rounds.
function A.Settle(client)
 if not SERVER or not client.ixAmmoReady or client.ixAmmoBusy or not client:Alive() then return end
 if client.ixAmmoCharacter ~= client:GetCharacter() then return end
 local inventory = client:GetInventory("main")
 if not inventory then return end
 client.ixAmmoBusy = true
 local carried = Carried(client)
 for name, tracked in pairs(client.ixAmmoTracker or {}) do
  local id = game.GetAmmoID(name)
  if id and id >= 0 then
   local current = client:GetAmmoCount(id)
   if current < tracked and carried[name] then
    local need = tracked - current
    for _, item in ipairs(A.CarriedItems(client, inventory)) do
     if need > 0 and isstring(item.ammo) and item.ammo:lower() == name then
      local count = Stack(item)
      local used = math.min(count, need)
      need = need - used
      if used == count then item:Remove(true) else item:SetData("stack", count - used) end
     end
    end
    client.ixAmmoTracker[name] = current
   elseif current ~= tracked then
    -- Unowned reserves, grants and stripped weapons cannot create/delete items.
    client:SetAmmo(tracked, id)
   end
  end
 end
 client.ixAmmoBusy = nil
end

function playerMeta:CalculateAmmo(ammoType)
 if not SERVER or self.ixAmmoBusy or not self:GetCharacter() then return end
 local inventory = self:GetInventory("main")
 if not inventory then return end
 if self.ixAmmoCharacter ~= self:GetCharacter() then
  self.ixAmmoReady = false
  for name in pairs(self.ixAmmoTracker or {}) do self:SetAmmo(0, name) end
  self.ixAmmoTracker = {}
  self.ixAmmoCharacter = self:GetCharacter()
  ammoType = nil
 end
 A.Settle(self)
 ammoType = isstring(ammoType) and ammoType:lower() or nil
 local totals = {}
 for _, item in ipairs(A.CarriedItems(self, inventory)) do
  if isstring(item.ammo) then
   local name = item.ammo:lower()
   if not ammoType or ammoType == name then totals[name] = (totals[name] or 0) + Stack(item) end
  end
 end
 self.ixAmmoTracker = self.ixAmmoTracker or {}
 if ammoType then
  totals[ammoType] = totals[ammoType] or 0
 else
  for name in pairs(self.ixAmmoTracker) do totals[name] = totals[name] or 0 end
  for name in pairs(Carried(self)) do totals[name] = totals[name] or 0 end
  self.ixAmmoTracker = {}
 end
 for name, count in pairs(totals) do
  local id = game.GetAmmoID(name)
  if id and id >= 0 then self:SetAmmo(count, id); self.ixAmmoTracker[name] = count end
 end
 self.ixAmmoReady = true
end

if SERVER then
 function PLUGIN:PlayerTick(client)
  if not client:GetCharacter() or not client:Alive() then return end
  A.Settle(client)
  if (client.ixNextAmmoSync or 0) < CurTime() then
   client.ixNextAmmoSync = CurTime() + 0.25
   client:CalculateAmmo()
  end
  for name, id in pairs(Carried(client)) do
   if client.ixAmmoReady and not client.ixAmmoTracker[name] then
    client.ixAmmoTracker[name] = 0
    client:SetAmmo(0, id)
   end
  end
 end
 function PLUGIN:PlayerLoadedCharacter(client, character)
  client.ixAmmoReady = false
  client.ixAmmoTracker = {}
  client.ixAmmoCharacter = character
  timer.Simple(0, function()
   if IsValid(client) and client:GetCharacter() == character then client:CalculateAmmo() end
  end)
 end
 local function Refresh(inventory)
  local owner = inventory and inventory.owner
  if IsValid(owner) and owner:IsPlayer() and not owner.ixAmmoBusy then owner:CalculateAmmo() end
 end
 function PLUGIN:InventoryItemAdded(oldInv, newInv, item)
  if not item.ammo then return end
  Refresh(oldInv)
  if oldInv ~= newInv then Refresh(newInv) end
 end
 function PLUGIN:InventoryItemRemoved(inventory, item, newInv)
  if item.ammo then Refresh(inventory) end
 end
end
