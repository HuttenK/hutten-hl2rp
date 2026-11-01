local P = PLUGIN
ix.RenderBudget = ix.RenderBudget or {}
local B = ix.RenderBudget
if B.Stop then B.Stop() end
local enabled = CreateClientConVar("ix_render_budget", "1", true, false,
 "Distance budgets for remote ARC9 arm solves and holster refresh; 0 restores original behavior.", 0, 1)
local arms = CreateClientConVar("ix_render_budget_arms", "1", true, false,
 "Use cached ARC9 arm targets at distance. Disable independently if an imported model needs full solves.", 0, 1)
local views, states = {}, setmetatable({}, {__mode = "k"})
local helperSetting, helperOriginal
local stopped = false
B.stats = {solves = 0, cached = 0, muzzleKept = 0, muzzleSkipped = 0}

local function restoreHelper()
 if helperSetting and helperOriginal ~= nil and not helperSetting:GetBool() then
  helperSetting:SetBool(helperOriginal)
 end
 helperSetting, helperOriginal = nil, nil
end
local function policy()
 if stopped then return end
 if not enabled:GetBool() or not arms:GetBool() then restoreHelper(); states = setmetatable({}, {__mode = "k"}); return end
 -- The sole arm wrapper must exist before changing ARC9's global override.
 local helpers = ARC9 and ARC9.TPIK
 if not ix.arc9Helpers or not ix.arc9Helpers.CanBudget or not ix.arc9Helpers.CanBudget() or
  not helpers or not isfunction(helpers.HelperHasCachedRoots) then
  restoreHelper()
  return
 end
 if not helperSetting then
  helperSetting = GetConVar("arc9_tpik_helper_bone_force_full_fps")
  if helperSetting then
   helperOriginal = helperSetting:GetBool()
   if helperOriginal then helperSetting:SetBool(false) end
  end
 end
end
B.RefreshPolicy = policy

