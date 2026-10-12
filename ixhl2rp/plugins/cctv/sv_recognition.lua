local P,C=PLUGIN,ix.CCTV
local departments={security="Служба безопасности",military="Военный отдел",science="Научный отдел"}
function C.EquippedCardIdentity(p)
 -- GetIDCard reads the native cid inventory, not the bag or paired PDA.
 if not istable(p.inventories) or not p.GetInventory or not p:GetInventory("cid") or not p.GetIDCard or not ix.Item or not ix.Item.instances then return end
 local card=p:GetIDCard()
 if not card or not card.isKeycard or not card.GetData or card:GetData("revoked",false) then return end
 local name=C.IdentityText(card:GetData("name"),48)
 local cid=C.IdentityText(tostring(card:GetData("cid","")),40)
 local serial=C.IdentityText(card:GetData("number"),64)
 local department=departments[card.department]
 local level=card.clearanceLevel
 if not name or not cid or cid=="000-00" or not serial or not department or not C.Number(level,1,4) or level%1~=0 then return end
 return {name=name,department=department,level=level}
end
function P:RecognitionSnapshot(camera,origin,angles,fov)
 -- Called only from ResolveWatch after permission, power and lens checks.
 -- A short camera-local cache shares scans between multiple nearby viewers.
 local now=CurTime();local cached=camera.recognitionCache
 if cached and now-cached.at<C.recognition.interval then
  -- A moving bodycam must not starve viewers whose requests arrive just after
  -- somebody else's. Recheck at most eight cached candidates at THIS lens,
  -- and read their current cards; never replay a previous viewer's identity.
  local people={}
  for i,candidate in ipairs(cached.candidates or {}) do
   if i>C.recognition.limit then break end
   local p=candidate.player
   if IsValid(p) and p:IsPlayer() and p:UserID()==candidate.userid and C.VisibleFace(p,origin,angles,fov,camera.entity) then
    local identity=C.EquippedCardIdentity(p) or {name="НЕ ОПОЗНАН"}
    identity.entity=p:EntIndex();identity.userid=p:UserID();people[#people+1]=identity
   end
  end
  return {ttl=C.recognition.ttl,people=people}
 end
 local candidates={}
 for _,p in ipairs(player.GetAll()) do
  local box=C.VisibleFace(p,origin,angles,fov,camera.entity)
  if box then candidates[#candidates+1]={player=p,depth=box.depth} end
 end
 table.sort(candidates,function(a,b) return a.depth<b.depth end)
 local people,retained={},{}
 for i=1,math.min(#candidates,C.recognition.limit) do
  local p=candidates[i].player;local identity=C.EquippedCardIdentity(p) or {name="НЕ ОПОЗНАН"}
  identity.entity=p:EntIndex();identity.userid=p:UserID();people[#people+1]=identity
  retained[#retained+1]={player=p,userid=p:UserID()}
 end
 camera.recognitionCache={at=now,candidates=retained}
 return {ttl=C.recognition.ttl,people=people}
end
