local P,S=PLUGIN,ix.PoseStudio
P.posePlaced=P.posePlaced or {}
function P:ResolvePoseSelection(p,raw)
 local spec=S.Selection(raw)
 if not spec then return nil,"Анимация недоступна" end
 if spec.kind=="custom" then
  local row=self.poseStore.clips[tostring(spec.id)]
  if not self:PoseCanRead(p,row) then return nil,"Анимация недоступна" end
  local valid,err=self:PoseRigCheck(p,row.clip)
  if not valid then return nil,err end
  return {clip=row.clip,row=row,sequence=row.clip.base,offset=vector_origin},nil,spec
 end
 if spec.kind=="act" and not ix.command.HasAccess(p,"Act"..spec.name) then return nil,"Нет доступа к анимации" end
 local preview=S.NativePreview(p,spec)
 if not preview then return nil,"Эта поза недоступна для модели" end
 return preview,nil,spec
end
function P:PosePreview(p,data)
 if not S.Finite(data.token,0,65535) then return end
 local preview,err=self:ResolvePoseSelection(p,data.selection)
 local result={kind="preview",token=data.token,error=err}
 if preview then
  local offset=preview.offset or vector_origin
  result.preview={clip=preview.clip,sequence=preview.sequence,static=preview.static,offset={offset.x,offset.y,offset.z}}
 end
 self:PoseReply(p,result)
end
function P:ClearPlacement(p)
 local state=self.posePlaced[p]
 if not state then return end
 self.posePlaced[p]=nil
 if not IsValid(p) then return end
 p.ixUntimedSequence=nil; p.ixActModel=nil; p.ixActCharacter=nil
 p:SetNetVar("actEnterAngle",nil)
 p:SetCollisionGroup(state.collision)
 -- Never teleport a new character, a dead player, or a body already moved by
 -- another system. Test the old hull before restoring it (doors may close).
 if p:Alive() and p:GetCharacter()==state.character and p:GetPos():DistToSqr(state.position)<16 then
  local mins,maxs=p:GetHull()
  for _,offset in ipairs({vector_origin,Vector(0,0,8),Vector(16,0,0),Vector(-16,0,0),Vector(0,16,0),Vector(0,-16,0)}) do
   local pos=state.origin+offset
   local tr=util.TraceHull({start=pos,endpos=pos,mins=mins,maxs=maxs,filter=p,mask=MASK_PLAYERSOLID})
   if not tr.StartSolid and not tr.AllSolid and not tr.Hit then p:SetPos(pos); p:SetAngles(state.angle); break end
  end
 end
 p:SetLocalVelocity(vector_origin)
 net.Start("ixActLeave"); net.Send(p)
end
function P:StopPlacement(p)
 if not self.posePlaced[p] then return end
 if IsValid(p) then p.ixSeqCallback=nil; p:LeaveSequence() end
 self:ClearPlacement(p)
 self:StopPose(p,false)
end
function P:PlacePose(p,data)
 if (p.ixPosePlaceAt or 0)>CurTime() then return end
 p.ixPosePlaceAt=CurTime()+.5
 if not self:PoseAvailable(p) or p:GetNetVar("forcedSequence")~=nil then return self:PoseError(p,"Остановитесь и завершите текущее действие.") end
 local preview,err,spec=self:ResolvePoseSelection(p,data.selection)
 if not preview then return self:PoseError(p,err) end
 if preview.clip and preview.clip.mask=="upper" then return self:PoseError(p,"Верх тела применяется без перемещения персонажа.") end
 if not istable(data.anchor) or #data.anchor~=3 then return end
 for _,v in ipairs(data.anchor) do if not S.Finite(v,-32768,32768) then return end end
 local anchor=Vector(unpack(data.anchor))
 local valid,reason,position,angle=S.CheckPlacement(p,anchor,data.yaw,data.height,preview.offset)
 if not valid then return self:PoseError(p,reason) end
 local origin=p:GetPos()
 local originalAngle=p:GetAngles()
 -- Preserve per-act restrictions (wall checks, etc.) at the chosen location.
 if preview.check then
  p:SetPos(position); p:SetAngles(angle)
  local ok,result=pcall(preview.check,p)
  p:SetPos(origin); p:SetAngles(originalAngle)
  if not ok or result then return self:PoseError(p,isstring(result) and result or "Здесь нельзя использовать эту позу") end
 end
 local hands=p:GetWeapon("ix_hands")
 if not IsValid(hands) then return self:PoseError(p,"Уберите оружие и попробуйте снова.") end
 if spec.kind=="custom" then
  self:PlayPose(p,preview.row)
  if not self.poseActive[p] then return end
 else
  p:SelectWeapon("ix_hands")
  if p:ForceSequence(preview.sequence,nil,preview.duration or (spec.kind=="sit" and 0 or nil),false)==false then return end
 end
 self.posePlaced[p]={origin=origin,angle=originalAngle,position=position,character=p:GetCharacter(),model=p:GetModel(),collision=p:GetCollisionGroup()}
 p:SetPos(position); p:SetAngles(angle); p:SetLocalVelocity(vector_origin)
 p:SetMoveType(MOVETYPE_NONE); p:SetCollisionGroup(COLLISION_GROUP_WORLD)
 p:SetNetVar("actEnterAngle",angle); p.ixUntimedSequence=true
 p.ixActModel=p:GetModel(); p.ixActCharacter=p:GetCharacter()
 if self.poseActive[p] then self.poseActive[p].position=position end
 net.Start("ixActEnter"); net.WriteBool(true); net.Send(p)
 self:PoseReply(p,{kind="placed",token=data.token})
end
function P:PlacementThink()
 for p,state in pairs(self.posePlaced) do
  if not IsValid(p) or not self:PoseAvailable(p) or p:GetCharacter()~=state.character or p:GetModel()~=state.model
   or p:GetNetVar("forcedSequence")==nil or p:GetPos():DistToSqr(state.position)>16
   or (IsValid(p:GetActiveWeapon()) and p:GetActiveWeapon():GetClass()~="ix_hands") then self:StopPlacement(p) end
 end
end
