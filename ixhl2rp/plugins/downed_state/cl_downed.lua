local D = ix.Downed
local PLUGIN = PLUGIN
local red, white, muted = Color(215, 67, 78), Color(239, 232, 223), Color(174, 171, 172)
local gradient = Material("vgui/gradient-d")
local function scale(n) return math.floor(n * math.Clamp(ScrH() / 1080, 0.65, 1.5)) end
local function fonts()
    for name, size in pairs({Title = 34, Body = 19, Small = 15}) do
        surface.CreateFont("ixDowned" .. name, {font = "Segoe UI", size = scale(size),
            weight = name == "Title" and 300 or 400, antialias = true, extended = true})
    end
end
fonts()
hook.Add("OnScreenSizeChanged", "ixDownedFonts", fonts)
local function text(value, font, x, y, color, align)
    color, align = color or white, align or TEXT_ALIGN_LEFT
    local offset = math.max(1, scale(2))
    local alpha = color.a or 255
    draw.SimpleText(value, "ixDowned" .. font, x + offset, y + offset,
        Color(0, 0, 0, alpha * 0.9), align)
    draw.SimpleTextOutlined(value, "ixDowned" .. font, x, y, color, align, TEXT_ALIGN_TOP,
        1, Color(0, 0, 0, alpha * 0.65))
end
local function send(operation)
    net.Start("ixDownedGiveUp"); net.WriteUInt(operation, 2); net.SendToServer()
end

local PANEL = {}
function PANEL:Init()
    self:SetSize(ScrW(), ScrH())
    self:MakePopup()
    self:SetKeyboardInputEnabled(false)
    self.birth = RealTime()
    self.character = LocalPlayer():GetCharacter()
    self.button = self:Add("DButton")
    self.button:SetText("")
    self.button.OnMousePressed = function(button, key)
        if key ~= MOUSE_LEFT or not D.Active(LocalPlayer()) or button.sent then return end
        button.started = CurTime(); button:MouseCapture(true); send(0)
    end
    self.button.OnMouseReleased = function(button)
        button:MouseCapture(false)
        if button.started and not button.sent then send(1) end
        button.started = nil
    end
    self.button.Paint = function(button, w, h)
        local progress = button.started and math.Clamp((CurTime() - button.started) / D.HoldTime, 0, 1) or 0
        surface.SetDrawColor(red); surface.DrawRect(w * 0.15, h - 2, w * 0.7 * progress, 1)
        text(button.sent and "Вы отпускаете…" or "Перестать бороться", "Body", w / 2, scale(8),
            button:IsHovered() and white or muted, TEXT_ALIGN_CENTER)
        text("Сдаться · удерживайте 1,5 сек", "Small", w / 2, scale(35), muted, TEXT_ALIGN_CENTER)
    end
end
function PANEL:PerformLayout(w, h)
    self.button:SetSize(math.min(scale(290), w - 32), scale(65))
    self.button:SetPos((w - self.button:GetWide()) / 2, h * 0.48 + scale(113))
end
function PANEL:Think()
    local client = LocalPlayer()
    if not IsValid(client) or client:GetCharacter() ~= self.character or
        (client:Alive() and not D.Active(client)) then self:Remove() return end
    if self:GetWide() ~= ScrW() or self:GetTall() ~= ScrH() then self:SetSize(ScrW(), ScrH()) end
    self.button:SetVisible(D.Active(client))
    local button = self.button
    if button.started and not button.sent then
        if not input.IsMouseDown(MOUSE_LEFT) or not button:IsHovered() then
            button:OnMouseReleased()
        elseif CurTime() - button.started >= D.HoldTime then
            button.sent = CurTime(); send(2)
        end
    end
    if button.sent and CurTime() - button.sent > 3 and D.Active(client) then
        button.sent = nil; button.started = nil
    end
end
function PANEL:OnRemove()
    if self.button.started and not self.button.sent then send(1) end
