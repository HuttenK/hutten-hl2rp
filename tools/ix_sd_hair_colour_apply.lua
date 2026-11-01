if SERVER then return end
if not (ix and ix.SDHair and ix.SDHair.Valid) then
 print("[SD colour] Hair colour plugin is not loaded. Update the server gamemode first.")
 return
end
print("[SD colour] Applying corrected hair transparency...")
do
local H = ix.SDHair
if H.Clear then H.Clear() end

local prefix = "models/sectorialdistrict/citizens/"
local families = {
 haircurly={"haircurly", "haircurly_black", "haircurly_white"},
 haircurly2={"haircurly2", "haircurly2_black", "haircurly2_white"},
 haircurly3={"haircurly3", "haircurly3_black", "haircurly3_white"},
 hairlong01={"hairlong01", "hairlong01_black", "hairlong01_blonde", "hairlong01_red"},
 hairshaved={"hairshaved", "hairshaved_black", "hairshaved_white"},
 hairshaved04={"hairshaved04"},
 hairshaved06={"hairshaved06", "hairshaved06_black"},
 hairshort01={"hairshort01", "hairshort01_black", "hairshort01_blonde", "hairshort01_gray", "hairshort01_red", "hairshort01_white"}
}
local familyByMaterial = {}
for family, names in pairs(families) do
 for _, name in ipairs(names) do familyByMaterial[prefix .. name] = family end
end
local models, materials = {}, {}
local states, tracked = setmetatable({}, {__mode="k"}), setmetatable({}, {__mode="k"})
local enabled = true
local sourceFlags = {
 ["$alphatest"]=256, ["$nocull"]=8192, ["$translucent"]=2097152,
 ["$nodecal"]=67108864, ["$allowalphatocoverage"]=536870912
}

local function Normalize(name)
 return string.lower(name):gsub("\\", "/"):gsub("%.vmt$", "")
end

local function Slots(entity)
 local model = entity:GetModel()
 if models[model] then return models[model] end
 local slots = {}
 for index, name in ipairs(entity:GetMaterials()) do
  name = Normalize(name)
  if familyByMaterial[name] then slots[index-1] = name end
 end
 -- Do not cache an empty list while a networked model is still loading.
 if next(slots) then models[model] = slots end
 return slots
end

function H.Material(name, colour)
 local family, preset = familyByMaterial[name], H.byID[colour]
 if not family or not preset or not preset.rgb then return end
 local key = name .. ":" .. colour
 if materials[key] then return materials[key] end
 local source = Material(name)
 if source:IsError() or string.lower(source:GetShader()) ~= "vertexlitgeneric" then return end
 local neutral = "models/hutten/sd_hair/" .. family
 if not file.Exists("materials/" .. neutral .. ".vtf", "GAME") then return end
 -- Keep the source's alpha cutoff, normal map and strand detail. Each family
 -- uses one neutral atlas, retaining its UV layout and authored strand cutouts.
 local params = { ["$basetexture"]=neutral, ["$model"]=1, ["$phong"]=0, ["$color2"]="[1 1 1]" }
 -- These switches are packed into $flags by Source. GetFloat("$alphatest")
 -- returns nil, so copying them as ordinary parameters loses the cutouts.
 local flags = source:GetInt("$flags") or 0
 for key, mask in pairs(sourceFlags) do
  params[key] = bit.band(flags, mask) ~= 0 and "1" or "0"
 end
 for _, key in ipairs({"$alphatestreference", "$detailscale", "$detailblendmode", "$detailblendfactor"}) do
  local value = source:GetFloat(key)
  if value ~= nil then params[key] = tostring(value) end
 end
 for _, key in ipairs({"$bumpmap", "$detail"}) do
  local texture = source:GetTexture(key)
  if texture and texture:GetName() ~= "error" then params[key] = texture:GetName() end
 end
 -- CreateMaterial reuses existing names, even after a Lua reload. Version the
 -- name so existing clients cannot retain a material without alpha testing.
 local runtimeName = "ix_sd_hair_v2_" .. name:match("([^/]+)$") .. "_" .. colour
 local material = CreateMaterial(runtimeName, "VertexLitGeneric", params)
 local rgb = preset.rgb
 material:SetVector("$color2", Vector((rgb[1]/190)^2.2, (rgb[2]/190)^2.2, (rgb[3]/190)^2.2))
 material:Recompute()
 materials[key] = "!" .. runtimeName
 return materials[key]
end

local function Restore(entity, state, sameModel)
 for index, slot in pairs(state.slots) do
  if entity:GetSubMaterial(index) == slot.material then
   entity:SetSubMaterial(index, sameModel and slot.previous ~= "" and slot.previous or nil)
  end
 end
end

