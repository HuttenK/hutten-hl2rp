local PLUGIN = PLUGIN
local sessions = setmetatable({}, {__mode = "k"})
local serial = 0
for _, name in ipairs({"ixGunsmithState", "ixGunsmithRequest", "ixGunsmithClose"}) do util.AddNetworkString(name) end
local function flag(name)
 local c = GetConVar(name)
 return c and c:GetBool()
end
function PLUGIN:Nearby(client, bench)
 if not IsValid(client) or not client:Alive() or not client:GetCharacter() or client:IsRestricted() then return false end
 if not IsValid(bench) or bench:GetClass() ~= "ix_gunsmith" then return false end
 if client:GetPos():DistToSqr(bench:NearestPoint(client:GetPos())) > self.range * self.range then return false end
 local trace = util.TraceLine({start = client:EyePos(), endpos = bench:WorldSpaceCenter(), filter = client, mask = MASK_SOLID})
 return not trace.Hit or trace.Entity == bench
end
function PLUGIN:Weapons(client)
 local result = {}
 for _, item in pairs(client:GetItems() or {}) do
  local weapon = item.class and client:GetWeapon(item.class)
  if item.isWeapon and item:GetData("equip") and IsValid(weapon) and weapon.ARC9
   and weapon:GetOwner() == client and weapon.ixItem == item and weapon.ixInventoryReady then result[#result + 1] = weapon end
 end
 table.sort(result, function(a,b) return a:EntIndex() < b:EntIndex() end)
 return result
end
function PLUGIN:Resin(client, spend)
 local inventory = client:GetInventory("main")
 local items = inventory and inventory:GetItems() or {}
 local total = 0
 for _, item in pairs(items) do
  if item.uniqueID == "resin" then total = total + math.max(0, math.floor(tonumber(item:GetData("stack", 1)) or 0)) end
 end
 if not spend then return total end
 if total < spend then return false end
 for _, item in pairs(items) do
  if spend <= 0 then break end
  if item.uniqueID == "resin" then
   local count = math.max(0, math.floor(tonumber(item:GetData("stack", 1)) or 0))
   local take = math.min(count, spend)
   if take > 0 then
    if take == count then item:Remove(true) else item:SetData("stack", count - take) end
    spend = spend - take
   end
  end
 end
 return spend == 0
end
-- Parts are supplied by the bench for resin, not taken from or credited to the
-- player's separate ARC9 attachment stash. Scope this to synchronous servicing.
function PLUGIN:Stock(client, callback)
 local previous = self.stockClient
 self.stockClient = client
 local ok, result = xpcall(callback, debug.traceback)
 self.stockClient = previous
 if not ok then ErrorNoHalt("[Gunsmith] " .. tostring(result) .. "\n") end
 return ok, result
end
function PLUGIN:ARC9_PlayerGetAtts(client) if self.stockClient == client then return 999 end end
function PLUGIN:ARC9_PlayerGiveAtt(client) if self.stockClient == client then return false end end
function PLUGIN:ARC9_PlayerTakeAtt(client) if self.stockClient == client then return true end end
local function getPath(slots, address, path)
 for i, slot in ipairs(slots or {}) do
  local nextPath = table.Copy(path or {})
  nextPath[#nextPath + 1] = i
  if slot.Address == address then return nextPath end
  local found = getPath(slot.SubAttachments, address, nextPath)
  if found then return found end
 end
end
local function atPath(slots, path)
 local slot
 for _, i in ipairs(path or {}) do slot = slots and slots[i]; slots = slot and slot.SubAttachments end
 return slot
end
function PLUGIN:Allowed(weapon, address, att)
 if flag("arc9_atts_anarchy") or flag("arc9_atts_nocustomize") then return false end
 local slot = weapon:LocateSlotFromAddress(address)
 if not slot or slot.Hidden then return false end
 if att == "" then return slot.Installed and weapon:CanDetach(address) or false end
 local data = ARC9.GetAttTable(att)
 if not data or data.Ignore or (data.AdminOnly and not weapon:GetOwner():IsAdmin()) or slot.Installed == att then return false end
 return weapon:CanAttach(address, att, slot)
end
-- Compare meaningful state, not JSON key order or nil/default representation.
function PLUGIN:TreeSignature(slots)
 local out={}
 for _,slot in ipairs(slots or {}) do
  local id=slot.Installed or ""
  out[#out+1]=#id..":"..id..":"..tostring(id~="" and (slot.ToggleNum or 1) or 1).."["..self:TreeSignature(slot.SubAttachments).."]"
 end
 return table.concat(out,";")
end
-- ARC9 initializes child transforms by iterating serialized child records.
-- Supply empty records for newly introduced rails, including integral descendants.
function PLUGIN:ExpandTree(slots,depth)
 depth=depth or 0
 if depth>12 then return {} end
 local result={}
 for i,slot in ipairs(slots or {}) do
  local row={Installed=slot.Installed,ToggleNum=slot.ToggleNum or 1,SubAttachments={}}
  local def=slot.Installed and ARC9.GetAttTable(slot.Installed)
  for j in ipairs(def and def.Attachments or {}) do
   row.SubAttachments[j]=(slot.SubAttachments or {})[j] or {}
  end
  row.SubAttachments=self:ExpandTree(row.SubAttachments,depth+1)
  result[i]=row
 end
 return result
end

-- Shared simulation for preview and purchase; no ammo, currency or item writes.
function PLUGIN:Stage(client,weapon,address,att)
 local A = ix.arc9Inventory
 local path = getPath(weapon.Attachments, address)
 if not path then return false, false end
 local ok, accepted = self:Stock(client, function()
  if not self:Allowed(weapon, address, att) then return false end
  local slot = weapon:LocateSlotFromAddress(address)
  for _, merged in ipairs(slot.MergeSlotAddresses or {}) do
   local other = weapon:LocateSlotFromAddress(merged)
   if other then other.Installed = nil; other.SubAttachments = nil end
  end
  slot.Installed = att ~= "" and att or nil
  slot.ToggleNum = 1
  slot.SubAttachments = nil
  local last
  for _ = 1, 12 do
   weapon:DoInvalidateCache()
   weapon:BuildSubAttachments(self:ExpandTree(A.AttachmentTree(weapon.Attachments)))
   weapon:DoInvalidateCache()
   weapon:PruneAttachments()
   weapon:FillIntegralSlots()
   local tree = self:TreeSignature(weapon.Attachments)
   if tree == last then break end
   last = tree
  end
  weapon:DoInvalidateCache()
  weapon:BuildSubAttachments(self:ExpandTree(A.AttachmentTree(weapon.Attachments)))
  weapon:DoInvalidateCache()
  local changed = atPath(weapon.Attachments, path)
  return changed and (changed.Installed or "") == att or false
 end)
 return ok, accepted
end

-- Stage and validate structure before PostModify, which can unload ammunition.
function PLUGIN:Change(client, weapon, address, att)
 local A = ix.arc9Inventory
 if not A then return false, "unavailable" end
 if (weapon.GetReloading and weapon:GetReloading()) or (weapon.GetGrenadePrimed and weapon:GetGrenadePrimed()) then return false, "busy" end
 if self:Resin(client) < self.cost then return false, "resin" end
 local before = A.AttachmentTree(weapon.Attachments)
 local ammoBefore = {
  {rounds=math.max(0,weapon:Clip1()), ammo=weapon:GetValue("Ammo"), capacity=weapon:GetCapacity(false)},
  {rounds=math.max(0,weapon:Clip2()), ammo=weapon:GetValue("UBGLAmmo"), capacity=weapon:GetCapacity(true)}
 }
 local ok, accepted = self:Stage(client,weapon,address,att)
 if ok and accepted then
  -- Return old-caliber rounds through Helix before ARC9 updates ammo types.
  -- Preflight both magazines so unsupported ammunition cannot be converted.
  local refunds = {}
  for index, old in ipairs(ammoBefore) do
   local newAmmo = weapon:GetValue(index==1 and "Ammo" or "UBGLAmmo")
   if old.rounds>0 and (old.ammo~=newAmmo or old.capacity~=weapon:GetCapacity(index==2)
    or (index==2 and not weapon:GetValue("UBGL"))) then
    if not old.ammo or not A.AmmoItem(old.ammo) then accepted=false break end
    refunds[index]=old
   end
  end
  if accepted then
   for index, old in pairs(refunds) do
    if not A.ReturnAmmo(client,old.ammo,old.rounds) then accepted=false break end
    if index==1 then weapon:SetClip1(0); weapon:SetLoadedRounds(0) else weapon:SetClip2(0) end
   end
  end
 end
 if not ok or not accepted or not self:Resin(client, self.cost) then
  self:Stock(client, function() weapon:DoInvalidateCache(); weapon:BuildSubAttachments(before); weapon:DoInvalidateCache() end)
  weapon:SendWeapon(client)
  return false, "rejected"
 end
 weapon.LastAmmo=weapon:GetValue("Ammo")
 weapon.LastClipSize=math.Round(weapon:GetProcessedValue("ClipSize"))
 weapon.LastUBGLAmmo=weapon:GetValue("UBGLAmmo")
 weapon.LastUBGLClipSize=weapon:GetValue("UBGLClipSize")
 weapon:PostModify()
 weapon:SendWeapon()
 A.Save(weapon.ixItem, weapon)
 timer.Simple(0, function()
  if IsValid(weapon) and weapon.ixItem and weapon.ixInventoryReady then A.Save(weapon.ixItem, weapon) end
 end)
 return true, "installed"
end
function PLUGIN:Preview(client,weapon,address,att)
 local A=ix.arc9Inventory
 local before=A.AttachmentTree(weapon.Attachments)
 local ubgl=weapon.GetUBGL and weapon:GetUBGL()
 local ok,accepted=self:Stage(client,weapon,address,att)
 local result=ok and accepted and A.AttachmentTree(weapon.Attachments) or nil
 local restored=self:Stock(client,function()
  weapon:DoInvalidateCache(); weapon:BuildSubAttachments(before); weapon:DoInvalidateCache()
 end)
 if ubgl~=nil then weapon:SetUBGL(ubgl) end
 if not restored then ErrorNoHalt("[Gunsmith] Preview restoration failed\n"); return nil end
 return result
end
function PLUGIN:Send(client, data)
 local encoded = util.Compress(util.TableToJSON(data))
 if not encoded or #encoded > 60000 then return end
 net.Start("ixGunsmithState"); net.WriteUInt(#encoded,16); net.WriteData(encoded,#encoded); net.Send(client)
end
function PLUGIN:Validate(client, token, revision, weapon)
 local session = sessions[client]
 if not session or session.token ~= token or (revision ~= nil and session.revision ~= revision) then return nil end
 if not self:Nearby(client,session.bench) or client:GetCharacter():GetID() ~= session.character then
  sessions[client] = nil; self:Send(client,{closed=true,token=session.token}); return nil
 end
 if weapon then
  local owned = false
  for _, current in ipairs(self:Weapons(client)) do if current == weapon then owned = true break end end
  if not owned then self:Snapshot(client,session,nil,"unavailable"); return nil end
 end
 return session
end
function PLUGIN:Snapshot(client, session, weapon, message, opening)
 -- Freshly restored weapons may still have cached address references from equip.
 -- Normalize before publishing addresses or recording the session signature.
 if IsValid(weapon) and ix.arc9Inventory then
  local tree=self:ExpandTree(ix.arc9Inventory.AttachmentTree(weapon.Attachments))
  local ok=self:Stock(client,function()
   weapon:DoInvalidateCache()
   weapon:BuildSubAttachments(tree)
   weapon:DoInvalidateCache()
  end)
  if not ok then weapon=nil; message="unavailable" end
 end
 session.weapon=weapon
 session.signature=IsValid(weapon) and ix.arc9Inventory and PLUGIN:TreeSignature(weapon.Attachments) or nil
 local data = {opening=opening or false, token=session.token, revision=session.revision, bench=session.bench:EntIndex(), weapons={}, slots={},
  resin=self:Resin(client), cost=self.cost, message=message, policy=flag("arc9_atts_anarchy") or flag("arc9_atts_nocustomize") or false}
 for _, candidate in ipairs(self:Weapons(client)) do
  if #data.weapons >= 32 then break end
  data.weapons[#data.weapons+1] = {id=candidate:EntIndex(), name=tostring(candidate.PrintName or candidate:GetClass())}
 end
 if IsValid(weapon) then
  data.weapon = weapon:EntIndex()
  data.tree = ix.arc9Inventory.AttachmentTree(weapon.Attachments)
  local ok, slots = self:Stock(client,function()
   local slots = {}
   for _, slot in ipairs(weapon:GetSubSlotList()) do
    if not slot.Hidden and #slots < 256 then
     local childCount = 0
     local function count(children)
      for _, child in ipairs(children or {}) do if child.Installed then childCount=childCount+1 end; count(child.SubAttachments) end
     end
     count(slot.SubAttachments)
     slots[#slots+1] = {address=slot.Address, path=getPath(weapon.Attachments,slot.Address), name=tostring(slot.PrintName or slot.OriginalAddress or slot.Address),
      installed=slot.Installed or "", parent=slot.ParentAddress, children=childCount, removable=self:Allowed(weapon,slot.Address,"") and true or false}
    end
   end
   return slots
  end)
  data.slots = ok and slots or {}
 end
 self:Send(client,data)
end
function PLUGIN:Open(client, bench)
 if not ARC9 or not self:Nearby(client,bench) then return end
 serial = serial % 2147483646 + 1
 local session = {bench=bench, character=client:GetCharacter():GetID(), token=serial, revision=0, expires=CurTime()+600}
 sessions[client] = session
 local choices = self:Weapons(client)
 local weapon = choices[1]
 for _, candidate in ipairs(choices) do if candidate == client:GetActiveWeapon() then weapon=candidate end end
 self:Snapshot(client,session,weapon,nil,true)
end
net.Receive("ixGunsmithClose",function(_,client)
 local token = net.ReadUInt(31)
 if sessions[client] and sessions[client].token == token then sessions[client]=nil end
end)
net.Receive("ixGunsmithRequest",function(length,client)
 if length > 4096 then return end
 if (client.ixNextBenchRequest or 0)>CurTime() then return end
 client.ixNextBenchRequest=CurTime()+0.15
 local token,revision = net.ReadUInt(31),net.ReadUInt(24)
 local action,entity = net.ReadUInt(2),net.ReadUInt(16)
 local address,value,page = net.ReadUInt(16),net.ReadString(),net.ReadUInt(16)
 if #value > 128 then return end
 local weapon = Entity(entity)
 local expectedRevision=revision
 if action==0 then expectedRevision=nil end -- read-only recovery after a lost response
 local session = PLUGIN:Validate(client,token,expectedRevision,weapon)
 if not session then return end
 if (session.nextRequest or 0) > CurTime() then return end
 session.nextRequest = CurTime()+0.15
 session.expires = CurTime()+600
 if action == 0 then
  session.revision=(session.revision+1)%16777216
  PLUGIN:Snapshot(client,session,weapon)
 elseif action == 1 then
  if session.weapon~=weapon then return end
  local slot = weapon:LocateSlotFromAddress(address)
  if not slot then PLUGIN:Snapshot(client,session,weapon,"slot") return end
  local ok,options = PLUGIN:Stock(client,function()
   local matches = {}
   local lower = string.utf8lower or string.lower
   local search = lower(value)
   for _,id in ipairs(ARC9.GetAttsForCats(slot.Category) or {}) do
    local data = ARC9.GetAttTable(id)
    if data and (search=="" or lower(tostring(data.PrintName or id).." "..id):find(search,1,true))
     and PLUGIN:Allowed(weapon,address,id) then matches[#matches+1]=id end
   end
   table.sort(matches,function(a,b)
    local an,bn = tostring(ARC9.GetAttTable(a).PrintName or a),tostring(ARC9.GetAttTable(b).PrintName or b)
    return an==bn and a<b or an<bn
   end)
   return matches
  end)
  options = ok and options or {}
  page = math.Clamp(page,1,math.max(1,math.ceil(#options/PLUGIN.pageSize)))
  local entries = {}
  for i=(page-1)*PLUGIN.pageSize+1,math.min(page*PLUGIN.pageSize,#options) do entries[#entries+1]=options[i] end
  PLUGIN:Send(client,{parts=entries,weapon=entity,address=address,search=value,page=page,total=#options,token=token,revision=revision})
 elseif action == 2 or action == 3 then
  if session.weapon~=weapon or not ix.arc9Inventory or session.signature~=PLUGIN:TreeSignature(weapon.Attachments) then
   session.revision=(session.revision+1)%16777216
   PLUGIN:Snapshot(client,session,weapon,"slot")
   return
  end
  if action==3 then
   local tree=PLUGIN:Preview(client,weapon,address,value)
   PLUGIN:Send(client,{preview=true,tree=tree,weapon=entity,address=address,value=value,token=token,revision=revision})
   return
  end
  local success,message = PLUGIN:Change(client,weapon,address,value)
  session.revision = (session.revision+1)%16777216
  PLUGIN:Snapshot(client,session,weapon,message)
 end
end)
-- Reject native client trees/presets; server replication and field toggles remain.
function PLUGIN:InstallGates()
 net.Receive("arc9_networkweapon",function(_,client)
  local weapon = net.ReadEntity()
  if not IsValid(weapon) or not weapon.ARC9 or weapon:GetOwner() ~= client then return end
  if (client.ixNextWorkshopCorrection or 0)>CurTime() then return end
  client.ixNextWorkshopCorrection=CurTime()+0.5
  weapon:SendWeapon(client)
 end)
 net.Receive("arc9_togglecustomize",function(_,client)
  local weapon=client:GetActiveWeapon()
  if IsValid(weapon) and weapon.ARC9 then weapon:ToggleCustomize(false) end
 end)
 net.Receive("arc9_randomizeatts",function() end)
 local original=concommand.GetTable().arc9_giveswep_preset
 if original and original ~= self.presetGate then
  self.presetGate=function(client,command,args,text)
   if IsValid(client) and client:HasWeapon(args[1] or "") then client:Notify("Use the gunsmith workbench to modify a weapon.") return end
   return original(client,command,args,text)
  end
  concommand.Add("arc9_giveswep_preset",self.presetGate)
 end
end
function PLUGIN:InitPostEntity() self:InstallGates() end
timer.Simple(0,function() PLUGIN:InstallGates() end)
function PLUGIN:Think()
 if (self.nextCheck or 0)>CurTime() then return end
 self.nextCheck=CurTime()+0.5
 for client,session in pairs(sessions) do
  if CurTime()>session.expires or not self:Nearby(client,session.bench) or client:GetCharacter():GetID() ~= session.character then
   sessions[client]=nil
   if IsValid(client) then self:Send(client,{closed=true,token=session.token}) end
  end
 end
end
function PLUGIN:IsUsingBench(client) return sessions[client] ~= nil end
function PLUGIN:PlayerDisconnected(client) sessions[client]=nil end
-- Keep this directory and format so existing benches survive the conversion.
function PLUGIN:SaveData()
 local data={}
 for _,entity in ipairs(ents.FindByClass("ix_gunsmith")) do data[#data+1]={entity:GetPos(),entity:GetAngles()} end
 self:SetData(data)
end
function PLUGIN:LoadData()
 for _,data in ipairs(self:GetData() or {}) do
  local entity=ents.Create("ix_gunsmith")
  if IsValid(entity) then entity:SetPos(data[1]); entity:SetAngles(data[2]); entity:Spawn() end
 end
end
