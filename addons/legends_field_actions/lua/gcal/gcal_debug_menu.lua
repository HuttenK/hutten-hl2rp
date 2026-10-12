-- Debug menu commands for the current GCAL desktop-window menu.

if not CLIENT then return end

local function PrintPanelState(panel)
    print("GCAL.Menu.Panel valid:", IsValid(panel))
    if not IsValid(panel) then return end

    local window = IsValid(panel.GCALWindow) and panel.GCALWindow or panel:GetParent()
    print("Panel size:", panel:GetWide(), "x", panel:GetTall())
    print("Panel visible:", panel:IsVisible())
    print("Panel parent valid:", IsValid(panel:GetParent()))
    print("Panel position:", panel:GetX(), ",", panel:GetY())
    print("Window valid:", IsValid(window))

    if IsValid(window) then
        print("Window size:", window:GetWide(), "x", window:GetTall())
        print("Window visible:", window:IsVisible())
        print("Window parent valid:", IsValid(window:GetParent()))
        print("Window position:", window:GetX(), ",", window:GetY())
    end

    print("ActionsScroll valid:", IsValid(panel.ActionsScroll))
    print("ToggleScroll valid:", IsValid(panel.ToggleScroll))
    print("AnimsScroll valid:", IsValid(panel.AnimsScroll))
end

concommand.Add("gcal_debug_menu", function()
    print("===== GCAL MENU DEBUG =====")
    print("GCAL table exists:", GCAL ~= nil)
    print("GCAL.Menu exists:", GCAL and GCAL.Menu ~= nil)

    if not GCAL or not GCAL.Menu then
        print("ERROR: GCAL or GCAL.Menu not initialized!")
        print("===== END DEBUG =====")
        return
    end

    print("GCAL.Menu.Loaded:", GCAL.Menu.Loaded)
    print("GCAL.Menu.OpenFrame exists:", isfunction(GCAL.Menu.OpenFrame))
    print("GCAL.Menu.BuildWindow exists:", isfunction(GCAL.Menu.BuildWindow))
    print("GCAL.Menu.Refresh exists:", isfunction(GCAL.Menu.Refresh))
    print("GCAL.Menu.RegisterDesktopIcon exists:", isfunction(GCAL.Menu.RegisterDesktopIcon))

    local contextConVar = GetConVar("gcal_context_menu")
    print("ConVar 'gcal_context_menu' value:", contextConVar and contextConVar:GetString() or "NOT FOUND")

    local keepOpenConVar = GetConVar("gcal_menu_keep_open")
    print("ConVar 'gcal_menu_keep_open' value:", keepOpenConVar and keepOpenConVar:GetString() or "NOT FOUND")

    print("Registered animations:", table.Count(GCAL.Anims or {}))
    print("Active tracks:", table.Count(GCAL.ActiveTracks or {}))
    PrintPanelState(GCAL.Menu.Panel)

    print("\nAttempting GCAL.Menu.Refresh()...")
    local refreshSuccess, refreshError = pcall(GCAL.Menu.Refresh)
    print("Refresh succeeded:", refreshSuccess)
    if not refreshSuccess then
        print("Refresh error:", refreshError)
    end

    print("===== END DEBUG =====")
end)

concommand.Add("gcal_show_now", function()
    if not GCAL or not GCAL.Menu or not isfunction(GCAL.Menu.OpenFrame) then
        print("[GCAL ERROR] Current menu API not available!")
        return
    end

    local panel = GCAL.Menu.Panel
    local window = IsValid(panel) and (IsValid(panel.GCALWindow) and panel.GCALWindow or panel:GetParent()) or nil

    if not IsValid(window) then
        local success, frameOrError = pcall(GCAL.Menu.OpenFrame)
        if not success then
            print("[GCAL ERROR] Failed to open menu:", frameOrError)
            return
        end

        window = frameOrError
        panel = GCAL.Menu.Panel
    end

    if not IsValid(window) or not IsValid(panel) then
        print("[GCAL ERROR] Menu window or panel is not valid after opening!")
        return
    end

    window:SetVisible(true)
    if window.MakePopup then window:MakePopup() end
    if GCAL.Menu.DetachWindow then GCAL.Menu.DetachWindow(window) end
    GCAL.Menu.Refresh()

    print("[GCAL] Menu window opened and refreshed")
end)

concommand.Add("gcal_rebuild_menu", function()
    if not GCAL or not GCAL.Menu or not isfunction(GCAL.Menu.OpenFrame) then
        print("[GCAL ERROR] Current menu API not available!")
        return
    end

    local panel = GCAL.Menu.Panel
    local window = IsValid(panel) and (IsValid(panel.GCALWindow) and panel.GCALWindow or panel:GetParent()) or nil

    if IsValid(window) then
        window:Remove()
    end

    local success, frameOrError = pcall(GCAL.Menu.OpenFrame)
    if not success then
        print("[GCAL ERROR] Failed to rebuild menu:", frameOrError)
        return
    end

    print("[GCAL] Menu window rebuilt")
end)

print("[GCAL] Debug menu commands loaded: gcal_debug_menu, gcal_show_now, gcal_rebuild_menu")
