-- Equipment belongs to an item, not a SWEP class. Source only gives one held
-- entity per class, so identical items exchange their saved state when drawn.
ix.WeaponSlots = ix.WeaponSlots or {}
local W = ix.WeaponSlots
W.count = 3

function W.Label(slot)
 return slot == 3 and "Пистолет / нож" or "Двуручное " .. slot
end

function W.Description(slot)
 return slot == 3 and "Пистолеты и малое одноручное холодное оружие." or
  "Двуручное огнестрельное и холодное оружие."
end

function W.Kind(item)
 if not item or not item.isWeapon then return end
 if item.twoHanded or item.isFlamethrower or item.isDisposableEFT then return "long" end
 if item.weaponCategory == "melee" then return "pistol" end
 if item.isGrenade or item.isGrenadeARC9 or item.weaponCategory == "utility" then return "utility" end
 return item.weaponCategory == "sidearm" and "pistol" or "long"
end

function W.Accepts(item, slot)
 local kind = W.Kind(item)
 return (slot == 1 or slot == 2) and kind == "long" or slot == 3 and kind == "pistol"
end

function W.Equipped(item)
 local slot = W.Slot(item)
 if slot then return W.Accepts(item, slot) end
 return W.Kind(item) == "utility" and item:GetData("equip") == true
end

function W.Index(inventory)
 local index = inventory and tonumber((inventory.type or ""):match("^weapon([123])$"))
 return index
end

function W.Inventory(item)
 return item and item.inventory_id and ix.Inventory:Get(item.inventory_id)
end

function W.Slot(item)
 return W.Index(W.Inventory(item))
end

function W.Item(client, slot)
 if not isnumber(slot) or slot % 1 ~= 0 or slot < 1 or slot > W.count then return end
 local inventory = client:GetInventory("weapon" .. slot)
 if not inventory or inventory.owner ~= client then return end
 local item = ix.Item.instances[inventory:GetFirstAtSlot(1, 1)]
 if item and item.isWeapon and item.inventory_id == inventory.id then return item end
end

function W.Owns(client, item)
 local inventory = W.Inventory(item)
 return IsValid(client) and client:IsPlayer() and client:GetCharacter() and inventory and inventory.owner == client
end

function W.Pending(item)
 return ix.Inventory.pendingTransfers and ix.Inventory.pendingTransfers["item_" .. item.id] ~= nil
end

function W.Live(client, item)
 -- Inventory owners can be cargo crates or other entities. Only a player
 -- can hold a linked SWEP; saving a stored weapon must preserve its item data.
 if not IsValid(client) or not client:IsPlayer() or not item then return end
 local weapon = client:GetWeapon(item.class)
 if IsValid(weapon) and weapon.ixItem == item then return weapon end
end

function W.Busy(weapon)
 if not IsValid(weapon) then return false end
 local now = CurTime()
 return (weapon.GetGrenadePrimed and weapon:GetGrenadePrimed()) or
  (weapon.GetReloading and weapon:GetReloading()) or
  (weapon.GetAnimLockTime and weapon:GetAnimLockTime() > now) or
  (weapon.GetNextPrimaryFire and weapon:GetNextPrimaryFire() > now) or
  (weapon.GetNextSecondaryFire and weapon:GetNextSecondaryFire() > now) or false
end

function W.CanEquip(client, item)
 if not W.Owns(client, item) or not item.isWeapon or item:GetData("arc9Spent") then return false end
 if not client:Alive() or client:IsRestricted() then return false end
 if client.GetNoDraw and client:GetNoDraw() then return false end
 if item.hasLock and item:CheckBiolock(client) == false then return false end
 if ix.Amputation and ix.Amputation.IsTwoHanded(item) and
  ix.Amputation.HasKind(client:GetCharacter(), "arm") then return false end
 return true
end

