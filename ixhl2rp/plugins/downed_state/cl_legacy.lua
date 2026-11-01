-- Older server files can still register this shader behind the new medical UI.
-- It draws autonomous_vignette without checking its material and replaces the
-- whole view with the error texture on clients missing that old content pack.
local function RemoveLegacyUnconsciousOverlay()
    local callbacks = hook.GetTable().HUDPaintBackground
    local callback = callbacks and callbacks["autonomous.unconscious"]
    if not callback then return end

    hook.Remove("HUDPaintBackground", "autonomous.unconscious")
    local info = isfunction(callback) and debug.getinfo(callback, "S")
    print("[Downed] Disabled obsolete autonomous.unconscious overlay from " ..
        (info and info.short_src or "unknown source") .. "; using the medical screen.")
end

RemoveLegacyUnconsciousOverlay()
-- Account for old schema/plugin files loaded after us, and Lua refreshes.
hook.Add("InitializedPlugins", "ixDownedLegacyOverlay", RemoveLegacyUnconsciousOverlay)
hook.Add("InitPostEntity", "ixDownedLegacyOverlay", RemoveLegacyUnconsciousOverlay)
hook.Add("OnReloaded", "ixDownedLegacyOverlay", RemoveLegacyUnconsciousOverlay)
