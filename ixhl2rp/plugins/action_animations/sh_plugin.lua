local P=PLUGIN
P.name="Contextual Action Animations"
P.author="Hutten"
P.description="Model-aware upper-body actions without replacing walking animations."
ix.ActionAnimations=ix.ActionAnimations or {}
local A=ix.ActionAnimations
A.enabled=true
ix.util.Include("sh_ik.lua")
function A.Conflict(p)
 if not IsValid(p) or not p:IsPlayer() or not p:Alive() or not p:GetCharacter() or p:InVehicle() then return true end
 local ragdoll=p:GetLocalVar("ragdoll")
 if p:IsRestricted() or p:GetNetVar("tied") or p:GetNetVar("brth") or p:GetNetVar("crit")
  or p:GetNetVar("forcedSequence") or p:GetNetVar("untimedSequence") or p.ixUntimedSequence or p:GetNetVar("bedRestAngle")
  or p:GetNW2Bool("ixPoseStudioPlaying",false) or IsValid(p:GetNW2Entity("ixPushCart"))
  or p:GetNetVar("prone",false) or p:GetLocalVar("knocked",false) or IsValid(ragdoll) or (isnumber(ragdoll) and ragdoll>0)
  or IsValid(p.ixRagdoll) or p:GetMoveType()==MOVETYPE_OBSERVER or p:GetNoDraw() then return true end
 if p.IsProne and p:IsProne() then return true end
 if ix.Downed and ix.Downed.Active and ix.Downed.Active(p) then return true end
 return false
end
function A.BlockAutomatic(p)
 return A.Conflict(p) or p:GetNW2String("ixContextAction","")~="" or (SERVER and A.Select and A.Select(p)~="")
end
function A.WeaponAllows(p,kind)
 local weapon=p:GetActiveWeapon()
 if kind=="medical" then return IsValid(weapon) and weapon:GetClass():find("^ix_med_")~=nil or not p:IsWepRaised() end
 return not p:IsWepRaised() and (not IsValid(weapon) or weapon:GetClass()=="ix_hands" or weapon:GetClass()=="gmod_tool")
end
ix.util.Include("sv_actions.lua")
ix.util.Include("cl_actions.lua")
function P:OnUnload()
 A.enabled=false
 if A.Unload then A.Unload() end
end
