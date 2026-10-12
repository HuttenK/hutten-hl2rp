local S = ix.sleep

-- Resolve on the player's actual model. Cellar/SD models expose down stances
-- without necessarily including the optional prone extension. The compiled
-- male/female down01..03 bounds fit the same conservative clearance used below.
-- Never substitute a standing idle, client-provided sequence, or donor model.
S.restSequences={"prone_passive","stances_down02","stances_down01","stances_down03"}
function S.RestSequence(p)
 for _,name in ipairs(S.restSequences) do
  local sequence=p:LookupSequence(name)
  if sequence and sequence>=0 then return name,sequence end
 end
end

-- Model-space overrides may be supplied by a schema after plugins load.
-- center: Vector(x,y,0), yaw: local long-axis yaw, surface: local mattress Z.
-- Dynamic center traces are used when no surface is supplied. Never use OBBMaxs.z
-- as a mattress height: it is usually the headboard, and sometimes an upper bunk.
S.layouts = S.layouts or {}
S.layouts["models/props/interior/bunkbed.mdl"] = S.layouts["models/props/interior/bunkbed.mdl"] or {disabled=true}

function S.IsBed(entity)
 if not IsValid(entity) then return false end
 local class = entity:GetClass()
 -- Furniture is normally prop_physics; an inventory item using a bed model is not a bed.
 if class ~= "ix_bed" and class ~= "prop_physics" and class ~= "prop_physics_multiplayer" and class ~= "prop_dynamic" and class ~= "prop_dynamic_override" then return false end
 local model = string.lower(entity:GetModel() or "")
 return ix.bed and ix.bed.stored and ix.bed.stored[model] ~= nil or false
end

-- Based on the recovered sleep helper; all target geometry stays server-derived.
function S.TraceBed(p)
 if not IsValid(p) then return end
 local origin = p:GetShootPos()
 local trace = util.TraceLine({start=origin, endpos=origin + p:GetAimVector()*S.USE_RANGE, filter=p, mask=MASK_SOLID})
 if S.IsBed(trace.Entity) then return trace.Entity end
 if IsValid(trace.Entity) and not trace.Entity:IsWorld() then return end
 local pos = p:GetPos()
 trace = util.TraceLine({start=pos + Vector(0,0,8), endpos=pos - Vector(0,0,24), filter=p, mask=MASK_SOLID})
 if S.IsBed(trace.Entity) then return trace.Entity end
end

function S.CanReach(p, bed)
 if not S.IsBed(bed) then return false end
 local eye = p:GetShootPos()
 if eye:DistToSqr(bed:NearestPoint(eye)) > S.USE_RANGE^2 then return false end
 local trace = util.TraceLine({start=eye, endpos=bed:WorldSpaceCenter(), filter=p, mask=MASK_SOLID})
 return not trace.StartSolid and (not trace.Hit or trace.Entity == bed)
end

function S.BedTransform(p, bed)
 local model = string.lower(bed:GetModel() or "")
 local layout = S.layouts[model] or {}
 if layout.disabled then return nil, "Для этой двухъярусной койки ещё не настроено безопасное место сна." end
 local angles = bed:GetAngles()
 if bed:GetUp().z < .995 then return nil, "Поставьте койку ровно." end
 if IsValid(bed:GetParent()) or bed:GetVelocity():LengthSqr() > 4 then return nil, "Койка должна стоять неподвижно." end
 local low, high = bed:OBBMins(), bed:OBBMaxs()
 local center = layout.center or Vector((low.x+high.x)/2, (low.y+high.y)/2, 0)
 local yaw = layout.yaw or ((high.x-low.x) >= (high.y-low.y) and 0 or 90)
 local heading = Angle(0, yaw, 0)
 local localTop = layout.surface and layout.surface + 8 or high.z + 8
 local localBottom = layout.surface and layout.surface - 8 or low.z - 8
 local height, position
 for _, offset in ipairs({Vector(), heading:Forward()*20, heading:Forward()*-20, heading:Right()*9, heading:Right()*-9}) do
  local point = center + offset
  local tr = util.TraceLine({start=bed:LocalToWorld(Vector(point.x,point.y,localTop)),
   endpos=bed:LocalToWorld(Vector(point.x,point.y,localBottom)), filter=p, mask=MASK_SOLID})
  if not tr.Hit or tr.StartSolid or tr.Entity ~= bed or tr.HitNormal.z < .95 then
   return nil, "На койке не найден свободный ровный матрас."
  end
  if height and math.abs(height-tr.HitPos.z) > 4 then return nil, "Поверхность койки требует настройки матраса." end
  if not height then height=tr.HitPos.z; position=tr.HitPos + Vector(0,0,4*p:GetModelScale()) end
 end
 return position, Angle(0, math.NormalizeAngle(angles.y+yaw), 0)
end

function S.HullClear(p, pos)
 local mins, maxs = p:GetHull()
 local tr = util.TraceHull({start=pos, endpos=pos, mins=mins, maxs=maxs, filter=p, mask=MASK_PLAYERSOLID})
 return not tr.StartSolid and not tr.AllSolid and not tr.Hit
end

function S.ClearPlacement(p, bed, pos, angle)
 -- Keep the player's native standing hull throughout rest. This conservative
 -- headroom check means waking never expands a prone hull into a ceiling.
 if not S.HullClear(p, pos) then return false end
 local forward, right = angle:Forward(), angle:Right()
 -- Compiled prone_passive and Cellar male/female down01..03 fit these bounds.
 -- Include margin and model scale rather than checking only the player's hull.
 local scale = p:GetModelScale()
 local x = (math.abs(forward.x)*44 + math.abs(right.x)*23)*scale
 local y = (math.abs(forward.y)*44 + math.abs(right.y)*23)*scale
 local body = util.TraceHull({start=pos, endpos=pos, mins=Vector(-x,-y,-3*scale), maxs=Vector(x,y,25*scale), filter=p, mask=MASK_PLAYERSOLID})
 if body.Hit or body.StartSolid or body.AllSolid then return false end
 -- Check the entire path, not just visibility to the nearest corner of a bed.
 local line = util.TraceLine({start=p:GetShootPos(), endpos=pos+S.VIEW, filter={p,bed}, mask=MASK_SOLID})
 if line.Hit or line.StartSolid then return false end
 local mins, maxs = p:GetHull()
 local path = util.TraceHull({start=p:GetPos()+Vector(0,0,2), endpos=pos, mins=mins, maxs=maxs, filter={p,bed}, mask=MASK_PLAYERSOLID})
 return not path.Hit and not path.StartSolid and not path.AllSolid
end

function S.ExitPosition(p, state)
 -- Try the entry point, then the already occupied mattress. No ring search can
 -- choose a point on the other side of a wall; every displacement has a hull sweep.
 local origin = p:GetPos()
 for _, pos in ipairs({state.returnPos, origin}) do
  if origin:DistToSqr(pos) <= (S.USE_RANGE+32)^2 and S.HullClear(p,pos) then
   local mins, maxs = p:GetHull()
   local tr = util.TraceHull({start=origin, endpos=pos, mins=mins, maxs=maxs,
    filter=IsValid(state.bed) and {p,state.bed} or p, mask=MASK_PLAYERSOLID})
   if not tr.Hit and not tr.StartSolid and not tr.AllSolid then return pos end
  end
 end
end
