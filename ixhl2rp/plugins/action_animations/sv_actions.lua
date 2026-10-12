local A=ix.ActionAnimations
function A.WaterSession(p)
 local W=ix.water
 local a=W and W.actions and W.actions[p]
 if not a or a.character~=p:GetCharacter() or not IsValid(a.entity) or not isvector(a.anchor)
  or not isnumber(a.started) or not isnumber(a.finish) or a.finish<=CurTime() or a.finish-a.started>3
  or a.finish<=a.started or (a.source~="sink" and a.source~="toilet") or W.Source(a.entity)~=a.source or not W.Near(p,a.entity) then return end
 for _,axis in ipairs({"x","y","z"}) do if a.anchor[axis]~=a.anchor[axis] or math.abs(a.anchor[axis])>4096 then return end end
 if a.kind=="fill" then
  local found=false
  for _,item in ipairs(W.Containers(p)) do if item==a.item then found=true;break end end
  if not found then return end
 elseif a.kind~="drink" and a.kind~="wash" then return end
 return a
end
-- These are accepted server sessions, never raw item clicks or client claims.
function A.Select(p)
 if not A.enabled or A.Conflict(p) then return "" end
 local medical=p.ixMedicalSession
 if medical and medical.emoteStarted and not medical.finishing and medical.character==p:GetCharacter()
  and ix.Medicine and ix.Medicine.ValidSession(p,medical) and A.WeaponAllows(p,"medical") then
  return "medical",medical.target
 end
 local held=p:GetLocalVar("holdingObject")
 if IsValid(held) and held:GetClass()=="ix_cargo_crate" and held.ixHeldOwner==p and A.WeaponAllows(p,"carry") then
  return "carry",held
 end
 local facility=ix.plugin.list.facility_utilities
 local work=facility and facility.work and facility.work[p]
 if work and facility:WorkValid(p,work) and A.WeaponAllows(p,"operate") then return "operate",work.entity end
 local water=A.WaterSession(p)
 if water and A.WeaponAllows(p,"wash") then
  return water.kind=="drink" and "waterdrink" or water.kind=="fill" and "waterfill" or "wash",water.entity,water
 end
 local decon=ix.plugin.list.decontamination
 local clean=decon and decon.actions and decon.actions[p]
 if clean and clean.character==p:GetCharacter() and IsValid(clean.entity) and clean.finish>CurTime() and A.WeaponAllows(p,"wash") then return "wash",clean.entity end
 if not A.WeaponAllows(p,"radio") then return "" end
 local voice=p.ixRadioVoice
 if voice and voice.character==p:GetCharacter() and voice.expires>CurTime() and p.inventories and ix.voice then
  local info=ix.voice.Transmission(p)
  if info and info.data.channelID==voice.channel then return "radio" end
 end
 if p.ixActionRadio and p.ixActionRadio.character==p:GetCharacter() and p.ixActionRadio.finish>CurTime() then return "radio" end
 local bodycam=p.ixActionBodycam
 if bodycam and bodycam.character==p:GetCharacter() and bodycam.finish>CurTime() and ix.bodycams
  and ix.bodycams.WornHelmet(p)==bodycam.helmet and ix.bodycams.Attached(bodycam.helmet)
  and ix.bodycams.Enabled(bodycam.helmet)==bodycam.enabled then return "bodycam" end
 return ""
