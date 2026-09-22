local F=ix.Fieldlink
-- Resolve the selected physical device, never an arbitrary PDA in the bag.
function F.DeviceItem(p)
 local c=IsValid(p) and p:GetCharacter()
 local id=c and c:GetData("fieldlinkDevice")
 if not id or not p.HasItemByID then return end
 local found,item=p:HasItemByID(id)
 if found and item and item.uniqueID=="pda" then return item end
end
function F.Identity(p)
 local item=F.DeviceItem(p)
 local identity=item and item:GetData("fieldlinkIdentity")
 if istable(identity) and isstring(identity.id) and identity.id:sub(1,4)=="cid:" and isstring(identity.name) then return identity end
end
function F.CardIdentity(card)
 if not card or card.equip_inv~="cid" or card:GetData("revoked",false) then return end
 local name=F.Text(card:GetData("name"),100)
 local cid=F.Text(tostring(card:GetData("cid","")),40)
 local serial=F.Text(card:GetData("number"),64)
 if not name or not cid or not serial then return end
 return {id="cid:"..serial,name=name,cid=cid,serial=serial,card=card:GetID()}
end
function F.IdentityID(p)
 local identity=F.Identity(p)
 return identity and identity.id
end
function F.Clearance(p)
 local identity=F.Identity(p)
 if not identity then return 0 end
 local plugin=ix.plugin.list.site_pda
 local registry=plugin and plugin.state and plugin.state.clearances or {}
 local value=tonumber(registry[tostring(identity.id)] or identity.clearance) or 0
 if value~=value then return 0 end
 return math.Clamp(math.floor(value),0,4)
end
function F.CanReadIncident(p,record)
 return F.Identity(p) and (F.Clearance(p)>=2 or record.authorID==F.IdentityID(p)) or false
end
function F.CanResolve(p,record)
 return F.Identity(p) and (F.Clearance(p)>=3 or (F.Clearance(p)>=2 and record.ownerID==F.IdentityID(p))) or false
end
