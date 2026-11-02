ix.RenderBudget = ix.RenderBudget or {}
local B = ix.RenderBudget
local enabled = CreateClientConVar("ix_render_budget", "1", true, false, "Distance budget for holster refresh.", 0, 1)
local views = {}
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
 if not enabled:GetBool() or entity == LocalPlayer() then return 0 end
 local distance = B.DistanceSquared(entity)
 if distance <= 768 * 768 then return 0 end
 return distance <= 1536 * 1536 and .1 or .2
end