function H.Apply(entity, colour)
 if not enabled or not IsValid(entity) then return end
 local model = entity:GetModel()
 if not H.Valid(colour) or not H.Supported(model) then colour = "original" end
 local state = states[entity]
 if state and (state.model ~= model or colour == "original") then
  Restore(entity, state, state.model == model)
  states[entity], state = nil, nil
 end
 if colour == "original" then return end
 state = state or {model=model, slots={}}
 states[entity] = state
 for index, name in pairs(Slots(entity)) do
  local slot, current = state.slots[index], entity:GetSubMaterial(index)
  if slot and current ~= slot.material then state.slots[index], slot = nil, nil end
  -- Never unhide height-compensation masks or replace another addon's override.
  if slot or current == "" or current == nil then
   local material = H.Material(name, colour)
   if material then
    if not slot then slot = {previous=current}; state.slots[index] = slot end
    if current ~= material then entity:SetSubMaterial(index, material) end
    slot.material = material
   end
  end
 end
end

function H.Update(entity)
 if not IsValid(entity) then tracked[entity] = nil; return end
 local colour = entity:IsPlayer() and H.Saved(entity:GetCharacter()) or entity:GetNetVar("sdHairColor", "original")
 H.Apply(entity, colour)
end

local function Track(entity)
 if not enabled or not IsValid(entity) then return end
 local class = entity:GetClass()
 if entity:IsPlayer() or class == "prop_ragdoll" or class == "ix_cart_patient" then
  tracked[entity] = true
  H.Update(entity)
 end
end

function H.Clear()
 enabled = false
 timer.Remove("ixSDHairColour")
 hook.Remove("OnEntityCreated", "ixSDHairColour")
 hook.Remove("PrePlayerDraw", "ixSDHairColour")
 hook.Remove("InitPostEntity", "ixSDHairColour")
 hook.Remove("ShutDown", "ixSDHairColour")
 for entity, state in pairs(states) do
  if IsValid(entity) then Restore(entity, state, entity:GetModel() == state.model) end
 end
end

hook.Add("OnEntityCreated", "ixSDHairColour", function(entity)
 timer.Simple(0, function() Track(entity) end)
end)
hook.Add("PrePlayerDraw", "ixSDHairColour", function(client) H.Update(client) end)
local function Existing()
 if enabled then for _, entity in ipairs(ents.GetAll()) do Track(entity) end end
end
hook.Add("InitPostEntity", "ixSDHairColour", Existing)
hook.Add("ShutDown", "ixSDHairColour", H.Clear)
timer.Create("ixSDHairColour", 0.25, 0, function()
 for entity in pairs(tracked) do H.Update(entity) end
end)
timer.Simple(0, Existing)

end
if SERVER then return end
print("[SD colour] Checking mounted textures and current appearance...")
local report = {time=os.date("%Y-%m-%d %H:%M:%S"), assets={}, entities={}}
local H = ix and ix.SDHair
report.loaded = H and isfunction(H.Apply) or false
local count = 0
for _, family in ipairs({"haircurly", "haircurly2", "haircurly3", "hairlong01", "hairshaved", "hairshaved04", "hairshaved06", "hairshort01"}) do
 local present = file.Exists("materials/models/hutten/sd_hair/" .. family .. ".vtf", "GAME")
 report.assets[family] = present
 if present then count = count + 1 end
end
local ok, err = xpcall(function()
 if not report.loaded then return end
 for _, entity in ipairs(player.GetAll()) do
  if H.Supported(entity:GetModel()) then
   local character = entity:GetCharacter()
   local row = {index=entity:EntIndex(), model=entity:GetModel(), skin=entity:GetSkin(),
    localPlayer=entity==LocalPlayer(), saved=H.Saved(character), network=entity:GetNetVar("sdHairColor"), slots={}}
   H.Update(entity)
   for index, name in ipairs(entity:GetMaterials()) do
    if string.find(string.lower(name), "hair", 1, true) then
     local override = entity:GetSubMaterial(index-1)
     local original = Material(name)
     local slot = {index=index-1, source=name, override=override, sourceFlags=original:GetInt("$flags")}
     if override and override ~= "" then
      local material = Material(override:gsub("^!", ""))
      local texture = material:GetTexture("$basetexture")
      slot.error, slot.shader = material:IsError(), material:GetShader()
      slot.texture = texture and texture:GetName() or false
      slot.colour = tostring(material:GetVector("$color2"))
      slot.phong = material:GetInt("$phong")
      slot.flags = material:GetInt("$flags")
      slot.alphaTest = bit.band(slot.flags or 0, 256) ~= 0
      slot.noCull = bit.band(slot.flags or 0, 8192) ~= 0
      slot.alphaReference = material:GetFloat("$alphatestreference")
     end
     row.slots[#row.slots+1] = slot
    end
   end
   report.entities[#report.entities+1] = row
   print("[SD colour] Character:", character and character:GetName() or "unavailable", "Saved:", row.saved, "Network:", row.network)
  end
 end
end, debug.traceback)
report.error = not ok and err or nil
file.CreateDir("ix_sd_hair_audit")
file.Write("ix_sd_hair_audit/colour.json", util.TableToJSON(report, true))
print("[SD colour] Loaded:", report.loaded, "Mounted textures:", count .. "/8")
print("[SD colour] Saved data/ix_sd_hair_audit/colour.json")
if not ok then print("[SD colour] Error:", err) end
