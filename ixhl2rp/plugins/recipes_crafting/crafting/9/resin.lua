RECIPE.name = "recipe.crafting.resin"
RECIPE.category = "recipe.category.components"
RECIPE.requirements = {
	mat_varnish = 2,   -- processed catalyst (itself acid + oil)
	mat_resine = 4,    -- rubber base stock
	mat_oil = 4,       -- petroleum feedstock
	mat_acid = 3,      -- cross-linking agent
	mat_sulfur = 2,    -- vulcanising agent
	mat_plastic = 3,   -- polymer filler
	mat_charcoal = 4,  -- carbon / heat source
}
RECIPE.results = {
	resin = {4, 6}
}
RECIPE.skill = {"crafting", 9}
RECIPE.tools = {"tool_welding"}
RECIPE.tool_durability = {
	tool_welding = 15,
}
RECIPE.station = "station_tokar"
RECIPE.xp = 240
