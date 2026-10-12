local Q, UI = ix.questDirector, ix.questDirector.ui

-- Identical camera calculation for the editor and the player's portrait.
function Q:PortraitCamera(entity, camera)
    local anchor
    if camera.head then
        entity:SetupBones()
        local bone = entity:LookupBone("ValveBiped.Bip01_Head1")
        if bone then
            local matrix = entity:GetBoneMatrix(bone)
            if matrix then anchor = matrix:GetTranslation() end
        end
        if not anchor then
            local low, high = entity:GetRenderBounds()
            anchor = entity:LocalToWorld(Vector((low.x + high.x) * 0.5, (low.y + high.y) * 0.5, low.z + (high.z - low.z) * 0.88))
        end
    else anchor = entity:LocalToWorld(Vector(0, 0, 0)) end
    local target = anchor + Vector(camera.x, camera.y, camera.z)
    local yaw, pitch = math.rad(camera.yaw), math.rad(camera.pitch)
    local direction = Vector(math.cos(pitch) * math.cos(yaw), math.cos(pitch) * math.sin(yaw), math.sin(pitch))
    return target, target + direction * camera.distance
end

function Q:SetupPortrait(panel, getDefinition)
    panel:SetAmbientLight(Color(175, 175, 175))
    panel:SetDirectionalLight(BOX_FRONT, Color(230, 220, 205))
    panel:SetMouseInputEnabled(false)
    panel.Think = function(s)
        local row = getDefinition()
        local path = string.Trim(row.model or ""):lower()
        if s.requestedModel ~= path then
            s.requestedModel = path
            s.invalidModel = not path:match("^models/.+%.mdl$") or path:find("..", 1, true) or not file.Exists(path, "GAME")
            if not s.invalidModel then s:SetModel(path) s.lastSequence = nil end
        end
        s:SetAlpha(s.invalidModel and 60 or 255)
    end
    panel.LayoutEntity = function(s, entity)
        local row = getDefinition()
        entity:SetAngles(Angle(0, 0, 0))
        entity:SetSkin(row.skin or 0)
        for id, value in pairs(row.bodygroups or {}) do entity:SetBodygroup(tonumber(id), value) end
        for name, value in pairs(row.pose or {}) do entity:SetPoseParameter(name, value) end
        if s.lastSequence ~= row.sequence then
            local sequence = entity:LookupSequence(row.sequence or "idle_all_01")
            if sequence < 0 then sequence = entity:SelectWeightedSequence(ACT_IDLE) end
            entity:ResetSequence(math.max(sequence, 0)) entity:SetCycle(row.cycle or 0)
            s.lastSequence = row.sequence
        end
        if row.animate ~= false then s:RunAnimation() else entity:SetCycle(row.cycle or 0) end
        local camera = row.portrait or Q:CleanPortrait()
        local target, position = Q:PortraitCamera(entity, camera)
        s:SetLookAng(nil) s:SetLookAt(target) s:SetCamPos(position) s:SetFOV(camera.fov)
        s.FarZ = math.max(4096, camera.distance + 1024)
    end
    panel:Think()
end

function Q:EditNPCPortrait(sheet, row)
    local body = vgui.Create("DPanel", sheet) body.Paint = nil body:DockPadding(10, 8, 10, 8)
    sheet:AddSheet("Портрет диалога", body)
    row.portrait = row.portrait or self:CleanPortrait()
    local left = body:Add("DPanel") left:Dock(LEFT) left:SetWide(300) left:DockMargin(0, 0, 16, 0)
    left.Paint = function(_, w, h) draw.RoundedBox(0, 0, 0, w, h, Color(8, 9, 8)) end
    local preview = left:Add("DModelPanel")
    self:SetupPortrait(preview, function() return row end)
    local hint = left:Add("DLabel") hint:SetWrap(true) hint:SetAutoStretchVertical(true)
    hint:SetTextColor(color_white) hint:SetText("Так портрет увидит игрок. Настройте лицо, затем сохраните NPC. Для моделей без кости головы можно отключить привязку и задать точку вручную.")
    left.PerformLayout = function(s, w, h)
        local height = math.min(w * 1.15, math.max(100, h - 125))
        preview:SetPos(1, 1) preview:SetSize(w - 2, height)
        hint:SetPos(10, height + 14) hint:SetWide(w - 20)
    end
    body.PerformLayout = function(_, w) left:SetWide(math.Clamp(math.floor(w * 0.4), 180, 360)) end
    local controls = body:Add("DScrollPanel") controls:Dock(FILL)
    local function fill()
        controls:Clear()
        UI.Label(controls, "Камера портрета", true)
        UI.Label(controls, "Начните с привязки к голове. X — вперёд, Y — вбок, Z — вверх. Дистанция и угол обзора задают крупность лица; поворот и наклон — ракурс.")
        UI.Bool(controls, "Привязать точку к голове (иначе — к началу модели)", row.portrait, "head")
        for _, field in ipairs({{"x", "Смещение X", -512, 512}, {"y", "Смещение Y", -512, 512}, {"z", "Смещение Z", -512, 512},
            {"distance", "Дистанция", 8, 1024}, {"yaw", "Поворот камеры", -180, 180}, {"pitch", "Наклон камеры", -80, 80}, {"fov", "Угол обзора", 10, 80}}) do
            UI.Label(controls, field[2])
            local input = controls:Add("DNumSlider") input:Dock(TOP) input:SetTall(36)
            input:SetText("") input:SetMinMax(field[3], field[4]) input:SetDecimals(1) input:SetValue(row.portrait[field[1]])
            input.OnValueChanged = function(_, value) row.portrait[field[1]] = Q.Number(value, row.portrait[field[1]], field[3], field[4]) end
        end
        UI.Button(controls, "Сбросить камеру на лицо", function() row.portrait = Q:CleanPortrait() fill() end)
    end
    fill()
end
