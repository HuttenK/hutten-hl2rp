local A=ix.ActionAnimations
-- Only server-validated treatment and carried cargo drive contextual poses.
function A.Select(p)
 if not A.enabled or A.Conflict(p) then return "" end
 local medical=p.ixMedicalSession
 if medical and medical.emoteStarted and not medical.finishing and medical.character==p:GetCharacter()
  and ix.Medicine and ix.Medicine.ValidSession(p,medical) and A.WeaponAllows(p,"medical") then
  return "medical",medical.target
 end
 local held=p:GetLocalVar("holdingObject")
 if IsValid(held) and held:GetClass()=="ix_cargo_crate" and held.ixHeldOwner==p and A.WeaponAllows(p,"carry") then
  return "carry",held
 end
 return ""
end
function A.Publish(p,kind,target)
 if p:GetNW2String("ixContextAction","")~=kind then
  p:SetNW2String("ixContextAction",kind);p:SetNW2Float("ixContextActionStarted",CurTime())
 end
 target=IsValid(target) and target or NULL
 if p:GetNW2Entity("ixContextActionTarget")~=target then p:SetNW2Entity("ixContextActionTarget",target) end
end
timer.Create("ixContextActionSessions",.1,0,function()
 for _,p in ipairs(player.GetAll()) do
  local kind,target=A.Select(p);A.Publish(p,kind,target)
 end
end)
local function stop(p) if IsValid(p) then A.Publish(p,"") end end
hook.Add("PlayerDeath","ixContextActionStop",stop)
hook.Add("PrePlayerLoadedCharacter","ixContextActionStop",stop)
hook.Add("PlayerDisconnected","ixContextActionStop",stop)
function A.Unload()
 timer.Remove("ixContextActionSessions")
 for _,name in ipairs({"PlayerDeath","PrePlayerLoadedCharacter","PlayerDisconnected"}) do hook.Remove(name,"ixContextActionStop") end
 for _,p in ipairs(player.GetAll()) do stop(p) end
end
