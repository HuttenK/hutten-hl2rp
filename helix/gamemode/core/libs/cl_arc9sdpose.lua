-- Supply ARC9's weapon anchor from a native MP stance while SD keeps its own
-- locomotion. ARC9 still plays/synchronizes the actual weapon animation and
-- solves the player's arms. No character sequences or Workshop files change.
if ix.arc9SDPose and ix.arc9SDPose.Shutdown then ix.arc9SDPose.Shutdown() end
local R = {}
ix.arc9SDPose = R
local references, wrapped = {}, {}
local spineName = "ValveBiped.Bip01_Spine4"
local handName = "ValveBiped.Bip01_R_Hand"
local referenceModel = "models/player/kleiner.mdl"

local function ClearOwner(owner)
 local entry = references[owner]
 references[owner] = nil
 if entry and IsValid(entry.model) then entry.model:Remove() end
end

local function Eligible(weapon, owner)
 return IsValid(owner) and owner:IsPlayer() and owner.GetCharacter and owner:GetCharacter() and
  owner:Alive() and not owner:IsDormant() and
  ix.anim.CanRetargetARC9SDPose(owner, weapon) and
  not (ix.Downed and ix.Downed.Crawling and ix.Downed.Crawling(owner)) and
  not ix.anim.CanUseARC9NativePose(owner, weapon)
end

function R.Ready(weapon, owner)
 if not Eligible(weapon, owner) or not R.Install(weapon) then return false end
 local entry = references[owner]
 if entry and entry.target ~= owner:GetModel() then ClearOwner(owner) entry = nil end
 if not entry then
  entry = {target = owner:GetModel(), sequences = {}}
  references[owner] = entry
 end
 if not IsValid(entry.model) then
  if (entry.retry or 0) > CurTime() then return false end
  entry.retry = CurTime() + 2
  -- util.IsValidModel returns false clientside for models the server has not
  -- precached, even when ClientsideModel can load them. Validate the created
  -- model's sequences/bones below instead of blocking a local reference rig.
  entry.model = ClientsideModel(referenceModel, RENDERGROUP_OTHER)
  if not IsValid(entry.model) then return false end
  entry.model:SetNoDraw(true)
  entry.model:DrawShadow(false)
  entry.model:SetPlaybackRate(0)
  entry.sequences = {}
 end
 local donor = entry.model
 if donor:GetSequenceCount() < 2 then return false end
 local activity = ix.anim.GetARC9PoseActivity(owner, weapon)
 local sequence = entry.sequences[activity]
 if sequence == nil then
  sequence = donor:SelectWeightedSequence(activity)
  entry.sequences[activity] = sequence
 end
 if not isnumber(sequence) or sequence < 0 then return false end
 entry.spine = donor:LookupBone(spineName)
 entry.anchor = weapon.TPIKParentToSpine4 and entry.spine or donor:LookupBone(handName)
 if entry.spine == nil or entry.anchor == nil then return false end
 entry.sequence = sequence
 return true
end

function R.Anchor(weapon, owner)
 if not R.Ready(weapon, owner) then return end
 local entry = references[owner]
 local donor = entry.model
 local facing = owner:GetRenderAngles()
 local eyes = owner:EyeAngles()
 local frame = FrameNumber()
 -- One skeleton sample per visible owner/frame, shared by depth and colour
 -- passes. Also invalidate on an in-frame stance, yaw or model-scale change.
 local key = entry.sequence .. ":" .. facing.y .. ":" .. eyes.p .. ":" .. eyes.y .. ":" .. owner:GetModelScale()
 if entry.frame ~= frame or entry.key ~= key then
  entry.frame, entry.key = frame, key
  donor:SetPos(vector_origin)
  donor:SetAngles(Angle(0, facing.y, 0))
  donor:SetModelScale(owner:GetModelScale(), 0)
  if donor:GetSequence() ~= entry.sequence then donor:ResetSequence(entry.sequence) end
  donor:SetCycle(owner:GetCycle())
  donor:SetPoseParameter("aim_pitch", math.NormalizeAngle(eyes.p))
  donor:SetPoseParameter("aim_yaw", math.AngleDifference(eyes.y, facing.y))
  donor:SetPoseParameter("move_yaw", math.AngleDifference(owner:GetVelocity():Angle().y, eyes.y))
  donor:InvalidateBoneCache()
  donor:SetupBones()
 end
 owner:SetupBones()
 local target = owner:GetBoneMatrix(owner:LookupBone(spineName))
 local base = donor:GetBoneMatrix(entry.spine)
 local anchor = donor:GetBoneMatrix(entry.anchor)
 if not target or not base or not anchor then return end
 -- Keep the real character's chest position (including crouch/height), but
 -- use the MP bone orientation/hand offset expected by WorldModelOffset.
 return target:GetTranslation() + anchor:GetTranslation() - base:GetTranslation(), anchor:GetAngles()
