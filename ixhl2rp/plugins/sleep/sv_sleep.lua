local P, S = PLUGIN, ix.sleep
P.bedSessions = P.bedSessions or {}
P.bedOccupants = P.bedOccupants or {}
util.AddNetworkString("ixBedRestMenu")
util.AddNetworkString("ixBedRestRequest")

function P:BedUnavailable(p)
 local ragdoll = p:GetLocalVar("ragdoll")
 return not p:GetCharacter() or not p:Alive() or p:InVehicle() or p:WaterLevel()>0 or p:IsRestricted() or p:IsFrozen()
  or p:GetNetVar("tied",false) or p:GetNetVar("brth",false) or p:GetNetVar("crit",false)
  or p:GetLocalVar("knocked",false) or ragdoll and ragdoll~=0 or IsValid(p.ixRagdoll)
  or p:GetLocalVar("bIsHoldingObject",false) or IsValid(p:GetLocalVar("holdingObject"))
  or IsValid(p.ixPushCart) or (ix.Downed and ix.Downed.Active and ix.Downed.Active(p))
end

function P:OwnsBedSequence(p, state)
 return p.ixSeqCallback == state.callback and p:GetNetVar("forcedSequence") == state.sequence
end

function P:ReleaseBed(p, state)
 if self.bedOccupants[state.bed] == p then self.bedOccupants[state.bed] = nil end
end

function P:EndBedRest(p, leaveSequence)
 local state = self.bedSessions[p]
 if not state then return end
 self.bedSessions[p] = nil
 self:ReleaseBed(p,state)
 if not IsValid(p) then return end
 p:SetNetVar("bedRestAngle",nil)
 p:SetNetVar("bedRestSleeping",nil)
 p:SetLocalVar("bedRestBlocked",nil)
 if p:GetViewOffset():DistToSqr(S.VIEW)<.01 then p:SetViewOffset(state.view) end
 if p:GetViewOffsetDucked():DistToSqr(S.VIEW)<.01 then p:SetViewOffsetDucked(state.duckView) end
 -- Native SetRagdolled sets OBSERVER before OnCharacterFallover. Preserve any
 -- subsequent owner's movement/canShoot state when leaving our own sequence.
 if leaveSequence and self:OwnsBedSequence(p,state) then
  if p:GetMoveType() ~= MOVETYPE_NONE then p.ixSequenceMoveType = p:GetMoveType() end
  if p:GetNetVar("canShoot",false) ~= false then p.ixCouldShoot = p:GetNetVar("canShoot") end
  p:LeaveSequence()
 end
end

function P:WakeBedRest(p)
 local state = self.bedSessions[p]
 if not state then return "Вы сейчас не отдыхаете на койке." end
 p.ixBedUseUntil = CurTime()+.4
 p:SetNetVar("bedRestSleeping",nil)
 state.sleeping = false
 if not p:Alive() or p:GetCharacter()~=state.character or self:BedUnavailable(p) or p:GetMoveType()~=MOVETYPE_NONE then
  self:EndBedRest(p,true)
  return
 end
 local exit = S.ExitPosition(p,state)
 if not exit then
  state.waking = true
  p:SetLocalVar("bedRestBlocked",true)
  return "Вы проснулись. Освободите место рядом с койкой, чтобы встать."
 end
 self:EndBedRest(p,true)
 p:SetPos(exit)
 p:SetLocalVelocity(vector_origin)
end

function P:BeginBedRest(p, bed, sleeping)
 local current = self.bedSessions[p]
 if current then
  if current.waking then return "Сначала освободите место, чтобы встать." end
  if self:BedUnavailable(p) or p:GetCharacter()~=current.character or p:GetModel()~=current.model
   or not self:OwnsBedSequence(p,current) then self:EndBedRest(p,true); return "Сейчас нельзя отдыхать." end
  current.sleeping = sleeping == true
  p:SetNetVar("bedRestSleeping",current.sleeping or nil)
  return
 end
 if (p.ixBedRequestAt or 0)>CurTime() then return end
 p.ixBedRequestAt = CurTime()+.4
 if self:BedUnavailable(p) or p:GetMoveType()~=MOVETYPE_WALK or not p:OnGround() or p:GetVelocity():LengthSqr()>100
  or p:GetNetVar("forcedSequence")~=nil or p.ixUntimedSequence or p:GetNetVar("sitHelperPos")
  or (p.IsProne and p:IsProne()) or p:GetNW2Bool("ixPoseStudioPlaying",false) then return "Сначала завершите текущее действие и остановитесь." end
 if not S.CanReach(p,bed) then return "Посмотрите на койку и подойдите ближе." end
 local occupant = self.bedOccupants[bed]
 if occupant and self.bedSessions[occupant] then return "Эта койка уже занята." end
 -- ix_bed.user belongs to the medical touch timer; do not steal that ownership.
 if IsValid(bed.user) and bed.user~=p then return "На этой койке уже кто-то лежит." end
 local sequenceName, sequence = S.RestSequence(p)
 if not sequenceName then return "Эта модель персонажа не поддерживает анимацию лежания." end
 local pos, angle = S.BedTransform(p,bed)
 if not pos then return angle end
 if not S.ClearPlacement(p,bed,pos,angle) then return "Матрас или путь к нему занят. Освободите место вокруг койки." end
 local state = {bed=bed,character=p:GetCharacter(),model=p:GetModel(),position=pos,angle=angle,
  bedPos=bed:GetPos(),bedAngle=bed:GetAngles(),returnPos=p:GetPos(),view=p:GetViewOffset(),duckView=p:GetViewOffsetDucked(),
  sleeping=sleeping==true,sequence=sequence,entered=CurTime()}
 state.callback = function()
  if P.bedSessions[p]==state then P:EndBedRest(p,false) end
 end
 -- Native ForceSequence owns movement and shooting restoration. See
 -- helix/gamemode/core/libs/sh_anims.lua; zero duration is an untimed sequence.
 if p:ForceSequence(sequenceName,state.callback,0)==false then return "Не удалось начать анимацию лежания." end
 self.bedSessions[p]=state
 self.bedOccupants[bed]=p
 p:SetPos(pos)
 p:SetAngles(angle)
 p:SetLocalVelocity(vector_origin)
 p:SetViewOffset(S.VIEW)
 p:SetViewOffsetDucked(S.VIEW)
 p:SetNetVar("bedRestAngle",angle)
 p:SetNetVar("bedRestSleeping",state.sleeping or nil)
 p:Notify(state.sleeping and "Вы засыпаете. Нажмите использование или прыжок, чтобы встать." or "Вы легли отдохнуть. /Sleep — уснуть; /Wake — встать.")
