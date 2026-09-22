-- Acts probe the current model independently of its locomotion class.
function ix.act.Sequence(entity, candidates)
	if not IsValid(entity) or entity:GetSequenceCount() < 2 then return end
	for _, candidate in ipairs(candidates) do
		local id = isnumber(candidate) and entity:SelectWeightedSequence(candidate) or entity:LookupSequence(candidate)
		if isnumber(id) and id >= 0 then
			return entity:GetSequenceName(id), id
		end
	end
 -- Only consult shared static poses after exhausting the model's own clips.
 if ix.sharedPoses then
  for _,candidate in ipairs(candidates) do
   local pose=ix.sharedPoses.Resolve(entity,candidate)
   if pose then return candidate,pose.base,pose end
  end
 end
end

function ix.act.NativeSit(entity)
	local candidates = {"sit_zen", "sit_passive", "sit_fist"}
	if ACT_HL2MP_SIT_PASSIVE then candidates[#candidates + 1] = ACT_HL2MP_SIT_PASSIVE end
	if ACT_HL2MP_SIT_FIST then candidates[#candidates + 1] = ACT_HL2MP_SIT_FIST end
	return ix.act.Sequence(entity, candidates)
end

function ix.act.Resolve(entity, classes, variant)
	if not IsValid(entity) then return end
	local preferred = ix.anim.GetModelClass(entity:GetModel(), entity)
	local function supported(data)
		local pose = istable(data) and data.sequence and data.sequence[variant]
		return pose and ix.act.Sequence(entity, {istable(pose) and pose[1] or pose}) and data
	end
	local data = supported(classes[preferred])
	if data then return data end
	-- Deterministic order on both realms, preserving checks and transitions.
	local keys = table.GetKeys(classes)
	table.sort(keys)
	for _, class in ipairs(keys) do
		data = supported(classes[class])
		if data then return data end
	end
	if classes.nativeSit and variant == 1 then
		local name = ix.act.NativeSit(entity)
		if name then return {sequence = {name}, untimed = true, idle = true} end
	end
end
