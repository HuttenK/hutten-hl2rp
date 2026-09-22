-- The pack-specific chromatic shader has no equivalent stock material.
-- Keep the world image neutral instead of loading an unavailable shader.
hook.Remove("RenderScreenspaceEffects", "autonomous.chroma")
