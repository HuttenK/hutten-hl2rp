local F=ix.Fieldlink
-- Resolve named neutral locomotion before Helix's raised-weapon translator.
-- ACT_IDLE / ACT_HL2MP_IDLE can randomly select scared/cowering alternatives.
local neutralNames={
 [ACT_MP_STAND_IDLE]={"idle_all_01","idle_unarmed","idle01"},
 [ACT_MP_WALK]={"walk_all","walk_all_01"},
 [ACT_MP_RUN]={"run_all_01","run_all"},
 [ACT_MP_CROUCH_IDLE]={"cidle_all","crouch_idle"},
 [ACT_MP_CROUCHWALK]={"cwalk_all","crouch_walk"}
}
function F.PDABaseSequence(p,activity)
 local w=p:GetActiveWeapon()
 if not IsValid(w) or w:GetClass()~=F.class or p:InVehicle() or not p:OnGround()
  or p:GetNetVar("forcedSequence") or p:GetNetVar("sharedPose")
  or p:GetLocalVar("ragdoll",0)~=0 or p:GetLocalVar("knocked",false)
  or (ix.Downed and ix.Downed.Crawling(p)) then return end
 for _,name in ipairs(neutralNames[activity] or {}) do
  local id=p:LookupSequence(name)
  if id and id>=0 then return id end
 end
 -- NPC-only rigs use their lowered activity. Never use a combat stance as fallback.
 local class=p.ixAnimModelClass or "player"
 local tree=ix.anim and ix.anim[class] and ix.anim[class].normal
 local value=tree and tree[activity]
 if istable(value) then value=value[1] end
 if isstring(value) then local id=p:LookupSequence(value);if id and id>=0 then return id end
 elseif isnumber(value) then local id=p:SelectWeightedSequence(value);if id and id>=0 then return id end end
end