end
hook.Add("BodycamStateChanged","ixActionBodycamSwitch",function(p,helmet,enabled)
 if not A.enabled or A.Conflict(p) or not A.WeaponAllows(p,"bodycam") or not ix.bodycams or ix.bodycams.WornHelmet(p)~=helmet then return end
 local current=A.Select(p)
 if current~="" and current~="bodycam" then return end
 -- Use the same humanoid chain as the client IK. Unsupported rigs still
 -- toggle their camera but never receive a broken full-body sequence.
 for _,name in ipairs({"Head1","Pelvis","L_UpperArm","L_Forearm","L_Hand","R_UpperArm","R_Forearm","R_Hand"}) do
  if not p.LookupBone or not p:LookupBone("ValveBiped.Bip01_"..name) then return end
 end
 p.ixActionBodycam={character=p:GetCharacter(),helmet=helmet,enabled=enabled,finish=CurTime()+1.15}
 A.Publish(p,"bodycam")
 p:SetNW2Float("ixContextActionStarted",CurTime())
end)
hook.Add("AdjustRadioTransmitEavesdroppers","ixActionRadioSent",function(info)
 if info.bShouldSend and not info.voice and IsValid(info.player) then
  info.player.ixActionRadio={character=info.player:GetCharacter(),finish=CurTime()+2.5}
 end
end)
function A.Publish(p,kind,target,water)
 if p:GetNW2String("ixContextAction","")~=kind then
  p:SetNW2String("ixContextAction",kind);p:SetNW2Float("ixContextActionStarted",CurTime())
 end
 target=IsValid(target) and target or NULL
 if p:GetNW2Entity("ixContextActionTarget")~=target then p:SetNW2Entity("ixContextActionTarget",target) end
 -- Network only data from a currently accepted server session. No client
 -- supplied point, model, duration or inventory identifier is accepted.
 if water then
  if p.ixContextWaterSession~=water then
   p:SetNW2Float("ixContextActionStarted",water.started)
   p:SetNW2Vector("ixContextActionAnchor",water.anchor)
  end
  p:SetNW2Float("ixContextActionFinish",water.finish)
 else p:SetNW2Float("ixContextActionFinish",0) end
 p.ixContextWaterSession=water
 local source=water and water.source or ""
 if p:GetNW2String("ixContextActionSource","")~=source then p:SetNW2String("ixContextActionSource",source) end
 -- Radio and water props are cosmetic copies of actual owned items.
 local model=""
 if kind=="radio" and p.inventories then
  local id=p:GetFirstAtSlot(1,1,"radio");local item=id and ix.Item.instances[id]
  if item and item.IsOn and item:IsOn() and isstring(item.model) then model=item.model end
 elseif kind=="waterfill" and water and water.item and water.item.GetModel then
  local value=water.item:GetModel()
  if isstring(value) and #value<=180 and value:lower():match("^models/[%w_%-./]+%.mdl$") and not value:find("..",1,true) then model=value end
 end
 if p:GetNW2String("ixContextActionProp","")~=model then p:SetNW2String("ixContextActionProp",model) end
end
timer.Create("ixContextActionSessions",.1,0,function()
 for _,p in ipairs(player.GetAll()) do
  local kind,target,water=A.Select(p)
  if kind~="bodycam" then p.ixActionBodycam=nil end
  A.Publish(p,kind,target,water)
 end
end)
hook.Add("WaterActionStarted","ixContextWaterStart",function(p)
 local kind,target,water=A.Select(p)
 if water then p.ixActionBodycam=nil;A.Publish(p,kind,target,water) end
end)
hook.Add("WaterActionEnded","ixContextWaterEnd",function(p)
 if IsValid(p) and p.ixContextWaterSession then
  local kind,target,water=A.Select(p);A.Publish(p,kind,target,water)
 end
end)
local function stop(p)
 p.ixActionRadio=nil;p.ixActionBodycam=nil
 if IsValid(p) then A.Publish(p,"") end
end
hook.Add("PlayerDeath","ixContextActionStop",stop)
hook.Add("PrePlayerLoadedCharacter","ixContextActionStop",stop)
hook.Add("PlayerDisconnected","ixContextActionStop",stop)
function A.Unload()
 timer.Remove("ixContextActionSessions")
 hook.Remove("AdjustRadioTransmitEavesdroppers","ixActionRadioSent")
 hook.Remove("BodycamStateChanged","ixActionBodycamSwitch")
 hook.Remove("WaterActionStarted","ixContextWaterStart");hook.Remove("WaterActionEnded","ixContextWaterEnd")
 for _,name in ipairs({"PlayerDeath","PrePlayerLoadedCharacter","PlayerDisconnected"}) do hook.Remove(name,"ixContextActionStop") end
 for _,p in ipairs(player.GetAll()) do stop(p) end
end
