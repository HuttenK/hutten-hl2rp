local P,T=PLUGIN,ix.TV
local function position(v) if v then return {x=v.x,y=v.y,z=v.z} end end
for _,name in ipairs({"ixTVResetState","ixTVChannel","ixTVScreen","ixTVPreset","ixTVReady","ixTVAction","ixTVReply","ixTVOpen"}) do util.AddNetworkString(name) end
local function transmit(name,data,target)
 net.Start(name);net.WriteString(util.TableToJSON(data))
 if IsValid(target) then net.Send(target) else net.Broadcast() end
end
function P:SaveTV()
 local screens={}
 for id,s in pairs(self.screens) do
  -- Do not copy an engine entity into persistent data.
  local copy={}
  for k,v in pairs(s) do if k~="entity" and k~="entityIndex" then copy[k]=v end end
  copy.origin=position(s.origin)
  if IsValid(s.entity) then
   s.binding={mapid=s.entity:MapCreationID(),pos=position(s.entity:GetPos())}
   copy.binding=s.binding
  end
  screens[id]=copy
 end
 ix.data.Set("tv_network_v3",{channels=self.channels,screens=screens,nextScreen=self.nextScreen,legacyImported=self.legacyImported})
 ix.data.Set("tv_model_presets_v3",self.presets,false,true)
end
function P:Initialize()
 if self.tvInitialized then return end
 self.tvInitialized=true
 for _,s in pairs(self.screens or {}) do ix.PropScreens.Unbind(s.entity,"ixTVScreenID",s.id) end
 self.channels={};self.screens={};self.nextScreen=1
 self.presets={[T.defaultModel]=table.Copy(T.defaultConfig)}
 local presets=ix.data.Get("tv_model_presets_v3",{},false,true)
 if istable(presets) then
  for model,c in pairs(presets) do
   if T.Model(model) and T.Config(c) and (self.presets[model] or table.Count(self.presets)<64) then self.presets[model]=T.UpgradeConfig(model,c) end
  end
 end
 local saved=ix.data.Get("tv_network_v3",{})
 if not istable(saved) then saved={} end
 self.legacyImported=saved.legacyImported==true
 for id=1,T.maxChannels do
  local c=istable(saved.channels) and (saved.channels[id] or saved.channels[tostring(id)])
  if istable(c) and T.Text(c.name,48) then
   local fresh=T.Channel(id,T.Text(c.name,48))
   fresh.source=T.Source(c.source,true) and c.source or ""
   fresh.sound=T.Source(c.sound,true) and c.sound or ""
   fresh.subtitles=T.Subtitles(c.subtitles) and c.subtitles or ""
   fresh.loop=c.loop==true;fresh.soundLoop=c.soundLoop==true
   fresh.volume=T.Number(c.volume,0,1) and c.volume or 1
   self.channels[id]=fresh
  end
 end
 if not next(self.channels) then
  for id,name in ipairs({"Общий эфир","Персонал","Класс D","Брифинг"}) do self.channels[id]=T.Channel(id,name) end
  local old=ix.data.Get("tv_material","")
  self.channels[1].source=old~="vgui/white" and T.Source(old,true) and old or ""
  local sound=ix.data.Get("tv_sound","");self.channels[1].sound=T.Source(sound,true) and sound or ""
  local captions=ix.data.Get("tv_subtitles","");self.channels[1].subtitles=T.Subtitles(captions) and captions or ""
  self.channels[1].loop=ix.data.Get("tv_loop",false)==true
  local oldConfig=ix.data.Get("tv_config",{})
  local c=istable(oldConfig) and oldConfig[T.defaultModel]
  if istable(c) then
   local a=Angle();a:RotateAroundAxis(a:Forward(),tonumber(c.roll) or 0);a:RotateAroundAxis(a:Right(),tonumber(c.pitch) or 270);a:RotateAroundAxis(a:Up(),tonumber(c.yaw) or 90)
   local migrated=T.Config({x=c.forwardOffset,y=c.rightOffset or 0,z=c.upOffset,p=math.NormalizeAngle(a.p),yaw=math.NormalizeAngle(a.y),r=math.NormalizeAngle(a.r),w=c.width,h=c.height})
   if migrated then self.presets[T.defaultModel]=T.UpgradeConfig(T.defaultModel,migrated) end
  end
 end
 self.channels[1]=self.channels[1] or T.Channel(1,"Общий эфир")
 local count=0
 for id,s in pairs(istable(saved.screens) and saved.screens or {}) do
  id=tonumber(id)
  if id and id%1==0 and id>0 and id<1000000 and count<T.maxScreens and istable(s) and T.Config(s.config)
   and ((s.world==true and T.Position(s.origin)) or T.Model(s.model)) then
   s.id=id;s.config=T.UpgradeConfig(s.world and "" or s.model,s.config);s.entity=nil;s.entityIndex=nil
   s.name=T.Text(s.name,48) or ("Экран "..id);s.channel=self.channels[s.channel] and s.channel or 1
   s.on=s.on~=false;s.world=s.world==true
   s.origin=s.world and T.Position(s.origin) or nil
   self.screens[id]=s;self.nextScreen=math.max(self.nextScreen,id+1);count=count+1
  end
 end
 self.nextScreen=math.max(self.nextScreen,T.Number(saved.nextScreen,1,1000000) and math.floor(saved.nextScreen) or 1)
 file.CreateDir("ix_tv_subtitles")
