ix.Fieldlink = ix.Fieldlink or {}
local F=ix.Fieldlink
F.class="pdaremake1"
F.alerts={"ШТАТНЫЙ РЕЖИМ","ПОВЫШЕННАЯ ГОТОВНОСТЬ","НАРУШЕНИЕ СОДЕРЖАНИЯ","ЭВАКУАЦИЯ"}
F.categories={"Наблюдение","Медицинская помощь","Безопасность","Техническая неисправность"}
function F.Text(value,limit)
 if type(value)~="string" or #value>limit*4 then return nil end
 value=string.Trim(value:gsub("[%z\1-\8\11\12\14-\31]",""))
 local ok,result=pcall(string.utf8sub,value,1,limit)
 if not ok or result=="" then return nil end
 return result
end
function F.Ready(client)
 if not IsValid(client) or not client:Alive() or not client:GetCharacter() or not client.HasItem or not client:HasItem("pda") then return false end
 if client:GetLocalVar("ragdoll",0)~=0 or not client:GetCharacter():GetData("fieldlinkEnabled",false) then return false end
 local w=client:GetActiveWeapon()
 if SERVER then
  local item=F.DeviceItem(client)
  if not item or not IsValid(w) or w.ixFieldlinkItem~=item:GetID() then return false end
 end
 if SERVER and IsValid(w) and w.ixFieldlinkCharacter~=client:GetCharacter():GetID() then return false end
 return IsValid(w) and w:GetClass()==F.class and w.GetPDAEquipped and w:GetPDAEquipped()
end