-- EyePos() inside a world pass is its actual camera, including CCTV/reflections.
-- Retain recently rendered views for effect events arriving outside a render hook.
hook.Add("PreDrawOpaqueRenderables", "ixRenderBudgetViews", function(_, sky)
 if sky then return end
 local pos, now = EyePos(), RealTime()
 for i = #views, 1, -1 do
  if now - views[i].time > .35 then table.remove(views, i)
  elseif views[i].pos:DistToSqr(pos) < 64 * 64 then views[i].pos = pos; views[i].time = now; return end
 end
 views[#views + 1] = {pos = pos, time = now}
 if #views > 16 then table.remove(views, 1) end
end)
function B.DistanceSquared(entity)
 local pos = entity:GetPos()
 local setup = render.GetViewSetup(false)
 local distance = pos:DistToSqr(setup and setup.origin or EyePos())
 distance = math.min(distance, pos:DistToSqr(EyePos()))
 local now = RealTime()
 for _, view in ipairs(views) do
  if now - view.time <= .35 then distance = math.min(distance, pos:DistToSqr(view.pos)) end
 end
 return distance
end
function B.Interval(entity)
 if stopped or not enabled:GetBool() or entity == LocalPlayer() then return 0 end
 local distance = B.DistanceSquared(entity)
 if distance <= 768 * 768 then return 0 end
 return distance <= 1536 * 1536 and .1 or .2
end

-- Called INSIDE the existing single DoTPIK owner, after height/pose hooks.
-- Never skip DoTPIK: ARC9 reprojects cached targets and writes bones every draw.
-- Only its expensive target/IK recomputation receives a lower distant cadence.
function B.RunTPIK(weapon, original, ...)
 local helpers = ARC9 and ARC9.TPIK
 if not helpers or not isfunction(helpers.HelperHasCachedRoots) then
  restoreHelper()
  return original(weapon, ...)
 end
 if stopped or not enabled:GetBool() or not arms:GetBool() or not helperSetting or helperSetting:GetBool() then
  return original(weapon, ...)
 end
 local owner = weapon:GetOwner()
 if not IsValid(owner) or not owner:IsPlayer() then return original(weapon, ...) end
 local interval = B.Interval(owner)
 local state = states[weapon]
 local model, scale = owner:GetModel(), owner:GetModelScale()
 local sequence = weapon.GetSequenceIndex and weapon:GetSequenceIndex()
 local hold = weapon:GetHoldType()
 local reload = weapon.GetReloading and weapon:GetReloading()
 local action = owner:GetNW2String("ixContextAction", "")
 local pose = owner:GetNetVar("forcedSequence") or owner:GetNetVar("sharedPose")
 local dirty = not state or state.owner ~= owner or state.model ~= model or state.scale ~= scale or
  state.sequence ~= sequence or state.hold ~= hold or state.reload ~= reload or state.action ~= action or state.pose ~= pose or
  state.cache ~= weapon.TPIKCache or interval < state.interval
 local now, previous = CurTime(), weapon.LastTPIKTime
 -- Match ARC9's full-rate exception only for rigs with cached helper roots.
 -- Ordinary nearby rigs retain their configured native solve frequency.
 local fullNear = interval == 0 and helperOriginal and helpers and
  isfunction(helpers.HelperHasCachedRoots) and helpers.HelperHasCachedRoots(owner)
 local full = dirty or fullNear or interval > 0 and now >= state.nextSolve
 if full then
  weapon.LastTPIKTime = -math.huge
  B.stats.solves = B.stats.solves + 1
 elseif interval > 0 then
  weapon.LastTPIKTime = now
  B.stats.cached = B.stats.cached + 1
 end
 local ok, result = pcall(original, weapon, ...)
 -- Do not leave a fabricated future timestamp behind when changing views/settings.
 if not full and interval > 0 then weapon.LastTPIKTime = previous end
 if not ok then weapon.LastTPIKTime = previous; error(result, 0) end
 state = state or {}
 state.owner, state.model, state.scale, state.sequence, state.hold = owner, model, scale, sequence, hold
 state.reload, state.action, state.pose = reload, action, pose
 state.cache, state.interval = weapon.TPIKCache, interval
 if full then state.nextSolve = now + interval end
 states[weapon] = state
 return result
end

function B.AllowMuzzle(weapon)
 -- A flash communicates a shot. Do not drop it with cosmetic update budgets.
 B.stats.muzzleKept = B.stats.muzzleKept + 1
 return true
end
local function install() policy() end
timer.Simple(0, install)
timer.Create("ixRenderBudgetInstall", 2, 0, install)
cvars.AddChangeCallback("ix_render_budget", policy, "ixRenderBudget")
cvars.AddChangeCallback("ix_render_budget_arms", policy, "ixRenderBudget")
concommand.Add("ix_render_budget_status", function()
 print("[Render budget] Enabled:", enabled:GetBool(), "Arms:", arms:GetBool(),
  "Helper full-FPS override:", helperSetting and helperSetting:GetBool() or false)
 print("[Render budget] Local/near <=768: original fidelity; 768-1536: 10Hz; farther: 5Hz. Recent camera views included.")
 print("[Render budget] Full solves:", B.stats.solves, "Cached draws:", B.stats.cached, "Muzzle effects: unthrottled")
end)
function B.Stop()
 stopped = true; restoreHelper()
 timer.Remove("ixRenderBudgetInstall")
 hook.Remove("PreDrawOpaqueRenderables", "ixRenderBudgetViews")
 hook.Remove("ShutDown", "ixRenderBudget")
 cvars.RemoveChangeCallback("ix_render_budget", "ixRenderBudget")
 cvars.RemoveChangeCallback("ix_render_budget_arms", "ixRenderBudget")
 concommand.Remove("ix_render_budget_status")
end
hook.Add("ShutDown", "ixRenderBudget", restoreHelper)
local oldUnload = P.OnUnload
function P:OnUnload()
 B.Stop()
 if oldUnload then oldUnload(self) end
end
