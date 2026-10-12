local PLUGIN = PLUGIN
PLUGIN.name = "ARC9 Arm Helper Compatibility"
PLUGIN.author = "Legends"
PLUGIN.description = "Keeps weighted arm helper bones aligned with ARC9 arm poses."

if SERVER then return end

ix.arc9Helpers = ix.arc9Helpers or {}
local H = ix.arc9Helpers
local cache = setmetatable({}, {__mode = "k"})
-- Persist ownership across Lua refreshes. A later decorator must not cause us
-- to wrap its wrapper again every Think (body dragging used to do exactly that).
H.wrapped = H.wrapped or setmetatable({}, {__mode = "k"})
local wrapped = H.wrapped
local core = {}
for _, side in ipairs({"L", "R"}) do
 for _, part in ipairs({"UpperArm", "Forearm", "Hand"}) do
  core["ValveBiped.Bip01_" .. side .. "_" .. part] = true
 end
 -- Standard phalanges are explicitly driven by ARC9. Extra finger-base bones
 -- (Finger10/20/30/40, etc.) are not: they must follow their nearest driven parent.
 for finger = 0, 4 do
  local name = "ValveBiped.Bip01_" .. side .. "_Finger" .. finger
  core[name] = true
  core[name .. "1"] = true
  core[name .. "2"] = true
 end
end
local enabled = CreateClientConVar("ix_arc9_helperbones", "1", true, false,
 "Follow extra shoulder/arm helper bones during ARC9 third-person animation.")

function H.GetEntries(player)
 local model, count = player:GetModel(), player:GetBoneCount()
 local saved = cache[player]
 if saved and saved.model == model and saved.count == count then return saved.entries end
 local entries = {}
 if not count or count < 1 then return entries end
 for bone = 0, count - 1 do
  local name = player:GetBoneName(bone) or ""
  local lower = string.lower(name)
  -- Only explicitly driven bones and weapon attachments are excluded.
  if not core[name] and not lower:find("attachment", 1, true) then
   local parent = player:GetBoneParent(bone)
   local seen = {}
   while parent and parent >= 0 and not seen[parent] do
    seen[parent] = true
    local parentName = player:GetBoneName(parent) or ""
    local parentLower = string.lower(parentName)
    if parentLower:find("attachment", 1, true) then break end
    if core[parentName] then
     -- Unused bones may not be writable at this model's LOD.
     if player:BoneHasFlag(bone, BONE_USED_BY_VERTEX_LOD0) then
      entries[#entries + 1] = {bone = bone, driver = parent}
     end
     break
    end
    parent = player:GetBoneParent(parent)
   end
  end
 end
 cache[player] = {model = model, count = count, entries = entries}
 return entries
end

function H.Capture(player)
 local entries = H.GetEntries(player)
 if #entries == 0 then return end
 player:SetupBones()
 local captured = {}
 for _, entry in ipairs(entries) do
  local parent, child = player:GetBoneMatrix(entry.driver), player:GetBoneMatrix(entry.bone)
  if parent and child then
   local inverse = parent:GetInverse()
   if inverse then captured[#captured + 1] = {bone = entry.bone, driver = entry.driver, relative = inverse * child} end
  end
 end
 return captured
end

function H.Apply(player, captured)
 for _, entry in ipairs(captured or {}) do
  local parent = player:GetBoneMatrix(entry.driver)
  if parent and player:GetBoneMatrix(entry.bone) then
   -- Absolute result from the pre-solve relationship, never an extra delta.
   -- Safe when ARC9 already moved this helper: it receives the same transform.
   player:SetBoneMatrix(entry.bone, parent * entry.relative)
  end
 end
end

-- Recover the old mutually nested helper/drag wrappers on a live client. Only
-- peel our known source files and the named original upvalue; never execute or
-- replace an unrelated addon's wrapper. New installs do this once per weapon.
function H.UnwrapLegacy(original)
 for _ = 1, 4096 do
  local info = debug.getinfo(original, "S")
  local source = info and (info.source or ""):gsub("\\", "/") or ""
  if not source:match("plugins/arc9_helperbones%.lua$")
      and not source:match("plugins/body_drag/cl_arms%.lua$") then break end
  local inner
  for index = 1, 32 do
   local name, value = debug.getupvalue(original, index)
   if not name then break end
   if name == "original" and isfunction(value) then inner = value break end
  end
  if not inner or inner == original then break end
  original = inner
 end
 return original
end

function H.Install(weapon)
 if not IsValid(weapon) or not weapon.ARC9 or not isfunction(weapon.DoTPIK) then return end
 if wrapped[weapon] then return end
 local original = H.UnwrapLegacy(weapon.DoTPIK)
 local wrapper = function(self, ...)
  local player = self:GetOwner()
  local captured, model
  if enabled:GetBool() and IsValid(player) and player:IsPlayer() then
   model = player:GetModel()
   captured = H.Capture(player)
  end
  -- Remain inside ARC9's bone-write render context. Do not write bones in Think.
  local result = original(self, ...)
  if captured and IsValid(player) and self:GetOwner() == player and player:GetModel() == model then
   H.Apply(player, captured)
  end
  -- Consumers run after both ARC9 and the weighted helper-bone repair. There
  -- is one owner of DoTPIK; consumers must not decorate that function again.
  if IsValid(player) and self:GetOwner() == player then
   hook.Run("ixARC9PostArmPose", self, player)
  end
  return result
 end
 weapon.DoTPIK = wrapper
 wrapped[weapon] = {wrapper = wrapper, original = original}
end

-- Install on instances instead of replacing Workshop files or global SWEP tables.
-- Think runs before rendering, so this does not depend on PrePlayerDraw hook order.
hook.Add("Think", "ixARC9ArmHelpers", function()
 for _, player in ipairs(player.GetAll()) do H.Install(player:GetActiveWeapon()) end
end)
