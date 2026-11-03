local A = ix.Amputation
if A.ClearVisualCallbacks then A.ClearVisualCallbacks() end
local attached = setmetatable({}, {__mode = "k"})

function A.VisualKey(entity)
 local owner = entity.ixAmputationVisualOwner
 if IsValid(owner) then entity = owner end
 local key = entity:GetNetVar("ixAmputation")
 return A.limbs[key] and key or nil
end

function A.BuildMissingLimb(entity)
 local key = A.VisualKey(entity)
 if !key then return end
 local bones = A.CollectBones(entity, A.limbs[key])
 if !bones then return end
 local root = entity:GetBoneMatrix(bones[1])
 if !root then return end
 local anchor = root:GetTranslation()
 -- Move the final *world matrices*, not local ManipulateBonePosition offsets.
 -- Every removed child meets at the elbow/knee instead of leaving miniature
 -- fingers/feet at the ends of the old limb. Never create a singular matrix.
 local scale = A.scale * math.Clamp(entity:GetModelScale(), 0.1, 10)
 for _, bone in ipairs(bones) do
  if entity:GetBoneName(bone) == "__INVALIDBONE__" then continue end
  local matrix = entity:GetBoneMatrix(bone)
  if !matrix then continue end
  matrix:SetTranslation(anchor)
  matrix:SetScale(scale)
  entity:SetBoneMatrix(bone, matrix)
 end
end

function A.BindVisual(entity, owner)
 if !IsValid(entity) then return end
 entity.ixAmputationVisualOwner = owner
 if attached[entity] then return end
 attached[entity] = entity:AddCallback("BuildBonePositions", A.BuildMissingLimb)
end

function A.ClearVisualCallbacks()
 for entity, callback in pairs(attached) do
  if IsValid(entity) then
   entity:RemoveCallback("BuildBonePositions", callback)
   entity:InvalidateBoneCache()
  end
 end
 attached = setmetatable({}, {__mode = "k"})
end

local function bindWorld(entity)
 if IsValid(entity) and (entity:IsPlayer() or entity:IsRagdoll()) then A.BindVisual(entity) end
end
hook.Add("NetworkEntityCreated", "ixAmputationVisual", bindWorld)
hook.Add("NotifyShouldTransmit", "ixAmputationVisual", function(entity, visible)
 if visible then bindWorld(entity) end
end)
hook.Add("PrePlayerDraw", "ixAmputationVisual", function(client) A.BindVisual(client) end)
hook.Add("PreDrawPlayerHands", "ixAmputationVisual", function(hands, _, client)
 A.BindVisual(hands, client)
end)
hook.Add("ShutDown", "ixAmputationVisual", A.ClearVisualCallbacks)
for _, entity in ipairs(player.GetAll()) do bindWorld(entity) end
for _, entity in ipairs(ents.FindByClass("prop_ragdoll")) do bindWorld(entity) end
