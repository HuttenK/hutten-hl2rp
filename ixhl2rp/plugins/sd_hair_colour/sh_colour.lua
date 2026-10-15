ix.SDHair = ix.SDHair or {}
local H = ix.SDHair

H.presets = {
 {id="original", en="Original", ru="Исходный"},
 {id="black", en="Black", ru="Чёрный", rgb={30,28,26}},
 {id="darkbrown", en="Dark brown", ru="Тёмно-каштановый", rgb={65,43,32}},
 {id="brown", en="Brown", ru="Каштановый", rgb={105,70,45}},
 {id="blond", en="Blond", ru="Светлый", rgb={175,143,92}},
 {id="ginger", en="Ginger", ru="Рыжий", rgb={150,68,32}},
 {id="grey", en="Grey", ru="Седой", rgb={120,122,124}},
 {id="white", en="White", ru="Белый", rgb={210,210,205}}
}
H.byID = {}
for _, preset in ipairs(H.presets) do H.byID[preset.id] = preset end

function H.Supported(model)
 return isstring(model) and string.lower(model):match("^models/sd/citizens/citizen_[%a]+_%d+_hair%d+%.mdl$") ~= nil
end

function H.Valid(value)
 return isstring(value) and H.byID[value] ~= nil
end

function H.Saved(character)
 local value = character and character.GetSdHairColor and character:GetSdHairColor()
 return H.Valid(value) and value or "original"
end

ix.char.RegisterVar("sdHairColor", {
 bNoDisplay = true,
 field = "sd_hair_color", fieldType = ix.type.string, default = "original",
 Net = {Transmit = ix.transmit.all},
 OnValidate = function(self, value, payload, client)
  if value == nil then value = "original" end
  if not H.Valid(value) then return false, "unknownError" end
  local faction = ix.faction.indices[payload.faction]
  local models = faction and faction:GetModels(client, payload.gender) or {}
  local model = models[payload.model]
  if istable(model) then model = model[1] end
  return H.Supported(model) and value or "original"
 end
})

ix.command.Add("CharSetHairColor", {
 alias = "CharSetHairColour",
 description = "Изменить цвет волос персонажа: original, black, darkbrown, brown, blond, ginger, grey, white.",
 adminOnly = true,
 arguments = {ix.type.character, ix.type.string},
 OnRun = function(self, client, character, value)
  value = string.lower(string.Trim(value))
  value = ({blonde="blond", gray="grey", red="ginger", default="original"})[value] or value
  if not H.Valid(value) then
   return "Цвета: original, black, darkbrown, brown, blond, ginger, grey, white."
  end
  if not H.Supported(character:GetModel()) then return "У этого персонажа нет поддерживаемых SD-волос." end
  character:SetSdHairColor(value)
  character:Save()
  return "Цвет волос «" .. character:GetName() .. "»: " .. H.byID[value].ru .. "."
 end
})
