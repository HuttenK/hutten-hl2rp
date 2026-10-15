local H = ix.CharacterHeight
if H.ClearHeadwear then H.ClearHeadwear() end
local entries, profiles, active, wrappers = {}, {}, {}, {}
local hidden = "!ix_height_hidden"
CreateMaterial("ix_height_hidden", "VertexLitGeneric", {['$no_draw'] = '1'})
local gear = {hats = true, hlvr_consthat = true, helmet_spetsnaz = true, helmet_a_col = true}
local depthFlags = bit.bor(STUDIO_SHADOWDEPTHTEXTURE, STUDIO_SSAODEPTHTEXTURE)
local function depthPass(flags) return flags and bit.band(flags, depthFlags) ~= 0 end

function H.HeadwearProfile(entity)
 local path = string.lower(entity:GetModel() or "")
 if not path:find("models/sd/citizens/citizen_", 1, true) then return end
 if profiles[path] ~= nil then return profiles[path] or nil end
 local indices = {}
 for index, material in ipairs(entity:GetMaterials()) do
  if gear[string.lower(material):match("([^/]+)$")] then indices[#indices + 1] = index - 1 end
 end
 local head = entity:LookupBone("ValveBiped.Bip01_Head1")
 if not head or #indices == 0 then return end
 local profile = {indices = indices, head = head}
 profiles[path] = profile
 return profile or nil
end

function H.RestoreHeadwear(entity)
 local saved = active[entity]
 active[entity] = nil
 if saved and IsValid(entity) then
  for index, material in pairs(saved) do entity:SetSubMaterial(index, material ~= "" and material or nil) end
 end
 return saved
end

local function remove(entity)
 H.RestoreHeadwear(entity)
 local entry = entries[entity]
 if entry and IsValid(entry.model) then entry.model:Remove() end
 entries[entity] = nil
end

function H.BeginHeadwear(entity, flags)
 -- Depth shaders replace the material mask on the full-body helmet copy.
 -- Let the original fitted helmet cast the shadow instead of a hidden body.
 if depthPass(flags) or active[entity] or not IsValid(entity) or entity:GetModelScale() >= .9999
  or entity:GetBodygroup(1) <= 0 or entity:GetMaterial() ~= "" then return end
 local profile = H.HeadwearProfile(entity)
 if not profile then return end
 local entry = entries[entity]
 if entry and (entry.path ~= entity:GetModel() or not IsValid(entry.model)) then remove(entity); entry = nil end
 if not entry then
  local model = ClientsideModel(entity:GetModel(), RENDERGROUP_OPAQUE)
  if not IsValid(model) then return end
  model:SetNoDraw(true)
  model:SetIK(false)
  -- Audited on all 52 installed SD citizen rigs: these four materials belong
  -- exclusively to headwear, and all their vertices use Head1 (329 meshes).
  -- Keep the owner's original hair bodygroup; never replace it with full hair.
  for index in ipairs(model:GetMaterials()) do model:SetSubMaterial(index - 1, hidden) end
  entry = {model = model, path = entity:GetModel(), profile = profile}
  entries[entity] = entry
  model:AddCallback("BuildBonePositions", function(copy)
   if entry.matrix then copy:SetBoneMatrix(profile.head, entry.matrix) end
  end)
 end
 entry.used = RealTime()
 local saved = {}
 for _, index in ipairs(profile.indices) do
  saved[index] = entity:GetSubMaterial(index) or ""
  entry.model:SetSubMaterial(index, saved[index] ~= "" and saved[index] or nil)
  entity:SetSubMaterial(index, hidden)
 end
 active[entity] = saved
 return true
end

function H.EndHeadwear(entity, flags)
 if depthPass(flags) then return end
 if not H.RestoreHeadwear(entity) then return end
 local entry = entries[entity]
 if not entry or not IsValid(entry.model) then return end
 local head = entity:GetBoneMatrix(entry.profile.head)
 if not head then return end
 local visible = head:GetScale()
 if math.min(visible.x, visible.y, visible.z) < .1 then return end
 -- Absolute scale, retaining the actual animated head's position and rotation.
 -- Taller bodies keep their normal fitted headwear in the original draw pass.
 entry.matrix = Matrix(head)
 entry.matrix:SetScale(Vector(1, 1, 1))
 local model = entry.model
 model:SetPos(entity:GetPos())
 -- Ragdolls/patients need not have a render-angle override.
 model:SetAngles(entity:GetRenderAngles() or entity:GetAngles())
 model:SetSkin(entity:GetSkin())
 model:SetBodygroup(1, entity:GetBodygroup(1))
 model:SetColor(entity:GetColor())
 model.GetPlayerColor = entity.GetPlayerColor and function() return entity:GetPlayerColor() end or nil
 model:InvalidateBoneCache()
 model:SetupBones()
 model:DrawModel(flags)
 -- SetNoDraw + manual DrawModel does not set up projected-texture lighting.
 -- Draw the additive beam contribution explicitly; never add it to depth passes.
 -- https://wiki.facepunch.com/gmod/render.RenderFlashlights
 render.RenderFlashlights(function() model:DrawModel(flags) end)
end

function H.WrapHeadwear(entity)
 if wrappers[entity] or not H.HeadwearProfile(entity) then return end
 local state = {original = entity.RenderOverride, enabled = true}
 state.wrapper = function(self, flags)
  if not state.enabled then
   if state.original then return state.original(self, flags) end
   return self:DrawModel(flags)
  end
  H.BeginHeadwear(self, flags)
  local ok, error = xpcall(function()
   if state.original then state.original(self, flags) else self:DrawModel(flags) end
   H.EndHeadwear(self, flags)
  end, debug.traceback)
  H.RestoreHeadwear(self)
  if not ok then ErrorNoHalt(error .. "\n") end
 end
 wrappers[entity] = state
 entity.RenderOverride = state.wrapper
end

function H.ClearHeadwear()
 for entity in pairs(active) do H.RestoreHeadwear(entity) end
 for entity in pairs(entries) do remove(entity) end
 for entity, state in pairs(wrappers) do
  state.enabled = false
  if IsValid(entity) and entity.RenderOverride == state.wrapper then entity.RenderOverride = state.original end
 end
 entries, wrappers, profiles = {}, {}, {}
end

hook.Add("PrePlayerDraw", "ixCharacterHeightHeadwear", function(entity, flags) H.BeginHeadwear(entity, flags) end)
hook.Add("PostPlayerDraw", "ixCharacterHeightHeadwear", function(entity, flags) H.EndHeadwear(entity, flags) end)
-- Another addon may cancel a player draw after PrePlayerDraw. Never leave its
-- material hidden for a later frame, portrait, shadow or camera render.
hook.Add("PostRender", "ixCharacterHeightHeadwear", function()
 for entity in pairs(active) do H.RestoreHeadwear(entity) end
end)
hook.Add("EntityRemoved", "ixCharacterHeightHeadwear", function(entity) remove(entity); wrappers[entity] = nil end)
hook.Add("ShutDown", "ixCharacterHeightHeadwear", H.ClearHeadwear)
timer.Create("ixCharacterHeightHeadwear", 1, 0, function()
 for _, class in ipairs({"prop_ragdoll", "ix_cart_patient"}) do
  for _, entity in ipairs(ents.FindByClass(class)) do H.WrapHeadwear(entity) end
 end
 for entity, entry in pairs(entries) do
  if not IsValid(entity) or RealTime() - entry.used > 5 then remove(entity) end
 end
end)
