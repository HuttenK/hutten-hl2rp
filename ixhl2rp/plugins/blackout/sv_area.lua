local PLUGIN = PLUGIN

local function finite(n)
    return isnumber(n) and n == n and n > -math.huge and n < math.huge
end

function PLUGIN:ZoneNameForArea(id)
    for name, zone in pairs(self.zones) do
        if zone.areaID == id then return name end
    end
end

function PLUGIN:AreaDefinitionCreating(id, info)
    if info.type ~= "blackout" then return end
    -- Legacy migration uses already saved bounds, including any old padding.
    if self.syncingAreas then info.properties.display = false; return end
    if not isstring(id) or string.Trim(id) == "" or #id > 128 then
        return false, "Укажите название зоны (до 128 байт)."
    end
    local name = self:ZoneNameForArea(id)
    if not name and self.zones[id] then
        return false, "Зона электроснабжения с таким названием уже существует."
    end
    if not name and table.Count(self.zones) >= 1024 then
        return false, "Достигнут предел: 1024 зоны электроснабжения."
    end
    local allowed, reason = self:AreaVolumesChanging(id, info)
    if allowed == false then return false, reason end
    local mn, mx = info.startPosition, info.endPosition
    for _, axis in ipairs({"x", "y", "z"}) do
        if not finite(mn[axis]) or not finite(mx[axis]) or mx[axis] <= mn[axis] then
            return false, "Выберите два противоположных угла объёма, включая пол и потолок."
        end
    end
    for key,limit in pairs({blackoutDarkness=100,blackoutSoftness=128}) do
        local value=info.properties[key]
        if value~=nil and not finite(tonumber(value)) then return false, "Некорректные параметры затемнения." end
        if value~=nil then info.properties[key]=math.Clamp(math.Round(tonumber(value)),0,limit) end
    end
    local margin = tonumber(info.properties.blackoutMargin) or self.areaMargin
    if not finite(margin) then return false, "Некорректный запас границ." end
    margin = math.Clamp(margin, 0, 16)
    local pad = Vector(margin, margin, margin)
    info.startPosition, info.endPosition = mn - pad, mx + pad
    info.properties.blackoutMargin = margin
    info.properties.display = false
end

function PLUGIN:SaveAreaDefinitions()
    local areas = ix.plugin.list.area
    if areas and ix.area.loaded then areas:SaveData() end
end

function PLUGIN:RefreshAreaPower()
    local facility = ix.plugin.list.facility_utilities
    if facility and facility.RecomputePower then facility:RecomputePower(0) end
    self:SetZoneLights()
    self:NetworkZones()
end

function PLUGIN:ApplyZoneArea(id, info)
    local name = self:ZoneNameForArea(id) or id
    local zone = self.zones[name]
    local created = not zone
    zone = zone or {active = info.properties and info.properties.blackoutStartOff == true}
    -- The saved power state wins over the creation checkbox after repair/restart.
    zone.min, zone.max, zone.areaID = info.startPosition, info.endPosition, id
    zone.volumes = info.volumes
    info.properties=info.properties or {}
    zone.darkness=math.Clamp(tonumber(info.properties.blackoutDarkness) or zone.darkness or 86,0,100)
    zone.softness=math.Clamp(tonumber(info.properties.blackoutSoftness) or zone.softness or 24,0,128)
    info.properties.blackoutDarkness=zone.darkness;info.properties.blackoutSoftness=zone.softness
    self.zones[name] = zone
    if created and zone.active then self:SetZoneBoxes(zone, true) end
end

function PLUGIN:AreaDefinitionCreated(id, info)
    if self.syncingAreas then return end
    if info.type ~= "blackout" then
        local name = self:ZoneNameForArea(id)
        if name then self:RemoveZone(name, true); self:SaveAreaDefinitions() end
        return
    end
    self:ApplyZoneArea(id, info)
    self:RefreshAreaPower()
    self:SaveAreaDefinitions()
    self:SaveData()
    self:SaveFuseboxes()
end

function PLUGIN:AreaDefinitionDeleted(id)
    if self.syncingAreas then return end
    local name = self:ZoneNameForArea(id)
    if not name then return end
    self:RemoveZone(name, true)
    self:SaveAreaDefinitions()
end

function PLUGIN:AreaVolumeAdding(id, info, box)
    if info.type ~= "blackout" then return end
    local margin = math.Clamp(tonumber(info.properties.blackoutMargin) or self.areaMargin, 0, 16)
    local pad = Vector(margin, margin, margin)
    box.min, box.max = box.min - pad, box.max + pad
end

function PLUGIN:AreaVolumesChanging(id, info)
    if info.type ~= "blackout" then return end
    local count = #ix.area.GetVolumes(info)
    for _, zone in pairs(self.zones) do
        if zone.areaID ~= id then count = count + #ix.area.GetVolumes(zone) end
    end
    if count > 1024 then return false, "areaVolumeComplex" end
end