end
function P:LoadData()
 self.tvRestoring=true;self.tvBindingsReady=false
 self:Initialize()
end
function P:PostLoadData()
 -- Helix persistence restores props during LoadData; resolve their bindings
 -- only after every plugin has completed that phase.
 self:Initialize()
 for _,s in pairs(self.screens) do
  local boundPos=istable(s.binding) and T.Position(s.binding.pos)
  if not s.world and boundPos then
   local ent=s.binding.mapid and s.binding.mapid>=0 and ents.GetMapCreatedEntity(s.binding.mapid)
   if not IsValid(ent) or ent:GetModel()~=s.model then
    ent=nil
    for _,candidate in ipairs(ents.FindByModel(s.model)) do
     if candidate:GetPos():DistToSqr(boundPos)<16 then ent=candidate;break end
    end
   end
   if IsValid(ent) then s.entity=ent;ix.PropScreens.Bind(ent,"ixTVScreenID",s.id) end
  end
 end
 self.tvRestoring=false;self.tvCleaningUp=false;self.tvBindingsReady=true
 self:PruneMissingScreens()
 if self:DiscoverLegacy() then self:SaveTV() end
 self:Sync()
end
function P:DiscoverLegacy()
 -- Import old automatic TVs once. A removed screen must stay removed after
 -- restart; new props can be explicitly registered with the placement tool.
 if self.legacyImported then return false end
 self.legacyImported=true
 for _,ent in ipairs(ents.FindByModel(T.defaultModel)) do
  local known=false
  for _,s in pairs(self.screens) do if s.entity==ent then known=true;break end end
  if not known and table.Count(self.screens)<T.maxScreens and ent:GetClass()~="ix_item" and not ent.CCTVKind and ent:GetNW2Int("ixCCTVSurfaceID",0)==0 then
   self:AddScreen({entity=ent,model=T.defaultModel,config=table.Copy(self.presets[T.defaultModel]),channel=1,on=true,name="Телевизор",world=false})
  end
 end
 return true
end
function P:AddScreen(s)
 s.id=self.nextScreen;self.nextScreen=self.nextScreen+1;self.screens[s.id]=s
 if IsValid(s.entity) then ix.PropScreens.Bind(s.entity,"ixTVScreenID",s.id) end
 return s
end
function P:RemoveScreen(id)
 local s=self.screens and self.screens[id];if not s then return false end
 ix.PropScreens.Unbind(s.entity,"ixTVScreenID",id)
 self.screens[id]=nil
 transmit("ixTVScreen",{id=id,removed=true})
 return true
end
function P:PruneMissingScreens()
 if not self.tvBindingsReady or self.tvRestoring or self.tvCleaningUp or self.tvShuttingDown then return end
 local changed=false
 for id,s in pairs(self.screens) do
  if not s.world and not IsValid(s.entity) then self:RemoveScreen(id);changed=true end
 end
 if changed then self:SaveTV() end
end
function P:EntityRemoved(ent)
 -- Server-side identity check: client PVS/full updates are not deletions.
 if not self.tvInitialized or self.tvRestoring or self.tvCleaningUp or self.tvShuttingDown then return end
 local changed=false
 for id,s in pairs(self.screens) do
  if not s.world and s.entity==ent then self:RemoveScreen(id);changed=true end
 end
 if changed then self:SaveTV() end
