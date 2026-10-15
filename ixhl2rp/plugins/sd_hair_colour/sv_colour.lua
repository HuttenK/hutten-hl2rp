local H = ix.SDHair

for _, family in ipairs({"haircurly", "haircurly2", "haircurly3", "hairlong01", "hairshaved", "hairshaved04", "hairshaved06", "hairshort01"}) do
 resource.AddFile("materials/models/hutten/sd_hair/" .. family .. ".vtf")
end

function H.Copy(source, target)
 if not IsValid(source) or not IsValid(target) then return end
 local value = source:IsPlayer() and H.Saved(source:GetCharacter()) or source:GetNetVar("sdHairColor", "original")
 target:SetNetVar("sdHairColor", H.Valid(value) and value or "original")
end

function H.Sync(client)
 if not IsValid(client) then return end
 client:SetNetVar("sdHairColor", H.Saved(client:GetCharacter()))
 -- Only the current living body's displays follow edits. Corpses retain the
 -- snapshot taken at creation, even after character switches or disconnects.
 local body = client.ixRagdoll
 if IsValid(body) and body.ixPlayer == client then H.Copy(client, body) end
 local cart = ix.PushCart and ix.PushCart:PatientCart(client)
 local display = IsValid(cart) and cart:GetNW2Entity("ixCartPatientDisplay")
 if IsValid(display) then H.Copy(client, display) end
end

hook.Add("CharacterVarChanged", "ixSDHairColour", function(character, key)
 if key ~= "sdHairColor" then return end
 local client = character:GetPlayer()
 if IsValid(client) and client:GetCharacter() == character then H.Sync(client) end
end)
hook.Add("PlayerLoadedCharacter", "ixSDHairColour", H.Sync)
hook.Add("PostPlayerLoadout", "ixSDHairColour", H.Sync)
hook.Add("OnCreatePlayerServerRagdoll", "ixSDHairColour", H.Copy)
hook.Add("OnCharacterCreated", "ixSDHairColour", function(_, character)
 -- Core inserts only the standard columns; persist the new choice immediately,
 -- including characters created and left in the menu before their first spawn.
 local query = mysql:Update("ix_characters")
 query:Update("sd_hair_color", H.Saved(character))
 query:Where("id", character:GetID())
 query:Execute()
end)
timer.Simple(0, function()
 for _, client in ipairs(player.GetAll()) do H.Sync(client) end
end)
