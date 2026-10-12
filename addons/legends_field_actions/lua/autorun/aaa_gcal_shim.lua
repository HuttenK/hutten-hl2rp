if SERVER then
    AddCSLuaFile()
end

GCAL = GCAL or {}
GCAL.Anims = GCAL.Anims or {}
GCAL.ActiveTracks = GCAL.ActiveTracks or {}

VManip = VManip or {}
VMLegs = VMLegs or {}

setmetatable(VManip, getmetatable(VManip) or {
    __call = function()
        return true
    end
})

local function StubNoop()
    return false
end

local function StubNil()
    return nil
end

local function StubZero()
    return 0
end

function VManip:RegisterAnim(arg1, arg2, arg3)
    local name, data
    if isstring(arg1) then
        name, data = arg1, arg2
    else
        name, data = arg2, arg3
    end

    if not name or not data then return end
    self.Anims = self.Anims or GCAL.Anims or {}
    self.Anims[name] = data
end

function VManip:GetAnim(name)
    self.Anims = self.Anims or GCAL.Anims or {}
    return self.Anims[name]
end

VManip.PlayAnim = VManip.PlayAnim or StubNoop
VManip.IsActive = VManip.IsActive or StubNoop
VManip.IsValid = VManip.IsValid or StubNoop
VManip.Remove = VManip.Remove or function() end
VManip.GetCurrentAnim = VManip.GetCurrentAnim or StubNil
VManip.GetVMGesture = VManip.GetVMGesture or StubNil
VManip.GetLerp = VManip.GetLerp or StubZero
VManip.GetCycle = VManip.GetCycle or StubZero
VManip.SetCycle = VManip.SetCycle or function() end
VManip.IsSegmented = VManip.IsSegmented or StubNoop
VManip.GetCurrentSegment = VManip.GetCurrentSegment or StubNil
VManip.GetSegmentCount = VManip.GetSegmentCount or StubZero
VManip.IsPreventQuit = VManip.IsPreventQuit or StubNoop
VManip.QuitHolding = VManip.QuitHolding or function() end
VManip.QueueAnim = VManip.QueueAnim or function() end
VManip.PlaySegment = VManip.PlaySegment or StubNoop
VManip.Anims = VManip.Anims or GCAL.Anims or {}
VManip.ActiveTracks = VManip.ActiveTracks or GCAL.ActiveTracks or {}

function VMLegs:RegisterAnim(arg1, arg2, arg3)
    local name, data
    if isstring(arg1) then
        name, data = arg1, arg2
    else
        name, data = arg2, arg3
    end

    if not name or not data then return end
    self.Anims = self.Anims or GCAL.Anims or {}
    self.Anims["legs_" .. name] = data
end

function VMLegs:GetAnim(name)
    self.Anims = self.Anims or GCAL.Anims or {}
    return self.Anims["legs_" .. name] or self.Anims[name]
end

VMLegs.PlayAnim = VMLegs.PlayAnim or StubNoop
VMLegs.IsActive = VMLegs.IsActive or StubNoop
VMLegs.Remove = VMLegs.Remove or function() end
VMLegs.GetCurrentAnim = VMLegs.GetCurrentAnim or StubNil
VMLegs.Anims = VMLegs.Anims or GCAL.Anims or {}