end
function PANEL:Paint(w, h)
    local client = LocalPlayer()
    if not IsValid(client) then return end
    local dead = not client:Alive()
    local reveal = math.Clamp((RealTime() - self.birth) / 0.8, 0, 1)
    local blood = D.Blood(client:GetCharacter())
    self.blood = Lerp(math.Clamp(FrameTime() * 5, 0, 1), self.blood or blood, blood)
    -- Slow eyelid-like shadows, never a full blackout while rescue is possible.
    local breath = (math.sin(RealTime() * 0.8) + 1) * 0.5
    surface.SetDrawColor(8, 5, 7, (dead and 205 or 40 + (1 - blood) * 35) * reveal)
    surface.DrawRect(0, 0, w, h)
    surface.SetMaterial(gradient)
    surface.SetDrawColor(4, 3, 5, (200 + breath * 24) * reveal)
    local edge = h * (0.34 + breath * 0.025)
    surface.DrawTexturedRect(0, h - edge, w, edge)
    surface.DrawTexturedRectRotated(w / 2, edge / 2, w, edge, 180)
    local x, y = w / 2, h * 0.48
    if dead then
        local remaining = math.max(0, math.ceil(client:GetNetVar("deathTime", CurTime()) - CurTime()))
        text("Возвращение через " .. remaining .. " сек", "Small", x, y + scale(62), muted, TEXT_ALIGN_CENTER)
        return
    end
    local ink = Color(white.r, white.g, white.b, (195 + breath * 35) * reveal)
    text("В глазах всё темнеет…", "Title", x, y, ink, TEXT_ALIGN_CENTER)
    local length = math.min(scale(260), w * 0.6)
    text("Кровь · " .. math.floor(self.blood * 100 + 0.5) .. "%", "Small", x, y + scale(53), muted, TEXT_ALIGN_CENTER)
    surface.SetDrawColor(27, 15, 19, 220); surface.DrawRect(x - length / 2 - 1, y + scale(82) - 1, length + 2, scale(3) + 2)
    surface.SetDrawColor(90, 49, 54, 170); surface.DrawRect(x - length / 2, y + scale(82), length, scale(3))
    surface.SetDrawColor(181, 63, 72, 225); surface.DrawRect(x - length / 2, y + scale(82), length * self.blood, scale(3))
end
vgui.Register("ixDownedScreen", PANEL, "EditablePanel")

hook.Add("Think", "ixDownedScreen", function()
    local client = LocalPlayer()
    if not IsValid(client) or not client.GetCharacter or not client:GetCharacter() then return end
    if (D.Active(client) or not client:Alive()) and not IsValid(ix.gui.downedScreen) then
        ix.gui.downedScreen = vgui.Create("ixDownedScreen")
    end
end)

function PLUGIN:CalcView(client, origin, angles, fov)
    if not D.Active(client) then return end
    local body = Entity(client:GetLocalVar("ragdoll", 0))
    if not IsValid(body) then return end
    local eyes = body:LookupAttachment("eyes")
    local attachment = eyes and eyes > 0 and body:GetAttachment(eyes)
    local position, look
    if attachment then
        position, look = attachment.Pos, attachment.Ang
    else
        local head = body:LookupBone("ValveBiped.Bip01_Head1")
        position = head and body:GetBonePosition(head) or origin
        look = angles
    end
    position = position or origin
    -- Stay at the eyes, with a small collision-tested clearance from facial geometry.
    local trace = util.TraceHull({start = position, endpos = position + look:Forward() * 3,
        mins = Vector(-1, -1, -1), maxs = Vector(1, 1, 1), filter = {client, body}, mask = MASK_SOLID})
    if not trace.StartSolid then position = trace.HitPos end
    return {origin = position, angles = look, fov = math.min(fov, 85), drawviewer = false, znear = 1}
end
function PLUGIN:AdjustBlurAmount()
    local client = LocalPlayer()
    if D.Active(client) then return -client:GetLocalVar("blur", 0) end
end
