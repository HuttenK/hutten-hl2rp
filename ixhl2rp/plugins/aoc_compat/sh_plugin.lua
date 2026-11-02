local PLUGIN = PLUGIN
PLUGIN.name = "Age of Chivalry Compatibility"
PLUGIN.author = "Hutten"
PLUGIN.description = "AoC poses and inventory ammunition without modifying Workshop addons."

ix.AOC = ix.AOC or {}
local A = ix.AOC
A.revision = (A.revision or 0) + 1
ix.util.Include("sh_content.lua")
ix.util.Include("sh_animations.lua")
ix.util.Include("sh_weapons.lua")
ix.util.Include("sv_pickups.lua")

function PLUGIN:OnEntityCreated(entity)
 if not entity:IsWeapon() then return end
 timer.Simple(0, function()
  if IsValid(entity) and entity:IsWeapon() and entity.AOC_Base then A.Prepare(entity) end
 end)
end

function PLUGIN:PostLoadAnimations()
 -- DynaBase can reload libraries without changing the model path/count.
 A.revision = A.revision + 1
 for _, client in ipairs(player.GetAll()) do
  client.ixAOCSequences = nil
  client.ixMainSequenceChoice = nil
 end
end

function PLUGIN:InitPostEntity()
 -- The early mount may follow an addon which already precached m_anm.
 -- Use DynaBase's own startup reload path (including its render pause), once.
 if A.contentMounted and not A.contentRefreshed and wOS and wOS.DynaBase and wOS.DynaBase.InitCompleted then
  A.contentRefreshed = true
  if CLIENT then wOS.DynaBase:ReloadAnimations()
  else RunConsoleCommand("r_flushlod") end
 end
end

function PLUGIN:DoAnimationEvent(client, event, data)
 return A.AnimationEvent(client, event, data)
end

concommand.Add("ix_aoc_pose_info", function(client)
 if CLIENT then client = LocalPlayer() end
 if not IsValid(client) then print("[AoC/Helix] Run this command in a player's console.") return end
 local weapon = client:GetActiveWeapon()
 print("[AoC/Helix] Model:", client:GetModel(), "sequences:", client:GetSequenceCount())
 print("[AoC/Helix] Content bridge:", A.contentStatus or "not initialized")
 print("[AoC/Helix] DynaBase:", wOS and wOS.DynaBase ~= nil or false,
  "AoC registered:", wOS and wOS.DynaBase and wOS.DynaBase.Registers and wOS.DynaBase.Registers["Age of Chivalry Extension"] ~= nil or false)
 print("[AoC/Helix] Dynamic mount:", client:LookupSequence("_dynamic_wiltos_enabled_"),
  "AoC sword idle:", client:LookupSequence("wos_aoc_sword_idle"))
 if not IsValid(weapon) or not weapon.AOC_Base then print("[AoC/Helix] Hold an Age of Chivalry weapon first.") return end
 A.Prepare(weapon)
 print("[AoC/Helix] Weapon:", weapon:GetClass(), "hold:", weapon:GetHoldType())
 for _, act in ipairs({ACT_MP_STAND_IDLE, ACT_MP_RUN, ACT_MP_CROUCH_IDLE, ACT_MP_ATTACK_STAND_PRIMARYFIRE}) do
  local entry = weapon.ActivityTranslate and weapon.ActivityTranslate[act]
  print("[AoC/Helix] Pose:", act, tostring(entry), "sequence:", A.Sequence(client, entry))
 end
end)
