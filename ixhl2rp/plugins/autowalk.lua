PLUGIN.name = "Auto-Walk"
PLUGIN.author = "Schwarz Kruppzo / Hutten"
PLUGIN.description = "Automatic walking with a configurable shortcut."
if SERVER then return end

local enabled=false
function ix.StopAutoWalk() enabled=false end
concommand.Add("ix_autowalk",function()
 if enabled then enabled=false; return end
 if not ix.PlayerControls or not ix.PlayerControls.CanUseHotkeys(false) then return end
 local p=LocalPlayer()
 if p:GetNetVar("forcedSequence") or p:InVehicle() or p:GetNW2Bool("Arcade") then return end
 enabled=true
end)
-- Ordinary input reaches the server's normal speed/stamina/collision checks.
function PLUGIN:CreateMove(cmd)
 if not enabled then return end
 local p=LocalPlayer()
 if not ix.PlayerControls.CanUseHotkeys(false) or p:InVehicle() or p:GetNW2Bool("Arcade")
  or p:GetNetVar("forcedSequence") or p:GetLocalVar("ragdoll",0)~=0 or p:GetLocalVar("knocked",false)
  or p:GetMoveType()~=MOVETYPE_WALK or p:IsFrozen() then enabled=false; return end
 if cmd:GetForwardMove()~=0 or cmd:GetSideMove()~=0 or cmd:GetUpMove()~=0
  or cmd:KeyDown(IN_FORWARD) or cmd:KeyDown(IN_BACK) or cmd:KeyDown(IN_MOVELEFT) or cmd:KeyDown(IN_MOVERIGHT)
  or cmd:KeyDown(IN_JUMP) then enabled=false; return end
 cmd:SetForwardMove(cmd:KeyDown(IN_SPEED) and p:GetRunSpeed() or p:GetWalkSpeed())
end
