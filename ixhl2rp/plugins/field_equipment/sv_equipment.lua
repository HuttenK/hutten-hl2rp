local F=ix.field
for _,name in ipairs({"ixPlateInspect","ixPlateChange","ixFieldAnim"}) do util.AddNetworkString(name) end
function F.Inspect(p,item)
 if not F.Owns(p,item) or F.Capacity(item)==nil then return end
 net.Start("ixPlateInspect")
 net.WriteUInt(item.id,32); net.WriteUInt(F.Capacity(item),2)
 for _,hp in ipairs(F.Plates(item)) do net.WriteFloat(hp) end
 net.Send(p)
end
function F.ChangePlate(p,item,slot,insert)
 if not F.Owns(p,item) or not p:Alive() or p:InCriticalState() or p:IsRestricted() then return false end
 local cap=F.Capacity(item)
 if not cap or slot<1 or slot>cap or slot~=math.floor(slot) then return false end
 local plates=F.Plates(item)
 if insert then
  if plates[slot]>0 then return false end
  local plate
  for _,candidate in ipairs(p:GetItems()) do
   if candidate.uniqueID=="mat_armor_plate" and F.Owns(p,candidate) then plate=candidate; break end
  end
  if not plate then p:Notify("Нужна бронепластина в инвентаре."); return false end
  plates[slot]=math.Clamp(tonumber(plate:GetData("plateHealth",1)) or 1,.001,1)
  plate:Remove(true)
 else
  if plates[slot]==0 then return false end
  if plates[slot]>0 then
   local plate=ix.Item:Instance("mat_armor_plate")
   plate:SetData("plateHealth",plates[slot])
   local success=p:AddItem(plate)
   if not success then plate:Remove(true); p:Notify("Нет места для пластины."); return false end
  end
  plates[slot]=0
 end
 item:SetData("plates",plates)
 return true
end
net.Receive("ixPlateChange",function(_,p)
 local id=net.ReadUInt(32); local slot=net.ReadUInt(2); local insert=net.ReadBool()
 if (p.ixPlateNext or 0)>CurTime() then return end
 p.ixPlateNext=CurTime()+.25
 local item=ix.Item.instances[id]
 F.ChangePlate(p,item,slot,insert); F.Inspect(p,item)
end)
function F.Animate(p,name)
 if not IsValid(p) then return end
 if ix.Downed and ix.Downed.Crawling and ix.Downed.Crawling(p) then return end
 p.ixFieldAnimAt=CurTime()
 net.Start("ixFieldAnim"); net.WriteString(name); net.Send(p)
end
hook.Add("OnItemEquipped","ixFieldGlasses",function(p,item)
 if item.equip_inv=="glasses" and not item.nvgType then F.Animate(p,"nvg_aviators_in") end
end)
hook.Add("OnItemUnequipped","ixFieldGlasses",function(p,item)
 if item.equip_inv=="glasses" and not item.nvgType then F.Animate(p,"nvg_aviators_out") end
end)
hook.Add("PlayerPickedUpInventoryItem","ixFieldPickup",function(p) F.Animate(p,"ix_field_pickup") end)

function F.NVG(p)
 if not IsValid(p) or not p:GetCharacter() then return end
 local id=p:GetFirstAtSlot(1,1,"glasses")
 local item=id and ix.Item.instances[id]
 if item and item.nvgType and item:IsEquipped() then return item end
end
-- Replace the addon's unrestricted receiver with inventory validation.
net.Receive("arcticnvgs_toggle",function(_,p)
 local on=net.ReadBool()
 if not on then p:SetNWBool("nvg_on",false); return end
 local item=F.NVG(p)
 if not item or not p:Alive() or p:InCriticalState() or p:IsRestricted() then return end
 if (p.ixNVGNext or 0)>CurTime() then return end
 p.ixNVGNext=CurTime()+.3
 p:SetNWBool("nvg_on",true)
end)
function F.SetNVG(p,item,on)
 local id=on and ArcticNVGs_ShortNameToID and ArcticNVGs_ShortNameToID[item.nvgType] or 0
 p:SetNWInt("nvg",id or 0); p:SetNWBool("nvg_on",false)
 F.Animate(p,on and ("equip:"..item.nvgType) or ("remove:"..item.nvgType))
end
local function clear(p)
 if not IsValid(p) then return end
 p:SetNWBool("nvg_on",false); p:SetNWInt("nvg",0)
end
hook.Add("PlayerDeath","ixFieldNVGDeath",clear)
hook.Add("PlayerLoadedCharacter","ixFieldNVGCharacter",clear)
timer.Create("ixFieldNVGValidate",.5,0,function()
 for _,p in ipairs(player.GetAll()) do
  local item=F.NVG(p)
  if not item or not p:Alive() or p:InCriticalState() then
   if p:GetNWInt("nvg",0)~=0 then clear(p) end
  elseif ArcticNVGs_ShortNameToID then
   local id=ArcticNVGs_ShortNameToID[item.nvgType] or 0
   if p:GetNWInt("nvg",0)~=id then p:SetNWInt("nvg",id) end
  end
 end
end)

