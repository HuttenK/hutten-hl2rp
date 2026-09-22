local FlowCategory = {}
FlowCategory.__index = FlowCategory
function FlowCategory:Add(name, info)
	self[name] = {
		id = name,
		positive = info.positive,
		negative = info.negative,
		flows = {}
	}
end

local Flow = {}
Flow.__index = Flow
function Flow:Add(name, info, category)
	self[name] = {
		id = name,
		positive = info.positive,
		negative = info.negative,
		category = category
	}

	local group = istable(category) and category or ix.City.FlowCategory[category]
	if group then
		group.flows[name] = self[name]
	end
	self[name].index = name
end

local City = ix.util.Lib("City", {
	Flow = Flow,
	FlowCategory = FlowCategory,
	stored = {},
	restockCallbacks = {},
	dynamicOrders = {}
})

City.FlowCategory:Add("TradeImport", {
	positive = "от импорта товаров",
	negative = "на импорт товаров"
})

City.Flow:Add("Trade", {}, City.FlowCategory.TradeImport)

if SERVER then
	function City:GetEconomicFlowByID(id)
		return self.Flow[id]
	end

	function City:GetEconomicFlow(id)
		return self.Flow[id]
	end

	function City:Get(id)
		return self.stored[id]
	end

/*
	function City:MarketOrder(id, reason)
		if self.dynamicOrders[id] then
			return self.dynamicOrders[id]
		end
		
		local order = ix.meta.CityStockOrder:New(0, reason, id)

		self.dynamicOrders[id] = order

		return order
	end*/

	function City:RegisterRestock(class, callback)
		self.restockCallbacks[class] = callback
	end

	function City:Restock(entity)
		local class, city = entity:GetClass(), entity.city

		if !city or !self.restockCallbacks[class] then return end

		city = self:Get(city)
		if not city or city:IsLoading() then return end

		/*if !city or (city and city:IsLoading()) then 
			return 
		end*/

		self.restockCallbacks[class](city, entity)
	end
end
