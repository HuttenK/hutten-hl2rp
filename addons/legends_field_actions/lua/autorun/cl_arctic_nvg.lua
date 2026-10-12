if SERVER then return end

ArcticNVGs_Enabled = false
ArcticNVGs_GlobalOffsetAngle = Angle(0, 0, 0)
ArcticNVGs_GlobalOffsetPosition = Vector(-4, 0, -2)

ArcticNVGs_Fade = 0

ArcticNVGs_LastNVG = 0

ArcticNVGs_Inactive = false

local toggleBusyUntil=0
function ArcticNVGs_Toggle()
    local p=LocalPlayer()
    if not IsValid(p) or not p:Alive() or CurTime()<toggleBusyUntil then return end
    local goggles=p:GetNWInt("nvg",0)
    local spec=ArcticNVGs[goggles]
    if not spec then return end
    local on=not ArcticNVGs_Enabled
    local anim=on and spec.VManipIn or spec.VManipOut
    if anim and (not VManip or not VManip:PlayAnim(anim)) then return end
    local delay=on and (spec.EquipDelay or 0) or (spec.UnequipDelay or 0)
    toggleBusyUntil=CurTime()+math.max(delay,.7)
    timer.Simple(delay,function()
        if not IsValid(p) or not p:Alive() or p:GetNWInt("nvg",0)~=goggles then return end
        ArcticNVGs_LastNVG=goggles
        ArcticNVGs_Enabled=on
        surface.PlaySound(on and (spec.EquipSound or "arctic_nvgs/nvg_on_1.wav") or (spec.UnequipSound or "arctic_nvgs/nvg_off_1.wav"))
        ArcticNVGs_Fade=spec.NoFade and 0 or 1
        ArcticNVGs_Inactive=false
        ArcticNVGs_RebuildLamp()
        net.Start("arcticnvgs_toggle"); net.WriteBool(on); net.SendToServer()
    end)
end

concommand.Add("arc_vm_nvg", function(ply)
    ArcticNVGs_Toggle()
end)

function ArcticNVGs_RebuildNVGsForPlayer(ply)
    local goggles = ply:GetNWInt("nvg", 0)
    local enabled = ply:GetNWBool("nvg_on", false)

    if goggles == 0 or not enabled or not ArcticNVGs[goggles] then
        SafeRemoveEntity(ply.ArcticNVGsModel)
        ply.ArcticNVGsModel = nil
        ply.ArcticNVGsModel_NVG = nil
    else
        local goggles_table = ArcticNVGs[goggles]
        SafeRemoveEntity(ply.ArcticNVGsModel)
        local model = ClientsideModel(goggles_table.Model)
        model:SetNoDraw(true)
        ply.ArcticNVGsModel = model
        ply.ArcticNVGsModel_NVG = goggles
    end
end

function ArcticNVGs_RebuildLamp()
    if ArcticNVGs_Lamp then ArcticNVGs_Lamp:Remove(); ArcticNVGs_Lamp=nil end
    if ArcticNVGs_Enabled then
        local goggles = LocalPlayer():GetNWInt("nvg", 0)
        local goggles_table = ArcticNVGs[goggles]

        if not goggles_table or goggles_table.NoBrightenWorld then return end

        local lamp = ProjectedTexture()
        ArcticNVGs_Lamp = lamp
        if not lamp then return end
        lamp:SetTexture("effects/flashlight/square")
        lamp:SetFOV(170)
        lamp:SetFarZ(2069)
        lamp:SetBrightness(0.01)
        lamp:SetConstantAttenuation(0.5)
        ArcticNVGs_Lamp:Update()
    else
        if ArcticNVGs_Lamp then
            ArcticNVGs_Lamp:Remove()
        end
    end
end

