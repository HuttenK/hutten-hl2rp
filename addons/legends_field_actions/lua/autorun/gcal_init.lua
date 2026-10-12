--[[
   █████████    █████████    █████████   █████      
  ███▒▒▒▒▒███  ███▒▒▒▒▒███  ███▒▒▒▒▒███ ▒▒███       
 ███     ▒▒▒  ███     ▒▒▒  ▒███    ▒███  ▒███       
▒███         ▒███          ▒███████████  ▒███       
▒███    █████▒███          ▒███▒▒▒▒▒███  ▒███       
▒▒███  ▒▒███ ▒▒███     ███ ▒███    ▒███  ▒███      █
 ▒▒█████████  ▒▒█████████  █████   █████ ███████████
  ▒▒▒▒▒▒▒▒▒    ▒▒▒▒▒▒▒▒▒  ▒▒▒▒▒   ▒▒▒▒▒ ▒▒▒▒▒▒▒▒▒▒▒ 
                                                    
                                                    
                                                    
        Garry's Mod Compliant Armature Layer
    Loking at the code? You can find it on github!
    https://github.com/Midawek/gcal
    Looking on how to make a gcal addon? Please use the wiki!
    https://midawek.xyz/gcal/wiki
]]


if SERVER then
    AddCSLuaFile("gcal/gcal_lerp.lua")
    AddCSLuaFile("gcal/gcal_tpik.lua")
    AddCSLuaFile("gcal/gcal_core.lua")
    AddCSLuaFile("gcal/gcal_compat.lua")
    AddCSLuaFile("gcal/gcal_legs.lua")
    AddCSLuaFile("gcal/gcal_base_anims.lua")
    AddCSLuaFile("gcal/gcal_menu.lua")
    AddCSLuaFile("gcal/gcal_debug_menu.lua")
    AddCSLuaFile("autorun/client/gcal_menu_autorun.lua")
end

-- Kept script-local so error diagnostics and conflict detection share one source.
local conflictingWorkshopAddons = {
    ["2155366756"] = "VManip (Base)",
    ["3262499127"] = "Chen's VManip Patch",
    ["3080114310"] = "VManip (Base) Remix 2024",
    ["3039950711"] = "VManip (Fix_and_function)",
    ["3425927104"] = "Vmanip Base with knockdown",
    ["2844472642"] = "Vmanip +",
    ["3714993549"] = "Vmanip (Lite)",
    ["349050451"] = "Chuck's Weaponry 2.0",
    ["3627079098"] = "VManip Legs Fix"
    -- ["1234567890"] = "Example Addon"
}

local function GCAL_MatchesOwnPath(value)
    value = string.lower(tostring(value or ""))
    return string.find(value, "addons/gcal/", 1, true) ~= nil
        or string.find(value, "addons\\gcal\\", 1, true) ~= nil
        or string.find(value, "lua/gcal/", 1, true) ~= nil
        or string.find(value, "lua\\gcal\\", 1, true) ~= nil
        or string.find(value, "gcal_init.lua", 1, true) ~= nil
end

local function GCAL_IsOwnLuaError(errorMessage, stack, addonName)
    if GCAL_MatchesOwnPath(errorMessage) then return true end

    local normalizedAddonName = string.lower(tostring(addonName or ""))
    if normalizedAddonName == "gcal" or string.find(normalizedAddonName, "compliant armature layer", 1, true) then
        return true
    end

    for _, frame in pairs(istable(stack) and stack or {}) do
        if GCAL_MatchesOwnPath(frame) then return true end

        if istable(frame) then
            for _, value in pairs(frame) do
                if GCAL_MatchesOwnPath(value) then return true end
            end
        end
    end

    return false
end

local function GCAL_KnownConflictLabel(addonName, addonID)
    addonID = tostring(addonID or "")
    if conflictingWorkshopAddons[addonID] then
        return conflictingWorkshopAddons[addonID], addonID
    end

    local normalizedName = string.lower(string.Trim(tostring(addonName or "")))
    if normalizedName == "" then return nil end

    for workshopID, label in pairs(conflictingWorkshopAddons) do
        if normalizedName == string.lower(label) then return label, workshopID end
    end
