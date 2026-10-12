local P=PLUGIN
P.settings=P.settings or {};P.revision=P.revision or 0
for key,rule in pairs(P.settingRules) do if P.settings[key]==nil then P.settings[key]=rule[1] end end
P.entities=P.entities or {};P.burns=P.burns or {};P.pending=P.pending or {};P.scorched=P.scorched or {}
for _,name in ipairs({'ix610Control','ix610Save'}) do util.AddNetworkString(name) end
local converts={['1']='1',['2']='2',['3']='3',['4']='3',['5']='3',['6']='2',['7']='1',['8']='7',biomass='2',pillar='2',tripod='2'}
function P:SaveData() self:SetData({settings=self.settings,revision=self.revision}) end
function P:LoadData()
 local saved=self:GetData() or {};local settings=saved.settings or {}
 for key,rule in pairs(self.settingRules) do local v=self:ValidateSetting(key,settings[key]);if v==nil then v=rule[1] end;self.settings[key]=v end
 self.revision=math.Clamp(math.floor(tonumber(saved.revision) or 0),0,2147483646)
end
function P:Counts()
 local growth,npcs=0,0
 for ent in pairs(self.entities) do
  if not IsValid(ent) then self.entities[ent]=nil
  elseif not ent.Dead and ent:Health()>0 then
   if self.growthClasses[ent:GetClass()] then growth=growth+1 else npcs=npcs+1 end
  end
 end
 return growth,npcs
end
function P:CanSpawn(class)
 if self.settings.paused then return false end
 local growth,npcs=self:Counts()
 return self.growthClasses[class] and growth<self.settings.maxGrowth or not self.growthClasses[class] and npcs<self.settings.maxNPCs
end
function P:SpawnControlled(class,pos,angles)
 if not self:CanSpawn(class) then return end
 local ent=ents.Create(class);if not IsValid(ent) then return end
 ent.ix610Managed=true;ent:SetPos(pos);if angles then ent:SetAngles(angles) end
 -- Register before Spawn to make recursive creation respect the same global cap.
 self.entities[ent]=true;ent:Spawn();ent:Activate();self:Adapt(ent)
 return ent
end
function P:IsSterilized(ent)
 return ent.ix610Sterilized or (ent.IsOnFire and ent:IsOnFire())