end
function P:PreCleanupMap()
 -- Helix restores persistent props in LoadData, then we rebind in PostLoadData.
 self.tvCleaningUp=true;self.tvBindingsReady=false
 if self.tvInitialized then self:SaveTV() end
end
function P:ShutDown() self.tvShuttingDown=true end
function P:SendChannel(c,target) transmit("ixTVChannel",c,target) end
function P:SendScreen(s,target)
 local out={id=s.id,name=s.name,channel=s.channel,on=s.on,world=s.world,origin=position(s.origin),model=s.model,config=s.config,entityIndex=IsValid(s.entity) and s.entity:EntIndex() or 0}
 transmit("ixTVScreen",out,target)
end
function P:Sync(target)
 self:PruneMissingScreens()
 net.Start("ixTVResetState");if IsValid(target) then net.Send(target) else net.Broadcast() end
 for _,c in pairs(self.channels) do self:SendChannel(c,target) end
 for _,s in pairs(self.screens) do self:SendScreen(s,target) end
 for model,c in pairs(self.presets) do transmit("ixTVPreset",{model=model,config=c},target) end
end
function P:OpenControls(p,place,screen)
 self:Initialize();self:Sync(p)
 net.Start("ixTVOpen");net.WriteBool(place==true);net.WriteUInt(screen or 0,20);net.Send(p)
