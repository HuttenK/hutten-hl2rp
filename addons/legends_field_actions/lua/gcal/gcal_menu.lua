-- GCAL context menu

if not CLIENT then return end

GCAL = GCAL or {}
GCAL.Menu = GCAL.Menu or {}

if GCAL.Menu.Loaded then return end
GCAL.Menu.Loaded = true

-- Initialize ConVar, defaulting if needed
CreateClientConVar("gcal_context_menu", "1", true, false, "Legacy toggle for the old GCAL context panel.")
CreateClientConVar("gcal_menu_keep_open", "1", true, false, "Keep the GCAL desktop window open after releasing the context menu key.")
if not GetConVar("gcal_conflict_popup") then
    CreateClientConVar("gcal_conflict_popup", "1", true, false, "Show GCAL's conflict warning popup when incompatible addons are detected.")
end
local prideConVar = GetConVar("gcal_pride")
if not prideConVar then
    prideConVar = CreateClientConVar("gcal_pride", "0", true, false, "Enable GCAL's hidden pride theme.")
end
for _, adjustmentConVar in ipairs({
    {"gcal_anim_offset_x", "Global GCAL animation forward/back offset."},
    {"gcal_anim_offset_y", "Global GCAL animation right/left offset."},
    {"gcal_anim_offset_z", "Global GCAL animation up/down offset."},
    {"gcal_anim_angle_p", "Global GCAL animation pitch offset."},
    {"gcal_anim_angle_y", "Global GCAL animation yaw offset."},
    {"gcal_anim_angle_r", "Global GCAL animation roll offset."},
    {"gcal_tpik_offset_x", "Global GCAL thirdperson TPIK forward/back offset."},
    {"gcal_tpik_offset_y", "Global GCAL thirdperson TPIK right/left offset."},
    {"gcal_tpik_offset_z", "Global GCAL thirdperson TPIK up/down offset."},
    {"gcal_tpik_angle_p", "Global GCAL thirdperson TPIK pitch offset."},
    {"gcal_tpik_angle_y", "Global GCAL thirdperson TPIK yaw offset."},
    {"gcal_tpik_angle_r", "Global GCAL thirdperson TPIK roll offset."},
    {"gcal_tpik_target_radius_add", "Global GCAL thirdperson TPIK target radius adjustment."},
    {"gcal_tpik_pole_source_add", "Global GCAL thirdperson TPIK source pole blend adjustment."},
    {"gcal_tpik_pole_native_add", "Global GCAL thirdperson TPIK native pole blend adjustment."},
    {"gcal_tpik_smoothing_add", "Global GCAL thirdperson TPIK smoothing adjustment."}
}) do
    if not GetConVar(adjustmentConVar[1]) then
        CreateClientConVar(adjustmentConVar[1], "0", true, false, adjustmentConVar[2])
    end
end

local PANEL_PAD = 16

surface.CreateFont("GCAL.Menu.Title", {
    font = "Trebuchet24",
    size = 26,
    weight = 900,
    extended = true
})

surface.CreateFont("GCAL.Menu.Subtitle", {
    font = "Trebuchet24",
    size = 14,
    weight = 700,
    extended = true
})

surface.CreateFont("GCAL.Menu.Body", {
    font = "Trebuchet24",
    size = 15,
    weight = 500,
    extended = true
})

surface.CreateFont("GCAL.Menu.Small", {
    font = "Trebuchet24",
    size = 13,
    weight = 700,
    extended = true
})

local colBg = Color(14, 16, 21, 242)
local colPanel = Color(22, 25, 32, 248)
local colPanelSoft = Color(30, 35, 44, 238)
local colColumn = Color(19, 22, 28, 205)
local colHeader = Color(27, 33, 41, 245)
local colLine = Color(110, 126, 148, 78)
local colText = Color(239, 243, 248)
local colMuted = Color(151, 163, 177)
local colAccent = Color(102, 207, 177)
local colWarn = Color(241, 181, 103)
local colBad = Color(236, 116, 121)
local colFrame = Color(10, 12, 16, 252)
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
    return prideConVar and prideConVar:GetBool() or false
end

local PrideGradientColor

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

