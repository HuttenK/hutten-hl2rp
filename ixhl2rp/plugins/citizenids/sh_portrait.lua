-- Portraits are stored on the physical item. Only registration writes this field.
function Schema:GetIdentityPortrait(item)
 local data=item and item:GetData("portrait")
 if not istable(data) or not isstring(data.model) or data.model=="" then return end
 return table.Copy(data)
end
if SERVER then
 function Schema:CaptureIdentityPortrait(item,character)
  local player=character and character:GetPlayer()
  if not IsValid(player) or player:GetCharacter()~=character then return false end
  local model=player:GetModel()
  if not isstring(model) or model=="" then return false end
  local groups={}
  for i=0,player:GetNumBodyGroups()-1 do groups[tostring(i)]=player:GetBodygroup(i) end
  item:SetData("portrait",{model=model,skin=player:GetSkin(),bodygroups=groups,registered=os.time()})
  return true
 end
end

-- Use the registered credential, never the owner's current player model.
function Schema:GetCredentialSnapshot(card)
 if not card or not card.isKeycard then return end
 local out={portrait=self:GetIdentityPortrait(card),level=card.clearanceLevel,department=card.departmentLabel,revoked=card:GetData("revoked",false)}
 for _,key in ipairs({"name","cid","number","position","site","callsign","issued","expires","authority","restrictions"}) do
  out[key]=string.sub(tostring(card:GetData(key,"")),1,128)
 end
 return out
end
