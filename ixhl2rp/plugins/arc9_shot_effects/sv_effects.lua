local P = PLUGIN
ix.arc9ShotEffects = ix.arc9ShotEffects or {}
local F = ix.arc9ShotEffects
if F.Stop then F.Stop() end
local installed = setmetatable({}, {__mode = "k"})
local stopped = false
F.sent = 0

function F.Install(weapon)
 if stopped or not IsValid(weapon) or not weapon.ARC9 or not isfunction(weapon.DoEffects) or installed[weapon] then return end
 local original = weapon.DoEffects
 -- Decorate only ARC9's standard dispatcher. Weapon-specific effects (flames,
 -- launchers, etc.) retain their own implementation and networking behavior.
 local info = debug.getinfo(original, "S")
 if not info or not (info.source or ""):gsub("\\", "/"):match("weapons/arc9_base/sh_effects%.lua$") then return end
 local wrapper = function(self, ...)
  if stopped then return original(self, ...) end
  if not self:GetProcessedValue("MuzzleParticle", true) or
   (vFireInstalled and self:GetProcessedValue("ShootEnt") == "vfire_ball") then return original(self, ...) end
  if not IsFirstTimePredicted() or self:GetProcessedValue("NoMuzzleEffect", true) then return end
  local owner = self:GetOwner()
  if not IsValid(owner) then return original(self, ...) end
  local origin = owner.GetShootPos and owner:GetShootPos() or self:GetPos()
  local data = EffectData()
  data:SetEntity(self)
  data:SetOrigin(origin)
  data:SetAttachment(self:GetQCAMuzzle())
  data:SetSurfaceProp(self:GetNthShot() % 2)
  -- ARC9 leaves Origin at zero. Explicitly route this event around the shooter,
  -- rather than depending on the map origin or implicit prediction filtering.
  -- https://wiki.facepunch.com/gmod/util.Effect
  -- https://wiki.facepunch.com/gmod/CRecipientFilter:AddPVS
  local recipients = RecipientFilter()
  recipients:AddPVS(origin)
  -- The shooter already runs the original predicted client effect. Single
  -- player has no client PrimaryAttack prediction, so retain its recipient.
  if owner:IsPlayer() and not game.SinglePlayer() then recipients:RemovePlayer(owner) end
  util.Effect("arc9_muzzleeffect", data, true, recipients)
  F.sent = F.sent + 1
 end
 installed[weapon] = {original = original, wrapper = wrapper}
 weapon.DoEffects = wrapper
end

local function seed()
 for _, weapon in ipairs(ents.FindByClass("arc9_*")) do F.Install(weapon) end
end
hook.Add("WeaponEquip", "ixARC9ShotEffects", F.Install)
hook.Add("OnEntityCreated", "ixARC9ShotEffects", function(entity)
 if not IsValid(entity) or not entity:GetClass():match("^arc9_") then return end
 timer.Simple(0, function() F.Install(entity) end)
end)
hook.Add("InitPostEntity", "ixARC9ShotEffects", seed)
timer.Simple(0, seed)
function F.Stop()
 stopped = true
 for weapon, row in pairs(installed) do
  if IsValid(weapon) and weapon.DoEffects == row.wrapper then weapon.DoEffects = row.original end
 end
 for _, event in ipairs({"WeaponEquip", "OnEntityCreated", "InitPostEntity"}) do hook.Remove(event, "ixARC9ShotEffects") end
end
function P:OnUnload() F.Stop() end
