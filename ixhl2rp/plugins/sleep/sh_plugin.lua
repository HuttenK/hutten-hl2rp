local P = PLUGIN
P.name = "Bed Rest"
P.author = "Hutten integration"
P.description = "Добровольный отдых и сон на койке."

ix.sleep = ix.sleep or {}
local S = ix.sleep
S.USE_RANGE = 96
S.FADE_TIME = 2.4
S.VIEW = Vector(0, 0, 20)

-- This schema drops unknown network keys: register all sleep-owned state.
ix.Net:AddPlayerVar("bedRestAngle", false, nil, ix.Net.Type.Angle)
ix.Net:AddPlayerVar("bedRestSleeping", false, nil, ix.Net.Type.Bool)
ix.Net:AddPlayerVar("bedRestBlocked", true, nil, ix.Net.Type.Bool)

function S.IsResting(p)
 return IsValid(p) and p:GetNetVar("bedRestAngle") ~= nil
end
function S.IsSleeping(p)
 return S.IsResting(p) and p:GetNetVar("bedRestSleeping", false)
end

ix.util.Include("sh_beds.lua")
ix.util.Include("sv_sleep.lua")
ix.util.Include("cl_sleep.lua")

for _, entry in ipairs({
 {"Rest", {"отдыхать"}, "Лечь на койку, не засыпая.", false},
 {"Sleep", {"спать"}, "Добровольно уснуть на койке. /Wake — встать.", true}
}) do
 local sleeping = entry[4]
 ix.command.Add(entry[1], {alias=entry[2], description=entry[3], OnRun=function(_, p)
  return P:BeginBedRest(p, S.TraceBed(p), sleeping)
 end})
end
ix.command.Add("Wake", {alias={"проснуться", "встать"}, description="Проснуться и встать с койки.", OnRun=function(_, p)
 return P:WakeBedRest(p)
end})

-- Same native hook used by sithelper. Do not allow prone to replace our hull/view.
P["prone.CanEnter"] = function(_, p)
 if S.IsResting(p) then return false end
end
function P:CanPlayerEnterVehicle(p)
 if S.IsResting(p) then return false end
end
function P:UpdateAnimation(p)
 local angle = p:GetNetVar("bedRestAngle")
 if angle then p:SetRenderAngles(angle) end
end
function P:StartCommand(p, command)
 if not S.IsResting(p) then return end
 command:ClearMovement()
 command:RemoveKey(IN_ATTACK + IN_ATTACK2 + IN_DUCK + IN_RELOAD)
end
