local P, S = PLUGIN, ix.PoseStudio
for _,name in ipairs({"ixPoseStudioRequest", "ixPoseStudioReply", "ixPoseStudioState", "ixPoseStudioOpen"}) do util.AddNetworkString(name) end
P.poseStore = P.poseStore or {nextID=1, clips={}, props={}}
P.poseActive = P.poseActive or {}

function P:LoadData()
 local data = self:GetData(nil, false, true)
 if istable(data) and istable(data.clips) and istable(data.props) then
  self.poseStore = {nextID=1, clips={}, props={},portabilityBackups=istable(data.portabilityBackups) and table.Copy(data.portabilityBackups) or {}}
  for key,row in pairs(data.clips) do
   local id = tonumber(key)
   local clip,upgraded
   if istable(row) then clip,upgraded=S.MigrateLegacyClip(row.clip) end
   if S.Finite(id, 1, 100000000) and id == math.floor(id) and clip and S.Text(row.owner, 24)
    and #util.TableToJSON(clip)<=S.limit.bytes then
    self.poseStore.clips[tostring(id)] = {id=id, owner=row.owner, author=tostring(row.author or ""),
     revision=(tonumber(row.revision) or 1)+(upgraded and 1 or 0), status=({private=true,pending=true,approved=true})[row.status] and row.status or "private", clip=clip}
    if upgraded then
     self.poseStore.portabilityBackups[tostring(id)]=self.poseStore.portabilityBackups[tostring(id)] or table.Copy(row)
    end
    self.poseStore.nextID = math.max(self.poseStore.nextID, id+1)
   end
  end
  for model in pairs(data.props) do if S.Model(model) then self.poseStore.props[model]=true end end
  -- Loading may recover legacy metadata in memory. Only an explicit save or
  -- another normal library operation persists changes; never rewrite on boot.
 end