function PLUGIN:AreaDefinitionUpdated(id, info)
    self:AreaDefinitionCreated(id, info)
end

-- Expose legacy zones without changing their volume, state or circuit/cable name.
function PLUGIN:PublishZoneArea(name)
    if not ix.area or not ix.area.loaded then return end
    local zone = self.zones[name]
    if not zone then return end
    local id = zone.areaID or name
    local n = 1
    while ix.area.stored[id] do
        if ix.area.stored[id].type == "blackout" and (self:ZoneNameForArea(id) or name) == name then
            zone.areaID = id
            return
        end
        n = n + 1
        id = name .. " [power " .. n .. "]"
    end
    zone.areaID = id
    local syncing = self.syncingAreas
    self.syncingAreas = true
    ix.area.Create(id, "blackout", zone.min, zone.max, nil, {
        color = Color(235, 180, 70), display = false,
        blackoutMargin = 0, blackoutStartOff = zone.active == true,
        blackoutDarkness = zone.darkness or 86, blackoutSoftness = zone.softness or 24
    }, zone.volumes)
    self.syncingAreas = syncing
    if not syncing then self:SaveAreaDefinitions() end
end

function PLUGIN:PostLoadData()
    -- Helix calls this after ALL LoadData hooks, regardless of plugin order.
    if not self.zonesLoaded or not ix.area or not ix.area.loaded or self.unloading then return end
    self.syncingAreas = true
    local removed = {}
    for name, zone in pairs(self.zones) do
        local area = zone.areaID and ix.area.stored[zone.areaID]
        if zone.areaID and (not area or area.type ~= "blackout") then
            removed[#removed + 1] = name
        else
            self:PublishZoneArea(name)
        end
    end
    for _, name in ipairs(removed) do self:RemoveZone(name, true) end
    for id, info in pairs(ix.area.stored) do
        if info.type == "blackout" then self:ApplyZoneArea(id, info) end
    end
    self.syncingAreas = nil
    self:RefreshAreaPower()
    self:SaveAreaDefinitions()
    self:SaveData()
    self:SaveFuseboxes()
end

-- Support refreshing the plugin on an already loaded map too.
timer.Simple(0, function()
    if ix.plugin.list.blackout == PLUGIN then PLUGIN:PostLoadData() end
end)

-- Appearance updates deliberately avoid Create: saved bounds must not be padded again.
util.AddNetworkString("ixBlackoutAppearance")
function PLUGIN:UpdateAreaAppearance(client,id,darkness,softness)
    if not IsValid(client) or not client:Alive() or not CAMI.PlayerHasAccess(client,"Helix - AreaEdit",nil) then return false end
    if not finite(darkness) or not finite(softness) or darkness<0 or darkness>100 or softness<0 or softness>128 then return false end
    local info=ix.area.stored[id];local name=self:ZoneNameForArea(id)
    if not info or info.type~="blackout" or not name then return false end
    info.properties.blackoutDarkness=math.Round(darkness);info.properties.blackoutSoftness=math.Round(softness)
    local zone=self.zones[name];zone.darkness=info.properties.blackoutDarkness;zone.softness=info.properties.blackoutSoftness
    self:SaveAreaDefinitions();self:SaveData();self:NetworkZones()
    ix.area.Sync(id)
    return true
end
net.Receive("ixBlackoutAppearance",function(_,client)
    local id=net.ReadString();local darkness=net.ReadUInt(7);local softness=net.ReadUInt(8)
    if PLUGIN:UpdateAreaAppearance(client,id,darkness,softness) then client:Notify("Затемнение зоны обновлено.") end
end)

util.AddNetworkString("ixBlackoutHeight")
function PLUGIN:UpdateAreaHeight(client,id,lower,upper)
    if not IsValid(client) or not client:Alive() or not CAMI.PlayerHasAccess(client,"Helix - AreaEdit",nil) then return false end
    if not finite(lower) or not finite(upper) or lower < -32768 or upper > 32768 or upper-lower < 1 then
        return false,"Некорректная высота: потолок должен быть выше пола (Z: −32768…32768)."
    end
    local info=ix.area.stored[id];local name=self:ZoneNameForArea(id)
    if not info or info.type~="blackout" or not name then return false,"Зона больше не существует." end
    -- Preserve the footprint, zone identity and power state. Do not call Create:
    -- its creation margin would expand the already padded bounds a second time.
    local volumes={}
    for _,box in ipairs(ix.area.GetVolumes(info)) do
        volumes[#volumes+1]={min=Vector(box.min.x,box.min.y,lower),max=Vector(box.max.x,box.max.y,upper)}
    end
    return ix.area.UpdateVolumes(id,volumes)
end
net.Receive("ixBlackoutHeight",function(_,client)
    local id=net.ReadString();local lower,upper=net.ReadFloat(),net.ReadFloat()
    local ok,reason=PLUGIN:UpdateAreaHeight(client,id,lower,upper)
    if ok then client:Notify("Высота зоны обновлена.") elseif reason then client:Notify(reason) end
end)
