-- Three independent item displays, including undrawn copies of one SWEP class.
local W = ix.WeaponSlots
-- Auto-refresh must retire the previous closure's models before replacing it.
if W.ClearHolsters then
 for _, client in ipairs(player.GetAll()) do W.ClearHolsters(client) end
end
local owners = setmetatable({}, {__mode = "k"})

function W.ClearHolsters(client)
 for _, entry in pairs(owners[client] or {}) do
  if ix.WeaponAssembly then ix.WeaponAssembly.Remove(entry.host) end
  if IsValid(entry.host) then entry.host:Remove() end
 end
 owners[client] = nil
end

function W.MirrorHolsterAngle(angle)
 -- Reflect forward/up across the torso's left/right plane. Keep a proper
 -- rotation (no negative model scale), so meshes and attachments stay intact.
 return Angle(angle.p, -angle.y, -angle.r)
end

function W.HolsterMount(slot)
 -- Upright rifles at opposite shoulders, with fixed spacing independent of
 -- hidden viewmodel arms/render bounds. Keep the established hip transform.
 if slot == 3 then return Vector(0, -8, -4), Angle(90, 0, 0) end
 local rotation = Angle(-90, 90, 0)
 return Vector(-3.5, slot == 2 and 5.5 or -5.5, 9), slot == 2 and W.MirrorHolsterAngle(rotation) or rotation
end

-- These complete EFT world models run along local Z, unlike the firearm
-- assemblies. Hang them from the belt: blades down, crowbar/hammer head up.
local meleeHipProfiles = {}
for class, bladeDown in pairs({
 arc9_eft_melee_6x5 = true,
 arc9_eft_melee_gladius = true,
 arc9_eft_melee_kukri = true,
 arc9_eft_melee_crowbar = false,
 arc9_eft_melee_hultafors = false
}) do
 meleeHipProfiles[class] = {
  bone = "ValveBiped.Bip01_Pelvis", bodyFrame = true, staticModel = true,
  pos = Vector(-2, -8, 2), ang = Angle(bladeDown and 180 or 0, 90, 0),
  anchorZ = bladeDown and "min" or "max"
 }
end

local meleeBackProfiles = {}
for _, class in ipairs({"arc9_eft_melee_crowbar", "arc9_eft_melee_gladius", "arc9_eft_melee_hultafors"}) do
 meleeBackProfiles[class] = {}
 for slot = 1, 2 do
  meleeBackProfiles[class][slot] = {
   bone = "ValveBiped.Bip01_Spine1", bodyFrame = true, staticModel = true, slotMount = true,
   pos = W.HolsterMount(slot), ang = Angle(class == "arc9_eft_melee_gladius" and 180 or 0, slot == 2 and -90 or 90, 0)
  }
 end
end

function W.HolsterProfile(plugin, class, hip, slot)
 if hip and meleeHipProfiles[class] then return meleeHipProfiles[class] end
 if not hip and meleeBackProfiles[class] then return meleeBackProfiles[class][slot or 1] end
 return plugin:HolsterProfile(class, hip)
end

