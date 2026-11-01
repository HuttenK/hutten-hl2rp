local P = PLUGIN
ix.arc9ShotEffects = ix.arc9ShotEffects or {}
local F = ix.arc9ShotEffects
if F.Stop then F.Stop() end
local original, replacement, stopped
local head = Material("effects/whiteflare")
local tracer = Material("arc9/tracer")
local smoke = Material("effects/fas_smoke_beam")
F.tracers = 0

local function finite(value, fallback)
 return isnumber(value) and value == value and math.abs(value) < math.huge and value or fallback
end
function F.TracerWidth(size, distanceSquared)
 -- ARC9's log(distanceSquared - 256^2) yields NaN near the viewer. Keep its
 -- distant scaling, but give close tracers a finite, nonzero minimum width.
 return math.max(0, finite(size, 1)) * math.max(1, math.log(math.max(1, distanceSquared - 256 * 256)))
end
function F.TracerOrigin(weapon, fallback)
 local owner, viewer = weapon:GetOwner(), LocalPlayer()
 local world = owner ~= viewer or not IsValid(viewer) or viewer:ShouldDrawLocalPlayer() or
  (ix.CCTV and ix.CCTV.rendering) or (ARC9 and ARC9.PresetCam)
 -- Read the assembled barrel/suppressor, not the SWEP's CSS fallback model.
 local muzzle = weapon.GetMuzzleDevice and weapon:GetMuzzleDevice(world)
 if IsValid(muzzle) then
  local attachment = muzzle:GetAttachment(weapon:GetQCAMuzzle())
  if attachment and attachment.Pos then return attachment.Pos end
 end
 return fallback
end

local function install()
 if stopped or replacement then return end
 local native = effects.Create("arc9_tracer")
 if not native or not isfunction(native.Init) then return end
 local info = debug.getinfo(native.Init, "S")
 if not info or not (info.source or ""):gsub("\\", "/"):match("effects/arc9_tracer%.lua$") then return end
 original, replacement = native, table.Copy(native)
 replacement.Init = function(self, data)
  self.Dir, self.Weapon, self.Cancelled, self.DieTime = nil, nil, false, 0
  local weapon = data:GetEntity()
  if not IsValid(weapon) or not weapon.ARC9 then return end
  local start = F.TracerOrigin(weapon, data:GetStart())
  local finish = data:GetOrigin()
  local distance = (finish - start):Length()
  if distance <= .001 then return end
  self.StartPos, self.EndPos, self.Dir = start, finish, (finish - start) / distance
  self.Speed = math.max(1, finite(data:GetScale(), 15000))
  if data:GetScale() <= 0 then self.Speed = 15000 end
  -- Keep a short hitscan cue visible for more than its sub-frame flight time.
  -- This is only a beam animation; the bullet has already hit on the server.
  self.LifeTime = math.max(.035, distance / self.Speed)
  self.LifeTime2 = .2
  self.StartTime = UnPredictedCurTime()
  self.DieTime = self.StartTime + math.max(self.LifeTime, self.LifeTime2)
  self.Weapon = weapon
  self.Color = weapon:GetProcessedValue("TracerColor", true) or color_white
  self.Size = finite(weapon:GetProcessedValue("TracerSize", true), 1)
  -- The engine already supplied the hit position: no second trace, projectile,
  -- collision simulation or damage is necessary for a cosmetic hitscan line.
  self:SetRenderBoundsWS(start, finish, Vector(16, 16, 16))
  F.tracers = F.tracers + 1
 end
 replacement.Think = function(self) return self.DieTime > UnPredictedCurTime() end
 replacement.Render = function(self)
  if self.Cancelled or not self.Dir then return end
  if IsValid(self.Weapon) and self.Weapon.TracerCancelled then self.Cancelled = true return end
  local elapsed = math.max(0, UnPredictedCurTime() - self.StartTime)
  local travel = math.Clamp(elapsed / self.LifeTime, 0, 1)
  local fade = math.Clamp(elapsed / self.LifeTime2, 0, 1)
  local start = self.StartPos + travel * .1 * (self.EndPos - self.StartPos)
  local finish = self.StartPos + travel * (self.EndPos - self.StartPos)
  local size = F.TracerWidth(self.Size, EyePos():DistToSqr(finish))
  if size <= 0 then return end
  local tail = self.Dir * math.max(0, math.min(self.Speed / 25, 512, (finish - start):Length()))
  if elapsed <= self.LifeTime then
   local dot = math.abs(EyeAngles():Forward():Dot(self.Dir))
   render.SetMaterial(head)
   render.DrawSprite(finish, size * dot * 2, size * dot * 2, self.Color)
   render.SetMaterial(tracer)
   render.DrawBeam(finish, finish - tail, size * .75, 1, 0, self.Color)
  end
  render.SetMaterial(smoke)
  render.DrawBeam(finish - tail, start, size * fade, 0, 1, Color(155, 155, 155, 155 * (1 - fade)))
 end
 effects.Register(replacement, "arc9_tracer")
end
timer.Simple(0, install)
timer.Create("ixARC9ShotEffects", 2, 0, install)
concommand.Add("ix_arc9_effects_info", function()
 for _, name in ipairs({"arc9_muzzle_others", "arc9_muzzle_light", "arc9_bullet_physics", "ix_render_budget"}) do
  local setting = GetConVar(name)
  print("[ARC9 effects]", name, setting and setting:GetString() or "missing")
 end
 print("[ARC9 effects] Hitscan adapter:", replacement ~= nil, "Tracers received:", F.tracers)
 print("[ARC9 effects] Muzzle events are not distance-throttled by the gamemode.")
end)
function F.Stop()
 stopped = true
 if replacement then
  local current = effects.Create("arc9_tracer")
  if current and current.Init == replacement.Init then effects.Register(original, "arc9_tracer") end
 end
 timer.Remove("ixARC9ShotEffects")
 concommand.Remove("ix_arc9_effects_info")
end
function P:OnUnload() F.Stop() end
