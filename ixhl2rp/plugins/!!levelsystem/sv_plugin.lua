local PLUGIN = PLUGIN
local CHAR = ix.meta.character

local function Finite(value)
    return isnumber(value) and value == value and value > -math.huge and value < math.huge
end

-- One authority for level transitions, including admin changes. Reassigning the
-- current level is a no-op; points are awarded only for crossed levels.
function CHAR:SetProgressionLevel(targetLevel, resetXP)
    if not Finite(targetLevel) then return false end
    local previous = self:GetLevel()
    local target = math.Clamp(math.floor(targetLevel), 1, PLUGIN.maxLevel)
    if previous == target then return false end
    local points = 0
    if target > previous then
        for level = previous + 1, target do
            points = points + PLUGIN:GetPointsAtLevel(level)
        end
    else
        for level = target + 1, previous do
            points = points - PLUGIN:GetPointsAtLevel(level)
        end
    end
    self:SetSkillPoints(self:GetSkillPoints() + points)
    self:SetLevel(target)
    if resetXP then self:SetLevelXP(0) end
    self:SetData("levelup", true)
    local client = self:GetPlayer()
    if IsValid(client) then
        ix.chat.Send(nil, "level", "", nil, {client}, {t = target > previous and 1 or 3})
    end
    hook.Run("CharacterLevelChanged", client, self, previous, target)
    return true
end

function CHAR:LevelUp(deltaXP)
    self:SetProgressionLevel(self:GetLevel() + 1, true)
    if deltaXP and deltaXP ~= 0 then self:AddLevelXP(deltaXP, nil, true) end
end

function CHAR:LevelDown(deltaXP)
    self:SetProgressionLevel(self:GetLevel() - 1, true)
    if deltaXP and deltaXP ~= 0 then self:AddLevelXP(deltaXP, nil, true) end
end

function CHAR:AddLevelXP(xp, reasonType, alreadyAdjusted)
    xp = xp == nil and 1 or xp
    if not Finite(xp) then return false end
    local client = self:GetPlayer()
    if xp > 0 and not alreadyAdjusted and IsValid(client) and client.IsDonator and client:IsDonator() then
        xp = xp * 1.15
    end
    local level = self:GetLevel()
    local current = self:GetLevelXP() + xp
    if not Finite(current) then return false end
    -- Bounded traversal avoids recursion at the cap and repeated donor bonuses.
    while level < PLUGIN.maxLevel do
        local required = PLUGIN:GetRequiredLevelXP(level)
        if required <= 0 or current < required then break end
        current = current - required
        level = level + 1
    end
    while current < 0 and level > 1 do
        level = level - 1
        current = current + math.max(0, PLUGIN:GetRequiredLevelXP(level))
    end
    self:SetProgressionLevel(level, false)
    self:SetLevelXP(level >= PLUGIN.maxLevel and 0 or math.max(0, current))
    hook.Run("CharacterEarnedXP", client, self, xp, reasonType)
    return true
end

local PLAYER = FindMetaTable("Player")
function PLAYER:RewardXP(xp, text)
    local character = self:GetCharacter()
    if character and character:AddLevelXP(xp) then
        local reason = isstring(text) and (L(text, self) or text) or text
        self:NotifyLocalized("xp.reward", xp, reason)
    end
end
