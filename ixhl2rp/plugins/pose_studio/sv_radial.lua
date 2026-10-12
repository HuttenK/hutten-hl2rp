local P,S=PLUGIN,ix.PoseStudio
local names={Sit="Сесть",SitWall="У стены",Stand="Стоять",Cheer="Приветствие",Lean="Облокотиться",Injured="Ранение",
 Arrest="Руки за голову",Threat="Угроза",Deny="Отказ",Motion="Указать направление",Wave="Помахать",Pant="Отдышаться",Window="У окна"}
function P:PoseRadial(p,data)
 if not S.Finite(data.token,0,65535) then return end
 local mode=({own=true,shared=true})[data.mode] and data.mode or "root"
 local result={kind="radial",token=data.token,mode=mode,model=p:GetModel(),acts={},sits={},clips={},page=1,pages=1}
 if mode=="root" then
  for name,classes in pairs(ix.act and ix.act.stored or {}) do
   if ix.command.HasAccess(p,"Act"..name) then
    local variants=1
    for _,value in pairs(classes) do
     if istable(value) and istable(value.sequence) then variants=math.max(variants,#value.sequence) end
    end
    for variant=1,variants do
     if ix.act.Resolve(p,classes,variant) then
      result.acts[#result.acts+1]={name=name,variant=variant,label=(names[name] or name)..(variants>1 and " · "..variant or "")}
     end
    end
   end
  end
  table.sort(result.acts,function(a,b) return a.name==b.name and a.variant<b.variant or a.name<b.name end)
  local sit=ix.plugin.Get("sithelper")
  if sit then for i=1,24 do if sit:ResolvePose(p,i) then result.sits[#result.sits+1]=i end end end
 else
  local allowed=self:PoseAllowedProps(p)
  for _,record in pairs(self.poseStore.clips) do
   if mode=="own" and record.owner==p:SteamID64() or mode=="shared" and record.status=="approved" then
    local available,reason=S.ModelSupports(p,record.clip)
    if available then
     for _,prop in ipairs(record.clip.props) do
      if not allowed[prop.model] or not util.IsValidModel(prop.model) then
       available=false; reason="Нужен реквизит из инвентаря или разрешённого контента."; break
      end
     end
    end
    result.clips[#result.clips+1]={id=record.id,name=record.clip.name,portable=record.clip.portable,mask=record.clip.mask,
     available=available==true,reason=not available and reason or nil}
   end
  end
  table.sort(result.clips,function(a,b) return a.name==b.name and a.id<b.id or a.name<b.name end)
  result.pages=math.max(1,math.ceil(#result.clips/S.limit.page))
  local page=S.Finite(data.page,1,100000) and math.floor(data.page) or 1
  result.page=math.Clamp(page,1,result.pages)
  local visible={}
  for i=(result.page-1)*S.limit.page+1,math.min(result.page*S.limit.page,#result.clips) do visible[#visible+1]=result.clips[i] end
  result.clips=visible
 end
 self:PoseReply(p,result)
end
function P:RunStudioAct(p,data)
 if not S.Text(data.name,64) or not S.Finite(data.variant,1,64) or data.variant~=math.floor(data.variant) then return end
 local classes=ix.act and ix.act.stored[data.name]
 if not classes or not ix.command.HasAccess(p,"Act"..data.name) or not ix.act.Resolve(p,classes,data.variant) then return end
 self:StopPose(p)
 ix.command.Run(p,"Act"..data.name,{tostring(data.variant)})
end
