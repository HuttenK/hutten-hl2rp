local PLUGIN = PLUGIN

PLUGIN.level   = PLUGIN.level or {}
PLUGIN.wetEnts = PLUGIN.wetEnts or {} -- [ent] = true: предметы, которым мы выставили водное демпфирование

-- ==== Синхронизация уровня воды клиентам ====
function PLUGIN:Sync(target)
	netstream.Start(target or player.GetAll(), "flood.sync", self.level)
end

-- Установить уровень воды в зоне (с зажимом по AABB), разослать и сохранить.
function PLUGIN:SetLevel(name, z)
	local area = ix.area.stored[name]
	if (!area or area.type != "flood") then return end

	local mins, maxs = self:GetAreaBounds(area)
	local floorZ = mins.z
	local ceilZ  = maxs.z

	z = math.Clamp(z, floorZ, ceilZ)

	-- На самом дне считаем зону осушённой (nil) — клиент не рисует воду, физика не трогает.
	if (z <= floorZ + 0.5) then
		self.level[name] = nil
	else
		self.level[name] = z
	end

	self:Sync()
	self:SaveData()
end

-- ==== Откачка (вызывается насосом ix_flood_pump) ====
-- Возвращает новый уровень и флаг «осушено полностью».
function PLUGIN:DrainStep(name, amount)
	local area = ix.area.stored[name]
	if (!area or area.type != "flood") then return end

	local mins = self:GetAreaBounds(area)

	local cur = self.level[name]
	if (!cur) then return mins.z, true end -- уже сухо

	self:SetLevel(name, cur - (amount or self.defaults.pumpStep))

	local drained = (self.level[name] == nil)

	if (drained) then
		for _, ply in ipairs(player.GetAll()) do
			ply:Notify("Зона '" .. name .. "' осушена. Вода откачана.")
		end
	end

	return self.level[name] or mins.z, drained
end

-- ==== Кабель насос <-> бак ====
-- Снять связь и убрать кабель у насоса (и у его бака).
local function removeRope(ent)
	if (!IsValid(ent)) then return end
	if (IsValid(ent.ixRope)) then ent.ixRope:Remove() end
	if (IsValid(ent.ixRopeConstraint)) then ent.ixRopeConstraint:Remove() end
	ent.ixRope = nil
	ent.ixRopeConstraint = nil
end

function PLUGIN:UnlinkPump(pump)
	if (!IsValid(pump)) then return end

	removeRope(pump)

	local tank = pump.linkedTank
	if (IsValid(tank)) then
		tank.linkedPump = nil
		removeRope(tank)
	end

	if (IsValid(tank)) then tank:SetNetVar("linked", false) end

	pump.linkedTank = nil
	pump:SetNetVar("linked", false)
end

-- Соединить насос и бак видимым физическим кабелем.
function PLUGIN:LinkPumpTank(pump, tank)
	if (!IsValid(pump) or !IsValid(tank)) then return end

	-- сначала разорвать старые связи обоих
	self:UnlinkPump(pump)
	if (IsValid(tank.linkedPump)) then self:UnlinkPump(tank.linkedPump) end

	local d = self.defaults

	local pumpTop = pump:GetPos() + pump:GetUp() * 40
	local tankTop = tank:GetPos() + tank:GetUp() * 40
	local length  = pumpTop:Distance(tankTop)

	local constr, rope = constraint.Rope(
		pump, tank, 0, 0,
		pump:WorldToLocal(pumpTop), tank:WorldToLocal(tankTop),
		length, 8, 0,
		d.cableWidth, d.cableMaterial, false
	)

	pump.linkedTank = tank
	tank.linkedPump = pump
	pump.ixRope = rope
	tank.ixRope = rope
	pump.ixRopeConstraint = constr
	tank.ixRopeConstraint = constr
	pump:SetNetVar("linked", true)
	tank:SetNetVar("linked", true)
end

-- ==== Подъём развёрнутых предметов (насос/бак) обратно в инвентарь ====
function PLUGIN:CanPickupDeployable(ent, client)
	if (!IsValid(ent) or !IsValid(client) or !client:IsPlayer()) then return false end

	local char = client:GetCharacter()
	if (!char) then return false end

	local owner = ent:GetNetVar("owner")
	return client:IsAdmin() or (owner and owner == char:GetID())
end

function PLUGIN:PickupDeployable(ent, client)
	local inv = client:GetInventory("main")
	if (!inv) then return end

	local placed = false

	if (ent.ixItemID and ix.Item.instances[ent.ixItemID]) then
		if (inv:AddItemByID(ent.ixItemID)) then placed = true end
	end

	if (!placed and ent.ixItemUnique) then
		if (inv:GiveItem(ent.ixItemUnique)) then placed = true end
	end

	if (!placed) then
		client:Notify("Инвентарь полон.")
		return
	end

	inv:Sync()
	client:Notify("Предмет поднят.")
	ent.bPickedUp = true
	ent:Remove()
end

-- При уничтожении (не подъёмом) роняем предмет в мир, чтобы он не пропал.
function PLUGIN:DropDeployableItem(ent)
	if (ent.bPickedUp) then return end
	if (!ent.ixItemID) then return end

	local item = ix.Item.instances[ent.ixItemID]
	if (item) then
		ix.Item:Spawn(ent:GetPos() + Vector(0, 0, 10), Angle(), item)
	end
end

-- ==== Плавучесть: толкаем погружённые физ-предметы вверх (каждый тик) ====
local function isBuoyant(ent)
	local class = ent:GetClass()
	return class == "prop_physics" or class == "ix_item"
end

