local S=ix.PoseStudio
S.placementHeight={min=-24,max=48}
function S.Selection(raw)
 if not istable(raw) then return end
 if raw.kind=="custom" and S.Finite(raw.id,1,100000000) and raw.id==math.floor(raw.id) then return {kind="custom",id=raw.id} end
 if raw.kind=="sit" and S.Finite(raw.id,1,24) and raw.id==math.floor(raw.id) then return {kind="sit",id=raw.id} end
 if raw.kind=="act" and S.Text(raw.name,64) and S.Finite(raw.variant,1,64) and raw.variant==math.floor(raw.variant) then
  return {kind="act",name=raw.name,variant=raw.variant}
 end
end
function S.SelectionKey(spec)
 return spec.kind..":"..tostring(spec.id or spec.name)..":"..tostring(spec.variant or 0)
end
function S.NativePreview(p,spec)
 if spec.kind=="sit" then
  local helper=ix.plugin.Get("sithelper")
  if not helper then return end
  local name,index,shared=helper:ResolvePose(p,spec.id)
  if name then return {sequence=name,index=index,shared=shared,static=true,offset=helper:GetPoseOffset(p,spec.id,p:GetCharacter())} end
 elseif spec.kind=="act" then
  local classes=ix.act and ix.act.stored[spec.name]
  local data=classes and ix.act.Resolve(p,classes,spec.variant)
  if not data then return end
  local sequence=data.sequence[spec.variant]
  local extra=istable(sequence) and sequence or {}
  local name,index,shared=ix.act.Sequence(p,{extra[1] or sequence})
  local offset=extra.offset and extra.offset(p) or vector_origin
  if extra.offset then offset=Vector(offset:Dot(p:GetForward()),offset:Dot(p:GetRight()),offset.z) end
  if name then return {sequence=name,index=index,shared=shared,static=shared~=nil and not shared.animated,
   duration=data.untimed and 0 or extra.duration or (shared and shared.duration),check=extra.check,offset=offset} end
 end
end
function S.PlacementPoint(p)
 local forward=util.TraceLine({start=p:EyePos(),endpos=p:EyePos()+p:EyeAngles():Forward()*80,filter=p})
 local trace=util.TraceHull({start=forward.HitPos+Vector(0,0,3),endpos=forward.HitPos-Vector(0,0,100),
  mins=Vector(-3,-3,0),maxs=Vector(3,3,2),filter=p})
 return trace.HitPos,trace
end
function S.CheckPlacement(p,anchor,yaw,height,offset)
 if not isvector(anchor) or not S.Finite(yaw,-36000,36000) or not S.Finite(height,S.placementHeight.min,S.placementHeight.max) then
  return false,"Некорректная позиция"
 end
 for _,v in ipairs({anchor.x,anchor.y,anchor.z}) do if not S.Finite(v,-32768,32768) then return false,"Некорректная позиция" end end
 if anchor:DistToSqr(p:EyePos())>110^2 then return false,"Подойдите ближе" end
 local support=util.TraceHull({start=anchor+Vector(0,0,3),endpos=anchor-Vector(0,0,4),
  mins=Vector(-3,-3,0),maxs=Vector(3,3,2),filter=p})
 if not support.Hit or support.StartSolid or support.AllSolid or support.HitNormal.z<=.75 then return false,"Нет ровной опоры" end
 local angle=Angle(0,math.NormalizeAngle(yaw),0)
 local final=anchor+angle:Forward()*(offset and offset.x or 0)+angle:Right()*(offset and offset.y or 0)+Vector(0,0,(offset and offset.z or 0)+height)
 -- IsInWorld exists only on the server. Both client previews use the traces
 -- below; the server repeats them and verifies world bounds before placement.
 if (SERVER and not util.IsInWorld(final)) or final:DistToSqr(p:GetPos())>140^2 then return false,"Подойдите ближе" end
 -- Verify line of sight to the contact point and the raised root. Downward
 -- chair offsets are intentional, so validate their seat rather than the floor below it.
 local norm=(anchor-p:EyePos()):GetNormalized()
 local visible=util.TraceLine({start=p:EyePos(),endpos=anchor-norm*2,filter=p})
 if visible.Hit then return false,"Место закрыто препятствием" end
 local top=final+Vector(0,0,math.max(4,-(offset and offset.z or 0)-height+4))
 local sweep=util.TraceHull({start=anchor+Vector(0,0,4),endpos=top,
  mins=Vector(-3,-3,0),maxs=Vector(3,3,4),filter=p})
 if sweep.StartSolid or sweep.AllSolid or sweep.Hit then return false,"Недостаточно места по высоте" end
 return true,nil,final,angle
end