hook.Add("HUDPaintBackground", "ArcticNVGs_PDH", function()
    if ArcticNVGs_Enabled then
        local goggles = LocalPlayer():GetNWInt("nvg", 0)
        local goggles_table = ArcticNVGs[goggles]

        if not goggles_table or goggles != ArcticNVGs_LastNVG then
            ArcticNVGs_Enabled = false
            net.Start("arcticnvgs_toggle", true)
            net.WriteBool(ArcticNVGs_Enabled)
            net.SendToServer()
            return
        end

        if !ArcticNVGs_Inactive then
            if goggles_table.Overlay and not goggles_table.Overlay:IsError() then
                local x = 0
                local y = 0
                local w = ScrW()
                local h = ScrH()

                if goggles_table.ScaleToSquare then
                    w = h
                    x = (ScrW() - h) / 2

                    surface.SetDrawColor(0, 0, 0, 255)
                    surface.DrawRect(0, 0, x, h)
                    surface.DrawRect(ScrW() - x, 0, x, h)
                end

                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(goggles_table.Overlay)
                surface.DrawTexturedRect(x, y, w, h)
            end
        end
    end

    if ArcticNVGs_Fade > 0 then
        ArcticNVGs_Fade = math.Approach(ArcticNVGs_Fade, 0, FrameTime() / 0.5)
        surface.SetDrawColor(0, 0, 0, ArcticNVGs_Fade * 255 * 1.5)
        surface.DrawRect(0, 0, ScrW(), ScrH())
    end

    ArcticNVGs_LastNVG = LocalPlayer():GetNWInt("nvg", 0)
end)

hook.Add("RenderScreenspaceEffects", "ArcticNVGs_SSE", function()
    if !ArcticNVGs_Enabled then
        if ArcticNVGs_Lamp then
            ArcticNVGs_RebuildLamp()
        end
        return
    end
    if ArcticNVGs_Inactive then return end

    local goggles = LocalPlayer():GetNWInt("nvg", 0)
    local goggles_table = ArcticNVGs[goggles]

    if !goggles_table or not LocalPlayer():Alive() then ArcticNVGs_Enabled = false; ArcticNVGs_RebuildLamp(); return end

    if ArcticNVGs_Lamp then
        ArcticNVGs_Lamp:SetPos(EyePos())
        ArcticNVGs_Lamp:SetAngles(EyeAngles())
        ArcticNVGs_Lamp:Update()
    end

    if ix and ix.FieldVisuals and ix.FieldVisuals.DrawNVG(goggles_table, goggles) then return end

    if goggles_table.ActiveLight then
        local dlight = DynamicLight(LocalPlayer():EntIndex())

        if not dlight then return end
        dlight.brightness = 1
        dlight.Size = goggles_table.ActiveLight
        dlight.r = 255
        dlight.g = 255
        dlight.b = 255
        dlight.Decay = 1000
        dlight.pos = EyePos()
        dlight.DieTime = CurTime() + 0.1
    end

    if !goggles_table.FullColor then
        local tab = {}

        tab[ "$pp_colour_addr" ] = 0
        tab[ "$pp_colour_addg" ] = 0
        tab[ "$pp_colour_addb" ] = 0
        tab[ "$pp_colour_brightness" ] = 0
        tab[ "$pp_colour_contrast" ] = 1
        tab[ "$pp_colour_colour" ] = 0
        tab[ "$pp_colour_mulr" ] = 0
        tab[ "$pp_colour_mulg" ] = 0
        tab[ "$pp_colour_mulb" ] = 0

        DrawColorModify(tab)
    end

    if goggles_table.ColorCorrectSettings then
        DrawColorModify(goggles_table.ColorCorrectSettings)
    end

    if goggles_table.EffectFunction then
        goggles_table.EffectFunction()
    end

    if goggles_table.BloomSettings then
        local tab = goggles_table.BloomSettings

        DrawBloom(tab.darken or 0, tab.multiply or 1,
            tab.sizex or 1, tab.sizey or 1, tab.passes or 1,
            tab.colormultiply or 1,
            tab.red or 1, tab.green or 1, tab.blue or 1)
    end
end)

