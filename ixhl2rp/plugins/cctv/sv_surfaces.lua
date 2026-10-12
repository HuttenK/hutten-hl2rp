local P,C=PLUGIN,ix.CCTV
function P:LoadSurfacePresets()
 self.surfacePresets={}
 local saved=ix.data.Get("foundation_cctv_presets_v1",{},false,true)
 for model,cfg in pairs(istable(saved) and saved or {}) do
  if C.PropModel(model) and C.SurfaceConfig(cfg) and table.Count(self.surfacePresets)<64 then self.surfacePresets[model]=C.SurfaceConfig(cfg) end
 end
end
function P:RestoreSurface(row)
 local binding=row.binding
 if row.kind~="terminal" or not C.ID(row.id) or self.devices[row.id] or not self:HasSpace("terminal")
  or not C.PropModel(row.model) or not C.SurfaceConfig(row.config) or not istable(binding) or not C.Vector(binding.pos) then return end
 self.devices[row.id]={id=row.id,kind="terminal",surface=true,name=C.Name(row.name) or "Экран CCTV",on=row.on~=false,
  model=row.model,config=C.SurfaceConfig(row.config),binding={pos=binding.pos,mapid=C.Number(binding.mapid,-1,1000000) and binding.mapid or -1}}
 self.nextID=math.max(self.nextID,row.id+1)
end
function P:PostLoadData()
 self:Ensure()
 local missing={}
 for id,d in pairs(self.devices) do
  if d.surface then
   local pos=C.Vector(d.binding and d.binding.pos);local ent
   local function matches(candidate)
    return C.SurfaceParent(candidate) and candidate:GetModel()==d.model
   end
   if d.binding and d.binding.mapid>=0 then ent=ents.GetMapCreatedEntity(d.binding.mapid) end
   if not matches(ent) then
    ent=nil
    if pos then for _,candidate in ipairs(ents.FindByModel(d.model)) do
     if matches(candidate) and candidate:GetPos():DistToSqr(pos)<16 then ent=candidate;break end
    end end
   end
   if IsValid(ent) then d.entity=ent;ix.PropScreens.Bind(ent,"ixCCTVSurfaceID",id) else missing[#missing+1]=id end
  end
 end
 -- All persistence plugins have now restored their props. Only the server
 -- removes missing bindings; a client's PVS updates must never delete them.
 for _,id in ipairs(missing) do self:DeleteRecord(id) end
 self.surfaceRestoring=false;self:SaveData();self:Sync()
end
function P:PlaceSurface(p,v)
 local cfg,ent=C.SurfacePlacement(p,p:GetEyeTrace())
 if not cfg then return false,"Наведите на поверхность prop не дальше 256 ед." end
 local d
 if v.id~=nil and v.id~=0 then
  if not C.ID(v.id) or not self.devices[v.id] or self.devices[v.id].kind~="terminal" then return false,"Пульт не найден." end
  d=self.devices[v.id]
 elseif not self:HasSpace("terminal") then return false,"Достигнут лимит экранов управления." end
 -- Additional screens start at the aimed spot instead of stacking onto the
 -- model's single saved preset. Each can still be calibrated independently.
 if v.preset==true and not ix.PropScreens.Occupied(ent) and self.surfacePresets and self.surfacePresets[ent:GetModel()] then cfg=table.Copy(self.surfacePresets[ent:GetModel()]) end
 if not d then
  d={id=self.nextID,kind="terminal",name="Экран CCTV "..self.nextID,on=true}
  self.nextID=self.nextID+1;self.devices[d.id]=d
 end
 local old,wasSurface=d.entity,d.surface
 if wasSurface then ix.PropScreens.Unbind(old,"ixCCTVSurfaceID",d.id) end
 d.surface=true;d.entity=ent;d.config=cfg;d.model=ent:GetModel()
 ix.PropScreens.Bind(ent,"ixCCTVSurfaceID",d.id)
 -- Move a legacy terminal's logical ID to the new prop, preserving links.
 -- Its OnRemove callback sees a different bound entity and leaves the ID alone.
 if not wasSurface and IsValid(old) and old~=ent then old:Remove() end
 self:SaveData();self:SendDevice(d)
 return true,"Экран установлен. Настройте размер и положение.",d.id
end
function P:SaveSurfacePreset(v)
 local d=self.devices[v.id];local cfg=C.SurfaceConfig(v.config)
 if not d or not d.surface or not cfg then return false,"Выберите экран и проверьте настройки." end
 self.surfacePresets=self.surfacePresets or {}
 if not self.surfacePresets[d.model] and table.Count(self.surfacePresets)>=64 then return false,"Максимум 64 пресета." end
 self.surfacePresets[d.model]=cfg
 ix.data.Set("foundation_cctv_presets_v1",self.surfacePresets,false,true)
 self:Sync();return true,"Размещение сохранено для этой модели."
end
function P:EntityRemoved(ent)
 if self.restoring or self.surfaceRestoring or self.stopping or ix.shuttingDown then return end
 local remove={}
 for id,d in pairs(self.devices or {}) do if d.surface and d.entity==ent then remove[#remove+1]=id end end
 for _,id in ipairs(remove) do self:DeleteRecord(id) end
end
function P:KeyPress(p,key)
 if key~=IN_USE or not self.devices or (p.ixCCTVUseAt or 0)>CurTime() then return end
 local target=ix.PropScreens.Aim(p,C.useDistance)
 if not target or target.kind~="cctv" then return end
 local d=target.row
 p.ixCCTVUseAt=CurTime()+.5
 if self:CanOperate(p,d.id) then self:SendOpen(p,"terminal",d.id) else p:Notify("Экран недоступен или обесточен.") end
end
function P:PlayerUse(p,ent)
 local target=IsValid(ent) and ix.PropScreens.Aim(p,C.useDistance)
 if target and target.kind=="cctv" and target.row.entity==ent then return false end
end