end
function P:SaveData() self:SetData(self.poseStore, false, true) end
function P:PoseUser(p) return IsValid(p) and p:GetCharacter() ~= nil end
function P:PoseReply(p, data)
 local text = util.TableToJSON(data)
 if not text or #text > 60000 then return end
 net.Start("ixPoseStudioReply"); net.WriteUInt(#text, 16); net.WriteData(text, #text); net.Send(p)
end
function P:PoseError(p, message) self:PoseReply(p, {kind="error", message=message}) end
function P:PoseCount(owner)
 local count=0
 for _,row in pairs(self.poseStore.clips) do if row.owner==owner then count=count+1 end end
 return count
end
function P:PoseAllowedProps(p)
 local models={}
 for model in pairs(self.poseStore.props) do models[model]="Контент сервера" end
 for _,item in pairs(p:GetItems()) do
  local model=item:GetModel()
  if isstring(model) then model=model:lower() end
  if S.Model(model) then models[model]=string.sub(tostring(item:GetName()),1,120) end
 end
 return models
end
function P:PoseCatalog(p, mode, page)
 mode = ({own=true,shared=true,review=true})[mode] and mode or "own"
 if mode=="review" and not p:IsAdmin() then return self:PoseError(p,"Только для администрации.") end
 local rows={}
 for _,row in pairs(self.poseStore.clips) do
  if (mode=="own" and row.owner==p:SteamID64()) or (mode=="shared" and row.status=="approved")
   or (mode=="review" and row.status=="pending") then
   rows[#rows+1]={id=row.id,name=row.clip.name,model=row.clip.model,status=row.status,author=row.author,revision=row.revision,portable=row.clip.portable,mask=row.clip.mask}
  end
 end
 table.sort(rows,function(a,b) return a.id>b.id end)
 local pages=math.max(1, math.ceil(#rows/S.limit.page))
 page=math.Clamp(math.floor(tonumber(page) or 1),1,pages)
 local visible={}
 for i=(page-1)*S.limit.page+1,math.min(page*S.limit.page,#rows) do visible[#visible+1]=rows[i] end
 local props={}
 for model,name in pairs(self:PoseAllowedProps(p)) do props[#props+1]={model=model,name=name} end
 table.sort(props,function(a,b) return a.model<b.model end)
 while #props>128 do table.remove(props) end
 self:PoseReply(p,{kind="catalog",rows=visible,mode=mode,page=page,pages=pages,count=self:PoseCount(p:SteamID64()),props=props})
end
function P:PoseCanRead(p,row)
 return row and (row.owner==p:SteamID64() or row.status=="approved" or p:IsAdmin())
end
function P:PoseRigCheck(p,clip)
 local compatible,err=S.ModelSupports(p,clip)
 if not compatible then return false,err end
 local allowed=self:PoseAllowedProps(p)
 for _,prop in ipairs(clip.props) do
  if not p:LookupBone(prop.bone) or not allowed[prop.model] or not util.IsValidModel(prop.model) then
   return false,"Реквизит отсутствует в инвентаре или не разрешён администрацией."
  end
 end
 return true
end
function P:SavePose(p, data)
 local id=tostring(data.id or "")
 local old=self.poseStore.clips[id]
 if data.id and (not old or old.owner~=p:SteamID64()) then return self:PoseError(p,"Чужую анимацию можно только скопировать.") end
 if old and data.revision~=old.revision then return self:PoseError(p,"Версия изменилась. Откройте сохранённую анимацию заново.") end
 if not old and self:PoseCount(p:SteamID64())>=S.limit.clips then return self:PoseError(p,"Лимит: 30 анимаций.") end
 local clip,err=S.Validate(data.clip)
 if not clip then return self:PoseError(p,err) end
 if #util.TableToJSON(clip)>S.limit.bytes then return self:PoseError(p,"Анимация превышает лимит 48 КБ. Уменьшите число костей или кадров.") end
 local valid,message=self:PoseRigCheck(p,clip)
 if not valid then return self:PoseError(p,message) end
 if not old then id=tostring(self.poseStore.nextID); self.poseStore.nextID=self.poseStore.nextID+1 end
 local row={id=tonumber(id),owner=p:SteamID64(),author=p:GetCharacter():GetName(),revision=old and old.revision+1 or 1,status="private",clip=clip}
 self.poseStore.clips[id]=row
 self:SaveData()
 self:PoseReply(p,{kind="saved",row=row})
end
function P:PoseState(p, state, recipient)
 local text=util.TableToJSON(state and {token=state.token,clip=state.clip,started=state.started,model=state.model} or {})
 if not text or #text>60000 then return end
 net.Start("ixPoseStudioState"); net.WriteEntity(p); net.WriteUInt(#text,16); net.WriteData(text,#text)
 if recipient then net.Send(recipient) else net.Broadcast() end
end
function P:StopPose(p, leaveSequence)
 local state=self.poseActive[p]
 if not state then return end
 self.poseActive[p]=nil
 if IsValid(p) then
  p:SetNW2Bool("ixPoseStudioPlaying",false)
  p:SetNW2Bool("ixPoseStudioUpperBody",false)
  if state.clip.mask~="upper" then
   p:SetPlaybackRate(1)
   if leaveSequence~=false and state.sequence~=nil and p:GetNetVar("forcedSequence")==state.sequence then p:LeaveSequence() end
  end
  self:PoseState(p)
 end
end
function P:PoseAvailable(p,clip)
 local ragdoll=p:GetLocalVar("ragdoll",0)
 local placed=self.posePlaced and self.posePlaced[p]
 clip=clip or (self.poseActive[p] and self.poseActive[p].clip)
 local upper=clip and clip.mask=="upper"
 return self:PoseUser(p) and p:Alive() and (upper or placed or p:OnGround()) and not p:InVehicle() and p:WaterLevel()==0
  and (not ragdoll or ragdoll==0) and not p:GetLocalVar("knocked",false)
  and not p:GetNetVar("tied",false) and not p:IsFrozen() and (p:GetMoveType()==MOVETYPE_WALK or placed and p:GetMoveType()==MOVETYPE_NONE)
  and (upper or p:GetVelocity():Length2DSqr()<16) and not (ix.Downed and ix.Downed.Crawling(p))
end
function P:PlayPose(p,row)
 if not self:PoseCanRead(p,row) then return self:PoseError(p,"Анимация недоступна.") end
 if (p.ixPosePlayAt or 0)>CurTime() then return end
 p.ixPosePlayAt=CurTime()+1
 if not self:PoseAvailable(p,row.clip) then return self:PoseError(p,"Сейчас нельзя начать эту анимацию. Для полной позы остановитесь на земле.") end
 if p:GetNetVar("forcedSequence") and not self.poseActive[p] then return self:PoseError(p,"Сначала завершите текущее действие.") end
 local valid,message=self:PoseRigCheck(p,row.clip)
 if not valid then return self:PoseError(p,message) end
 local hands=p:GetWeapon("ix_hands")
 if not IsValid(hands) then return self:PoseError(p,"Уберите оружие и попробуйте снова.") end
 self:StopPose(p)
 p:SelectWeapon("ix_hands")
 local upper=row.clip.mask=="upper"
 if not upper then
  local base=S.TargetBase(p,row.clip)
  local started=p:ForceSequence(base,function() self:StopPose(p,false) end,0,true)
  if started==false then return self:PoseError(p,"Не удалось запустить базовую анимацию.") end
 end
 local state={clip=table.Copy(row.clip),started=CurTime(),character=p:GetCharacter(),model=p:GetModel(),
  sequence=p:GetNetVar("forcedSequence"),token=tostring(row.id)..":"..tostring(SysTime()),position=p:GetPos()}
 self.poseActive[p]=state
 p:SetNW2Bool("ixPoseStudioPlaying",true)
 p:SetNW2Bool("ixPoseStudioUpperBody",upper)
 if not upper then p:SetCycle(row.clip.cycle); p:SetPlaybackRate(0) end
 self:PoseState(p,state)
end
function P:PlayNamedPose(p,name)
 if not self:PoseUser(p) then return end
 for _,row in pairs(self.poseStore.clips) do
  if row.owner==p:SteamID64() and (tostring(row.id)==name or row.clip.name==name) then return self:PlayPose(p,row) end
 end
 self:PoseError(p,"Анимация не найдена в вашей библиотеке.")
end
function P:SetPoseProp(p,model,enabled)
 if not self:PoseUser(p) or not p:IsAdmin() then return end
 model=string.Trim(model):lower()
 if not S.Model(model) or (enabled and not util.IsValidModel(model)) then return p:Notify("Укажите существующую models/...mdl модель.") end
 self.poseStore.props[model]=enabled or nil; self:SaveData()
 p:Notify(enabled and "Реквизит разрешён." or "Реквизит удалён из списка.")
end
function P:OpenStudio(p)
 if not self:PoseUser(p) then return end
 if (p.ixPoseOpenAt or 0)>CurTime() then return end
 p.ixPoseOpenAt=CurTime()+1
 self:StopPose(p)
 if self.StopPlacement then self:StopPlacement(p) end
 net.Start("ixPoseStudioOpen"); net.Send(p)
end
function P:HandlePose(p,data)
 if not self:PoseUser(p) or not istable(data) then return end
 local op=data.op
 local row=self.poseStore.clips[tostring(data.id or "")]
 if op=="preview" then self:PosePreview(p,data)
 elseif op=="place" then self:PlacePose(p,data)
 elseif op=="radial" then self:PoseRadial(p,data)
 elseif op=="act" then self:RunStudioAct(p,data)
 elseif op=="stopAll" then
  self:StopPlacement(p)
  self:StopPose(p)
  local acts=ix.plugin.Get("act")
  if acts and p:GetNetVar("actEnterAngle") then acts:AbortAct(p) end
 elseif op=="list" then self:PoseCatalog(p,data.mode,data.page)
 elseif op=="load" then
  if self:PoseCanRead(p,row) then self:PoseReply(p,{kind="loaded",row=row}) else self:PoseError(p,"Анимация недоступна.") end
 elseif op=="save" then self:SavePose(p,data)
 elseif op=="stop" then self:StopPlacement(p); self:StopPose(p)
 elseif op=="play" then self:PlayPose(p,row)
 elseif op=="delete" then
  if row and (row.owner==p:SteamID64() or p:IsAdmin()) then
   for target,state in pairs(self.poseActive) do if state.token:match("^(%d+):")==tostring(row.id) then self:StopPose(target) end end
   self.poseStore.clips[tostring(row.id)]=nil; self:SaveData(); self:PoseReply(p,{kind="deleted",id=row.id})
  else self:PoseError(p,"Нет доступа к удалению.") end
 elseif op=="submit" then
  if row and row.owner==p:SteamID64() then
   row.status="pending"; self:SaveData(); self:PoseReply(p,{kind="status",id=row.id,status=row.status,message="Отправлено на проверку. После одобрения появится в общей библиотеке."})
  end
 elseif op=="approve" or op=="reject" then
  if not p:IsAdmin() then return self:PoseError(p,"Только для администрации.") end
  if row then
   row.status=op=="approve" and "approved" or "private"; self:SaveData()
   self:PoseReply(p,{kind="status",id=row.id,status=row.status,message=op=="approve" and "Опубликовано." or "Публикация снята."})
  end
 elseif op=="import" then
  if not row or row.status~="approved" then return self:PoseError(p,"Импорт доступен только после одобрения.") end
  self:SavePose(p,{clip=row.clip})
 elseif op=="sync" then
  if (p.ixPoseSyncAt or 0)>CurTime() then return end
  p.ixPoseSyncAt=CurTime()+10
  local index=0
  for target,state in pairs(self.poseActive) do
   index=index+1
   timer.Simple(index*.12,function()
    if IsValid(p) and IsValid(target) and self.poseActive[target]==state then self:PoseState(target,state,p) end
   end)
  end
 end
end
net.Receive("ixPoseStudioRequest",function(bits,p)
 if bits>50000*8 or not P:PoseUser(p) then return end
 local now=CurTime()
 local budget=p.ixPoseBudget or {tokens=10,time=now}
 budget.tokens=math.min(10,budget.tokens+(now-budget.time)*3); budget.time=now; p.ixPoseBudget=budget
 if budget.tokens<1 then return end
 budget.tokens=budget.tokens-1
 local size=net.ReadUInt(16)
 if size>50000 or size*8+16>bits then return end
 local raw=net.ReadData(size)
 if not raw then return end
 local data=util.JSONToTable(raw)
 P:HandlePose(p,data)
end)
function P:StartCommand(p,cmd)
 if not self.poseActive[p] and not (self.posePlaced and self.posePlaced[p]) then return end
 local upper=self.poseActive[p] and self.poseActive[p].clip.mask=="upper"
 local moved=not upper and (cmd:GetForwardMove()~=0 or cmd:GetSideMove()~=0 or cmd:GetUpMove()~=0 or cmd:KeyDown(IN_JUMP) or cmd:KeyDown(IN_DUCK))
 if moved or cmd:KeyDown(IN_ATTACK) or cmd:KeyDown(IN_ATTACK2)
  or cmd:KeyDown(IN_USE) then
  if self.StopPlacement then self:StopPlacement(p) end
  self:StopPose(p)
  cmd:RemoveKey(IN_ATTACK); cmd:RemoveKey(IN_ATTACK2)
 end
end
function P:Think()
 if (self.poseCheckAt or 0)>CurTime() then return end
 self.poseCheckAt=CurTime()+.1
 if self.PlacementThink then self:PlacementThink() end
 for p,state in pairs(self.poseActive) do
  local weapon=IsValid(p) and p:GetActiveWeapon()
  if not IsValid(p) or not self:PoseAvailable(p) or p:GetCharacter()~=state.character or p:GetModel()~=state.model
   or p:GetNetVar("forcedSequence")~=state.sequence or (state.clip.mask~="upper" and p:GetPos():DistToSqr(state.position)>4)
   or (IsValid(weapon) and weapon:GetClass()~="ix_hands")
   or (#state.clip.frames>1 and not state.clip.loop and CurTime()-state.started>=S.Duration(state.clip)) then
   self:StopPose(p)
  else
   if state.clip.mask~="upper" then p:SetCycle(state.clip.cycle); p:SetPlaybackRate(0) end
   if (state.nextProps or 0)<=CurTime() then
    state.nextProps=CurTime()+1
    if not self:PoseRigCheck(p,state.clip) then self:StopPose(p) end
   end
  end
 end
end
function P:PlayerDeath(p) self:StopPose(p); if self.StopPlacement then self:StopPlacement(p) end end
function P:PlayerLoadedCharacter(p)
 timer.Simple(1,function()
  if self:PoseUser(p) then p.ixPoseSyncAt=nil; self:HandlePose(p,{op="sync"}) end
 end)
end
function P:PlayerSpawn(p) self:StopPose(p); if self.StopPlacement then self:StopPlacement(p) end end
function P:PlayerDisconnected(p) self:StopPose(p); if self.StopPlacement then self:StopPlacement(p) end end
function P:PrePlayerLoadedCharacter(p) self:StopPose(p); if self.StopPlacement then self:StopPlacement(p) end end
function P:OnCharacterFallover(p) self:StopPose(p); if self.StopPlacement then self:StopPlacement(p) end end
function P:PlayerEnterVehicle(p) self:StopPose(p); if self.StopPlacement then self:StopPlacement(p) end end
function P:PlayerLeaveSequence(p) self:StopPose(p,false); if self.ClearPlacement then self:ClearPlacement(p) end end
function P:PlayerEnterSequence(p) self:StopPose(p); if self.StopPlacement then self:StopPlacement(p) end end
function P:EntityTakeDamage(entity,damage) if damage:GetDamage()>0 then self:StopPose(entity); if self.StopPlacement then self:StopPlacement(entity) end end end
