local F=ix.Fieldlink
-- Resolve the selected physical device, never an arbitrary PDA in the bag.
function F.DeviceItem(p)
 local c=IsValid(p) and p:GetCharacter()
 local id=c and c:GetData("fieldlinkDevice")
 if not id or not p.HasItemByID then return end
 local found,item=p:HasItemByID(id)
 if found and item and item.uniqueID=="pda" then return item end
end
function F.CardIdentity(card)
 if not card or not card.isKeycard or card:GetData("revoked",false) then return end
 local name=F.Text(card:GetData("name"),100)
 local cid=F.Text(tostring(card:GetData("cid","")),40)
 local serial=F.Text(card:GetData("number"),64)
 if not name or not cid or not serial or cid=="000-00" then return end
 return {id="cid:"..serial,name=name,cid=cid,serial=serial,card=card:GetID(),clearance=card.clearanceLevel,department=card.department}
end
function F.Identity(p)
 local item=F.DeviceItem(p)
 local saved=item and item:GetData("fieldlinkIdentity")
 -- Online-player lists also contain connecting players and unregistered devices.
 -- Neither can have a FIELDLINK identity, so do not query their equipment.
 if not istable(saved) or not saved.id then return end
 local card=IsValid(p) and p.GetIDCard and p:GetIDCard()
 local identity=F.CardIdentity(card)
 if identity and saved.id==identity.id then return identity end
end
function F.IdentityID(p)
 local identity=F.Identity(p)
 return identity and identity.id
end
function F.Clearance(p)
 local identity=F.Identity(p)
 return identity and math.Clamp(tonumber(identity.clearance) or 0,0,4) or 0
end
function F.CanReadIncident(p,record)
 return F.Identity(p) and (F.Clearance(p)>=2 or record.authorID==F.IdentityID(p)) or false
end
function F.CanResolve(p,record)
 return F.Identity(p) and (F.Clearance(p)>=3 or (F.Clearance(p)>=2 and record.ownerID==F.IdentityID(p))) or false
end