end

function R.Install(weapon)
 if not IsValid(weapon) or not weapon.ARC9 or not isfunction(weapon.GetAttachmentPos) or not isfunction(weapon.ShouldTPIK) then return false end
 local existing = wrapped[weapon]
 if existing and weapon.GetAttachmentPos == existing.wrapper then return true end
 local original = weapon.GetAttachmentPos
 local state = {original = original}
 state.wrapper = function(self, slot, wm, idle, nomodeloffset, custompos, customang, duplicate)
  -- Only the held weapon's root. Attachments retain their ARC9 parent bones;
  -- first-person, dropped weapons, inventory previews and holsters bypass it.
  if slot.WMBase and wm and not idle and not custompos then
   local owner = self:GetOwner()
   local pos, ang
   if Eligible(self, owner) and self:ShouldTPIK() then pos, ang = R.Anchor(self, owner) end
   local mode = pos and owner:GetModel() or false
   if state.mode ~= mode or state.owner ~= owner then
    state.mode, state.owner = mode, owner
    self.AttPosCache = {}
    self.TPIKCache = {}
    self.LastTPIKTime = 0
   end
   if pos then
    -- The base's custom-origin argument preserves offsets, sights, recoil,
    -- reload motion and attachment hooks without copying its implementation.
    return original(self, slot, wm, idle, nomodeloffset, pos, ang, duplicate)
   end
  end
  return original(self, slot, wm, idle, nomodeloffset, custompos, customang, duplicate)
 end
 wrapped[weapon] = state
 weapon.GetAttachmentPos = state.wrapper
 return true
end

local function Unwrap(weapon)
 local state = wrapped[weapon]
 wrapped[weapon] = nil
 if state and IsValid(weapon) and weapon.GetAttachmentPos == state.wrapper then
  weapon.GetAttachmentPos = state.original
  weapon.AttPosCache = {}
  weapon.TPIKCache = {}
 end
end

function R.Shutdown()
 for owner in pairs(references) do ClearOwner(owner) end
 for weapon in pairs(wrapped) do Unwrap(weapon) end
end

hook.Add("Think", "ixARC9SDPose", function()
 for _, owner in ipairs(player.GetAll()) do
  local weapon = owner:GetActiveWeapon()
  if Eligible(weapon, owner) then R.Install(weapon) end
 end
 if (R.nextCleanup or 0) > CurTime() then return end
 R.nextCleanup = CurTime() + 1
 for owner, entry in pairs(references) do
  if not IsValid(owner) or entry.target ~= owner:GetModel() or not Eligible(owner:GetActiveWeapon(), owner) then ClearOwner(owner) end
 end
 for weapon in pairs(wrapped) do
  if not IsValid(weapon) or not Eligible(weapon, weapon:GetOwner()) then Unwrap(weapon) end
 end
end)
hook.Add("EntityRemoved", "ixARC9SDPose", function(entity) ClearOwner(entity) Unwrap(entity) end)
hook.Add("ShutDown", "ixARC9SDPose", R.Shutdown)
