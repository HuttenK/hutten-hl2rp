-- Installed ARC9 2910505837 DoTPIK rate/cache decision, 18 October 2026.
    local tpikdelay = 0

    local lod

    if ply == LocalPlayer() then
        local localtpiktime = math.Clamp(arc9_tpik_framerate_you:GetInt() or 60, 10, 150)
        tpikdelay = 1 / localtpiktime
    else
        local dist = EyePos():DistToSqr(ply:GetPos())
        local convartpiktime = math.Clamp(arc9_tpik_framerate_notyou:GetInt() or 20, 5, 150)
        tpikdelay = 1 / convartpiktime

        lod = self:ShouldLOD()

        if lod == 1 then
            tpikdelay = math.max(0.05, tpikdelay) -- max 20 fps if lodding
        elseif lod == 1.5 then
            tpikdelay = math.max(0.1, tpikdelay)
        end
    end

    local shouldfulltpik = true

    if self.LastTPIKTime + tpikdelay > CurTime() then
        shouldfulltpik = false
    end

    if not shouldfulltpik
        and arc9_tpik_helper_bone_force_full_fps
        and arc9_tpik_helper_bone_force_full_fps:GetBool()
        and TPIKHelperHasCachedRoots(ply) then
        shouldfulltpik = true
    end

