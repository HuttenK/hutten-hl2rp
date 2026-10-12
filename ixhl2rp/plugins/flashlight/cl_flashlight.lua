local PLUGIN = PLUGIN
if PLUGIN.OnUnload then PLUGIN:OnUnload() end
local lamps = {}

function PLUGIN:Think()
    self.localBeam = nil
    local viewer = LocalPlayer()
    if not IsValid(viewer) then return end
    local candidates = {}
    for _, client in ipairs(player.GetAll()) do
        if client:Alive() and not client:IsDormant() and client:GetNWBool("ixFieldFlashlight", false) then
            local distance = client:GetPos():DistToSqr(viewer:GetPos())
            if distance < 1400 * 1400 then candidates[#candidates + 1] = {client = client, distance = client == viewer and -1 or distance} end
        end
    end
    table.sort(candidates, function(a, b) return a.distance < b.distance end)
    local keep = {}
    for index = 1, math.min(3, #candidates) do
        local client = candidates[index].client
        keep[client] = true
        local entry = lamps[client]
        if not entry then
            local lamp = ProjectedTexture()
            if lamp then
                lamp:SetTexture("effects/flashlight001")
                lamp:SetNearZ(4); lamp:SetFarZ(1000); lamp:SetFOV(52)
                lamp:SetColor(Color(255, 244, 226)); lamp:SetBrightness(1.35)
                -- Source clamps constant + linear/d + quadratic/d^2 to 1.
                -- Extend the useful throw without raising point-blank intensity.
                lamp:SetConstantAttenuation(0); lamp:SetLinearAttenuation(350); lamp:SetQuadraticAttenuation(0)
                lamp:SetEnableShadows(true)
                entry = {lamp = lamp, angle = client:EyeAngles(), fade = 0}
                lamps[client] = entry
            end
        end
        if entry then
            local localView = client == viewer and not client:ShouldDrawLocalPlayer()
            -- Global EyePos/EyeAngles may still belong to a CCTV RenderView.
            local view = localView and render.GetViewSetup(false)
            local pos = view and view.origin or client:GetShootPos()
            local aim = view and view.angles or client:EyeAngles()
            local polish = ix.option.Get("fieldFlashlightPolish", true)
            local smooth = polish and not ix.option.Get("disableAnimations", false)
            entry.angle = smooth and LerpAngle(math.Clamp(FrameTime() * 22, 0, 1), entry.angle, aim) or aim
            -- Keep the origin close to the eye; trace the small offset to avoid walls.
            local offset = pos + aim:Right() * 3 - aim:Up() * 2
            local tr = util.TraceLine({start = pos, endpos = offset, filter = client, mask = MASK_SOLID})
            pos = tr.Hit and pos or offset
            entry.fade = math.Approach(entry.fade, 1, FrameTime() * 10)
            entry.lamp:SetPos(pos); entry.lamp:SetAngles(entry.angle)
            entry.lamp:SetColor(polish and Color(255, 244, 226) or color_white)
            entry.lamp:SetBrightness(1.35 * entry.fade)
            entry.lamp:Update()
            if localView then self.localBeam = {pos=pos,angle=entry.angle,fade=entry.fade,updatedAt=RealTime()} end
        end
    end
    for client, entry in pairs(lamps) do
        if not keep[client] then entry.lamp:Remove(); lamps[client] = nil end
    end
end

function PLUGIN:OnUnload()
    self.localBeam = nil
    for _, entry in pairs(lamps) do entry.lamp:Remove() end
    lamps = {}
end