function W.DrawHolsters(plugin, client)
 local data = client:GetNetVar("ixWeaponSlots")
 if not data or data.character ~= client:GetCharacter():GetID() then W.ClearHolsters(client) return end
 local rows = data.items or {}
 local cache = owners[client] or {}
 owners[client] = cache
 for slot = 1, W.count do
  local row, entry = rows[slot], cache[slot]
  if entry and (not row or row.id ~= entry.id or row.model ~= entry.path) then
   if ix.WeaponAssembly then ix.WeaponAssembly.Remove(entry.host) end
   if IsValid(entry.host) then entry.host:Remove() end
   entry = nil
   cache[slot] = nil
  end
  if row then
   if not entry or not IsValid(entry.host) then
    local path = row.model
    if not isstring(path) or not util.IsValidModel(path) then path = row.fallback end
    if isstring(path) and util.IsValidModel(path) then
     local host = ClientsideModel(path, RENDERGROUP_OPAQUE)
     if IsValid(host) then
      host:SetNoDraw(true)
      entry = {id = row.id, path = row.model, host = host}
      cache[slot] = entry
     end
    end
   end
  end
 end
 local active = client:GetActiveWeapon()
 local activeID = IsValid(active) and active:GetNWInt("ixWeaponItem", 0) or 0
 for slot = 1, W.count do
  repeat
  local row, entry = rows[slot], cache[slot]
  if not row or not entry or row.id == activeID then break end
  local hip = slot == 3
  local profile = W.HolsterProfile(plugin, row.class, hip, slot)
  local boneName = profile.bone
  local bone = client:LookupBone(boneName)
  local matrix = bone and client:GetBoneMatrix(bone)
  if not matrix then break end
  local facing = plugin:HolsterBoneFrame(client, boneName, matrix)
  local scale = client:GetModelScale()
  local A = ix.WeaponAssembly
  if not profile.staticModel and A and ix.arc9Inventory.IsClass(row.class) then
   local assembly = A.Get(entry.host, row.class, row.tree, row.rounds)
   if not assembly then break end
   local mount, rotation = W.HolsterMount(slot)
   local pos, ang = LocalToWorld(mount, rotation, matrix:GetTranslation(), facing)
   local offset = LocalToWorld(A.Center(assembly), angle_zero, vector_origin, ang)
   A.Draw(assembly, pos - offset, ang)
  else
   -- Preserve the authored per-weapon profiles and origin handling for stock
   -- and ArcCW models as well; centering every mesh changes those placements.
   local model = entry.host
   local pos, ang = matrix:GetTranslation(), matrix:GetAngles()
   if profile.bodyFrame then
    local frame = profile.slotMount and facing or Angle(0, client:GetRenderAngles().y, 0)
    pos, ang = LocalToWorld(profile.pos * scale, profile.ang, pos, frame)
    model:SetModelScale(1, 0)
    local mins, maxs = model:GetRenderBounds()
    local anchor = (mins + maxs) * 0.5
    -- Align the upper end with the belt, not the centre of a long weapon.
    -- Bounds are from the standalone world mesh, never hidden viewmodel arms.
    if profile.anchorZ then anchor.z = profile.anchorZ == "min" and mins.z or maxs.z end
    local offset = LocalToWorld(anchor * scale, angle_zero, vector_origin, ang)
    pos = pos - offset
   else
    local right, up, forward = ang:Right(), ang:Up(), ang:Forward()
    pos = pos + profile.pos.x * right + profile.pos.y * forward + profile.pos.z * up
    ang:RotateAroundAxis(right, profile.ang.p)
    ang:RotateAroundAxis(up, profile.ang.y)
    ang:RotateAroundAxis(forward, profile.ang.r)
   end
   if slot == 2 and not profile.slotMount then
    pos = pos - facing:Right() * (8 * scale)
    local _, relative = WorldToLocal(vector_origin, ang, vector_origin, facing)
    _, ang = LocalToWorld(vector_origin, W.MirrorHolsterAngle(relative), vector_origin, facing)
   end
   model:SetModelScale(scale, 0)
   model:SetPos(pos)
   model:SetAngles(ang)
   model:SetupBones()
   model:DrawModel()
  end
  until true
 end
end

hook.Add("EntityRemoved", "ixWeaponSlotHolsters", W.ClearHolsters)
hook.Add("ShutDown", "ixWeaponSlotHolsters", function()
 for client in pairs(owners) do W.ClearHolsters(client) end
end)
hook.Add("Think", "ixWeaponSlotHolsterCleanup", function()
 if (W.nextHolsterCleanup or 0) > CurTime() then return end
 W.nextHolsterCleanup = CurTime() + 1
 for client in pairs(owners) do
  if not IsValid(client) or not client:Alive() or client:IsDormant() or not client:GetCharacter() or
   client:GetNoDraw() or client:GetPos():DistToSqr(EyePos()) > 2500 * 2500 then W.ClearHolsters(client) end
 end
end)
