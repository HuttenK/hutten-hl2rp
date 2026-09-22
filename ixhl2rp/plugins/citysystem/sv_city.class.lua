

local ValueChangeException = ix.meta.ValueChangeException


local Resource = class("CityResource")
function Resource:Init(name, baseValue)
	--self.id = id
	self.name = name
	self.base = baseValue
	self.exception = ValueChangeException:New(self.base, self.base)

	self.cachedValue = nil
end

function Resource:AddRaw(modifier, reasonID)
	local flow

	if isnumber(reasonID) then
		flow = ix.City:GetEconomicFlow(reasonID)
	else
		flow = ix.City:GetEconomicFlowByID(reasonID)
	end
	
	if !flow then return end
	
	modifier.reason = flow.index

	self.exception:AddModifier(modifier)
	self.cachedValue = nil
end

local AddValue = ix.meta.AddValueModifier
function Resource:Add(value, reasonID)
	local add = AddValue:New(0, value)

	self:AddRaw(add, reasonID)
end

function Resource:Get()
	if self.cachedValue then
		return self.cachedValue
	else
		self.cachedValue = self.exception:GetModifiedValue()

		return self.cachedValue
	end
end

local StockOrder = class("CityStockOrder")
function StockOrder:Init(value, reason, uniqueID)
	self.isOrder = true
	self.id = uniqueID
	self.value = isnumber(value) and value == value and value < math.huge and math.max(value, 0) or 0
	self.reason = reason
end

function StockOrder:Add(value)
	if not isnumber(value) or value ~= value or math.abs(value) == math.huge then return end
	self.value = math.max(0, self.value + value)
end






local StockItem = class("CityStockItem")

local function Quantity(value)
    if not isnumber(value) or value ~= value or math.abs(value) == math.huge then return 0 end
    return math.max(0, value)
end

function StockItem:Init(id)
    self.id = id
    self.stored, self.supply, self.demand = 0, 0, 0
    self.init_stored = 0
    self.supplyOrders, self.demandOrders = {}, {}
    self.reason = {supply = {}, demand = {}}
end

function StockItem:GetStored() return self.stored end
function StockItem:SetStored(value) self.stored = Quantity(value) end
function StockItem:SetSupply(value) self.supply = Quantity(value) end
function StockItem:SetDemand(value) self.demand = Quantity(value) end

local function Total(base, orders)
    for _, order in ipairs(orders) do base = base + Quantity(order.value) end
    return base
end

function StockItem:GetSupply() return Total(self.supply + (self.add_supply or 0), self.supplyOrders) end
function StockItem:GetDemand() return Total(self.demand + (self.add_demand or 0), self.demandOrders) end
function StockItem:AddSupply(value)
    if istable(value) and value.isOrder then
        table.insert(self.supplyOrders, value)
    else self.supply = self.supply + Quantity(value) end
end
function StockItem:AddDemand(value)
    if istable(value) and value.isOrder then
        table.insert(self.demandOrders, value)
    else self.demand = self.demand + Quantity(value) end
end
function StockItem:AddStored(value) self:SetStored(self.stored + Quantity(value)) end
function StockItem:TakeStored(value)
    local taken = math.min(self.stored, Quantity(value))
    self:SetStored(self.stored - taken)
    return taken
end
function StockItem:Add(value) self:AddStored(value) end
function StockItem:Remove(value) return self:TakeStored(value) end
function StockItem:Set(supply, demand, storage)
    self:SetSupply(supply)
    self:SetDemand(demand)
    self:SetStored(storage)
    self.init_stored = self.stored
    self:UpdateStaticSupply()
end
function StockItem:UpdateStaticSupply()
    self.add_supply = math.max(self.stored - self.init_stored, 0)
    self.add_demand = math.max(self.init_stored - self.stored, 0)
end
function StockItem:Reasons() return self.reason end
function StockItem:AddReason(flow, supply, value)
    local target = self.reason[supply and "supply" or "demand"]
    target[flow.id] = math.max(0, (target[flow.id] or 0) + value)
end
function StockItem:GetPrice()
    local supply, demand = self:GetSupply(), self:GetDemand()
    local pressure = (demand - supply) / math.max(supply, demand, 1)
    return math.max(0, (self.baseCost or 1) * math.Clamp(1 + pressure * 0.75, 0.25, 1.75))
end

local Stock = class("CityStock")

function Stock:Init(city)
	self.city = city

	self.items = {}
end

function Stock:RegisterItem(id)
	if !self.items[id] then
		local item = StockItem:New(id)

		item.baseCost = 1

		self.items[id] = item
	end

	return self.items[id]
end

function Stock:AddItem(id, count, noSupply, static)
	local item = self:GetItem(id)

	if !item then
		item = self:RegisterItem(id)
	end
	
	item:Add(count)

	if !noSupply then
		if static then
			item:UpdateStaticSupply()
		else
			item:AddSupply(count)
		end
	end
end

function Stock:TakeItem(id, count, noDemand, static)
    local item = self:GetItem(id, true)
    local requested = Quantity(count)
    local taken = item:TakeStored(requested)
    if not noDemand then
        if static then item:UpdateStaticSupply() else item:AddDemand(requested) end
    end
    return taken
end

function Stock:AddSupplyOrder(id, reason)
	local item = self:GetItem(id, true)
	local order = ix.meta.CityStockOrder:New(0, reason)

	item:AddSupply(order)

	return order
end

function Stock:AddDemandOrder(id, reason)
	local item = self:GetItem(id, true)
	local order = ix.meta.CityStockOrder:New(0, reason)

	item:AddDemand(order)

	return order
end

function Stock:GetPrice(id)
	local item = self.items[id]

	return item and item:GetPrice() or 0
end

function Stock:GetItem(id, create)
	if !self.items[id] and create then
		return self:RegisterItem(id)
	end

	return self.items[id]
end

function Stock:GetItems()
	return table.GetKeys(self.items) 
end


local CITY = class("City")
function CITY:Init(id)
	ix.City.stored[id] = self

	self.id = id
	self.isLoading = false

	self.resources = {}
	self.resources.tokens = Resource:New("Tokens", 0)

	self.stock = Stock:New(self)
end

function CITY:IsLoading()
	return self.isLoading
end