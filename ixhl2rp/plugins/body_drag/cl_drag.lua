local D = ix.BodyDrag
local function Request(release, entity)
    net.Start("ixBodyDragAction")
    net.WriteBool(release)
    if not release then net.WriteEntity(entity) end
    net.SendToServer()
end

function D.OpenMenu(entity)
    local client = LocalPlayer()
    local body = D.Body(client)
    if body and entity ~= body then return end
    if not body and not D.CanTarget(client, entity) then return end
    if IsValid(D.menu) then D.menu:Remove() end
    local menu = ix.SimpleMenu()
    D.menu = menu
    if body then
        menu:AddOption("ОТПУСТИТЬ ПЕРСОНАЖА", function()
            if D.Body(client) == body then Request(true) end
        end)
    else
        menu:AddOption("ВЗЯТЬ ЛЕВОЙ РУКОЙ", function() Request(false, entity) end)
        local patient = D.Patient(entity)
        if IsValid(patient) and patient:GetNetVar("crit", false) then
            local function Critical(slay)
                net.Start("crit.use")
                net.WriteEntity(entity)
                net.WriteBool(slay)
                net.SendToServer()
            end
            menu:AddOption("ОГРАБИТЬ", function() Critical(true) end)
            menu:AddOption("ДОБИТЬ", function() Critical(false) end)
        end
    end
    menu:AddOption("ОТМЕНА", function() end)
    menu:Open()
    menu:Center()
    return true
end

function D.HandleBind(client, bind, pressed)
    if not pressed or not bind:lower():find("+use", 1, true) then return end
    local trace = util.TraceLine({start = client:GetShootPos(),
        endpos = client:GetShootPos() + client:GetAimVector() * D.RANGE, filter = client, mask = MASK_SOLID})
    return D.OpenMenu(trace.Entity)
end

function PLUGIN:PlayerBindPress(client, bind, pressed)
    return D.HandleBind(client, bind, pressed)
end

hook.Add("HUDPaint", "ixBodyDragHint", function()
    if not D.Body(LocalPlayer()) then return end
    local key = string.upper(input.LookupBinding("+use") or "E")
    draw.SimpleTextOutlined(key .. " на персонаже — отпустить · Перезарядка недоступна", "ixCrit",
        ScrW() * 0.5, ScrH() * 0.84, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
end)
