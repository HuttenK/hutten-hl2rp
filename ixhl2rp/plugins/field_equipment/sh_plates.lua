local F = ix.field
ix.config.Add("platePistolHits",60,"Pistol/SMG hits to break one plate.",nil,{category="Equipment",data={min=1,max=300}})
ix.config.Add("plateRifleHits",30,"Rifle hits to break one plate.",nil,{category="Equipment",data={min=1,max=300}})
ix.config.Add("stabVestProtection",50,"Anti-stab melee damage reduction (%).",nil,{category="Equipment",data={min=0,max=100}})
function F.Capacity(item)
 if item.plateCapacity ~= nil then return item.plateCapacity end
 if item.armor and (item.equip_inv == "vest" or item.equip_inv == "torso") and
  not item.rad_resist and not string.find(item.uniqueID or "", "hazard", 1, true) then
  return item.armor.class >= 3 and 3 or (item.armor.class == 2 and 2 or 0)
 end
end
function F.Plates(item)
 local data=item:GetData("plates",{})
 local plates={}
 for i=1,(F.Capacity(item) or 0) do plates[i]=math.Clamp(tonumber(data[i]) or 0,-1,1) end
 return plates
end
function F.Count(item)
 local count=0
 for _, hp in ipairs(F.Plates(item)) do if hp>0 then count=count+1 end end
 return count
end
function F.Owns(p,item)
 return IsValid(p) and p:GetCharacter() and item and p:HasItemByID(item.id) and not IsValid(item:GetEntity())
end
function F.Wear(weapon)
 local ammo=string.lower(tostring(weapon and weapon.Primary and weapon.Primary.Ammo or ""))
 local hold=weapon and weapon.HoldType or ""
 if hold=="" and weapon and weapon.GetHoldType then hold=weapon:GetHoldType() end
 local pistol=hold=="pistol" or hold=="revolver" or hold=="smg" or
  ammo:find("pistol",1,true) or ammo:find("9x19",1,true) or ammo:find("9x18",1,true) or
  ammo:find("45acp",1,true) or ammo:find("smg",1,true)
 return 1/math.max(1,ix.config.Get(pistol and "platePistolHits" or "plateRifleHits",pistol and 60 or 30))
end
-- Return nil when the legacy helmet/limb armor system should handle this hit.
function F.Absorb(p,hit,info,amount)
 -- Vests cover torso and arms; head protection belongs to helmets.
 if hit==HITGROUP_HEAD or hit==HITGROUP_LEFTLEG or hit==HITGROUP_RIGHTLEG then return end
 local carrier
 for item,on in pairs(p.char_outfit and p.char_outfit.armor or {}) do
  if on and F.Capacity(item)~=nil and (not carrier or item.id<carrier.id) then carrier=item end
 end
 if not carrier then return end
 local cap=F.Capacity(carrier)
 local melee=info.class=="slash" or info.class=="club" or info.class=="fists"
 if cap==0 then
  if melee then return amount*(1-ix.config.Get("stabVestProtection",50)/100) end
  return
 end
 if info.class~="bullet" and info.class~="buckshot" and info.class~="impulse" then return end
 local count=F.Count(carrier)
 if count==0 then return end
 local reduced=amount*(1-count*.25)
 if count>0 and SERVER then
  -- Buckshot pellets from one shot must not burn through multiple plates.
  local token=tostring(info.attacker)..":"..tostring(engine.TickCount())
  carrier.ixPlateShot=carrier.ixPlateShot or {}
  if carrier.ixPlateShot.token~=token then
   carrier.ixPlateShot={token=token}
   local plates=F.Plates(carrier)
   for i,hp in ipairs(plates) do
    if hp>0 then
     local nextHP=hp-F.Wear(info.weapon)
     plates[i]=nextHP<=0.000001 and -1 or nextHP
     break
    end
   end
   carrier:SetData("plates",plates)
  end
 end
 return reduced
end

-- Padding keeps the existing limb-armor protection, with one plate's ballistic life.
function F.HasLimbPadding(player, hit)
 for item, equipped in pairs(player.char_outfit and player.char_outfit.armor or {}) do
  if equipped and item.limbPadding and item.armor and item.armor.coverage[hit] and item:GetData("value", 1)>0 then return true end
 end
 return false
end
function F.LimbPaddingWear(item, info, ordinaryWear)
 if not item.limbPadding or (info.class~="bullet" and info.class~="buckshot" and info.class~="impulse") then return ordinaryWear end
 local token=tostring(info.attacker)..":"..tostring(engine.TickCount())
 if item.ixPaddingShot==token then return 0 end
 item.ixPaddingShot=token
 return F.Wear(info.weapon)
end