end
function P:Action(p,action,d)
 if not IsValid(p) or not p:IsPlayer() or not p:IsAdmin() then return false,"Только для администрации." end
 self:Initialize()
 if not istable(d) then return false,"Неверные данные." end
 local c=self.channels[tonumber(d.channel)]
 if action=="createChannel" then
  local name=T.Text(d.name,48);if not name then return false,"Введите название канала (до 48 символов)." end
  for id=1,T.maxChannels do if not self.channels[id] then
   c=T.Channel(id,name);self.channels[id]=c;self:SaveTV();self:SendChannel(c);return true,"Канал создан."
  end end
  return false,"Максимум 8 каналов."
 elseif action=="place" then
  if not c then return false,"Выберите канал." end
  local trace=p:GetEyeTrace()
  if not trace.Hit or trace.HitPos:DistToSqr(p:GetShootPos())>512*512 then return false,"Подойдите к поверхности (до 512 ед.)." end
  local cfg,world,ent=T.SurfaceConfig(trace)
  if not cfg then return false,"Выберите стену или модель." end
  if table.Count(self.screens)>=T.maxScreens or self.nextScreen>=1000000 then return false,"Достигнут лимит экранов." end
  if not world and d.preset==true and not ix.PropScreens.Occupied(ent) and self.presets[ent:GetModel()] then cfg=table.Copy(self.presets[ent:GetModel()]) end
  local s=self:AddScreen({name="Экран "..self.nextScreen,on=true})
  s.channel=c.id;s.world=world;s.entity=not world and ent or nil;s.model=not world and ent:GetModel() or nil;s.config=cfg
  s.origin=world and (trace.HitPos+trace.HitNormal*.35) or nil
  if IsValid(s.entity) then ix.PropScreens.Bind(s.entity,"ixTVScreenID",s.id) end
  self:SaveTV();self:SendScreen(s);return true,"Экран размещён. Выберите его для точной настройки.",s.id
 elseif action=="screen" or action=="removeScreen" or action=="preset" then
  local s=self.screens[tonumber(d.screen)];if not s then return false,"Экран не найден." end
  if action=="removeScreen" then
   self:RemoveScreen(s.id);self:SaveTV();return true,"Экран удалён."
  end
  local cfg=T.Config(d.config)
  if not cfg then return false,"Проверьте размеры и положение экрана." end
  if action=="preset" then
   if s.world or not T.Model(s.model) then return false,"Пресет доступен только для модели." end
   if not self.presets[s.model] and table.Count(self.presets)>=64 then return false,"Максимум 64 пресета." end
   self.presets[s.model]=cfg;self:SaveTV();transmit("ixTVPreset",{model=s.model,config=cfg})
   return true,"Пресет сохранён для следующего размещения на этой модели."
  end
  local name=T.Text(d.name,48);if not name or not c then return false,"Введите имя экрана и выберите канал." end
  s.config=cfg;s.name=name;s.channel=c.id;s.on=d.on==true
  self:SaveTV();self:SendScreen(s);return true,"Экран сохранён."
 end
 if not c then return false,"Канал не найден." end
 if action=="rename" then
  local name=T.Text(d.name,48);if not name then return false,"Введите название канала." end;c.name=name
 elseif action=="deleteChannel" then
  if c.id==1 then return false,"Общий канал нельзя удалить." end
  for _,s in pairs(self.screens) do if s.channel==c.id then return false,"Сначала переведите экраны на другой канал." end end
  self.channels[c.id]=nil;self:SaveTV();transmit("ixTVChannel",{id=c.id,removed=true});return true,"Канал удалён."
 elseif action=="play" then
  if not T.Source(d.source,false) then return false,"Нужен прямой URL файла или материал. Страницы YouTube/Twitch не поддерживаются." end
  if c.source~=d.source then c.subtitles="" end
  c.source=d.source;c.playing=true;c.start=ix.BroadcastMedia.StartTime(c.start);c.soundStart=c.start;c.revision=c.revision+1
 elseif action=="stop" then c.playing=false;c.revision=c.revision+1
 elseif action=="loop" then c.loop=d.value==true
 elseif action=="volume" then
  if not T.Number(d.value,0,1) then return false,"Громкость: от 0 до 100%." end;c.volume=d.value
 elseif action=="sound" then
  if not T.Source(d.source,true) then return false,"Неверная звуковая ссылка." end
  c.sound=d.source;c.soundLoop=d.loop==true;c.soundStart=ix.BroadcastMedia.StartTime(c.soundStart)
  if c.sound~="" then c.playing=true end
 elseif action=="captions" then
  local name=d.file
  if name=="off" then c.subtitles=""
  else
   if not isstring(name) or not name:match("^[%w_-]+%.[%w]+$") or not (name:lower():match("%.srt$") or name:lower():match("%.vtt$")) then return false,"Имя файла SRT/VTT из data/ix_tv_subtitles/." end
   local path="ix_tv_subtitles/"..name;local size=file.Size(path,"DATA")
   if size<0 or size>48000 then return false,"Файл не найден или больше 48 КБ." end
   local raw=file.Read(path,"DATA");local cues=ix.BroadcastMedia.ParseSubtitles(raw)
   if not cues or not T.Subtitles(raw) then return false,"Не удалось прочитать субтитры или слишком большой объём после кодирования." end
   c.subtitles=raw
  end
 else return false,"Неизвестное действие." end
 self:SaveTV();self:SendChannel(c);return true,"Канал «"..c.name.."» обновлён."
end
net.Receive("ixTVReady",function(bits,p)
 if bits~=0 or (p.ixTVReadyAt or 0)>CurTime() then return end
 p.ixTVReadyAt=CurTime()+3;P:Initialize();P:Sync(p)
end)
net.Receive("ixTVAction",function(bits,p)
 if bits>70000 or not p:IsAdmin() or (p.ixTVActionAt or 0)>CurTime() then return end
 p.ixTVActionAt=CurTime()+.15
 local action,raw=net.ReadString(),net.ReadString()
 if #action>32 or #raw>8192 then return end
 local ok,message,id=P:Action(p,action,util.JSONToTable(raw))
 transmit("ixTVReply",{ok=ok,message=message,screen=id},p)
end)
function P:KeyPress(p,key)
 if key~=IN_USE or not self.screens or (p.ixTVUseAt or 0)>CurTime() then return end
 local target=ix.PropScreens.Aim(p,220);if not target or target.kind~="tv" then return end
 local s=target.row
 p.ixTVUseAt=CurTime()+.4
 if p:IsAdmin() and not p:KeyDown(IN_SPEED) then self:OpenControls(p,false,s.id);return end
 s.on=not s.on;self:SendScreen(s);self:SaveTV()
end
function P:PlayerUse(p,ent)
 if not self.screens then return end
 local target=ix.PropScreens.Aim(p,220)
 if target and target.kind=="tv" and target.row.entity==ent then return false end
end
function P:SaveData() if self.tvInitialized then self:SaveTV() end end

