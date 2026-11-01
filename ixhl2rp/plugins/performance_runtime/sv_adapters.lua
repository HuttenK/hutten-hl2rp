local P,R=PLUGIN,ix.runtime
if R.restoreAdapters then R.restoreAdapters() end
local npcs,props={},{}
local originalHearing,hearingWrapper
local stopped=false
local function remember(e)
 if not IsValid(e) then return end
 if e:IsNPC() then npcs[e]=true end
 if e:GetClass()=="prop_physics" then props[e]={} end
end
local function rebuild()
 npcs={};props={}
 for _,e in ipairs(ents.GetAll()) do remember(e) end
end
local function hearing(data)
 -- A profiler or another addon may retain a wrapper around this function.
 -- Unloading must still restore original semantics without replacing its hook.
 if stopped then return originalHearing(data) end
 -- Same CPTBase policy and method invocation, without the per-sound full
 -- entity enumeration. NPC membership is tracked even before flags initialize.
 if GetConVarNumber("ai_disabled")==1 or GetConVarNumber("cpt_npchearing_advanced")==0 or not IsValid(data.Entity) then return end
 for npc in pairs(npcs) do
  if IsValid(npc) and npc~=data.Entity and npc.CPTBase_NPC and npc.UseAdvancedHearing then
   npc:AdvancedHearingCode(data.Entity,data.SoundLevel,data.Pos,data.Volume)
  end
 end
end
local function knownHearingSource(current)
 local text=file.Read("autorun/server/cpt_hooks.lua","LUA")
 if not text then return false end
 local first=text:find('hook.Add("EntityEmitSound","CPTBase_DetectEntitySounds",function(data)',1,true)
 if not first then return false end
 local last=text:find("\nend)",first,true)
 if not last then return false end
 if util.CRC(text:sub(first,last+4):gsub("%s",""))~="293089188" then return false end
 -- Mounted bytes alone do not identify the live callback: another addon or
 -- profiler may own this hook ID. Only wrap the function from the verified
 -- source and exact definition lines, never an unknown replacement.
 local info=debug.getinfo(current,"S")
 if not info or not isstring(info.source) then return false end
 local path=info.source:gsub("\\","/"):lower()
 if not path:match("[/@]autorun/server/cpt_hooks%.lua$") then return false end
 local _,firstLine=text:sub(1,first-1):gsub("\n","")
 local _,lastLine=text:sub(1,last):gsub("\n","")
 return info.linedefined==firstLine+1 and info.lastlinedefined==lastLine+1
end
function P:InstallHearingAdapter()
 if stopped or hearingWrapper then return end
 local current=(hook.GetTable().EntityEmitSound or {}).CPTBase_DetectEntitySounds
 if isfunction(current) and knownHearingSource(current) then
  originalHearing=current;hearingWrapper=hearing
  hook.Add("EntityEmitSound","CPTBase_DetectEntitySounds",hearingWrapper)
 end
end
local propCursor
local function propSlice()
 local visited=0
 while visited<12 do
  local e,state=next(props,propCursor)
  if not e then propCursor=nil;return end
  propCursor=e;visited=visited+1
  local ph=IsValid(e) and e:GetPhysicsObject()
  if not IsValid(e) or not IsValid(ph) then
   -- Lifecycle removals normally handle this. Restart iteration if removed.
   props[e]=nil;propCursor=nil
  else
   -- Hammer constraints and scripted map mechanics need not appear in the
   -- Lua constraint registry. Leave map-owned physics to the engine.
   local protected=e:MapCreationID()>=0 or IsValid(e:GetParent()) or IsValid(e:GetOwner()) or IsValid(e.ixHeldOwner)
    or e:IsPlayerHolding() or e:GetPhysicsObjectCount()~=1 or constraint.HasConstraints(e)
    or e.ixRuntimeKeepAwake or e:GetMoveType()~=MOVETYPE_VPHYSICS
   if protected or ph:IsAsleep() or not ph:IsMoveable()
    or ph:GetVelocity():LengthSqr()>.0025 or ph:GetAngleVelocity():LengthSqr()>.0025 then
    state.restSince=nil
   else
    local pos=e:GetPos()
    if not state.pos or state.pos:DistToSqr(pos)>.0025 then state.pos=Vector(pos.x,pos.y,pos.z);state.restSince=CurTime() end
    state.restSince=state.restSince or CurTime()
    if CurTime()-state.restSince>=3 then
     -- Do not suspend falling or balanced-on-moving-body objects. Only solid
     -- world support qualifies; collision automatically wakes a sleeping prop.
     local mins=e:OBBMins()
     local bottom=e:LocalToWorld(Vector(0,0,mins.z))
     local tr=util.TraceLine({start=bottom+Vector(0,0,2),endpos=bottom-Vector(0,0,3),filter=e,mask=MASK_SOLID})
     if tr.HitWorld and not tr.StartSolid then ph:Sleep() end
     state.restSince=nil
    end
   end
  end
 end
 return false
end
function P:RestoreAdapters()
 if stopped then return end
 stopped=true
 if R.Cancel then R.Cancel("runtime.restingProps") end
 if hearingWrapper and (hook.GetTable().EntityEmitSound or {}).CPTBase_DetectEntitySounds==hearingWrapper then
  hook.Add("EntityEmitSound","CPTBase_DetectEntitySounds",originalHearing)
 end
 hook.Remove("OnEntityCreated","ixRuntimeEntities");hook.Remove("EntityRemoved","ixRuntimeEntities")
 hook.Remove("PostCleanupMap","ixRuntimeEntities");timer.Remove("ixRuntimeAdapters")
end
R.restoreAdapters=function() P:RestoreAdapters() end
hook.Add("OnEntityCreated","ixRuntimeEntities",function(e)
 timer.Simple(0,function() if not stopped then remember(e) end end)
end)
hook.Add("EntityRemoved","ixRuntimeEntities",function(e)
 npcs[e]=nil
 if propCursor==e then propCursor=nil end
 props[e]=nil
end)
hook.Add("PostCleanupMap","ixRuntimeEntities",function() if not stopped then rebuild() end end)
timer.Simple(0,function()
 if stopped then return end
 rebuild();P:InstallHearingAdapter()
 R.Schedule("runtime.restingProps",1,propSlice)
end)
timer.Create("ixRuntimeAdapters",5,0,function() P:InstallHearingAdapter() end)