-- Membership is also checked by the generic transfer path, including drag/drop.
function W.CanTransfer(item, old, new)
 if W.Pending(item) then return false, "notAllowed" end
 local oldSlot, newSlot = W.Index(old), W.Index(new)
 if new and new.isEquipment and not newSlot then return false, "notAllowed" end
 if newSlot and (not W.Accepts(item, newSlot) or not W.CanEquip(new.owner, item)) then return false, "notAllowed" end
 if old and W.Busy(W.Live(old.owner, item)) then return false, "notAllowed" end
 return true
end

if CLIENT then
 function W.Choices(client)
  local result, classes = {}, {}
  -- Keep three numbered entries, even if one is empty. Tools follow them.
  for slot = 1, W.count do
   local item = W.Item(client, slot)
   if item and not W.Accepts(item, slot) then item = nil end
   local entry = {ixWeaponSlot = slot, itemID = item and item.id or 0}
   entry.name = "[" .. slot .. "] " .. (item and item:GetPrintName() or "Пустой слот")
   entry.Instructions = item and "Оружие экипировано. Нажмите ЛКМ, чтобы взять в руки." or W.Label(slot) .. ": перенесите оружие в слот в меню экипировки."
   function entry:GetPrintName() return self.name end
   result[#result + 1] = entry
   if item then classes[item.class] = true end
  end
  for _, weapon in ipairs(client:GetWeapons()) do
   if not classes[weapon:GetClass()] then result[#result + 1] = weapon end
  end
  return result
 end

 function W.Select(entry)
  if entry.itemID == 0 then return end
  net.Start("ixWeaponSlotDraw")
   net.WriteUInt(entry.ixWeaponSlot, 2)
   net.WriteUInt(entry.itemID, 32)
  net.SendToServer()
 end

 net.Receive("ixWeaponSlotReady", function()
  W.pendingDraw = {entity = net.ReadUInt(16), slot = net.ReadUInt(2), id = net.ReadUInt(32), expires = RealTime() + 3}
 end)
 hook.Add("Think", "ixWeaponSlotPredictedDraw", function()
  local pending = W.pendingDraw
  if not pending then return end
  if RealTime() > pending.expires then W.pendingDraw = nil return end
  local client = LocalPlayer()
  if not IsValid(client) then return end
  local item = pending.slot == 0 and ix.Item.instances[pending.id] or W.Item(client, pending.slot)
  local weapon = Entity(pending.entity)
  -- Wait for the replacement entity and its identity to arrive. Selecting on
  -- the client preserves ARC9's predicted draw animation and switch hooks.
  if item and W.Owns(client, item) and W.Equipped(item) and item.id == pending.id and IsValid(weapon) and weapon:GetOwner() == client and
   weapon:GetNWInt("ixWeaponItem", 0) == pending.id then
   W.pendingDraw = nil
   input.SelectWeapon(weapon)
  end
 end)
 return
end

util.AddNetworkString("ixWeaponSlotDraw")
util.AddNetworkString("ixWeaponSlotReady")

function W.SelectLive(client, item, weapon)
 if client:IsBot() then client:SelectWeapon(item.class) return end
 net.Start("ixWeaponSlotReady")
  net.WriteUInt(weapon:EntIndex(), 16)
  net.WriteUInt(W.Slot(item) or 0, 2)
  net.WriteUInt(item.id, 32)
 net.Send(client)
end

hook.Add("CreatePlayerInventories", "ixUniversalWeaponSlots", function(client, inventories)
 for slot = 1, W.count do
  local inventory = ix.meta.Inventory:New()
  inventory.type = "weapon" .. slot
  inventory.multislot = false
  inventory.isEquipment = true
  inventory:SetSize(1, 1)
  inventories[inventory.type] = inventory
 end
end)

-- Only this item's linked entity may be saved or removed. In particular, an
-- undrawn duplicate must never strip the other copy of the same weapon class.
function W.Save(item, weapon)
 if not IsValid(weapon) or weapon.ixItem ~= item then return end
 if weapon.ARC9 then
  ix.arc9Inventory.Save(item, weapon)
  if weapon.GetFiremode then item:SetData("weaponFiremode", weapon:GetFiremode()) end
  if weapon.GetSafe then item:SetData("weaponSafety", weapon:GetSafe()) end
 else
  item:SetData("ammo", weapon:Clip1())
  item:SetData("ammo2", weapon:Clip2())
 end
end

function W.Release(client, item)
 local weapon = W.Live(client, item)
 if not weapon then return end
 if weapon.CancelReload then weapon:CancelReload() end
 ix.arc9Inventory.Settle(client)
 W.Save(item, weapon)
 weapon.ixItem = nil
 client.ixAmmoReady = false
 client:StripWeapon(item.class)
 if client.carryWeapons and client.carryWeapons[item.weaponCategory] == weapon then
  client.carryWeapons[item.weaponCategory] = nil
 end
 client:CalculateAmmo()
end

-- Forced removal of the live entity (knockdown, death or lost limb) must not
-- attempt to fit the item into a full bag or leave a delayed drag in flight.
function W.Suspend(client, item)
 local transfer = ix.Inventory.pendingTransfers and ix.Inventory.pendingTransfers["item_" .. item.id]
 if transfer then ix.Inventory:CancelTransfer(transfer) end
 W.Release(client, item)
end

local function give(client, item)
 local weapon = client:Give(item.class, true)
 if not IsValid(weapon) then return end
 if weapon.ARC9 then
  if not ix.arc9Inventory.Bind(item, weapon, client) then
   weapon.ixItem = nil
   client:StripWeapon(item.class)
   client:CalculateAmmo()
   return
  end
 else
  weapon.ixItem = item
  weapon:SetClip1(item:GetData("ammo", 0))
  weapon:SetClip2(item:GetData("ammo2", 0))
  weapon.ixInventoryReady = true
  client:CalculateAmmo()
 end
 weapon:SetNWInt("ixWeaponItem", item.id)
 if weapon.ARC9 then
  local modes = weapon:GetValue("Firemodes") or {}
  if weapon.SetFiremode and #modes > 0 then
   weapon:SetFiremode(math.Clamp(item:GetData("weaponFiremode", 1), 1, #modes))
  end
  if weapon.SetSafe then weapon:SetSafe(item:GetData("weaponSafety", false)) end
 end
 client.carryWeapons = client.carryWeapons or {}
 client.carryWeapons[item.weaponCategory] = weapon
 return weapon
end

function W.Activate(client, item, noSelect)
 if not W.CanEquip(client, item) or not W.Equipped(item) or W.Pending(item) then return false end
 if W.Slot(item) and W.Item(client, W.Slot(item)) ~= item then return false end
 if client.bUsingMedical then return false end
 local existing = client:GetWeapon(item.class)
 local active = client:GetActiveWeapon()
 if W.Busy(active) or (IsValid(existing) and existing.ixItem ~= item and W.Busy(existing)) then
  client:Notify("Сначала завершите действие с оружием.")
  return false
 end
 if IsValid(existing) and existing.ixItem ~= item and
  (not existing.ixItem or not W.Owns(client, existing.ixItem) or not W.Equipped(existing.ixItem)) then
  client:Notify("Сначала уберите выданное оружие этого класса.")
  return false
 end
 local previous = IsValid(existing) and existing.ixItem ~= item and existing.ixItem or nil
 local wasActive = previous and existing == active
 if previous then W.Release(client, previous) end
 local weapon = W.Live(client, item) or give(client, item)
 if not IsValid(weapon) then
  if previous then
   local restored = give(client, previous)
   if IsValid(restored) and wasActive then W.SelectLive(client, previous, restored) end
  end
  client:Notify("Не удалось взять оружие. Предмет и его состояние сохранены в слоте.")
  return false
 end
 if item.hasLock and not item:GetData("locked") then item:SetData("locked", client:GetCharacter():GetID()) end
 -- Respect normal weapon-switch restrictions (injuries, carts, crawling etc.).
 if not noSelect then W.SelectLive(client, item, weapon) end
 W.Publish(client)
 return weapon
end

function W.Transfer(client, item, target, quiet)
 local source = W.Inventory(item)
 if not W.Owns(client, item) or not target or target.owner ~= client or W.Pending(item) then return false end
 if source == target then return true end
 local x, y = item.x, item.y
 local width, height = source:GetItemSize(item)
 local ok, reason = source:Transfer(item.id, target)
 if not ok then if not quiet then client:NotifyLocalized(reason or "noFit") end return false end
 target:SendDeltaTransfer(item.id, source, x, y, width, height)
 W.Publish(client)
 return true
end

function W.Equip(client, item, slot, noSelect, noSound)
 if not W.CanEquip(client, item) then return false end
 -- Grenades and utility devices remain ordinary inventory equipment.
 -- Melee weapons share the same limited slots as firearms.
 if W.Kind(item) == "utility" and not slot then
  if W.Slot(item) or W.Pending(item) or W.Busy(client:GetActiveWeapon()) then return false end
  local wasEquipped = item:GetData("equip") == true
  item:SetData("equip", true)
  if not W.Activate(client, item, noSelect) then item:SetData("equip", wasEquipped) return false end
  if not noSound then client:EmitSound(item.useSound, 80) end
  return true
 end
 slot = tonumber(slot) or W.Slot(item)
 if not slot then
  for index = 1, W.count do if W.Accepts(item, index) and not W.Item(client, index) then slot = index break end end
 end
 if not slot or not W.Accepts(item, slot) then
  client:Notify("Нет подходящего свободного слота: два двуручных и один для пистолета или малого холодного оружия.")
  return false
 end
 if not W.Transfer(client, item, client:GetInventory("weapon" .. slot)) then return false end
 if not noSound then client:EmitSound(item.useSound, 80) end
 if not noSelect then W.Activate(client, item) end
 return true
end

function W.Unequip(client, item)
 if not W.Owns(client, item) then return false end
 if not W.Slot(item) and W.Kind(item) == "utility" then
  if W.Pending(item) or W.Busy(W.Live(client, item)) then return false end
  W.Release(client, item); item:SetData("equip", false)
  return true
 end
 -- Full inventory means leave the weapon equipped, never drop it implicitly.
 return W.Transfer(client, item, client:GetInventory("main"))
end

function W.OnTransfer(item, destination, source)
 if source and IsValid(source.owner) and (not W.Index(destination) or destination.owner ~= source.owner) then
  W.Release(source.owner, item)
 end
 item:SetData("equip", W.Accepts(item, W.Index(destination)) == true)
end

function W.Publish(client)
 if not IsValid(client) then return end
 local character = client:GetCharacter()
 local data = {character = character and character:GetID() or 0, items = {}, backpack = client:GetBackpack() ~= nil}
 local active = client:GetActiveWeapon()
 for slot = 1, W.count do
  local item = W.Item(client, slot)
  if item and W.Accepts(item, slot) then
   local weapon = W.Live(client, item)
   local profile = HOLSTER_DRAWINFO and HOLSTER_DRAWINFO[item.class]
   data.items[slot] = {id = item.id, class = item.class, model = item.holsterModel or (profile and profile.model) or item.model,
    fallback = item.holsterFallbackModel, small = slot == 3,
    tree = item:GetData("arc9_atts", {}), rounds = item:GetData("ammo", 0)}
   if weapon and weapon == active then data.active = item.id end
  end
 end
 local signature = util.TableToJSON(data)
 if signature ~= client.ixWeaponSlotsSignature then
  client.ixWeaponSlotsSignature = signature
  client:SetNetVar("ixWeaponSlots", data)
 end
end

function W.Restore(client)
 if not IsValid(client) or not client:GetCharacter() then return end
 -- One-time migration of old category-based equipment. No item is destroyed
 -- if all slots are full; an excess legacy weapon stays in its old inventory.
 local items = {}
 for _, item in pairs(client:GetItems()) do items[#items + 1] = item end
 table.sort(items, function(a, b) return a.id < b.id end)
 for _, item in ipairs(items) do
  if item and item.isWeapon then
   if W.Slot(item) and W.Accepts(item, W.Slot(item)) then
    item:SetData("equip", true)
   elseif W.Slot(item) then
    W.Suspend(client, item)
    item:SetData("equip", false)
    local moved = false
    for slot = 1, W.count do
     if W.Accepts(item, slot) and not W.Item(client, slot) then
      moved = W.Transfer(client, item, client:GetInventory("weapon" .. slot), true)
      if moved then break end
     end
    end
    if not moved then moved = W.Transfer(client, item, client:GetInventory("main"), true) end
    local backpack = client:GetBackpack()
    if not moved and backpack then moved = W.Transfer(client, item, backpack:GetInventory(), true) end
    if not moved then
     -- A full bag leaves a visible recovery item, never an active third rifle.
     client:Notify("Оружие не подходит к прежнему слоту. Освободите место и перенесите его из экипировки в инвентарь.")
    end
   elseif item:GetData("equip") then
    if W.Kind(item) == "utility" then
     W.Activate(client, item, true)
    else
     -- An old inventory-equipped melee must not remain usable as an extra
     -- weapon if its new slot is occupied. Preserve the item in its bag.
     W.Suspend(client, item)
     item:SetData("equip", false)
     for slot = 1, W.count do
      if W.Accepts(item, slot) and not W.Item(client, slot) then W.Transfer(client, item, client:GetInventory("weapon" .. slot), true) break end
     end
    end
   end
  end
 end
 W.Publish(client)
end

hook.Add("PlayerInventoriesLoaded", "ixWeaponSlotsRestore", W.Restore)
hook.Add("InventoryItemAdded", "ixWeaponSlotsAdded", function(old, inventory, item)
 if W.Index(inventory) and item.isWeapon then item:SetData("equip", W.Accepts(item, W.Index(inventory)) == true) end
 if IsValid(inventory.owner) and inventory.owner:IsPlayer() then W.Publish(inventory.owner) end
 if old and old.owner ~= inventory.owner and IsValid(old.owner) and old.owner:IsPlayer() then W.Publish(old.owner) end
end)
hook.Add("PlayerPostThink", "ixWeaponSlotsState", function(client)
 if (client.ixNextSlotSync or 0) > CurTime() then return end
 client.ixNextSlotSync = CurTime() + 0.25
 W.Publish(client)
end)
hook.Add("PrePlayerLoadedCharacter", "ixWeaponSlotsSave", function(client)
 for _, weapon in ipairs(client:GetWeapons()) do if weapon.ixItem then W.Save(weapon.ixItem, weapon) end end
 client.ixWeaponSlotsSignature = nil
 client:SetNetVar("ixWeaponSlots", nil)
end)
hook.Add("PlayerDeath", "ixWeaponSlotsDeath", function(client)
 for _, weapon in ipairs(client:GetWeapons()) do if weapon.ixItem then W.Save(weapon.ixItem, weapon) end end
end)
hook.Add("PlayerLoadout", "ixWeaponSlotsBeforeStrip", function(client)
 for _, weapon in ipairs(client:GetWeapons()) do if weapon.ixItem then W.Save(weapon.ixItem, weapon) end end
end)
hook.Add("CanPlayerDropItem", "ixWeaponSlotsPending", function(client, item)
 if item and item.isWeapon and (W.Pending(item) or W.Busy(W.Live(client, item))) then return false end
end)
hook.Add("CanTransferItem", "ixWeaponSlotsOnlyWeapons", function(item, destination)
 if W.Index(destination) and not item.isWeapon then return false, "notAllowed" end
end)

net.Receive("ixWeaponSlotDraw", function(length, client)
 if length > 40 or not IsValid(client) then return end
 if (client.ixNextWeaponSlot or 0) > CurTime() then return end
 client.ixNextWeaponSlot = CurTime() + 0.2
 local slot, id = net.ReadUInt(2), net.ReadUInt(32)
 local item = W.Item(client, slot)
 if item and item.id == id then W.Activate(client, item) end
end)
