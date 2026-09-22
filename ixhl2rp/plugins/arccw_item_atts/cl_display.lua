-- Full ARC9 assemblies for item presentation; never render a bare EFT receiver.
local P = PLUGIN
ix.WeaponAssembly = {}
local A = ix.WeaponAssembly
local records = {}

function A.Supports(item)
    local definition = item and item.class and weapons.Get(item.class)
    return item and item.isWeapon and definition and definition.MirrorVMWM and
        ix.arc9Inventory and ix.arc9Inventory.IsClass(item.class)
end

function A.Remove(host)
    local entry = records[host]
    if entry then P:RemovePreviewWeapon(entry.model); records[host] = nil end
end

function A.Get(host, class, tree, rounds)
    if not ARC9 or not IsValid(LocalPlayer()) then return end
    local signature = class .. ":" .. util.TableToJSON(tree or {}) .. ":" .. tostring(rounds or 0)
    local entry = records[host]
    if entry and entry.signature == signature then
        if IsValid(entry.model) then return entry.model end
        if (entry.retry or 0) > RealTime() then return end
    end
    A.Remove(host)
    local source = {GetClass = function() return class end, Clip1 = function() return rounds or 0 end,
        Clip2 = function() return 0 end}
    local model = P:CreatePreviewWeapon(source, tree)
    records[host] = {signature = signature, model = model, retry = RealTime() + 5}
    if IsValid(model) then return model end
end

function A.Draw(model, position, angles)
    if not IsValid(model) then return false end
    local old = ARC9.PresetCam
    ARC9.PresetCam = true
    local ok, err = xpcall(function()
        -- ARC9's assembly uses cached bones and world-position optimizations.
        -- Our carrier is not a live SWEP: explicitly move it and its root each draw.
        model:SetPos(position)
        model:SetAngles(angles)
        for _, part in ipairs(model.CModel or {}) do
            if IsValid(part) then
                part.OptimizPrevWMPos = nil
                part:InvalidateBoneCache()
            end
        end
        local root = model.CModel and model.CModel[1]
        if IsValid(root) then
            local pos, ang = model:GetAttachmentPos(root.slottbl, true, false, false, position, angles)
            root:SetPos(pos); root:SetAngles(ang)
            root:SetRenderOrigin(pos); root:SetRenderAngles(ang)
            root:InvalidateBoneCache()
            root:SetupBones()
        end
        model:DrawCustomModel(true, position, angles)
    end, debug.traceback)
    ARC9.PresetCam = old
    if not ok then
        if not model.ixDisplayError then ErrorNoHalt("[ARC9 item display] " .. tostring(err) .. "\n") end
        model.ixDisplayError = true
    end
    return ok
end

function A.Center(model)
    if model.CustomizeRotateAnchor then return Vector(model.CustomizeRotateAnchor) end
    local mn, mx = model.CModel[1]:GetRenderBounds()
    return (mn + mx) * 0.5
end

function A.DrawItem(host, item, pos, ang)
    if not A.Supports(item) then return false end
    local model = A.Get(host, item.class, item:GetData("arc9_atts"), item:GetData("ammo", 0))
    if not model then return false end
    if host.GetClass and host:GetClass() == "ix_item" then
        host:SetRenderBounds(Vector(-96, -96, -96), Vector(96, 96, 96))
    end
    local offset = LocalToWorld(A.Center(model), angle_zero, vector_origin, ang)
    return A.Draw(model, pos - offset, ang)
end

hook.Add("EntityRemoved", "ixARC9DisplayCleanup", A.Remove)
timer.Create("ixARC9DisplayCleanup", 2, 0, function()
    for host in pairs(records) do if not IsValid(host) then A.Remove(host) end end
end)
hook.Add("ShutDown", "ixARC9DisplayCleanup", function()
    for host in pairs(records) do A.Remove(host) end
end)

local PANEL = {}
function PANEL:Init() self:SetMouseInputEnabled(false) end
function PANEL:OnRemove() A.Remove(self) end
function PANEL:Paint(w, h)
    local item = self.item
    if not item then return end
    local model = A.Get(self, item.class, item:GetData("arc9_atts"), item:GetData("ammo", 0))
    if not model then return end
    local center = A.Center(model)
    local angle = Angle(5, 90, self.rotated and -90 or 0)
    local radius = math.max(10, math.abs((model.CustomizePos or Vector(0, 50, 0)).y) * 0.4)
    local distance = radius / math.tan(math.rad(17.5)) * math.max(1, w / math.max(h, 1))
    local sx, sy = self:LocalToScreen(0, 0)
    cam.Start({type = "3D", origin = center - angle:Forward() * distance, angles = angle,
        fov = 35, aspect = w / math.max(h, 1), x = sx, y = sy, w = w, h = h,
        znear = 1, zfar = 4096, subrect = true})
    render.ClearDepth()
    render.SuppressEngineLighting(true)
    render.ResetModelLighting(0.65, 0.65, 0.65)
    render.SetModelLighting(0, 1, 0.95, 0.9)
    render.SetModelLighting(4, 0.6, 0.7, 0.85)
    A.Draw(model, vector_origin, angle_zero)
    render.SetBlend(1); render.SetColorModulation(1, 1, 1)
    render.SuppressEngineLighting(false)
    cam.End3D()
end
vgui.Register("ixARC9ItemIcon", PANEL, "DPanel")
