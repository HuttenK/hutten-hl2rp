local C = ix.SCPCompat
local cameraState = {}

function C.CalcView(client, npc, origin, angles, fov)
    local camera = npc:GetNW2Entity("ixSCPCamera")
    local position
    if IsValid(camera) then
        local eyes = camera:GetAttachment(camera:LookupAttachment("eyes"))
        position = eyes and eyes.Pos or camera:GetPos() + camera:OBBCenter()
    else
        local center = npc:GetPos() + npc:OBBCenter() + npc:GetUp() * npc:OBBMaxs().z * .5
        local distance = math.max(client.CPTBase_Possessor_Zoom or 100, npc:BoundingRadius())
        local tr = util.TraceHull({start = center, endpos = center - angles:Forward() * distance,
            mask = MASK_SHOT, filter = {client, npc}, mins = Vector(-8,-8,-8), maxs = Vector(8,8,8)})
        position = tr.HitPos + tr.HitNormal * 5
    end
    if cameraState.npc ~= npc or cameraState.camera ~= camera then
        cameraState = {npc = npc, camera = camera, position = position}
    else cameraState.position = LerpVector(math.Clamp(FrameTime() * 10, 0, 1), cameraState.position, position) end
    local view = {origin = cameraState.position, angles = angles, fov = fov, drawviewer = false, drawviewmodel = false}
    if (cameraState.nextAim or 0) <= RealTime() then
        local hit = util.TraceLine({start = view.origin, endpos = view.origin + angles:Forward() * 32768,
            filter = {client, npc, camera}, mask = MASK_SHOT})
        net.Start("CPTBase_Possessor_HitPos"); net.WriteVector(hit.HitPos); net.WriteEntity(npc); net.SendToServer()
        cameraState.nextAim = RealTime() + 1 / 30
    end
    return view
end

function C.BindPress(client, bind, pressed)
    if pressed and (bind == "invnext" or bind == "invprev") then
        client.CPTBase_Possessor_Zoom = math.Clamp((client.CPTBase_Possessor_Zoom or 100) + (bind == "invnext" and 5 or -5), 0, 500)
        return true
    end
    -- Other control keys must reach CPTBase without Helix weapon/menu binds.
end

hook.Add("Think", "ixSCPViewReset", function() if not C.Controlled(LocalPlayer()) then cameraState = {} end end)

-- The old 079 HUD depends on NW1 possession flags whose other consumers are
-- broken in this addon version. Read the current controller and its counters.
hook.Add("HUDPaint", "ixSCP079Control", function()
    local npc = C.Controlled(LocalPlayer())
    if not npc or npc:GetClass() ~= "npc_cpt_scp_079" then return end
    local lines = {
        "SCP-079  |  E — вернуться к персонажу",
        string.format("Энергия: %d / %d  |  Уровень: %d", npc:GetNWInt("CPTBase_SCP079_AuxCount"),
            npc:GetNWInt("CPTBase_SCP079_MaxAuxCount"), npc:GetNWInt("CPTBase_SCP079_Tier")),
        string.format("Опыт: %d / %d  |  Заперто дверей: %d", npc:GetNWInt("CPTBase_SCP079_Experience"),
            npc:GetNWInt("CPTBase_SCP079_ExperienceMax"), npc:GetNWInt("CPTBase_SCP079_LockCount")),
        "SHIFT / CTRL — камеры  |  ЛКМ — активировать",
        "ПКМ — запереть  |  Пробел — отпереть всё"
    }
    if npc:GetNWBool("CPTBase_SCP079_OnCooldown") then lines[#lines + 1] = "Подождите…" end
    local x, y = 24, ScrH() - (#lines * 22 + 40)
    draw.RoundedBox(4, x - 10, y - 8, 520, #lines * 22 + 16, Color(0, 0, 0, 200))
    for i, line in ipairs(lines) do draw.SimpleText(line, "DermaDefault", x, y + (i - 1) * 22, Color(160, 220, 245)) end
end)
