-- Capability-based animation selection. Probes the mounted model once per realm,
-- never spawns a temporary entity or relies on Workshop filenames.
ix.anim.modelDetectionCache = {}
local cache = ix.anim.modelDetectionCache
local candidates = {"citizen_male", "citizen_female", "metrocop", "overwatch", "vortigaunt",
	"cellarMale", "cellarFemale", "cellarMaleMPF", "cellarFemaleMPF", "cellarOTA"}
local movement = {ACT_MP_STAND_IDLE, ACT_MP_WALK, ACT_MP_RUN, ACT_MP_CROUCH_IDLE, ACT_MP_CROUCHWALK}

function ix.anim.DetectModelClass(entity, model)
	model = string.lower(model or (IsValid(entity) and entity:GetModel()) or "")
	if cache[model] then return cache[model].class, cache[model] end
	-- A network model-change message may arrive before the entity model update.
	-- Do not poison the cache by probing the previous model or an unloaded asset.
	if not IsValid(entity) or string.lower(entity:GetModel() or "") ~= model or
		not entity.GetSequenceCount or entity:GetSequenceCount() < 2 then return end
	local probes = {}
	local function has(value)
		if value == nil then return false end
		if probes[value] == nil then
			local sequence = isstring(value) and entity:LookupSequence(value) or entity:SelectWeightedSequence(value)
			probes[value] = isnumber(sequence) and sequence >= 0
		end
		return probes[value]
	end
	local function accept(class, reason, score)
		local result = {class = class, reason = reason, score = score}
		cache[model] = result
		return class, result
	end
	-- Genuine playermodels should use Sandbox's complete weapon animation handling,
	-- even when their path lacks /player or contains misleading NPC names.
	if has(ACT_HL2MP_IDLE) and has(ACT_HL2MP_WALK) and has(ACT_HL2MP_RUN) and
		has(ACT_HL2MP_IDLE_CROUCH) and has(ACT_HL2MP_WALK_CROUCH) then
		return accept("player", "native multiplayer activities", 1)
	end
	local cellar = has("cidle_normal") and has("cwalk_normal") and has("idle_fists")
	local best, bestScore = nil, -1
	for _, class in ipairs(candidates) do
		local definition = ix.anim[class]
		local custom = class:sub(1, 6) == "cellar"
		if definition and custom == cellar then
			local hits, total = 0, 0
			for _, hold in ipairs({"normal", "pistol", "smg"}) do
				local tree = definition[hold]
				if tree then
					for _, activity in ipairs(movement) do
						local pair = tree[activity]
						if pair then
							if not istable(pair) then pair = {pair} end
							for _, value in ipairs(pair) do
								total = total + 1
								if has(value) then hits = hits + 1 end
							end
						end
					end
				end
			end
			local score = total > 0 and hits / total or 0
			-- Preserve existing subtype knowledge only as a tie-breaker.
			if score > bestScore or (score == bestScore and ix.anim.modelHints[model] == class) then
				best, bestScore = class, score
			end
		end
	end
	if best and bestScore >= 0.5 then
		return accept(best, cellar and "custom sequence family" or "NPC activity compatibility", bestScore)
	end
	-- Unknown/animation-less models deliberately remain uncached: mounting content
	-- later may make them usable. The caller retains Helix's established fallback.
end

function ix.anim.ClearModelDetectionCache()
	for model in pairs(cache) do cache[model] = nil end
	if ix.anim.ClearARC9PoseCache then ix.anim.ClearARC9PoseCache() end
end
