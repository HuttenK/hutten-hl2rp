-- Build presentation groups without changing the server's faction model indices.
-- Only variants actually allowed by the faction/gender are offered.
ix.BuildCharacterModelChoices = function(models, chargen)
	local byPath, assigned, result = {}, {}, {}
	for index, entry in ipairs(models) do
		local path = istable(entry) and entry[1] or entry
		if isstring(path) then byPath[path:lower()] = index end
	end
	for index, entry in ipairs(models) do
		local path = istable(entry) and entry[1] or entry
		local group = isstring(path) and chargen and chargen:GetHairGroup(path)
		if group then
			local choice = {index = index, entry = entry, variants = {}}
			for _, variant in ipairs(group) do
				local variantIndex = byPath[variant.model:lower()]
				if variantIndex then
					choice.variants[#choice.variants + 1] = {index = variantIndex, name = variant.name}
					assigned[variantIndex] = true
				end
			end
			if #choice.variants > 0 then result[#result + 1] = choice end
		end
	end
	-- Orphan variants remain selectable when a pack omits the registered base.
	for index, entry in ipairs(models) do
		if not assigned[index] then result[#result + 1] = {index = index, entry = entry, variants = {{index = index}}} end
	end
	table.sort(result, function(a, b) return a.index < b.index end)
	return result
end