end

local function GCAL_ErrorFrameDetails(stack)
    local firstFrame
    local externalFrame

    for _, frame in ipairs(istable(stack) and stack or {}) do
        local file
        local line
        local func

        if istable(frame) then
            file = frame.File or frame.file or frame.Source or frame.source
            line = frame.Line or frame.line
            func = frame.Function or frame.func or frame.Name or frame.name
        elseif isstring(frame) then
            file = frame
        end

        if file and tostring(file) ~= "[C]" then
            local detail = tostring(file)
            if line and tonumber(line) and tonumber(line) >= 0 then
                detail = detail .. ":" .. tostring(line)
            end
            if func and tostring(func) ~= "" then
                detail = detail .. " in " .. tostring(func)
            end

            firstFrame = firstFrame or detail
            if not GCAL_MatchesOwnPath(file) then
                externalFrame = externalFrame or detail
            end
        end
    end

    return firstFrame, externalFrame
end

local function GCAL_MountedConflictLabels()
    if not CLIENT or not engine or not engine.GetAddons then return {} end

    local mounted = {}
    for _, addon in ipairs(engine.GetAddons()) do
        local workshopID = tostring(addon.wsid or "")
        local label = conflictingWorkshopAddons[workshopID]
        if label and addon.mounted then
            mounted[#mounted + 1] = label .. " [" .. workshopID .. "]"
        end
    end

    table.sort(mounted)
    return mounted
end

local gcalLastErrorNotice = 0
hook.Add("OnLuaError", "GCAL_UnhandledException", function(errorMessage, realm, stack, addonName, addonID)
    local conflictLabel, conflictID = GCAL_KnownConflictLabel(addonName, addonID)
    if not GCAL_IsOwnLuaError(errorMessage, stack, addonName) and not conflictLabel then return end

    local firstFrame, externalFrame = GCAL_ErrorFrameDetails(stack)
    local mountedConflicts = GCAL_MountedConflictLabels()

    MsgC(
        Color(236, 116, 121),
        "[GCAL] An unexpected " .. tostring(realm or "Lua") .. " error occurred. ",
        Color(239, 243, 248),
        tostring(errorMessage or "Unknown error") .. "\n"
    )

    if addonName or addonID then
        MsgC(
            Color(151, 163, 177),
            "[GCAL] Engine attribution: " .. tostring(addonName or "unknown addon") ..
                (addonID and (" [" .. tostring(addonID) .. "]") or "") .. "\n"
        )
    end
    if firstFrame then
        MsgC(Color(151, 163, 177), "[GCAL] First Lua frame: " .. firstFrame .. "\n")
    end
    if externalFrame then
        MsgC(Color(255, 176, 93), "[GCAL] First external frame: " .. externalFrame .. "\n")
    end
    if conflictLabel then
        MsgC(
            Color(236, 116, 121),
            "[GCAL] Known conflict implicated by engine attribution: " .. conflictLabel ..
                " [" .. tostring(conflictID) .. "]\n"
        )
    elseif #mountedConflicts > 0 then
        MsgC(
            Color(255, 176, 93),
            "[GCAL] Known conflicts currently mounted (context only, not proof): " ..
                table.concat(mountedConflicts, ", ") .. "\n"
        )
    end

    if CLIENT and notification and notification.AddLegacy and CurTime() >= gcalLastErrorNotice then
        gcalLastErrorNotice = CurTime() + 5
        local notice = conflictLabel
            and ("GCAL error may involve " .. conflictLabel .. ". Check the console.")
            or "GCAL encountered an error. Check the console for trace details."
        notification.AddLegacy(notice, NOTIFY_ERROR, 6)
        if surface and surface.PlaySound then
            surface.PlaySound("buttons/button10.wav")
        end
    end
end)

if CLIENT then
    concommand.Add("gcal_debug_unhandled_error", function(_, _, args)
        if string.lower(tostring(args[1] or "")) == "conflict" then
            local workshopID = "2155366756"
            local label = conflictingWorkshopAddons[workshopID]
            MsgC(Color(255, 176, 93), "[GCAL] Triggering a synthetic known-conflict attribution report.\n")
            hook.Run(
                "OnLuaError",
                "Synthetic GCAL conflict-correlation test. No addon actually failed.",
                "client",
                {
                    {File = "addons/gcal/lua/autorun/gcal_init.lua", Line = 1, Function = "debug_test"},
                    {File = "addons/vmanip/lua/autorun/client/cl_vmanip.lua", Line = 1, Function = "debug_test"}
                },
                label,
                workshopID
            )
            return
        end

        MsgC(Color(255, 176, 93), "[GCAL] Triggering a deliberate clientside Lua error for handler testing.\n")

        timer.Simple(0, function()
            error("Deliberate GCAL unhandled-error test. This error is expected.")
        end)
    end, nil, "Test GCAL error reporting. Use 'gcal_debug_unhandled_error conflict' to simulate known-conflict attribution.")
end

if CLIENT then
    GCAL = GCAL or {}
    if not GetConVar("gcal_conflict_popup") then
        CreateClientConVar("gcal_conflict_popup", "1", true, false, "Show GCAL's conflict warning popup when incompatible addons are detected.")
    end

    function GCAL:RegisterConflictingWorkshopAddon(workshopID, label)
        workshopID = tostring(workshopID or "")
        if workshopID == "" then return end

        conflictingWorkshopAddons[workshopID] = label or ("Workshop addon " .. workshopID)
    end

    local function GetMountedConflictingWorkshopAddons()
        local found = {}

        for _, addon in ipairs(engine.GetAddons()) do
            local workshopID = tostring(addon.wsid or "")
            local label = conflictingWorkshopAddons[workshopID]

            if label and addon.mounted then
                found[#found + 1] = {
                    id = workshopID,
                    label = label,
                    display = label .. " [" .. workshopID .. "]"
                }
            end
        end

        table.sort(found, function(a, b)
            return a.display < b.display
        end)
        return found
    end

    local function ConflictPopupEnabled()
        local convar = GetConVar("gcal_conflict_popup")
        return convar == nil or convar:GetBool()
    end

    local conflictPopupFrame
    local conflictPopupDim

    local function ShowConflictPopup(hasLegacyFile, mountedConflicts)
        mountedConflicts = istable(mountedConflicts) and mountedConflicts or {}

        if IsValid(conflictPopupFrame) then conflictPopupFrame:Remove() end
        if IsValid(conflictPopupDim) then conflictPopupDim:Remove() end

        local colBg = Color(14, 16, 21, 242)
        local colPanel = Color(22, 25, 32, 248)
        local colPanelSoft = Color(30, 35, 44, 238)
        local colHeader = Color(27, 33, 41, 245)
        local colLine = Color(110, 126, 148, 78)
        local colText = Color(239, 243, 248)
        local colMuted = Color(151, 163, 177)
        local colAccent = Color(102, 207, 177)
        local colWarn = Color(241, 181, 103)
        local colBad = Color(236, 116, 121)
        local logoMaterial = Material("gcal/logo", "smooth")
        local prideLogoMaterial = Material("gcal/pridelogo", "smooth")
        local defaultAccent = Color(102, 207, 177)
        local prideColors = {
            Color(228, 3, 3),
            Color(255, 140, 0),
            Color(255, 237, 0),
            Color(0, 128, 38),
            Color(0, 77, 255),
            Color(117, 7, 135)
        }

        local function PrideEnabled()
            local prideConVar = GetConVar("gcal_pride")
            return prideConVar and prideConVar:GetBool() or false
        end

        local function PrideGradientColor(fraction)
            local scaled = (fraction % 1) * #prideColors
            local index = math.floor(scaled) + 1
            local blend = scaled - math.floor(scaled)
            local from = prideColors[index]
            local to = prideColors[index % #prideColors + 1]

            return Color(
                Lerp(blend, from.r, to.r),
                Lerp(blend, from.g, to.g),
                Lerp(blend, from.b, to.b)
            )
        end

        local function UpdatePrideAccent()
            if PrideEnabled() then
                local rainbow = HSVToColor((RealTime() * 55) % 360, 0.72, 1)
                colAccent.r = rainbow.r
                colAccent.g = rainbow.g
                colAccent.b = rainbow.b
                return
            end

            colAccent.r = defaultAccent.r
            colAccent.g = defaultAccent.g
            colAccent.b = defaultAccent.b
        end

        local function PaintPrideLine(x, y, width, height)
            if not PrideEnabled() then
                surface.SetDrawColor(colAccent.r, colAccent.g, colAccent.b, 120)
                surface.DrawRect(x, y, width, height)
                return
            end

            local phase = (RealTime() * 0.12) % 1
            local sliceWidth = 4
            for sliceX = 0, width - 1, sliceWidth do
                local color = PrideGradientColor((sliceX / math.max(width, 1) + phase) % 1)
                surface.SetDrawColor(color)
                surface.DrawRect(x + sliceX, y, math.min(sliceWidth, width - sliceX), height)
            end
        end

        local function DrawPrideTitle(panel, text, font, x, y)
            if not PrideEnabled() then
                draw.SimpleText(text, font, x, y, colText, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                return
            end

            surface.SetFont(font)
            local textWidth, textHeight = surface.GetTextSize(text)
            local screenX, screenY = panel:LocalToScreen(x, y)
            local phase = (RealTime() * 0.12) % 1
            local stripeWidth = 3

            for stripeX = 0, textWidth - 1, stripeWidth do
                local color = PrideGradientColor((stripeX / math.max(textWidth - 1, 1) + phase) % 1)
                render.SetScissorRect(
                    screenX + stripeX,
                    screenY,
                    math.min(screenX + stripeX + stripeWidth, screenX + textWidth),
                    screenY + textHeight,
                    true
                )
                draw.SimpleText(text, font, x, y, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end

            render.SetScissorRect(0, 0, 0, 0, false)
        end

        local function PaintConflictButton(btn, w, h)
            UpdatePrideAccent()
            btn.GCALHover = Lerp(FrameTime() * 12, btn.GCALHover or 0, btn:IsHovered() and 1 or 0)

            local a = btn.GCALHover
            local accent = btn.GCALAccent or colAccent
            local fill = Color(
                Lerp(a, colPanelSoft.r, accent.r * 0.45),
                Lerp(a, colPanelSoft.g, accent.g * 0.45),
                Lerp(a, colPanelSoft.b, accent.b * 0.45),
                225
            )

            draw.RoundedBox(5, 0, 0, w, h, fill)
            surface.SetDrawColor(accent.r, accent.g, accent.b, 50 + a * 90)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.RoundedBox(2, 8, 8, 3, h - 16, Color(accent.r, accent.g, accent.b, 160 + a * 60))
            draw.SimpleText(btn.GCALText or "", "GCAL.Menu.Body", 19, h * 0.5 - 1, colText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local lines = {
            "Conflicting addons were detected.",
            "Please disable them to prevent issues.",
            "GCAL won't work with those properly. It doesn't stop any code execution and you're free to use GCAL with them, but expect various issues.",
            "If you post a bug/issue with any of these addons on, you'll get laughed at and/or ignored. So please disable them before reporting issues regarding GCAL.",
        }

        if hasLegacyFile then
            lines[#lines + 1] = ""
            lines[#lines + 1] = "Legacy VManip files were also detected."
        end

        if #mountedConflicts > 0 then
            lines[#lines + 1] = ""
            lines[#lines + 1] = "Mounted Workshop conflicts:"

            for _, addon in ipairs(mountedConflicts) do
                lines[#lines + 1] = " - " .. addon.display
            end
        end

        surface.PlaySound("buttons/button10.wav")

        local dim = vgui.Create("DPanel")
        conflictPopupDim = dim
        dim:SetSize(ScrW(), ScrH())
        dim:MakePopup()
        dim:SetKeyboardInputEnabled(false)
        dim:SetMouseInputEnabled(false)
        function dim:Paint(w, h)
            draw.RoundedBox(0, 0, 0, w, h, Color(2, 4, 8, 178))
        end

        local frame = vgui.Create("DFrame")
        conflictPopupFrame = frame
        frame:SetTitle("")
        frame:SetSize(math.min(ScrW() - 80, 760), math.min(ScrH() - 70, 680))
        frame:Center()
        frame:MakePopup()
        frame:SetSizable(false)
        frame:SetDraggable(true)
        frame.StartTime = SysTime()
        if IsValid(frame.btnMinim) then
            frame.btnMinim:SetVisible(false)
            frame.btnMinim:SetEnabled(false)
        end
        if IsValid(frame.btnMaxim) then
            frame.btnMaxim:SetVisible(false)
            frame.btnMaxim:SetEnabled(false)
        end
        frame.OnClose = function()
            if IsValid(dim) then
                dim:Remove()
            end
            conflictPopupFrame = nil
            conflictPopupDim = nil
        end

        function frame:Paint(w, h)
            UpdatePrideAccent()
            Derma_DrawBackgroundBlur(self, self.StartTime)
            draw.RoundedBox(0, 0, 0, w, h, colBg)
            draw.RoundedBox(0, 1, 1, w - 2, h - 2, colPanel)
            draw.RoundedBox(0, 1, 1, w - 2, 92, colHeader)
            PaintPrideLine(10, 0, w - 20, PrideEnabled() and 3 or 1)
            surface.SetDrawColor(colLine)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            surface.DrawLine(16, 92, w - 16, 92)

            local titleX = 16
            local prideEnabled = PrideEnabled()
            local activeLogoMaterial = prideEnabled and prideLogoMaterial or logoMaterial
            if not activeLogoMaterial:IsError() then
                local logoAspect = activeLogoMaterial:Width() / math.max(activeLogoMaterial:Height(), 1)
                local logoMaxWidth = 112
                local logoMaxHeight = 58
                local logoWidth = math.min(logoMaxWidth, logoMaxHeight * logoAspect)
                local logoHeight = logoWidth / math.max(logoAspect, 0.01)
                local logoY = 15 + (logoMaxHeight - logoHeight) * 0.5
                local logoX = 16

                surface.SetMaterial(activeLogoMaterial)
                surface.SetDrawColor(255, 255, 255, prideEnabled and 245 or 235)
                surface.DrawTexturedRect(logoX, logoY, logoWidth, logoHeight)

                titleX = 16 + math.min(logoMaxWidth, logoMaxHeight * logoAspect) + 14
            end

            DrawPrideTitle(self, "GCAL Conflict Warning", "GCAL.Menu.Title", titleX, 15)
            draw.SimpleText("Conflicting addons can break GCAL in unexpected ways!", "GCAL.Menu.Subtitle", titleX + 1, 47, colMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            local pillText = tostring((hasLegacyFile and 1 or 0) + #mountedConflicts) .. " detected"
            draw.RoundedBox(5, w - 124, 18, 98, 22, Color(colWarn.r, colWarn.g, colWarn.b, 26))
            surface.SetDrawColor(colWarn.r, colWarn.g, colWarn.b, 150)
            surface.DrawOutlinedRect(w - 124, 18, 98, 22, 1)
            draw.SimpleText(pillText, "GCAL.Menu.Small", w - 75, 28, colWarn, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        local content = vgui.Create("DScrollPanel", frame)
        content:Dock(FILL)
        content:DockMargin(16, 108, 16, 104)

        local bar = content:GetVBar()
        bar:SetWide(5)
        bar.Paint = nil
        bar.btnUp.Paint = nil
        bar.btnDown.Paint = nil
        bar.btnGrip.Paint = function(_, w, h)
            draw.RoundedBox(3, 0, 0, w, h, Color(colAccent.r, colAccent.g, colAccent.b, 115))
        end

        for _, line in ipairs(lines) do
            if line == "" then
                local spacer = content:Add("DPanel")
                spacer:Dock(TOP)
                spacer:SetTall(8)
                spacer:SetPaintBackground(false)
            else
                local row = content:Add("DPanel")
                row:Dock(TOP)
                row:DockMargin(0, 0, 0, 6)
                row:SetTall(34)
                row.GCALText = line
                row.GCALAccent = string.StartsWith(line, " - ") and colMuted or colWarn

                local label = vgui.Create("DLabel", row)
                label:Dock(FILL)
                label:DockMargin(19, 7, 10, 7)
                label:SetWrap(true)
                label:SetAutoStretchVertical(true)
                label:SetFont("GCAL.Menu.Body")
                label:SetTextColor(string.StartsWith(line, " - ") and colMuted or colText)
                label:SetText(line)

                row.PerformLayout = function(self, w)
                    label:SetWide(math.max(w - 29, 1))
                    label:SizeToContentsY()
                    self:SetTall(math.max(34, label:GetTall() + 14))
                end

                row.Paint = function(self, w, h)
                    draw.RoundedBox(5, 0, 0, w, h, Color(colPanelSoft.r, colPanelSoft.g, colPanelSoft.b, 150))
                    surface.SetDrawColor(self.GCALAccent.r, self.GCALAccent.g, self.GCALAccent.b, 48)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                    draw.RoundedBox(2, 8, 8, 3, h - 16, Color(self.GCALAccent.r, self.GCALAccent.g, self.GCALAccent.b, 110))
                end
            end
        end

        local workshopButton = vgui.Create("DButton", frame)
        workshopButton:Dock(BOTTOM)
        workshopButton:DockMargin(16, 0, 16, 8)
        workshopButton:SetTall(34)
        workshopButton:SetText("")
        workshopButton.GCALText = "Open Subscribed Addons"
        workshopButton.GCALAccent = colAccent
        workshopButton.Paint = PaintConflictButton
        workshopButton.DoClick = function()
            surface.PlaySound("ui/buttonclickrelease.wav")
            local ply = LocalPlayer()
            local steamID64 = IsValid(ply) and ply:SteamID64() or ""
            if steamID64 == "" then
                gui.OpenURL("https://steamcommunity.com/workshop/browse/?appid=4000")
                return
            end

            gui.OpenURL("https://steamcommunity.com/profiles/" .. steamID64 .. "/myworkshopfiles?appid=4000&browsefilter=mysubscriptions")
        end

        local closeButton = vgui.Create("DButton", frame)
        closeButton:Dock(BOTTOM)
        closeButton:DockMargin(16, 0, 16, 16)
        closeButton:SetTall(34)
        closeButton:SetText("")
        closeButton.GCALText = "I know what I am doing, close this warning."
        closeButton.GCALAccent = colBad
        closeButton.Paint = PaintConflictButton
        closeButton.DoClick = function()
            surface.PlaySound("ui/buttonclickrelease.wav")
            frame:Close()
        end

        local suppressCheck = vgui.Create("DCheckBoxLabel", frame)
        suppressCheck:Dock(BOTTOM)
        suppressCheck:DockMargin(18, 0, 16, 8)
        suppressCheck:SetTall(24)
        suppressCheck:SetText("Do not show this popup again")
        suppressCheck:SetTextColor(colMuted)
        suppressCheck:SetFont("GCAL.Menu.Body")
        suppressCheck:SetChecked(not ConflictPopupEnabled())
        suppressCheck.OnChange = function(_, checked)
            RunConsoleCommand("gcal_conflict_popup", checked and "0" or "1")
        end

        return frame
    end

    local function TryShowConflictPopup(hasLegacyFile, mountedConflicts)
        local success, result = xpcall(function()
            return ShowConflictPopup(hasLegacyFile, mountedConflicts)
        end, debug.traceback)

        if success then return true, result end

        if IsValid(conflictPopupFrame) then conflictPopupFrame:Remove() end
        if IsValid(conflictPopupDim) then conflictPopupDim:Remove() end
        conflictPopupFrame = nil
        conflictPopupDim = nil

        MsgC(Color(236, 116, 121), "[GCAL] Conflict popup failed to open:\n")
        MsgC(Color(239, 243, 248), tostring(result) .. "\n")
        return false, result
    end

    include("gcal/gcal_lerp.lua")
    include("gcal/gcal_core.lua")
    include("gcal/gcal_menu.lua")
    include("gcal/gcal_compat.lua")
    include("gcal/gcal_legs.lua")
    include("gcal/gcal_base_anims.lua")
    include("gcal/gcal_debug_menu.lua")
    
    print("GCAL (Client) Initialized! :3")

    timer.Simple(1, function()
        local prideConVar = GetConVar("gcal_pride")
        if not prideConVar or not prideConVar:GetBool() then return end

        local prideColors = {
            Color(228, 3, 3),
            Color(255, 140, 0),
            Color(255, 237, 0),
            Color(0, 180, 65),
            Color(70, 130, 255),
            Color(170, 80, 210)
        }

        local function PrideChatColor(fraction)
            local scaled = math.Clamp(fraction, 0, 1) * (#prideColors - 1)
            local index = math.min(math.floor(scaled) + 1, #prideColors - 1)
            local blend = scaled - math.floor(scaled)
            local from = prideColors[index]
            local to = prideColors[index + 1]
            local lighten = 0.38

            return Color(
                Lerp(lighten, Lerp(blend, from.r, to.r), 255),
                Lerp(lighten, Lerp(blend, from.g, to.g), 255),
                Lerp(lighten, Lerp(blend, from.b, to.b), 255)
            )
        end

        local function AddPrideChatLine(text)
            local parts = {}
            local length = #text

            for i = 1, length do
                parts[#parts + 1] = PrideChatColor((i - 1) / math.max(length - 1, 1))
                parts[#parts + 1] = string.sub(text, i, i)
            end

            chat.AddText(unpack(parts))
        end

        AddPrideChatLine("GCAL proudly stands with LGBTQ+ players and creators.")
        AddPrideChatLine("You are welcome here. You belong here. Be yourself.")
    end)

    -- Conflict Detection Notice
    timer.Simple(1, function()
        local mountedConflicts = GetMountedConflictingWorkshopAddons()
        local hasLegacyFile = file.Exists("autorun/client/cl_vmanip.lua", "LUA")

        if hasLegacyFile or #mountedConflicts > 0 then
            local msg = "!!! GCAL WARNING: Conflicting Workshop addons detected! !!!"
            local msg2 = "Please disable the conflicting Workshop addons. Info in the popup."
            
            MsgC(Color(255, 0, 0), msg .. "\n")
            MsgC(Color(255, 255, 255), msg2 .. "\n")

            if #mountedConflicts > 0 then
                local displays = {}
                for _, addon in ipairs(mountedConflicts) do
                    displays[#displays + 1] = addon.display
                end
                MsgC(Color(255, 176, 93), "[GCAL] Conflicting mounted Workshop addons: " .. table.concat(displays, ", ") .. "\n")
            end

            if ConflictPopupEnabled() then
                TryShowConflictPopup(hasLegacyFile, mountedConflicts)
            else
                MsgC(Color(151, 163, 177), "[GCAL] Conflict popup is disabled. Run gcal_conflict_popup 1 to show it again on startup.\n")
            end
        end
    end)

    concommand.Add("gcal_debug_conflict_popup", function()
        local mountedConflicts = GetMountedConflictingWorkshopAddons()
        local hasLegacyFile = file.Exists("autorun/client/cl_vmanip.lua", "LUA")

        if not hasLegacyFile and #mountedConflicts == 0 then
            mountedConflicts = {
                {
                    id = "debug",
                    label = "Forced debug preview",
                    display = "Forced debug preview [not a real conflict]"
                }
            }
        end

        TryShowConflictPopup(hasLegacyFile, mountedConflicts)
    end, nil, "Force-open the GCAL conflict popup for debugging.")
end

if SERVER then
    util.AddNetworkString("GCAL_Play")
    util.AddNetworkString("GCAL_Stop")
    
    -- Backward compatibility networking
    util.AddNetworkString("VManip_SimplePlay")
    util.AddNetworkString("VManip_StopHold")

    include("gcal/gcal_lerp.lua")
    include("gcal/gcal_core.lua")
    include("gcal/gcal_compat.lua")
    include("gcal/gcal_base_anims.lua")
    
    print("GCAL (Server) Initialized! :3")

    concommand.Add("gcal_menu_open", function(ply)
        if IsValid(ply) then
            ply:ConCommand("gcal_menu_open")
        else
            print("GCAL menu is clientside. Run gcal_menu_open from a player console.")
        end
    end)
end