end
function P:ConvertVictim(source,victim)
 if not self.settings.conversion or self.settings.paused or self:IsSterilized(source) then return end
 if not IsValid(victim) or self:Is610(victim) or not (victim:IsNPC() or victim:IsPlayer()) then return end
 if (source.ix610ConversionAt or 0)>CurTime() then return end
 source.ix610ConversionAt=CurTime()+5
 local suffix=converts[source:GetClass():sub(#'npc_vj_scp_610_'+1)] or '2'
 local child=self:SpawnControlled('npc_vj_scp_610_'..suffix,victim:GetPos(),victim:GetAngles())
 if IsValid(child) and victim:IsNPC() then victim:Remove() end
end
function P:Adapt(ent)
 if not self:Is610(ent) then return end
 self.entities[ent]=true
 ent.HasHealthRegeneration=false;ent.HealthRegenerationAmount=0;ent.Immune_Fire=false
 if ent.ix610Adapted then return end
 ent.ix610Adapted=true;ent.ix610NextGrowth=CurTime()+self.settings.growthInterval
 ent.OnKilledEnemy=function(source,victim) P:ConvertVictim(source,victim) end
 local class=ent:GetClass()
 if self.growthClasses[class] then
  ent.OnThinkActive=function() end;ent.NextSpawnTime=math.huge
 end
 if class=='npc_vj_scp_610_biomass' or class=='npc_vj_scp_610_pillar' then
  ent.OnDeath=function(source,damage,hitgroup,status)
   if status~='Finish' or source.ix610DeathHandled then return end
   source.ix610DeathHandled=true
   if P.settings.deathSpawns and not P:IsSterilized(source) then
    P:SpawnControlled(class=='npc_vj_scp_610_biomass' and 'npc_vj_scp_610_8' or 'npc_vj_scp_610_1',source:GetPos())
   end
  end
 elseif class=='npc_vj_scp_610_6' then
  ent.CustomOnDeath_AfterCorpseSpawned=function(source,damage,hitgroup,corpse)
   if not P.settings.deathSpawns or P.settings.paused or P:IsSterilized(source) or not IsValid(corpse) then return end
   P.pending[corpse]={at=CurTime()+30,pos=corpse:GetPos(),class='npc_vj_scp_610_tripod'}
  end
 elseif class=='npc_vj_scp_610_tripod' then
  local killed=ent.CustomOnKilled
  ent.CustomOnKilled=function(source,...)
   if not P:IsSterilized(source) and killed then return killed(source,...) end
  end
 end
 -- Notify equipment independently of the optional death-spawn setting.
 -- VJ supplies the corpse here; never identify arbitrary props by their model.
 for _,callbackName in ipairs({'CustomOnDeath_AfterCorpseSpawned','OnCreateDeathCorpse'}) do
  local corpseCallback=ent[callbackName]
  ent[callbackName]=function(source,damage,hitgroup,corpse)
   hook.Run('SCP610CorpseCreated',source,corpse)
   if corpseCallback then return corpseCallback(source,damage,hitgroup,corpse) end
  end
 end
end
function P:TryGrowth(ent)
 if self.settings.paused or not self.settings.spreadEnabled or self:IsSterilized(ent) or ent.Dead or ent:Health()<=0 then return false end
 local childClass=self.growthClasses[ent:GetClass()];if not childClass or not self:CanSpawn(childClass) then return false end
 local now=CurTime();if now<(ent.ix610NextGrowth or 0) then return false end
 ent.ix610NextGrowth=now+self.settings.growthInterval
 local angle=math.Rand(0,math.pi*2);local distance=math.Rand(128,256)
 local origin=ent:GetPos();local point=origin+Vector(math.cos(angle)*distance,math.sin(angle)*distance,0)
 local tr=util.TraceLine({start=point+Vector(0,0,64),endpos=point-Vector(0,0,128),filter=ent,mask=MASK_SOLID_BRUSHONLY})
 if not tr.Hit or tr.HitSky or not tr.HitWorld or tr.HitNormal.z<.5 then return false end
 -- Prevent growth across walls and inside solid brushes or existing colonies.
 if util.TraceLine({start=origin+Vector(0,0,24),endpos=tr.HitPos+Vector(0,0,24),filter=ent,mask=MASK_SOLID_BRUSHONLY}).Hit then return false end
 local hull=util.TraceHull({start=tr.HitPos+Vector(0,0,8),endpos=tr.HitPos+Vector(0,0,8),mins=Vector(-24,-24,0),maxs=Vector(24,24,40),filter=ent,mask=MASK_SOLID})
 if hull.Hit or hull.StartSolid then return false end
 for other in pairs(self.entities) do if IsValid(other) and other:GetPos():DistToSqr(tr.HitPos)<96^2 then return false end end
 for _,patch in ipairs(self.scorched) do if patch.expires>now and patch.pos:DistToSqr(tr.HitPos)<192^2 then return false end end
 return IsValid(self:SpawnControlled(childClass,tr.HitPos+Vector(0,0,3)))
end
function P:EntityTakeDamage(target,damage)
 if self.pending[target] and (damage:IsDamageType(DMG_BURN) or damage:IsDamageType(DMG_SLOWBURN)) then self.pending[target]=nil end
 if not self:Is610(target) or damage:GetDamage()<=0 then return end
 self:Adapt(target);target.ix610DamagedAt=CurTime()
 if not damage:IsDamageType(DMG_BURN) and not damage:IsDamageType(DMG_SLOWBURN) then return end
 target.ix610Sterilized=true;target.HasHealthRegeneration=false
 damage:SetDamage(math.max(damage:GetDamage()*self.settings.fireMultiplier,math.max(target:GetMaxHealth(),1)*self.settings.fireHealthFraction))
 if not target.ix610ScorchRecorded then
  target.ix610ScorchRecorded=true
  if #self.scorched>=128 then table.remove(self.scorched,1) end
  self.scorched[#self.scorched+1]={pos=target:GetPos(),expires=CurTime()+120}
 end
end
function P:FlameTouch(projectile,target)
 if not IsValid(target) or not (target.ixInfectionFlora or self:Is610(target)) then return false end
 local owner=projectile:GetOwner();if target==owner then return true end
 local weapon=projectile.Weapon
 local range=IsValid(weapon) and (weapon.ARC9CODWW2FlameRange or 590.6) or 590.6
 if projectile.SpawnPosition and projectile:GetPos():DistToSqr(projectile.SpawnPosition)>range^2 then return true end
 if CurTime()<(target.ix610FlameAt or 0) then return true end
 target.ix610FlameAt=CurTime()+.2
 local damage=DamageInfo();damage:SetAttacker(IsValid(owner) and owner or game.GetWorld());damage:SetInflictor(IsValid(weapon) and weapon or projectile)
 damage:SetDamageType(DMG_BURN);damage:SetDamage(target.ixInfectionFlora and 60 or 12);target:TakeDamageInfo(damage)
 if IsValid(target) and self:Is610(target) and target:Health()>0 then
  target:Ignite(4,0);self.burns[target]={expires=CurTime()+4,next=CurTime()+.5,attacker=owner,weapon=weapon}
 end
 return true
end
function P:AdaptProjectile(ent)
 if not IsValid(ent) or ent.ix610FlameAdapter then return end
 ent.ix610FlameAdapter=true
 local original=ent.StartTouch
 ent.StartTouch=function(projectile,target)
  if P:FlameTouch(projectile,target) then projectile:Remove();return end
  if original then return original(projectile,target) end
 end
 -- Physical collisions can occur without a trigger touch against solid flora.
 local collide=ent.PhysicsCollide
 ent.PhysicsCollide=function(projectile,data,...)
  if IsValid(data.HitEntity) then P:FlameTouch(projectile,data.HitEntity) end
  if collide then return collide(projectile,data,...) end
 end
end
function P:OnEntityCreated(ent)
 timer.Simple(0,function()
  if not IsValid(ent) then return end
  if P:Is610(ent) then P:Adapt(ent)
  elseif ent:GetClass()=='arc9_codww2_flamethrower_fx' then P:AdaptProjectile(ent) end
 end)
end
function P:ControlTick()
 local now=CurTime();local budget=1
 for ent in pairs(self.entities) do
  if not IsValid(ent) then self.entities[ent]=nil else
   ent.HasHealthRegeneration=false
   if self.settings.regeneration>0 and not self:IsSterilized(ent) and not ent.Dead and ent:Health()>0 and now>(ent.ix610DamagedAt or 0)+20 then
    ent:SetHealth(math.min(ent:GetMaxHealth(),ent:Health()+self.settings.regeneration))
   end
   if budget>0 and self:TryGrowth(ent) then budget=budget-1 end
  end
 end
 for corpse,entry in pairs(self.pending) do
  if not IsValid(corpse) or self.settings.paused or not self.settings.deathSpawns or corpse:IsOnFire() then self.pending[corpse]=nil
  elseif now>=entry.at then
   self.pending[corpse]=nil
   if IsValid(self:SpawnControlled(entry.class,corpse:GetPos(),corpse:GetAngles())) then corpse:Remove() end
  end
 end
 for i=#self.scorched,1,-1 do if self.scorched[i].expires<=now then table.remove(self.scorched,i) end end
end
function P:BurnTick()
 local now=CurTime()
 for ent,burn in pairs(self.burns) do
  if not IsValid(ent) or ent.Dead or ent:Health()<=0 or ent:WaterLevel()>0 or now>=burn.expires then self.burns[ent]=nil
  elseif now>=burn.next then
   burn.next=now+.5
   local d=DamageInfo();d:SetDamage(5);d:SetDamageType(DMG_BURN);d:SetAttacker(IsValid(burn.attacker) and burn.attacker or game.GetWorld());d:SetInflictor(IsValid(burn.weapon) and burn.weapon or game.GetWorld());ent:TakeDamageInfo(d)
  end
 end
end
function P:SetPaused(value)
 self.settings.paused=value;self.pending={};self.revision=(self.revision+1)%2147483647;self:SaveData()
end
function P:Purge()
 self:SetPaused(true);self.burns={};local n=0
 for ent in pairs(self.entities) do if IsValid(ent) then ent:Remove();n=n+1 end end
 self.entities={};return n
end
function P:OpenControl(client)
 if not IsValid(client) or not client:IsAdmin() then return end
 local growth,npcs=self:Counts()
 net.Start('ix610Control');net.WriteTable(self.settings);net.WriteUInt(self.revision,31);net.WriteUInt(math.min(growth,65535),16);net.WriteUInt(math.min(npcs,65535),16);net.Send(client)
end
function P:UpdateSettings(client,data,revision)
 if not IsValid(client) or not client:IsAdmin() or not istable(data) then return false end
 if revision~=self.revision then client:Notify('Настройки изменены. Откройте панель заново.');return false end
 local nextSettings={}
 for key in pairs(self.settingRules) do local value=self:ValidateSetting(key,data[key]);if value==nil then return false end;nextSettings[key]=value end
 self.settings=nextSettings;self.revision=(self.revision+1)%2147483647
 if self.settings.paused or not self.settings.deathSpawns then self.pending={} end
 for ent in pairs(self.entities) do if IsValid(ent) then ent.ix610NextGrowth=CurTime()+self.settings.growthInterval end end
 self:SaveData();client:Notify('Параметры SCP-610 сохранены.');return true
end
net.Receive('ix610Save',function(bits,client)
 if bits>20000 or not client:IsAdmin() or CurTime()<(client.ix610WriteAt or 0) then return end
 client.ix610WriteAt=CurTime()+.5
 local raw=net.ReadString();if #raw>2000 then return end
 local data=util.JSONToTable(raw);P:UpdateSettings(client,data,net.ReadUInt(31))
end)
timer.Create('ix610ControlTick',1,0,function() P:ControlTick() end)
timer.Create('ix610BurnTick',.25,0,function() P:BurnTick() end)
timer.Simple(0,function() for _,ent in ipairs(ents.FindByClass('npc_vj_scp_610_*')) do P:Adapt(ent) end end)
