-- Ammo reserves are backed by inventory stacks, including future arrows/bolts.
ix.weaponInventory = ix.weaponInventory or {}
local A = ix.weaponInventory

function A.AmmoItem(ammo)
 ammo = string.lower(ammo or "")
 for id, definition in SortedPairs(ix.Item.stored) do
  if isstring(definition.ammo) and definition.ammo:lower() == ammo then return id, definition end
 end
end

if not SERVER then return end

-- GetItems already includes nested bags. An equipped backpack lives in a
-- separate equipment slot; count each instance only once across both lists.
function A.CarriedItems(client, main)
 local items = main:GetItems()
 local backpack = client:GetBackpack()
 local other = backpack and backpack:GetInventory()
 if not other or other == main then return items end
 local seen = {}
 for _, item in ipairs(items) do seen[item.id] = true end
 for _, item in ipairs(other:GetItems()) do
  if not seen[item.id] then items[#items + 1] = item; seen[item.id] = true end
 end
 return items
end

-- Old supply bundles and AoC pickup entities now yield one actual weapon.
function A.GiveThrowable(client, class)
 local definition = ix.Item:Get(class)
 if not definition or not definition.singleUse then return false end
 local item = ix.Item:Instance(class)
 if not item then return false end
 if client:AddItem(item) or IsValid(ix.Item:Spawn(client, nil, item)) then return true end
 item:Remove(true)
 return false
end

function A.ReturnAmmo(client, ammo, count)
 count = math.max(0, math.floor(tonumber(count) or 0))
 if count == 0 then return true end
 A.Settle(client)
 local id, definition = A.AmmoItem(ammo)
 if not id then client:Notify("Нет предмета для этих боеприпасов. Разрядка отменена.") return false end
 local capacity = math.max(1, definition.ammoAmount or definition.max_stack or 30)
 local inventory = client:GetInventory("main")
 if not inventory then return false end
 local refills = {}
 for _, item in ipairs(A.CarriedItems(client, inventory)) do
  if count == 0 then break end
  if item.uniqueID == id and not ix.WeaponSlots.Pending(item) then
   local value = item:GetValue()
   local add = math.min(count, capacity - value)
   if add > 0 then
    refills[#refills + 1] = {item = item, value = value + add}
    count = count - add
   end
  end
 end
 local pending = {}
 while count > 0 do
  local stack = math.min(count, capacity)
  local item = ix.Item:Instance(id, {stack = stack})
  if not item then
   for _, created in ipairs(pending) do created:Remove(true) end
   return false
  end
  item:SetData("stack", stack)
  pending[#pending + 1] = item
  count = count - stack
 end
 -- Apply the refills only after every required overflow item exists.
 for _, refill in ipairs(refills) do refill.item:SetData("stack", refill.value) end
 for _, item in ipairs(pending) do
  if not client:AddItem(item) then ix.Item:Spawn(client, nil, item) end
 end
 client:CalculateAmmo(ammo:lower())
 return true
end