hook.Add("PostPlayerDraw", "ArcticNVGs_PostPlayerDraw", function(ply)
    local goggles = ply:GetNWInt("nvg", 0)
    local enabled = ply:GetNWBool("nvg_on", false)

    local goggles_table = ArcticNVGs[goggles]

    if ply == LocalPlayer() and !ply:ShouldDrawLocalPlayer() then return end

    if goggles == 0 or !enabled then
        if ply.ArcticNVGsModel then
            ArcticNVGs_RebuildNVGsForPlayer(ply)
        end
        return
    end

    if !ply.ArcticNVGsModel then ArcticNVGs_RebuildNVGsForPlayer(ply) return end
    if ply.ArcticNVGsModel_NVG != goggles then
        SafeRemoveEntity(ply.ArcticNVGsModel)
        ArcticNVGs_RebuildNVGsForPlayer(ply)
        return
    end

    local att = ply:LookupAttachment("eyes")
    att = ply:GetAttachment(att)
    local bpos, bang = att.Pos, att.Ang
    local offset = (goggles_table.Offset or Vector(0, 0, 0)) + ArcticNVGs_GlobalOffsetPosition
    local offset_angle = (goggles_table.OffsetAngle or Angle(0, 0, 0)) + ArcticNVGs_GlobalOffsetAngle

    local pos = bpos
    local ang = bang

    pos, ang = LocalToWorld(offset, offset_angle, bpos, bang)

    ply.ArcticNVGsModel:SetPos(pos)
    ply.ArcticNVGsModel:SetAngles(ang)
    ply.ArcticNVGsModel:DrawModel()
end)

local ents_table = {}
local ents_count = 0

local coldtime = 30

function ArcticNVGs_GetWHOT(ent)
    if !ent then return false end
    if !ent:IsValid() then return false end
    if ent:IsWorld() then return false end
    if (ent.Health and (ent:Health() <= 0)) then return false end

    if ent:IsOnFire() then return true end
    if ent:IsNPC() then
        if ent.ArcCWCLHealth and ent.ArcCWCLHealth <= 0 then return false end
        return true
    end
    if ent:IsNextBot() then return true end
    if ent:IsPlayer() then
        if ent.ArcticMedShots_ActiveEffects and ent.ArcticMedShots_ActiveEffects["coldblooded"] then
            return false
        end

        return true
    end

    if ent:IsRagdoll() then
        local Time = CurTime()
        if !ent.ArcCW_ColdTime then ent.ArcCW_ColdTime = Time + coldtime end
        return ent.ArcCW_ColdTime > Time
    end

    if ent:IsVehicle() then
        return ent:GetVelocity():Length() >= 100
    end

end

hook.Add("PreDrawEffects", "ArcticNVGs_PreDrawEffects", function()
    if !ArcticNVGs_Enabled then return end
    if ArcticNVGs_Inactive then return end

    local goggles = LocalPlayer():GetNWInt("nvg", 0)
    local goggles_table = ArcticNVGs[goggles]

    if goggles_table and goggles_table.ThermalVision then
        if ents_count != ents.GetCount() then
            ents_table = ents.GetAll()
        end

        for _, ent in ipairs(ents_table) do
            if ArcticNVGs_GetWHOT(ent) then
                local Br = 0.9
                if ent.ArcCW_ColdTime then
                    Br = (0.75 * ent.ArcCW_ColdTime - CurTime()) / coldtime
                end

                if ent:IsVehicle() then
                    Br = math.Clamp(ent:GetVelocity():Length() / 400, 0, 1)
                end

                if Br > 0 then

                    render.SetBlend(0.5)
                    render.SuppressEngineLighting(true)

                    Br = Br * 250

                    -- render.MaterialOverride(thermal)

                    render.SetColorModulation(Br, Br, Br)

                    ent:DrawModel()

                end
            end
        end

        render.SetBlend(1)
        render.SuppressEngineLighting(false)
        render.SetColorModulation(1, 1, 1)
    end
end)