function PLUGIN:ApplyBuoyancy(name, area, lvl)
	local d = self.defaults

	local boxMin, boxMax = self:GetAreaBounds(area)

	for _, ent in ipairs(ents.FindInBox(boxMin, boxMax)) do
		if (!IsValid(ent) or !isBuoyant(ent)) then continue end

		local phys = ent:GetPhysicsObject()
		if (!IsValid(phys) or !phys:IsMotionEnabled()) then continue end

		local pos = ent:WorldSpaceCenter()
		local depth = lvl - pos.z
		if (depth <= 0) then continue end

		local mass = phys:GetMass()
		local submerge = math.Clamp(depth / d.submergeDepth, 0, 1)

		-- Сила вверх = масса * ускорение. У дна ускорение > гравитации (всплывает),
		-- у поверхности падает до нуля → предмет встаёт вровень с водой.
		phys:Wake()
		phys:ApplyForceCenter(Vector(0, 0, mass * d.buoyancyAccel * submerge))

		-- Вязкость воды.
		phys:SetDamping(d.linearDamp, d.angularDamp)
		ent.ixFloodWet = CurTime()
		self.wetEnts[ent] = true
	end
end

function PLUGIN:Tick()
	for name, area in pairs(ix.area.stored or {}) do
		if (area.type == "flood") then
			local lvl = self.level[name]
			local mins = self:GetAreaBounds(area)
			if (lvl and mins and lvl > mins.z) then
				self:ApplyBuoyancy(name, area, lvl)
			end
		end
	end
end

-- ==== Утопление + сброс водного демпфирования у высохших предметов ====
function PLUGIN:DrownTick()
	local d = self.defaults

	for _, ply in ipairs(player.GetAll()) do
		if (!ply:Alive() or !ply:GetCharacter()) then continue end

		local eye = ply:EyePos()
		local lvl = self:WaterLevelAt(eye)

		if (lvl and eye.z < lvl) then
			ply.ixFloodAir = (ply.ixFloodAir or d.maxAir) - d.drownInterval

			if (ply.ixFloodAir <= 0) then
				local dmg = DamageInfo()
				dmg:SetDamage(d.drownDamage)
				dmg:SetDamageType(DMG_DROWN)
				dmg:SetAttacker(game.GetWorld())
				dmg:SetInflictor(game.GetWorld())
				ply:TakeDamageInfo(dmg)

				ply:EmitSound("player/drown" .. math.random(1, 2) .. ".wav", 60)
			end
		else
			ply.ixFloodAir = d.maxAir
		end
	end

	-- Высохшим предметам возвращаем нулевое демпфирование.
	for ent in pairs(self.wetEnts) do
		if (!IsValid(ent)) then
			self.wetEnts[ent] = nil
		elseif ((CurTime() - (ent.ixFloodWet or 0)) > 0.4) then
			local phys = ent:GetPhysicsObject()
			if (IsValid(phys)) then phys:SetDamping(0, 0) end
			self.wetEnts[ent] = nil
		end
	end
end

-- ==== Сохранение: уровни воды + насосы + баки + связи ====
function PLUGIN:SaveData()
	local pumps, tanks, links = {}, {}, {}
	local tankIndex = {}

	for _, e in ipairs(ents.FindByClass("ix_flood_tank")) do
		tanks[#tanks + 1] = { e:GetPos(), e:GetAngles(), e:GetNetVar("owner"), e.ixItemUnique or "flood_tank" }
		tankIndex[e] = #tanks
	end

	for _, e in ipairs(ents.FindByClass("ix_flood_pump")) do
		pumps[#pumps + 1] = { e:GetPos(), e:GetAngles(), e:GetNetVar("owner"), e.ixItemUnique or "flood_pump" }

		if (IsValid(e.linkedTank) and tankIndex[e.linkedTank]) then
			links[#links + 1] = { #pumps, tankIndex[e.linkedTank] } -- {индекс насоса, индекс бака}
		end
	end

	self:SetData({
		level = self.level,
		pumps = pumps,
		tanks = tanks,
		links = links,
	})
end

function PLUGIN:LoadData()
	local data = self:GetData()
	if (!istable(data)) then return end

	self.level = istable(data.level) and data.level or {}

	local function spawnStatic(class, t)
		local e = ents.Create(class)
		if (!IsValid(e)) then return end

		e:SetPos(t[1])
		e:SetAngles(t[2])
		e:Spawn()

		-- физику не морозим — предмет можно двигать

		if (t[3]) then e:SetNetVar("owner", t[3]) end -- владелец (для подъёма после рестарта)
		e.ixItemUnique = t[4]                          -- что выдать при подъёме

		return e
	end

	local tanks, pumps = {}, {}

	for i, t in ipairs(data.tanks or {}) do
		tanks[i] = spawnStatic("ix_flood_tank", t)
	end

	for i, t in ipairs(data.pumps or {}) do
		pumps[i] = spawnStatic("ix_flood_pump", t)
	end

	-- Восстанавливаем связи и пересоздаём кабели.
	for _, lk in ipairs(data.links or {}) do
		local pump, tank = pumps[lk[1]], tanks[lk[2]]
		if (IsValid(pump) and IsValid(tank)) then
			self:LinkPumpTank(pump, tank)
		end
	end

	self:Sync()
end

function PLUGIN:PlayerLoadedCharacter(client)
	timer.Simple(1, function()
		if (IsValid(client)) then
			self:Sync(client)
		end
	end)
end

-- Подстраховка: при респавне вернуть нормальную гравитацию (если умер в воде).
function PLUGIN:PlayerSpawn(client)
	if (client.ixFloodSwim) then
		client:SetGravity(1)
		client.ixFloodSwim = nil
	end
end

timer.Create("ixFloodDrown", 1, 0, function()
	if (PLUGIN.DrownTick) then
		PLUGIN:DrownTick()
	end
end)
