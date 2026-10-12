-- Source and legacy water are safe to drink. Do not offer an obsolete recipe
-- that spends cloth and charcoal to remove contamination which no longer exists.
RECIPE.disabled = true
if ix.Craft and ix.Craft.recipes then ix.Craft.recipes.purified_water = nil end
