local P = PLUGIN
P.name = "ARC9 Held Weapon Models"
P.author = "Legends"
P.description = "Preserves assembled held weapons through ARC9's distant rendering levels."

if SERVER then return end

ix.arc9WorldModels = ix.arc9WorldModels or {}
local M = ix.arc9WorldModels
if M.Stop then M.Stop() end
local enabled = CreateClientConVar("ix_arc9_worldmodels", "1", true, false,
 "Keep assembled ARC9 models in players' hands; retain distant animation budgets.", 0, 1)
local installed = setmetatable({}, {__mode = "k"})
local stopped = false

local function held(weapon)
 if stopped or not enabled:GetBool() or not weapon.MirrorVMWM then return false end
 local owner = weapon:GetOwner()
 return IsValid(owner) and owner:IsPlayer() and owner:GetActiveWeapon() == weapon
end

local function native(fn, filename)
 if not isfunction(fn) then return false end
 local info = debug.getinfo(fn, "S")
 local source = info and (info.source or ""):gsub("\\", "/") or ""
 return source:sub(-#filename) == filename
end

function M.Install(weapon)
 if stopped or not IsValid(weapon) or not weapon.ARC9 or installed[weapon] then return end
 -- Leave custom renderers and other addons' decorators alone. These three
 -- native methods form one contract; applying only part would lose attachments.
 if not native(weapon.ShouldLOD, "weapons/arc9_base/cl_drawmodel.lua") or
  not native(weapon.DrawCustomModel, "weapons/arc9_base/cl_drawmodel.lua") or
  not native(weapon.SetupModel, "weapons/arc9_base/cl_model.lua") or
  not native(weapon.DrawWorldModel, "weapons/arc9_base/cl_wm.lua") then return end

 local row = {original = {
  ShouldLOD = weapon.ShouldLOD, SetupModel = weapon.SetupModel, DrawWorldModel = weapon.DrawWorldModel
 }, wrappers = {}}
 local originals, wrappers = row.original, row.wrappers

 wrappers.ShouldLOD = function(self, ...)
  local lod = originals.ShouldLOD(self, ...)
  -- LOD 2 draws SWEP.WorldModel (CSS for EFT guns). LOD 1.5 still
  -- reduces distant TPIK to 10 Hz, and our arm budget can reduce it further.
  -- Keep local -1, near 0 and intermediate levels unchanged.
  if held(self) and lod >= 2 then return 1.5 end
  return lod
 end
 wrappers.SetupModel = function(self, wm, lod, cm, ...)
  -- Native SetupModel exits before creating attachments for ANY positive LOD.
  -- Assemble once at level 0, independently of the ongoing animation budget.
  if wm and not cm and held(self) then lod = 0 end
  local result = originals.SetupModel(self, wm, lod, cm, ...)
  if wm and not cm then
   row.fullModel = (lod or 0) <= 0 and self.WModel or nil
  end
  return result
 end
 wrappers.DrawWorldModel = function(self, ...)
  if held(self) and (not self.WModel or row.fullModel ~= self.WModel) then
   -- A model cached before this adapter (or while dropped) can contain only
   -- the receiver. Refresh that world assembly once, leaving the viewmodel,
   -- attachment data, ammunition and inventory untouched.
   self:SetupModel(true, 0)
  end
  return originals.DrawWorldModel(self, ...)
 end
 installed[weapon] = row
 for name, fn in pairs(wrappers) do weapon[name] = fn end
end

local function seed()
 if stopped then return end
 for _, weapon in ipairs(ents.FindByClass("arc9_*")) do M.Install(weapon) end
end
hook.Add("PrePlayerDraw", "ixARC9WorldModels", function(client)
 M.Install(client:GetActiveWeapon())
end)
hook.Add("OnEntityCreated", "ixARC9WorldModels", function(entity)
 if not IsValid(entity) or not entity:GetClass():match("^arc9_") then return end
 timer.Simple(0, function() if not stopped then M.Install(entity) end end)
end)
hook.Add("EntityRemoved", "ixARC9WorldModels", function(entity) installed[entity] = nil end)
hook.Add("InitPostEntity", "ixARC9WorldModels", seed)
hook.Add("OnReloaded", "ixARC9WorldModels", function() timer.Simple(0, seed) end)
timer.Simple(0, seed)

concommand.Add("ix_arc9_worldmodel_info", function(_, _, args)
 local viewer = LocalPlayer()
 if not IsValid(viewer) then return end
 local subject = viewer
 if args[1] == "target" then
  subject = viewer:GetEyeTrace().Entity
  if not IsValid(subject) or not subject:IsPlayer() then
   print("[ARC9 models] Look at the affected player and run ix_arc9_worldmodel_info target.")
   return
  end
 end
 local weapon = subject:GetActiveWeapon()
 if not IsValid(weapon) or not weapon.ARC9 then
  print("[ARC9 models] The selected player must hold an ARC9 weapon.")
  return
 end
 M.Install(weapon)
 local row = installed[weapon]
 local rawLOD = row and row.original.ShouldLOD(weapon)
 local lodDistance = GetConVar("arc9_lod_distance")
 print("[ARC9 models]", weapon:GetClass(), "enabled:", enabled:GetBool(), "adapter:", row ~= nil,
  "held:", held(weapon), "native LOD:", rawLOD, "effective LOD:", weapon:ShouldLOD())
 print("[ARC9 models] Fallback:", weapon.WorldModel, "assembled:", weapon.WorldModelMirror or weapon.ViewModel,
  "parts:", #(weapon.WModel or {}), "full assembly:", row ~= nil and row.fullModel ~= nil and row.fullModel == weapon.WModel,
  "lod_distance:", lodDistance and lodDistance:GetFloat())
end)

function M.Stop()
 stopped = true
 for weapon, row in pairs(installed) do
  if IsValid(weapon) then
   for name, fn in pairs(row.wrappers) do
    if weapon[name] == fn then weapon[name] = row.original[name] end
   end
  end
 end
 for _, event in ipairs({"PrePlayerDraw", "OnEntityCreated", "EntityRemoved", "InitPostEntity", "OnReloaded"}) do
  hook.Remove(event, "ixARC9WorldModels")
 end
 concommand.Remove("ix_arc9_worldmodel_info")
end
function P:OnUnload() M.Stop() end
