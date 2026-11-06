local A = ix.AOC
local centerIndices = setmetatable({}, {__mode = "k"})

-- Some swings straddle the crosshair without ever tracing along it. Check the
-- same reach straight ahead when the blade comes closest to the aim direction.
local function centerIndex(data)
 local index = centerIndices[data]
 if index then return index end
 local best = math.huge
 for i, sample in ipairs(data) do
  local distance = sample.Angle.p ^ 2 + sample.Angle.y ^ 2
  if distance < best then best, index = distance, i end
 end
 centerIndices[data] = index
 return index
end

local function endSwing(weapon)
 weapon:SetSliceTime(0)
 weapon:SetCurrentSlice(0)
 weapon:SetCurrentAttack(0)
end

function A.AdvanceSwing(weapon)
 local started = weapon:GetSliceTime()
 if started == 0 then return end
 local attack = weapon:GetCurrentAttack()
 local data = attack == AOC_ATTACK_SLASH and weapon.Primary
  or attack == AOC_ATTACK_OVERHEAD and weapon.Secondary
  or attack == AOC_ATTACK_STAB and weapon.Tertiary
 local i = weapon:GetCurrentSlice()
 if not data or not data[i] then endSwing(weapon); return end
 local elapsed = CurTime() - started
 if data[i].Time > elapsed then return end

 local center, previous = centerIndex(data), nil
 while i <= #data and data[i].Time <= elapsed do
  local sample = data[i]
  -- Identical consecutive rays within one tick query exactly the same pose.
  if not previous or sample.Angle ~= previous.Angle or sample.Start ~= previous.Start or sample.End ~= previous.End then
   if weapon:Slice(attack, data, sample) then endSwing(weapon); return end
  end
  local reach = data.Range or sample.End
  if i == center and (sample.Angle.p ~= 0 or sample.Angle.y ~= 0 or sample.Start ~= 0 or sample.End ~= reach) then
   local aim = {Angle = angle_zero, Start = 0, End = reach}
   if weapon:Slice(attack, data, aim) then endSwing(weapon); return end
  end
  previous = sample
  i = i + 1
 end
 if i > #data then endSwing(weapon) else weapon:SetCurrentSlice(i) end
end

function A.PrepareSwing(weapon)
 if not weapon.AOC_Melee or not weapon.Slice or not weapon.Think or weapon.ixAOCSwingPrepared then return end
 weapon.ixAOCSwingPrepared = true
 local think = weapon.Think
 weapon.Think = function(self, ...)
  local owner = self:GetOwner()
  if IsValid(owner) and owner:IsPlayer() and owner:GetCharacter() then A.AdvanceSwing(self) end
  -- The next unprocessed ray is in the future. Native Think still handles
  -- idle, block release, subclass effects, and NPC attacks.
  return think(self, ...)
 end
end