PrideGradientColor = function(fraction)
    fraction = fraction % 1

    local scaled = fraction * #prideColors
    local index = math.floor(scaled) + 1
    local blend = scaled - math.floor(scaled)
    local from = prideColors[index]
    local to = prideColors[index % #prideColors + 1]

    return Color(
        Lerp(blend, from.r, to.r),
        Lerp(blend, from.g, to.g),
        Lerp(blend, from.b, to.b),
        255
    )
end

local function DrawPrideTitle(panel, text, font, x, y, fallbackColor)
    if not PrideEnabled() then
        draw.SimpleText(text, font, x, y, fallbackColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        return
    end

    surface.SetFont(font)
    local textWidth, textHeight = surface.GetTextSize(text)
    local screenX, screenY = panel:LocalToScreen(x, y)
    local stripeWidth = 3
    local phase = (RealTime() * 0.12) % 1

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

hook.Add("Think", "GCAL_MenuPrideAccent", function()
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
end)

local function PaintPill(x, y, w, h, color, text)
    draw.RoundedBox(5, x, y, w, h, Color(color.r, color.g, color.b, 26))
    surface.SetDrawColor(color.r, color.g, color.b, 150)
    surface.DrawOutlinedRect(x, y, w, h, 1)
    draw.SimpleText(text, "GCAL.Menu.Small", x + w * 0.5, y + h * 0.5 - 1, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function SortedAnimNames()
    local names = {}

    for name in pairs(GCAL.Anims or {}) do
        names[#names + 1] = name
    end

    table.sort(names, function(a, b)
        return string.lower(tostring(a)) < string.lower(tostring(b))
    end)

    return names
end

local function TrackCount()
    return table.Count(GCAL.ActiveTracks or {})
end

local function FirstTrackName()
    for id, track in pairs(GCAL.ActiveTracks or {}) do
        return tostring(id), track and tostring(track.name or "unknown") or "unknown"
    end

    return nil, nil
end

local function StopAllTracks()
    for id in pairs(GCAL.ActiveTracks or {}) do
        GCAL:StopTrack(id)
    end
end

GCAL.Menu.DisabledAnims = GCAL.Menu.DisabledAnims or {}
GCAL.Menu.CollapsedAddonGroups = GCAL.Menu.CollapsedAddonGroups or {}
GCAL.Menu.SoundOverrides = GCAL.Menu.SoundOverrides or {}
GCAL.Menu.AnimSearch = GCAL.Menu.AnimSearch or ""

local adjustmentFields = {
    {key = "pos_x", convar = "gcal_anim_offset_x", label = "Offset X", min = -20, max = 20, decimals = 2},
    {key = "pos_y", convar = "gcal_anim_offset_y", label = "Offset Y", min = -20, max = 20, decimals = 2},
    {key = "pos_z", convar = "gcal_anim_offset_z", label = "Offset Z", min = -20, max = 20, decimals = 2},
    {key = "ang_p", convar = "gcal_anim_angle_p", label = "Pitch", min = -45, max = 45, decimals = 1},
    {key = "ang_y", convar = "gcal_anim_angle_y", label = "Yaw", min = -45, max = 45, decimals = 1},
    {key = "ang_r", convar = "gcal_anim_angle_r", label = "Roll", min = -45, max = 45, decimals = 1}
}

local tpikAdjustmentFields = {
    {key = "tpik_pos_x", convar = "gcal_tpik_offset_x", label = "TPIK Offset X", min = -20, max = 20, decimals = 2},
    {key = "tpik_pos_y", convar = "gcal_tpik_offset_y", label = "TPIK Offset Y", min = -20, max = 20, decimals = 2},
    {key = "tpik_pos_z", convar = "gcal_tpik_offset_z", label = "TPIK Offset Z", min = -20, max = 20, decimals = 2},
    {key = "tpik_ang_p", convar = "gcal_tpik_angle_p", label = "TPIK Pitch", min = -45, max = 45, decimals = 1},
    {key = "tpik_ang_y", convar = "gcal_tpik_angle_y", label = "TPIK Yaw", min = -45, max = 45, decimals = 1},
    {key = "tpik_ang_r", convar = "gcal_tpik_angle_r", label = "TPIK Roll", min = -45, max = 45, decimals = 1},
    {key = "tpik_target_radius_add", convar = "gcal_tpik_target_radius_add", label = "TPIK Target Radius +/-", min = -38, max = 80, decimals = 1},
    {key = "tpik_pole_source_add", convar = "gcal_tpik_pole_source_add", label = "TPIK Source Pole +/-", min = -1, max = 1, decimals = 2},
    {key = "tpik_pole_native_add", convar = "gcal_tpik_pole_native_add", label = "TPIK Native Pole +/-", min = -1, max = 1, decimals = 2},
    {key = "tpik_smoothing_add", convar = "gcal_tpik_smoothing_add", label = "TPIK Smoothing +/-", min = -18, max = 42, decimals = 1}
}

local adjustmentFieldGroups = {
    {title = "VIEWMODEL", fields = adjustmentFields, tooltip = "Global adjustment applied to every GCAL firstperson animation."},
    {title = "THIRDPERSON TPIK", fields = tpikAdjustmentFields, tooltip = "Global adjustment applied to GCAL thirdperson TPIK solving."}
}

local function EachAdjustmentField(callback)
    for _, group in ipairs(adjustmentFieldGroups) do
        for _, field in ipairs(group.fields) do
            callback(field, group)
        end
    end
end

local function AnimCookieKey(name)
    return "gcal_anim_enabled_" .. string.gsub(tostring(name), "[^%w_]", "_")
end

local function AnimSoundCookieKey(name)
    return "gcal_anim_sound_" .. string.gsub(tostring(name), "[^%w_]", "_")
end

local function AnimSearchQuery()
    return string.Trim(string.lower(tostring(GCAL.Menu.AnimSearch or "")))
end

local function AnimMatchesSearch(name, anim, addonName)
    local query = AnimSearchQuery()
    if query == "" then return true end

    local haystack = string.lower(table.concat({
        tostring(name or ""),
        tostring(addonName or ""),
        tostring(anim and anim.model or ""),
        tostring(anim and anim.sequence or "")
    }, " "))

    return string.find(haystack, query, 1, true) ~= nil
end

local function AnimEnabled(name)
    if GCAL.Menu.DisabledAnims[name] ~= nil then
        return not GCAL.Menu.DisabledAnims[name]
    end

    if cookie and cookie.GetNumber then
        return cookie.GetNumber(AnimCookieKey(name), 1) ~= 0
    end

    return true
end

function GCAL:IsAnimEnabled(name)
    return AnimEnabled(name)
end

function GCAL:IsAnimSuppressed(name)
    return not AnimEnabled(name)
end

local function AnimSoundOverride(name)
    if GCAL.Menu.SoundOverrides[name] ~= nil then
        return GCAL.Menu.SoundOverrides[name] ~= "" and GCAL.Menu.SoundOverrides[name] or nil
    end

    if cookie and cookie.GetString then
        local value = cookie.GetString(AnimSoundCookieKey(name), "")
        return value ~= "" and value or nil
    end

    return nil
end

function GCAL:GetAnimSoundOverride(name)
    return AnimSoundOverride(name)
end

local function SetAnimSoundOverride(name, soundPath)
    soundPath = string.Trim(tostring(soundPath or ""))
    GCAL.Menu.SoundOverrides[name] = soundPath

    if cookie and cookie.Set then
        cookie.Set(AnimSoundCookieKey(name), soundPath)
    end
end

local function SetAnimEnabled(name, enabled)
    GCAL.Menu.DisabledAnims[name] = not enabled

    if cookie and cookie.Set then
        cookie.Set(AnimCookieKey(name), enabled and "1" or "0")
    end

    if not enabled then
        for id, track in pairs(GCAL.ActiveTracks or {}) do
            if track and track.name == name then
                GCAL:StopTrack(id)
            end
        end
    end
end

local function SetAllAnimsEnabled(enabled)
    for _, name in ipairs(SortedAnimNames()) do
        SetAnimEnabled(name, enabled)
    end
end

local function AnimAddonName(anim)
    return tostring(anim and (anim.addon_name or anim.addon or anim.source_addon) or "Other")
end

local function SortedAnimGroups()
    local groups = {}

    for _, name in ipairs(SortedAnimNames()) do
        local anim = GCAL.Anims[name] or {}
        local addonName = AnimAddonName(anim)

        groups[addonName] = groups[addonName] or {}
        groups[addonName][#groups[addonName] + 1] = name
    end

    local names = {}
    for addonName in pairs(groups) do
        names[#names + 1] = addonName
    end

    table.sort(names, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    return names, groups
end

local function GroupEnabledState(names)
    local enabledCount = 0

    for _, name in ipairs(names) do
        if AnimEnabled(name) then
            enabledCount = enabledCount + 1
        end
    end

    if enabledCount == #names then return "enabled" end
    if enabledCount == 0 then return "disabled" end
    return "mixed"
end

local function SetGroupEnabled(names, enabled)
    for _, name in ipairs(names) do
        SetAnimEnabled(name, enabled)
    end
end

local function GroupHasLegacyAnim(names)
    for _, name in ipairs(names) do
        local anim = GCAL.Anims[name]
        if anim and anim.legacy then return true end
    end

    return false
end

local function DebugEnabled()
    local debugConVar = GCAL.Debug or GetConVar("gcal_debug")
    return debugConVar ~= nil and debugConVar:GetBool() or false
end

local function KeepOpenEnabled()
    local keepOpenConVar = GetConVar("gcal_menu_keep_open")
    return keepOpenConVar ~= nil and keepOpenConVar:GetBool() or false
end

local function ConflictPopupEnabled()
    local conflictPopupConVar = GetConVar("gcal_conflict_popup")
    return conflictPopupConVar == nil or conflictPopupConVar:GetBool()
end

local function ThirdPersonEnabled()
    if not GCAL.InternalThirdPersonEnabled then return false end

    local thirdPersonConVar = GCAL.ThirdPerson or GetConVar("gcal_thirdperson")
    return thirdPersonConVar ~= nil and thirdPersonConVar:GetBool() or false
end

local pitchPresets = {
    {value = 75, label = "deep"},
    {value = 100, label = "normal"},
    {value = 140, label = "squeaky"}
}

local function PlaybackSpeed()
    local convar = GCAL.PlaybackSpeed or GetConVar("gcal_playback_speed")
    return convar and convar:GetFloat() or 1
end

local function SoundsMuted()
    local convar = GCAL.MuteSounds or GetConVar("gcal_mute_sounds")
    return convar and convar:GetBool() or false
end

local function SoundPitch()
    local convar = GCAL.SoundPitch or GetConVar("gcal_sound_pitch")
    return convar and convar:GetInt() or 100
end

local function GlobalAdjustmentValue(field)
    local convar = GetConVar(field.convar)
    return convar and convar:GetFloat() or 0
end

local function SetGlobalAdjustmentValue(field, value)
    RunConsoleCommand(field.convar, tostring(math.Round(tonumber(value) or 0, field.decimals)))
end

local function ResetGlobalAdjustments()
    EachAdjustmentField(function(field)
        RunConsoleCommand(field.convar, "0")
    end)
end

local function LocalAdjustmentValue(name, field)
    if not GCAL.GetAnimationAdjustmentValue then return 0 end

    return GCAL:GetAnimationAdjustmentValue(name, field.key)
end

local function HasLocalAdjustments(name)
    local hasAdjustments = false
    EachAdjustmentField(function(field)
        if math.abs(LocalAdjustmentValue(name, field)) > 0.001 then
            hasAdjustments = true
        end
    end)

    return hasAdjustments
end

local function NextPresetIndex(values, current, key)
    local best = 1
    local bestDistance = math.huge

    for i, value in ipairs(values) do
        local compare = key and value[key] or value
        local distance = math.abs(compare - current)
        if distance < bestDistance then
            best = i
            bestDistance = distance
        end
    end

    return best % #values + 1
end

local function CurrentPitchLabel()
    local current = SoundPitch()
    local best = pitchPresets[1]
    local bestDistance = math.huge

    for _, preset in ipairs(pitchPresets) do
        local distance = math.abs(preset.value - current)
        if distance < bestDistance then
            best = preset
            bestDistance = distance
        end
    end

    return best.label
end

function GCAL.Menu.DetachWindow(window)
    if not IsValid(window) then return end

    local x, y = window:GetPos()
    window:SetParent(vgui.GetWorldPanel())
    window:SetPos(x, y)
    window:SetVisible(true)
    window:SetMouseInputEnabled(true)
    window:SetKeyboardInputEnabled(true)

    if window.MakePopup then
        window:MakePopup()
    end
end

local function MakeButton(parent, text, accent, click, indent)
    local btn = vgui.Create("DButton", parent)
    btn:SetTall(34)
    btn:SetText("")
    btn.GCALText = text
    btn.GCALAccent = accent or colAccent
    btn.GCALHover = 0
    btn.GCALIndent = indent or 0

    btn.DoClick = function(self)
        surface.PlaySound("ui/buttonclickrelease.wav")
        click(self)
    end

    btn.Paint = function(self, w, h)
        self.GCALHover = Lerp(FrameTime() * 12, self.GCALHover, self:IsHovered() and 1 or 0)

        local a = self.GCALHover
        local fill = Color(
            Lerp(a, colPanelSoft.r, self.GCALAccent.r * 0.45),
            Lerp(a, colPanelSoft.g, self.GCALAccent.g * 0.45),
            Lerp(a, colPanelSoft.b, self.GCALAccent.b * 0.45),
            225
        )

        draw.RoundedBox(5, 0, 0, w, h, fill)
        surface.SetDrawColor(self.GCALAccent.r, self.GCALAccent.g, self.GCALAccent.b, 50 + a * 90)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        local textX = 19 + self.GCALIndent
        draw.RoundedBox(2, 8 + self.GCALIndent, 8, 3, h - 16, Color(self.GCALAccent.r, self.GCALAccent.g, self.GCALAccent.b, 160 + a * 60))
        draw.SimpleText(self.GCALText, "GCAL.Menu.Body", textX, h * 0.5 - 1, colText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    return btn
end

local function MakeStaticRow(parent, text, accent)
    local row = vgui.Create("DPanel", parent)
    row:SetTall(34)
    row.GCALText = text
    row.GCALAccent = accent or colMuted

    row.Paint = function(self, w, h)
        draw.RoundedBox(5, 0, 0, w, h, Color(colPanelSoft.r, colPanelSoft.g, colPanelSoft.b, 150))
        surface.SetDrawColor(self.GCALAccent.r, self.GCALAccent.g, self.GCALAccent.b, 48)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.RoundedBox(2, 8, 8, 3, h - 16, Color(self.GCALAccent.r, self.GCALAccent.g, self.GCALAccent.b, 110))
        draw.SimpleText(self.GCALText, "GCAL.Menu.Body", 19, h * 0.5 - 1, colMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    return row
end

local function MakeSlider(parent, label, minValue, maxValue, decimals, value, changed)
    local slider = vgui.Create("DNumSlider", parent)
    slider:SetTall(42)
    slider:SetText(label)
    slider:SetMin(minValue)
    slider:SetMax(maxValue)
    slider:SetDecimals(decimals)
    slider:SetValue(value)
    slider.Label:SetTextColor(colText)
    slider.TextArea:SetTextColor(colText)
    slider.OnValueChanged = function(_, newValue)
        changed(newValue)
    end

    return slider
end

local function MakeAdjustmentSliders(parent, fields, name)
    for _, field in ipairs(fields) do
        local slider = MakeSlider(parent, field.label, field.min, field.max, field.decimals, LocalAdjustmentValue(name, field), function(value)
            GCAL:SetAnimationAdjustmentValue(name, field.key, math.Round(tonumber(value) or 0, field.decimals))
        end)
        slider:Dock(TOP)
        slider:DockMargin(0, 0, 0, 8)
    end
end

local function MakeSearchEntry(parent, focusID)
    local entry = vgui.Create("DTextEntry", parent)
    entry:SetTall(30)
    entry:SetText(GCAL.Menu.AnimSearch or "")
    entry:SetUpdateOnType(true)
    entry:SetPlaceholderText("Search animations")
    entry:SetTextColor(colText)
    entry:SetPlaceholderColor(colMuted)
    entry:SetCursorColor(colAccent)
    entry:SetHighlightColor(Color(colAccent.r, colAccent.g, colAccent.b, 90))
    entry.Paint = function(self, w, h)
        draw.RoundedBox(5, 0, 0, w, h, colPanelSoft)
        surface.SetDrawColor(colLine)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        self:DrawTextEntryText(colText, colAccent, colText)
    end
    entry.OnValueChange = function(_, value)
        GCAL.Menu.AnimSearch = value or ""
        GCAL.Menu.AnimSearchFocus = focusID
        timer.Simple(0, GCAL.Menu.Refresh)
    end
    entry.OnGetFocus = function()
        GCAL.Menu.AnimSearchFocus = focusID
    end
    entry.OnLoseFocus = function()
        if GCAL.Menu.AnimSearchFocus == focusID then
            GCAL.Menu.AnimSearchFocus = nil
        end
    end

    return entry
end

local function MakeSection(parent, title)
    local section = vgui.Create("DPanel", parent)
    section:Dock(TOP)
    section:DockMargin(0, 0, 0, 8)
    section:SetTall(26)
    section:SetPaintBackground(false)

    section.Paint = function(_, w, h)
        draw.SimpleText(title, "GCAL.Menu.Subtitle", 0, h * 0.5 - 1, colMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(colLine)
        surface.SetFont("GCAL.Menu.Subtitle")
        local textWide = surface.GetTextSize(title)
        surface.DrawLine(textWide + 12, h * 0.5, w, h * 0.5)
    end

    return section
end

local function OpenAnimationAdjustmentEditor(name, label)
    if not GCAL.GetAnimationAdjustmentValue or not GCAL.SetAnimationAdjustmentValue then return end

    local frame = vgui.Create("DFrame")
    frame:SetTitle("GCAL Adjust: " .. label)
    frame:SetSize(470, 620)
    frame:Center()
    frame:MakePopup()

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:Dock(FILL)
    scroll:DockMargin(12, 12, 12, 12)

    MakeSection(scroll, "VIEWMODEL")
    MakeAdjustmentSliders(scroll, adjustmentFields, name)

    MakeSection(scroll, "THIRDPERSON TPIK")
    MakeAdjustmentSliders(scroll, tpikAdjustmentFields, name)

    local resetButton = MakeButton(scroll, "Reset this animation", colWarn, function()
        if GCAL.ClearAnimationAdjustment then
            GCAL:ClearAnimationAdjustment(name)
        end

        frame:Close()
        timer.Simple(0, function()
            OpenAnimationAdjustmentEditor(name, label)
            GCAL.Menu.Refresh()
        end)
    end)
    resetButton:Dock(TOP)
    resetButton:DockMargin(0, 4, 0, 8)
end

local function BuildAnimList(scroll)
    local names = SortedAnimNames()

    if #names == 0 then
        local empty = vgui.Create("DPanel", scroll)
        empty:Dock(TOP)
        empty:SetTall(64)
        empty.Paint = function(_, w, h)
            draw.RoundedBox(7, 0, 0, w, h, colPanelSoft)
            draw.SimpleText("No animations registered yet.", "GCAL.Menu.Body", 14, h * 0.5 - 1, colMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        return
    end

    local groupNames, groups = SortedAnimGroups()
    local shown = 0

    for _, addonName in ipairs(groupNames) do
        local groupAnims = groups[addonName]
        local matchedAnims = {}
        for _, name in ipairs(groupAnims) do
            local anim = GCAL.Anims[name] or {}
            if AnimMatchesSearch(name, anim, addonName) then
                matchedAnims[#matchedAnims + 1] = name
            end
        end
        if #matchedAnims == 0 then continue end

        local legacyLabel = GroupHasLegacyAnim(groupAnims) and "[LEGACY] " or ""
        local groupRow = MakeStaticRow(scroll, legacyLabel .. addonName, GroupHasLegacyAnim(groupAnims) and colWarn or colMuted)
        groupRow:Dock(TOP)
        groupRow:DockMargin(0, 0, 0, 4)
        groupRow:SetTooltip("Addon group")

        for _, name in ipairs(matchedAnims) do
            local anim = GCAL.Anims[name] or {}
            local label = tostring(name)
            local enabled = AnimEnabled(name)

            local btn = MakeButton(scroll, enabled and label or (label .. " disabled"), enabled and (anim.legacy and colWarn or colAccent) or colMuted, function()
                if not AnimEnabled(name) then
                    notification.AddLegacy("GCAL animation disabled: " .. label, NOTIFY_ERROR, 2)
                    return
                end

                if GCAL:Play(name, anim.legacy and "legacy_left_arm" or nil) then
                    notification.AddLegacy("GCAL played " .. label, NOTIFY_GENERIC, 2)
                else
                    notification.AddLegacy("GCAL could not play " .. label, NOTIFY_ERROR, 3)
                end
            end, 14)

            btn:Dock(TOP)
            btn:DockMargin(10, 0, 0, 5)
            local soundOverride = AnimSoundOverride(name)
            local tooltip = enabled and (anim.model and ("Model: models/" .. anim.model) or "No model specified") or "Enable this animation in the Toggle Anims column"
            if soundOverride then
                tooltip = tooltip .. "\nCustom sound: " .. soundOverride
            end
            if HasLocalAdjustments(name) then
                tooltip = tooltip .. "\nCustom offsets/TPIK active."
            end
            tooltip = tooltip .. "\nRight-click for sound and adjustment options."
            btn:SetTooltip(tooltip)

            btn.DoRightClick = function()
                local menu = DermaMenu()
                menu:AddOption("Edit offsets/TPIK...", function()
                    OpenAnimationAdjustmentEditor(name, label)
                end)

                if HasLocalAdjustments(name) then
                    menu:AddOption("Reset offsets/TPIK", function()
                        if GCAL.ClearAnimationAdjustment then
                            GCAL:ClearAnimationAdjustment(name)
                        end

                        notification.AddLegacy("GCAL offsets reset for " .. label, NOTIFY_GENERIC, 2)
                        GCAL.Menu.Refresh()
                    end)
                end

                menu:AddSpacer()
                menu:AddOption("Set custom sound...", function()
                    Derma_StringRequest(
                        "Custom animation sound",
                        "Enter a sound path for " .. label .. " (example: buttons/button14.wav)",
                        AnimSoundOverride(name) or "",
                        function(value)
                            SetAnimSoundOverride(name, value)
                            notification.AddLegacy("GCAL custom sound set for " .. label, NOTIFY_GENERIC, 2)
                            GCAL.Menu.Refresh()
                        end
                    )
                end)

                if AnimSoundOverride(name) then
                    menu:AddOption("Clear custom sound", function()
                        SetAnimSoundOverride(name, "")
                        notification.AddLegacy("GCAL custom sound cleared for " .. label, NOTIFY_GENERIC, 2)
                        GCAL.Menu.Refresh()
                    end)
                end

                menu:Open()
            end
            shown = shown + 1
        end
    end

    if shown == 0 then
        local empty = vgui.Create("DPanel", scroll)
        empty:Dock(TOP)
        empty:SetTall(52)
        empty.Paint = function(_, w, h)
            draw.RoundedBox(7, 0, 0, w, h, Color(28, 33, 43, 210))
            draw.SimpleText("No animations match the search.", "GCAL.Menu.Body", 14, h * 0.5 - 1, colMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
end

local function BuildToggleAnimList(scroll)
    local names = SortedAnimNames()

    if #names == 0 then
        local empty = vgui.Create("DPanel", scroll)
        empty:Dock(TOP)
        empty:SetTall(64)
        empty.Paint = function(_, w, h)
            draw.RoundedBox(7, 0, 0, w, h, colPanelSoft)
            draw.SimpleText("No animations registered yet.", "GCAL.Menu.Body", 14, h * 0.5 - 1, colMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        return
    end

    local groupNames, groups = SortedAnimGroups()
    local shown = 0

    for _, addonName in ipairs(groupNames) do
        local groupAnims = groups[addonName]
        local matchedAnims = {}
        for _, name in ipairs(groupAnims) do
            local anim = GCAL.Anims[name] or {}
            if AnimMatchesSearch(name, anim, addonName) then
                matchedAnims[#matchedAnims + 1] = name
            end
        end
        if #matchedAnims == 0 then continue end

        local state = GroupEnabledState(matchedAnims)
        local collapsed = GCAL.Menu.CollapsedAddonGroups[addonName] == true
        local marker = collapsed and "[+] " or "[-] "
        local legacyLabel = GroupHasLegacyAnim(matchedAnims) and "[LEGACY] " or ""
        local suffix = state == "mixed" and " mixed" or (" " .. state)
        local color = state == "enabled" and colAccent or (state == "disabled" and colBad or colWarn)

        local groupButton = MakeButton(scroll, marker .. legacyLabel .. addonName .. suffix, color, function()
            SetGroupEnabled(matchedAnims, state ~= "enabled")
            notification.AddLegacy("GCAL " .. (state == "enabled" and "disabled " or "enabled ") .. addonName, NOTIFY_GENERIC, 2)
            timer.Simple(0, GCAL.Menu.Refresh)
        end)
        groupButton:Dock(TOP)
        groupButton:DockMargin(0, 0, 0, collapsed and 7 or 4)
        groupButton:SetTooltip("Toggle every animation from this addon")

        groupButton.DoRightClick = function()
            GCAL.Menu.CollapsedAddonGroups[addonName] = not collapsed
            timer.Simple(0, GCAL.Menu.Refresh)
        end

        if not collapsed then
            for _, name in ipairs(matchedAnims) do
                local label = tostring(name)
                local enabled = AnimEnabled(name)

                local btn = MakeButton(scroll, (enabled and "On " or "Off ") .. label, enabled and colAccent or colBad, function()
                    SetAnimEnabled(name, not AnimEnabled(name))
                    notification.AddLegacy("GCAL " .. (AnimEnabled(name) and "enabled " or "disabled ") .. label, NOTIFY_GENERIC, 2)
                    timer.Simple(0, GCAL.Menu.Refresh)
                end, 14)

                btn:Dock(TOP)
                btn:DockMargin(10, 0, 0, 5)
                btn:SetTooltip("Toggle this animation. Right-click the addon row to collapse it.")
                shown = shown + 1
            end
        else
            shown = shown + #matchedAnims
        end
    end

    if shown == 0 then
        local empty = vgui.Create("DPanel", scroll)
        empty:Dock(TOP)
        empty:SetTall(52)
        empty.Paint = function(_, w, h)
            draw.RoundedBox(7, 0, 0, w, h, Color(28, 33, 43, 210))
            draw.SimpleText("No animations match the search.", "GCAL.Menu.Body", 14, h * 0.5 - 1, colMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
end

local function BuildTracks(scroll)
    local count = TrackCount()

    if count == 0 then
        local empty = vgui.Create("DPanel", scroll)
        empty:Dock(TOP)
        empty:SetTall(52)
        empty.Paint = function(_, w, h)
            draw.RoundedBox(7, 0, 0, w, h, Color(28, 33, 43, 210))
            draw.SimpleText("No active GCAL tracks.", "GCAL.Menu.Body", 14, h * 0.5 - 1, colMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        return
    end

    for id, track in pairs(GCAL.ActiveTracks or {}) do
        local text = tostring(id) .. "  /  " .. tostring(track.name or "unknown")
        local btn = MakeButton(scroll, text, colBad, function()
            GCAL:StopTrack(id)
            GCAL.Menu.Refresh()
        end)

        btn:Dock(TOP)
        btn:DockMargin(0, 0, 0, 7)
        btn:SetTooltip("Stop this track")
    end
end

function GCAL.Menu.Refresh()
    local panel = GCAL.Menu.Panel
    if not IsValid(panel) then return end

    if IsValid(panel.ActionsScroll) then
        panel.ActionsScroll:Clear()
    end

    if IsValid(panel.ToggleScroll) then
        panel.ToggleScroll:Clear()
    end

    if IsValid(panel.AnimsScroll) then
        panel.AnimsScroll:Clear()
    end

    if not IsValid(panel.ActionsScroll) or not IsValid(panel.ToggleScroll) or not IsValid(panel.AnimsScroll) then
        return
    end

    MakeSection(panel.ActionsScroll, "ACTIONS")

    local debugButton = MakeButton(panel.ActionsScroll, DebugEnabled() and "Disable debug HUD" or "Enable debug HUD", colAccent, function()
        RunConsoleCommand("gcal_debug", DebugEnabled() and "0" or "1")
        timer.Simple(0, GCAL.Menu.Refresh)
    end)
    debugButton:Dock(TOP)
    debugButton:DockMargin(0, 0, 0, 7)

    local keepOpenButton = MakeButton(panel.ActionsScroll, KeepOpenEnabled() and "Keep open after C: on" or "Keep open after C: off", colAccent, function()
        RunConsoleCommand("gcal_menu_keep_open", KeepOpenEnabled() and "0" or "1")

        local window = IsValid(panel.GCALWindow) and panel.GCALWindow or panel:GetParent()
        timer.Simple(0, function()
            if KeepOpenEnabled() then
                GCAL.Menu.DetachWindow(window)
            end

            GCAL.Menu.Refresh()
        end)
    end)
    keepOpenButton:Dock(TOP)
    keepOpenButton:DockMargin(0, 0, 0, 7)
    keepOpenButton:SetTooltip("When enabled, click the GCAL icon once and release C.")

    local conflictPopupButton = MakeButton(panel.ActionsScroll, ConflictPopupEnabled() and "Conflict popup: on" or "Conflict popup: off", ConflictPopupEnabled() and colAccent or colWarn, function()
        RunConsoleCommand("gcal_conflict_popup", ConflictPopupEnabled() and "0" or "1")
        timer.Simple(0, GCAL.Menu.Refresh)
    end)
    conflictPopupButton:Dock(TOP)
    conflictPopupButton:DockMargin(0, 0, 0, 7)
    conflictPopupButton:SetTooltip("Toggle the startup conflict warning popup. Console: gcal_conflict_popup 0/1.")

    if GCAL.InternalThirdPersonEnabled then
        local thirdPersonButton = MakeButton(panel.ActionsScroll, ThirdPersonEnabled() and "TPIK enabled: on" or "TPIK enabled: off", colAccent, function()
            RunConsoleCommand("gcal_thirdperson", ThirdPersonEnabled() and "0" or "1")
            timer.Simple(0, GCAL.Menu.Refresh)
        end)
        thirdPersonButton:Dock(TOP)
        thirdPersonButton:DockMargin(0, 0, 0, 7)
        thirdPersonButton:SetTooltip("Applies active GCAL arm tracks to the local player model in thirdperson. This is still in beta and may not work as expected.")
    end

    local camboneConVar = GCAL.CamBone or GetConVar("gcal_cambone")
    local camboneEnabled = camboneConVar ~= nil and camboneConVar:GetBool() or false
    local camboneButton = MakeButton(panel.ActionsScroll, camboneEnabled and "Cambone enabled: on" or "Cambone enabled: off", colAccent, function()
        RunConsoleCommand("gcal_cambone", camboneEnabled and "0" or "1")
        timer.Simple(0, GCAL.Menu.Refresh)
    end)
    camboneButton:Dock(TOP)
    camboneButton:DockMargin(0, 0, 0, 7)
    camboneButton:SetTooltip("Lets animation attachments drive the first-person view angles (VManip-style camera bone). Console: gcal_cambone 0/1.")

    local stopButton = MakeButton(panel.ActionsScroll, "Stop all animations", colBad, function()
        StopAllTracks()
        GCAL.Menu.Refresh()
    end)
    stopButton:Dock(TOP)
    stopButton:DockMargin(0, 0, 0, 7)

    local enableAllButton = MakeButton(panel.ActionsScroll, "Enable all animations", colAccent, function()
        SetAllAnimsEnabled(true)
        GCAL.Menu.Refresh()
    end)
    enableAllButton:Dock(TOP)
    enableAllButton:DockMargin(0, 0, 0, 7)

    local disableAllButton = MakeButton(panel.ActionsScroll, "Disable all animations", colWarn, function()
        SetAllAnimsEnabled(false)
        GCAL.Menu.Refresh()
    end)
    disableAllButton:Dock(TOP)
    disableAllButton:DockMargin(0, 0, 0, 7)

    MakeSection(panel.ActionsScroll, "PLAYGROUND")

    local speedSlider = MakeSlider(panel.ActionsScroll, "Playback speed", 0.1, 3, 2, PlaybackSpeed(), function(value)
        RunConsoleCommand("gcal_playback_speed", tostring(math.Round(value, 2)))
    end)
    speedSlider:Dock(TOP)
    speedSlider:DockMargin(0, 0, 0, 7)
    speedSlider:SetTooltip("Adjust global playback speed from 0.1x to 3.0x.")

    MakeSection(panel.ActionsScroll, "ANIMATION ADJUST")

    for _, group in ipairs(adjustmentFieldGroups) do
        MakeSection(panel.ActionsScroll, group.title)

        for _, field in ipairs(group.fields) do
            local slider = MakeSlider(panel.ActionsScroll, field.label, field.min, field.max, field.decimals, GlobalAdjustmentValue(field), function(value)
                SetGlobalAdjustmentValue(field, value)
            end)
            slider:Dock(TOP)
            slider:DockMargin(0, 0, 0, 7)
            slider:SetTooltip(group.tooltip or "Global adjustment applied to GCAL animations.")
        end
    end

    local resetAdjustmentsButton = MakeButton(panel.ActionsScroll, "Reset global adjustments", colMuted, function()
        ResetGlobalAdjustments()
        timer.Simple(0, GCAL.Menu.Refresh)
    end)
    resetAdjustmentsButton:Dock(TOP)
    resetAdjustmentsButton:DockMargin(0, 0, 0, 7)

    local soundButton = MakeButton(panel.ActionsScroll, SoundsMuted() and "Gesture sounds: muted" or "Gesture sounds: on", SoundsMuted() and colWarn or colAccent, function()
        RunConsoleCommand("gcal_mute_sounds", SoundsMuted() and "0" or "1")
        timer.Simple(0, GCAL.Menu.Refresh)
    end)
    soundButton:Dock(TOP)
    soundButton:DockMargin(0, 0, 0, 7)
    soundButton:SetTooltip("Toggle sounds emitted by GCAL animations.")

    local pitchButton = MakeButton(panel.ActionsScroll, "Sound pitch: " .. CurrentPitchLabel(), colAccent, function()
        local nextIndex = NextPresetIndex(pitchPresets, SoundPitch(), "value")
        RunConsoleCommand("gcal_sound_pitch", tostring(pitchPresets[nextIndex].value))
        timer.Simple(0, GCAL.Menu.Refresh)
    end)
    pitchButton:Dock(TOP)
    pitchButton:DockMargin(0, 0, 0, 7)
    pitchButton:SetTooltip("Cycle animation sound pitch between deep, normal, and squeaky.")

    local resetFunButton = MakeButton(panel.ActionsScroll, "Reset playground", colMuted, function()
        RunConsoleCommand("gcal_playback_speed", "1")
        RunConsoleCommand("gcal_mute_sounds", "0")
        RunConsoleCommand("gcal_sound_pitch", "100")
        timer.Simple(0, GCAL.Menu.Refresh)
    end)
    resetFunButton:Dock(TOP)
    resetFunButton:DockMargin(0, 0, 0, 7)
    resetFunButton:SetTooltip("Restore normal playback speed and sound settings.")

    MakeSection(panel.ActionsScroll, "TRACKS")
    BuildTracks(panel.ActionsScroll)

    MakeSection(panel.ToggleScroll, "TOGGLE ANIMS")
    BuildToggleAnimList(panel.ToggleScroll)

    MakeSection(panel.AnimsScroll, "ANIMS")
    BuildAnimList(panel.AnimsScroll)
end

function GCAL.Menu.BuildWindow(window)
    if not IsValid(window) then return end

    if window.SetTitle then window:SetTitle("") end
    if window.SetSizable then window:SetSizable(true) end
    if window.SetMinWidth then window:SetMinWidth(760) end
    if window.SetMinHeight then window:SetMinHeight(430) end

    if window.SetPaintShadow then window:SetPaintShadow(false) end
    if IsValid(window.btnMaxim) then window.btnMaxim:SetVisible(false) end
    if IsValid(window.btnMinim) then window.btnMinim:SetVisible(false) end
    if IsValid(window.btnClose) then
        window.btnClose:SetText("")
        window.btnClose.Paint = function(self, w, h)
            local hovered = self:IsHovered()
            draw.RoundedBox(4, 2, 2, w - 4, h - 4, hovered and Color(colBad.r, colBad.g, colBad.b, 70) or Color(255, 255, 255, 8))
            surface.SetDrawColor(hovered and colBad or colMuted)
            surface.DrawLine(8, 8, w - 8, h - 8)
            surface.DrawLine(w - 8, 8, 8, h - 8)
        end
    end

    window.Paint = function(_, w, h)
        draw.RoundedBox(7, 0, 0, w, h, colFrame)
        draw.RoundedBox(6, 1, 1, w - 2, h - 2, colPanel)
        PaintPrideLine(10, 0, w - 20, PrideEnabled() and 3 or 1)
        surface.SetDrawColor(colLine)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    if IsValid(window.GCALContent) then
        window.GCALContent:Remove()
    end

    local panel = vgui.Create("DPanel", window)
    window.GCALContent = panel
    GCAL.Menu.Panel = panel
    panel.GCALWindow = window
    panel:Dock(FILL)
    panel:SetMouseInputEnabled(true)

    panel.Paint = function(_, w, h)
        draw.RoundedBox(0, 0, 0, w, h, colBg)
        draw.RoundedBox(0, 1, 1, w - 2, h - 2, colPanel)
        draw.RoundedBox(0, 1, 1, w - 2, 92, colHeader)
        surface.SetDrawColor(colLine)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        surface.DrawLine(PANEL_PAD, 92, w - PANEL_PAD, 92)

        local titleX = PANEL_PAD

        local activeLogoMaterial = PrideEnabled() and prideLogoMaterial or logoMaterial
        if not activeLogoMaterial:IsError() then
            local logoAspect = activeLogoMaterial:Width() / math.max(activeLogoMaterial:Height(), 1)
            local logoMaxWidth = 112
            local logoMaxHeight = 58
            local logoWidth = math.min(logoMaxWidth, logoMaxHeight * logoAspect)
            local logoHeight = logoWidth / math.max(logoAspect, 0.01)
            local logoY = 15 + (logoMaxHeight - logoHeight) * 0.5
            local logoX = PANEL_PAD

            surface.SetMaterial(activeLogoMaterial)
            if PrideEnabled() then
                surface.SetDrawColor(colAccent.r, colAccent.g, colAccent.b, 24)
                surface.DrawTexturedRect(logoX - 2, logoY - 2, logoWidth + 4, logoHeight + 4)
            end
            surface.SetDrawColor(255, 255, 255, PrideEnabled() and 245 or 235)
            surface.DrawTexturedRect(logoX, logoY, logoWidth, logoHeight)

            titleX = PANEL_PAD + math.min(logoMaxWidth, logoMaxHeight * logoAspect) + 14
        end

        DrawPrideTitle(panel, "Garry's Mod Compliant Armature Layer", "GCAL.Menu.Title", titleX, 15, colText)
        draw.SimpleText("Modern and modular offhand animation library", "GCAL.Menu.Subtitle", titleX + 1, 47, colMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        local count = TrackCount()
        PaintPill(w - 118, 18, 92, 22, count > 0 and colAccent or colMuted, tostring(count) .. " active")

        local id, name = FirstTrackName()
        local status = id and (id .. " / " .. name) or "idle, ready"
        draw.SimpleText(status, "GCAL.Menu.Small", titleX + 1, 70, id and colAccent or colMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local searchEntry = MakeSearchEntry(panel, "header")
    panel.SearchEntry = searchEntry
    searchEntry:SetTooltip("Filter animations by name, addon, model, or sequence.")

    local columns = vgui.Create("DPanel", panel)
    columns:Dock(FILL)
    columns:DockMargin(PANEL_PAD, 108, PANEL_PAD, PANEL_PAD)
    columns:SetPaintBackground(false)

    panel.PerformLayout = function(self, w)
        if IsValid(searchEntry) then
            local searchWide = math.min(300, math.max(210, w * 0.34))
            searchEntry:SetSize(searchWide, 30)
            searchEntry:SetPos(w - searchWide - PANEL_PAD - 118, 58)
        end
    end

    local columnHolders = {}
    columns.PerformLayout = function(self)
        local columnWidth = math.max(160, math.floor((self:GetWide() - 20) / 3))

        for _, holder in ipairs(columnHolders) do
            if IsValid(holder) then
                holder:SetWide(columnWidth)
            end
        end
    end

    local function MakeColumn(name, rightMargin)
        local holder = vgui.Create("DPanel", columns)
        holder:Dock(LEFT)
        holder:DockMargin(0, 0, rightMargin or 0, 0)
        holder:SetWide(160)
        holder.Paint = function(_, w, h)
            draw.RoundedBox(6, 0, 0, w, h, colColumn)
            surface.SetDrawColor(colLine)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
        columnHolders[#columnHolders + 1] = holder

        local scroll = vgui.Create("DScrollPanel", holder)
        panel[name] = scroll
        scroll:Dock(FILL)
        scroll:DockMargin(10, 10, 8, 10)

        local bar = scroll:GetVBar()
        bar:SetWide(5)
        bar.Paint = nil
        bar.btnUp.Paint = nil
        bar.btnDown.Paint = nil
        bar.btnGrip.Paint = function(_, w, h)
            draw.RoundedBox(3, 0, 0, w, h, Color(colAccent.r, colAccent.g, colAccent.b, 115))
        end

        return scroll
    end

    MakeColumn("ActionsScroll", 10)
    MakeColumn("ToggleScroll", 10)
    MakeColumn("AnimsScroll", 0)

    GCAL.Menu.Refresh()
    return panel
end

function GCAL.Menu.OpenFrame()
    local frame = vgui.Create("DFrame")
    frame:SetSize(980, 640)
    frame:Center()
    frame:MakePopup()

    GCAL.Menu.BuildWindow(frame)
    return frame
end

function GCAL.Menu.RegisterDesktopIcon()
    if not list or not list.Set then return end

    list.Set("DesktopWindows", "GCAL_Menu", {
        title = "GCAL",
        icon = "gcal/squarelogo",
        width = 980,
        height = 640,
        onewindow = true,
        init = function(_, window)
            GCAL.Menu.BuildWindow(window)

            if KeepOpenEnabled() then
                timer.Simple(0, function()
                    GCAL.Menu.DetachWindow(window)
                end)
            end
        end
    })
end

GCAL.Menu.RegisterDesktopIcon()
timer.Simple(0, GCAL.Menu.RegisterDesktopIcon)

concommand.Add("gcal_menu_open", function()
    if not GCAL or not GCAL.Menu then
        MsgC(Color(255, 0, 0), "[GCAL ERROR] Menu system not initialized!\n")
        return
    end
    
    RunConsoleCommand("gcal_context_menu", "1")
    
    local success, err = pcall(function()
        GCAL.Menu.OpenFrame()
    end)
    
    if not success then
        MsgC(Color(255, 0, 0), "[GCAL ERROR] Failed to show menu: " .. tostring(err) .. "\n")
    else
        MsgC(Color(93, 210, 180), "[GCAL] Menu opened successfully!\n")
    end
end)

MsgC(Color(93, 210, 180), "[GCAL] Context menu desktop icon loaded. Hold C and open GCAL from the icon strip.\n")
