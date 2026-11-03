PLUGIN.name = "Черты персонажа"
PLUGIN.author = "Hutten"
PLUGIN.description = "Пассивные черты с балансом очков при создании персонажа."
ix.util.Include("sh_catalog.lua")
ix.util.Include("sh_speech.lua")
ix.util.Include("sh_weapons.lua")
ix.util.Include("sv_effects.lua")
ix.util.Include("cl_creation.lua")
local T=ix.Traits
ix.char.RegisterVar("traits", {
 field="traits", fieldType=ix.type.text, default={}, bNoDisplay=true,
 Net={Transmit=ix.transmit.all},
 OnValidate=function(self,value)
  local clean,reason=T.Validate(value)
  if clean==false then return false,"traitInvalid",reason end
  return clean
 end,
 OnAdjust=function(self,client,data,value,newData)
  -- Also normalise the genetics here: validation order is not a contract.
  if istable(data.genetic) then data.genetic[2]=T.ClampHeight(data.genetic[2],data.traits) end
 end
})
ix.lang.AddTable("russian",{traitInvalid="%s"})
ix.lang.AddTable("english",{traitInvalid="%s"})

function PLUGIN:CharacterMaxStamina(character)
 if T.Has(character,"wheezing") then return 85 end
end
function PLUGIN:AdjustStaminaOffsetRunning(client,offset)
 local character=client:GetCharacter()
 local n=T.Modifier(character,"sprintDrain")
 if n~=1 then return offset*n end
end
function PLUGIN:PlayerSwitchWeapon(client,old,weapon)
 if IsValid(weapon) and not T.CanUseWeapon(client:GetCharacter(),weapon:GetClass()) then return true end
end
