local P = ix.PushCart

P.actions = {
	push = {label = "Взяться за ручку", icon = "icon16/lorry.png"},
	stop = {label = "Отпустить тележку", icon = "icon16/control_stop.png"},
	open = {label = "Открыть ящик", icon = "icon16/box.png"},
	pickup = {label = "Поднять ящик", icon = "icon16/hand.png"},
	drop = {label = "Поставить ящик", icon = "icon16/arrow_down.png"},
	detach = {label = "Отсоединить ящик", icon = "icon16/disconnect.png"},
	pack = {label = "Сложить в инвентарь", icon = "icon16/package.png"}
}

-- Attached crates are not solid. Resolve their individual OBBs before the
-- chassis behind them, without letting the selection ray pass through walls.
function P:InteractionTarget(client)
	local start = client:GetShootPos()
	local delta = client:GetAimVector() * self.USE_RANGE
	local trace = util.TraceLine({start = start, endpos = start + delta, filter = client, mask = MASK_SOLID})
	local target = trace.Entity
	local fraction = trace.Hit and trace.Fraction or 1
	for _, cart in ipairs(self:FindCartsNear(start, 230)) do
		for _, crate in ipairs(cart:GetChildren()) do
			if self:IsLoadable(crate) and crate:GetParent() == cart then
				local hit, _, f = util.IntersectRayWithOBB(start, delta, crate:GetPos(), crate:GetAngles(), self.CRATE_MINS, self.CRATE_MAXS)
				if hit and f >= 0 and f < fraction then target, fraction = crate, f end
			end
		end
	end
	if IsValid(target) and (target.ixIsPushCart or self:IsLoadable(target)) then return target end
end

function P:CanInteract(client, entity)
	if !self:CanOperate(client) or !IsValid(entity) then return false end
	return self:GetPushedCart(client) == entity or self:InteractionTarget(client) == entity
end
