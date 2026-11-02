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
function A.ReturnAmmo(client, ammo, count)
 count = math.max(0, math.floor(tonumber(count) or 0))
 if count == 0 then return true end
 A.Settle(client)
 local id, definition = A.AmmoItem(ammo)
 if not id then client:Notify("Нет предмета для этих боеприпасов. Разрядка отменена.") return false end
 local pending = {}
 while count > 0 do
  local stack = math.min(count, math.max(1, definition.max_stack or definition.ammoAmount or 30))
  local item = ix.Item:Instance(id)
  if not item then
   for _, created in ipairs(pending) do created:Remove(true) end
   return false
  end
  item:SetData("stack", stack)
  pending[#pending + 1] = item
  count = count - stack
 end
 for _, item in ipairs(pending) do
  if not client:AddItem(item) then ix.Item:Spawn(client, nil, item) end
 end
 client:CalculateAmmo(ammo:lower())
 return true
end