end

function P:KeyPress(p, key)
 if key~=IN_USE and key~=IN_JUMP then return end
 local state = self.bedSessions[p]
 if state then
  if CurTime()-state.entered>.35 then
   local message = self:WakeBedRest(p)
   if message then p:Notify(message) end
  end
  return
 end
 if key~=IN_USE or (p.ixBedUseUntil or 0)>CurTime() or self:BedUnavailable(p) then return end
 local bed = S.TraceBed(p)
 if not S.CanReach(p,bed) then return end
 p.ixBedUseUntil = CurTime()+.5
 net.Start("ixBedRestMenu"); net.WriteEntity(bed); net.Send(p)
end

function P:PlayerUse(p, entity)
 if self.bedSessions[p] or S.IsBed(entity) or (p.ixBedUseUntil or 0)>CurTime() then return false end
end

net.Receive("ixBedRestRequest",function(length,p)
 if length>64 or length<2 or not p:GetCharacter() then return end
 if (p.ixBedPacketAt or 0)>CurTime() then return end
 p.ixBedPacketAt=CurTime()+.15
 local action, bed = net.ReadUInt(2), net.ReadEntity()
 local message
 if action==3 then message=P:WakeBedRest(p)
 elseif action==1 or action==2 then message=P:BeginBedRest(p,bed,action==2) end
 if message then p:Notify(message) end
end)

function P:PlayerEnterSequence(p)
 -- This hook runs BEFORE ForceSequence overwrites its state, including when an
 -- act uses the same numeric sequence. Retire the old callback exactly once.
 if self.bedSessions[p] then self:EndBedRest(p,true) end
end
function P:PlayerLeaveSequence(p)
 -- Runs before native movement restoration; never recursively leave a sequence.
 if self.bedSessions[p] then self:EndBedRest(p,false) end
end
function P:OnCharacterFallover(p, _, state)
 if state then self:EndBedRest(p,true) end
end
function P:EntityTakeDamage(entity, damage)
 if self.bedSessions[entity] and damage:GetDamage()>0 then self:WakeBedRest(entity) end
end
function P:DoPlayerDeath(p) self:EndBedRest(p,true) end
function P:PlayerDeath(p) self:EndBedRest(p,true) end
function P:PlayerSpawn(p) self:EndBedRest(p,true) end
function P:PrePlayerLoadedCharacter(p) self:EndBedRest(p,true) end
function P:PlayerDisconnected(p) self:EndBedRest(p,true) end
function P:EntityRemoved(entity)
 local p = self.bedOccupants[entity]
 if p and self.bedSessions[p] then
  local state = self.bedSessions[p]
  self:WakeBedRest(p)
  self:ReleaseBed(p,state)
 end
end
function P:Think()
 if (self.nextBedCheck or 0)>CurTime() then return end
 self.nextBedCheck=CurTime()+.2
 for p,state in pairs(self.bedSessions) do
  if not IsValid(p) then self:EndBedRest(p,false)
  elseif p:GetCharacter()~=state.character or p:GetModel()~=state.model or self:BedUnavailable(p)
   or not self:OwnsBedSequence(p,state) or p:GetMoveType()~=MOVETYPE_NONE or (p.IsProne and p:IsProne())
   or p:GetNW2Bool("ixPoseStudioPlaying",false) or p:GetPos():DistToSqr(state.position)>4 then self:EndBedRest(p,true)
  elseif state.waking then self:WakeBedRest(p)
  elseif not S.IsBed(state.bed) or state.bed:GetPos():DistToSqr(state.bedPos)>1
   or math.abs(math.AngleDifference(state.bed:GetAngles().y,state.bedAngle.y))>1
   or math.abs(math.AngleDifference(state.bed:GetAngles().p,state.bedAngle.p))>1
   or math.abs(math.AngleDifference(state.bed:GetAngles().r,state.bedAngle.r))>1 then self:WakeBedRest(p) end
 end
end
