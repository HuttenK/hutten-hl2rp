local D = ix.Downed

-- Applied to the completed view rather than competing with camera plugins for
-- the first non-nil CalcView return. This also covers single-player prediction
-- and the first frame after the ragdoll camera releases control.
function D.ApplyCrawlView(view, client, origin, angles, fov)
    if not IsValid(client) or client ~= LocalPlayer() or not D.Crawling(client)
        or client:GetViewEntity() ~= client or client:GetMoveType() ~= MOVETYPE_WALK
        or (client.CanOverrideView and client:CanOverrideView())
        or (istable(view) and (view.drawviewer or view.ortho)) then return view end
    local result = istable(view) and table.Copy(view) or {}
    result.origin = client:GetPos() + D.CrawlEyeOffset(client)
    result.angles = angles
    result.fov = result.fov or fov
    result.drawviewer = false
    result.znear = 1
    return result
end

hook.Add("ShouldDisableLegs", "ixCriticalCrawlLegs", function()
    -- The legacy first-person legs copy offsets/collapses upper-body bones for
    -- standing. It cannot represent prone and can stretch through the camera.
    -- Keep the real world player and its third-person prone pose untouched.
    if D.Crawling(LocalPlayer()) then return true end
end)
