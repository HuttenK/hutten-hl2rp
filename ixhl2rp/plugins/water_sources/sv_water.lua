local P, W = PLUGIN, ix.water
W.actions = {}; W.menus = {}
util.AddNetworkString("ixWaterMenu")
util.AddNetworkString("ixWaterAction")
util.AddNetworkString("ixWaterChoose")
local kinds = {[1]="drink", [2]="fill", [3]="wash"}
local function sourceAnchor(p,e)
 -- Capture the actual server use trace before a popup can change the aim.
 -- Store entity-local coordinates so moved/rotated props retain the contact.
 local tr=p:GetEyeTrace()
 local point=tr.Entity==e and tr.HitPos or e:NearestPoint(p:GetShootPos())
 local anchor=e:WorldToLocal(point)
 local mins,maxs=e:OBBMins(),e:OBBMaxs()
 for _,axis in ipairs({"x","y","z"}) do
  if not isnumber(anchor[axis]) or anchor[axis]~=anchor[axis] or math.abs(anchor[axis])>4096 then return end
  anchor[axis]=math.Clamp(anchor[axis],mins[axis],maxs[axis])
 end
 return anchor
end
function W.Open(p, e, quiet)
 if not W.Near(p,e) or W.actions[p] or CurTime() < (p.ixWaterMenuAt or 0) then return end
 p.ixWaterMenuAt = CurTime()+.5
 local items = W.Containers(p)
 W.menus[p] = {entity=e, character=p:GetCharacter(), source=W.Source(e), anchor=sourceAnchor(p,e), expires=CurTime()+20}
 if quiet then return true end
 net.Start("ixWaterMenu"); net.WriteEntity(e); net.WriteBool(W.Source(e)=="toilet")
 net.WriteUInt(math.min(#items, 128), 8)
 for i=1, math.min(#items,128) do
  local item=items[i]; net.WriteUInt(item.id,32); net.WriteString(string.sub(item:GetName() or item.uniqueID,1,200))
  net.WriteUInt(math.min(math.floor(item.reagents.volume),65535),16); net.WriteUInt(math.min(math.floor(item.reagents.max_volume),65535),16)
 end
 net.Send(p)
end
function W.Choose(p,e,code,id,toilet)
 -- A client intention obtains and consumes the original single-use grant.
 if not kinds[code] or not W.Near(p,e) or (W.Source(e)=="toilet")~=(toilet==true) then return false end
 local start=p:GetShootPos()
 local tr=util.TraceLine({start=start,endpos=start+p:GetAimVector()*150,filter=p,mask=MASK_SOLID})
 if tr.Entity~=e then return false end
 if not W.Open(p,e,true) then return false end
 return W.Begin(p,e,code,id)
end
function W.Cancel(p, quiet)
 local a=W.actions[p]; W.actions[p]=nil
 if not a then return end
 hook.Run("WaterActionEnded",p,a.kind)
 if IsValid(p) and not quiet and not W.OtherActivity(p) then p:SetAction() end
end
function W.Begin(p,e,code,id)
 local menu=W.menus[p]; W.menus[p]=nil
 local kind=kinds[code]
 if not kind or not menu or menu.entity~=e or menu.character~=p:GetCharacter() or menu.expires<CurTime()
  or menu.source~=W.Source(e) or not W.Near(p,e) or W.actions[p] or CurTime()<(p.ixWaterActionAt or 0) then return false end
 if kind=="wash" and W.Source(e)=="toilet" then return false end
 local item
 if kind=="fill" then
  for _, candidate in ipairs(W.Containers(p)) do if candidate.id==id then item=candidate;break end end
  if not item then p:Notify("Выбранная ёмкость недоступна или уже наполнена.");return false end
 end
 p.ixWaterActionAt=CurTime()+2
 p:SetAction(kind=="drink" and "Пьёте воду..." or kind=="fill" and "Набираете воду..." or "Моете руки...",2)
 W.actions[p]={entity=e,character=p:GetCharacter(),source=menu.source,anchor=menu.anchor,kind=kind,item=item,started=CurTime(),finish=CurTime()+2}
 e:EmitSound("ambient/water/water_spray1.wav",55,100,.35)
 hook.Run("WaterActionStarted",p,kind,e,2)
 return true
end
function W.Tick()
 for p,a in pairs(W.actions) do
  if not IsValid(p) or p:GetCharacter()~=a.character or W.Source(a.entity)~=a.source or not W.Near(p,a.entity) then W.Cancel(p)
  elseif CurTime()>=a.finish then
   W.Cancel(p)
   if a.kind=="fill" then
    local found=false
    for _,item in ipairs(W.Containers(p)) do if item==a.item then found=true;break end end
    if found then
     a.item.reagents:AddReagent("water",a.item.reagents.max_volume-a.item.reagents.volume,300,true)
     a.item.reagents:UpdateTotal(true)
     ix.chat.Send(p,"me","набирает воду в «"..a.item:GetName().."».")
    else p:Notify("Наполнение отменено: ёмкость перемещена или её содержимое изменилось.") end
   elseif a.kind=="drink" then
    a.character:UpdateNeeds(20,0)
    -- Only direct toilet drinking has this risk. Collected water and ordinary
    -- sinks remain clean; do not reintroduce a harmful bottled reagent.
    if W.Source(a.entity)=="toilet" and p:Team()~=FACTION_VORTIGAUNT then
     a.character:SetRadLevel(a.character:GetRadLevel()+(math.random(1,2)==1 and 100 or 50))
    end
    ix.chat.Send(p,"me",W.Source(a.entity)=="toilet" and "пьёт воду из бачка." or "пьёт воду из-под крана.")
   else ix.chat.Send(p,"me","тщательно моет руки под проточной водой.") end
  end
 end
end
function P:PlayerUse(p,e)
 if W.Source(e) then W.Open(p,e); return false end
end
function P:PlayerActionChanged(p) W.Cancel(p,true) end
function P:PlayerDisconnected(p) W.Cancel(p,true); W.menus[p]=nil end
function P:PlayerLoadedCharacter(p) W.Cancel(p); W.menus[p]=nil end
function P:PlayerDeath(p) W.Cancel(p); W.menus[p]=nil end
function P:OnUnload() for p in pairs(W.actions) do W.Cancel(p) end; W.menus={};timer.Remove("ixWaterActions");hook.Remove("PlayerInitialSpawn","ixWaterRegistryInitial") end
net.Receive("ixWaterAction",function(bits,p)
 if bits>64 or CurTime()<(p.ixWaterNetAt or 0) then return end
 p.ixWaterNetAt=CurTime()+.2
 W.Begin(p,net.ReadEntity(),net.ReadUInt(2),net.ReadUInt(32))
end)
timer.Create("ixWaterActions",.1,0,W.Tick)
net.Receive("ixWaterChoose",function(bits,p)
 if bits>64 or CurTime()<(p.ixWaterNetAt or 0) then return end
 p.ixWaterNetAt=CurTime()+.2
 W.Choose(p,net.ReadEntity(),net.ReadUInt(2),net.ReadUInt(32),net.ReadBool())
end)
