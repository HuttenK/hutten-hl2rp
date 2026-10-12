PLUGIN.name = "Sectorial District Character Creation"
PLUGIN.author = "Legends"
PLUGIN.description = "Validates and saves the selected SD model skin."

local function Count(client, payload)
 local faction = ix.faction.indices[payload.faction]
 if not faction or not faction.sdSkinCounts then return end
 local models = faction:GetModels(client, payload.gender) or {}
 local model = models[payload.model]
 if istable(model) then model=model[1] end
 return faction.sdSkinCounts[model], model
end

ix.char.RegisterVar("sdSkin", {
 bNoDisplay = true,
 field = "sd_skin", fieldType = ix.type.number, default = 0,
 Net = {Transmit = ix.transmit.all},
 OnValidate = function(self, value, payload, client)
  local count = Count(client, payload)
  value = value or 0
  if not count then return 0 end
  if not isnumber(value) or value ~= value or value % 1 ~= 0 or value < 0 or value >= count then
   return false, "unknownError"
  end
  return value
 end,
})
