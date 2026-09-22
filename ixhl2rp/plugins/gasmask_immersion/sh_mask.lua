ix.GasMask = ix.GasMask or {}
local M = ix.GasMask

-- Read equipment, never weapon ownership or a client-requested protection flag.
function M.Equipped(client)
    if not IsValid(client) or not client:GetCharacter() then return end
    local inventories = client:GetInventories()
    local inventory = inventories and inventories.mask
    local ids = inventory and inventory:GetSlot(1, 1)
    local item = ids and ix.Item.instances[ids[1]]
    if item and item.isGasmask then return item end
end

function M.Filter(client, mask)
    if not mask then return end
    local id = mask:GetData("filter")
    local filter = id and ix.Item.instances[id]
    if not filter or not filter.isFilter or not filter:IsEquipped() then return end
    -- A stale link must not protect a player after a filter was dropped/traded.
    for _, owned in pairs(client:GetItems()) do
        if owned == filter then return filter end
    end
end

function M.Profile(item)
    if not item then return end
    local visor = item.gasMaskVisor
    if visor == nil then visor = item.uniqueID ~= "gasmask_early" end
    return {visor = visor, overlay = item.gasMaskOverlay or "black_ops_1/screenoverlays/hazmatmask_001",
        breath = item.gasMaskBreath or "black_ops_1/wep/gasmask/breath.wav"}
end

function M.FilterFraction(client, mask)
    local filter = M.Filter(client, mask)
    if not filter then return 0 end
    return math.Clamp(filter:GetFilterQuality() / math.max(filter.filterQuality or 100, 1), 0, 1), filter.id
end

function M.Warning(fraction)
    if fraction <= 0 then return "gasmaskFilterEmpty" end
    if fraction <= 0.2 then return "gasmaskFilterLow" end
end
