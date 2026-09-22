
AddCSLuaFile()

ENT.Base = "base_entity"
ENT.Type = "anim"
ENT.PrintName = "Item"
ENT.Category = "Helix"
ENT.Spawnable = false
ENT.ShowPlayerInteraction = true
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.bNoPersist = true

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "ItemID")
	self:NetworkVar("Float", 0, "AssemblyHullLength")
end

function ENT:GetItem()
	return ix.Item.instances[self.ixItemID] or ix.Item.instances[self:GetItemID()]// ix.Item:Get(self:GetItemID())
end

-- Physics and ray tests are separate in Source. Share the same trace geometry
-- on both realms without creating a moving client physics object.
function ENT:UpdateAssemblyTrace()
	local length = self:GetAssemblyHullLength()
	if length == self.ixTraceLength then return end
	if IsValid(self.ixTraceShape) then self.ixTraceShape:Destroy() end
	self.ixTraceShape = nil
	self.ixTraceLength = length
	if length <= 0 then return end
	local mins, maxs = Vector(-length, -3, -4), Vector(length, 3, 4)
	self.ixTraceShape = CreatePhysCollideBox(mins, maxs)
	self:SetCollisionBounds(mins, maxs)
	self:EnableCustomCollisions(true)
end

function ENT:TestCollision(startpos, delta, isbox, extents)
	self:UpdateAssemblyTrace()
	if not IsValid(self.ixTraceShape) then return end
	local mins = -extents
	local maxs = Vector(extents.x, extents.y, extents.z - mins.z)
	mins.z = 0
	local hit, normal, fraction = self.ixTraceShape:TraceBox(
		self:GetPos(), self:GetAngles(), startpos, startpos + delta, mins, maxs)
	if hit then return {HitPos = hit, Normal = normal, Fraction = fraction} end
end

function ENT:RemoveAssemblyTrace()
	if IsValid(self.ixTraceShape) then self.ixTraceShape:Destroy() end
	self.ixTraceShape = nil
end

if SERVER then
	local invalidBoundsMin = Vector(-8, -8, -8)
	local invalidBoundsMax = Vector(8, 8, 8)

	function ENT:InitializeItemPhysics(item)
		local definition = item and item.isWeapon and item.class and weapons.Get(item.class)
		local assembled = definition and definition.MirrorVMWM and ix.arc9Inventory and
			ix.arc9Inventory.IsClass(item.class)
		self.ixAssemblyHull = assembled and true or nil
		self:SetMoveType(MOVETYPE_VPHYSICS)
		if assembled then
			-- EFT viewmodels have no reliable world collision mesh. Keep a centered,
			-- server-owned pickup hull matching the centered client assembly.
			local hold = definition.HoldType
			local pistol = hold == "pistol" or hold == "revolver"
			local length = pistol and 7 or 22
			self:SetAssemblyHullLength(length)
			self:PhysicsInitBox(Vector(-length, -3, -4), Vector(length, 3, 4))
			self:SetSolid(SOLID_VPHYSICS)
			self:EnableCustomCollisions(true)
		else
			self:SetAssemblyHullLength(0)
			self:PhysicsInit(SOLID_VPHYSICS)
			self:SetSolid(SOLID_VPHYSICS)
			if not IsValid(self:GetPhysicsObject()) then
				self:PhysicsInitBox(invalidBoundsMin, invalidBoundsMax)
				self:SetSolid(SOLID_VPHYSICS)
				self:EnableCustomCollisions(true)
			end
		end
		self:UpdateAssemblyTrace()
		local physics = self:GetPhysicsObject()
		if IsValid(physics) then
			if assembled then physics:SetMass(4) end
			physics:EnableMotion(true)
			physics:Wake()
		end
	end

	function ENT:Initialize()
		-- SetItem runs before Spawn; do not replace its box with model physics here.
		self:InitializeItemPhysics(self:GetItem())
		self:SetUseType(SIMPLE_USE)
		self:SetHealth(50)
	end

	function ENT:Use(activator, caller)
		-- Engine Use and the explicit E trace can arrive on the same press.
		-- Keep the original hold timer instead of resetting it every call.
		if IsValid(caller) and caller.ixInteractionTarget == self and
			timer.Exists("ixCharacterInteraction" .. caller:SteamID()) then return end
		local item = self:GetItem()

		if item then
			if IsValid(caller) and caller:IsPlayer() and caller:GetCharacter() and item then
				item.player = caller

				if item.functions.take.OnCanRun(item) then
					caller:PerformInteraction(ix.config.Get("itemPickupTime", 0.5), self, function(client)
						if !ix.Item:PerformItemEntityAction(client, item, self, "take") then
							return false
						end
					end)
				end

				item.player = nil
			end
		end
	end

	function ENT:Delete()
		local item = self:GetItem()

		if item then
			item:SetEntity(nil)
		end

		self.ixIsSafe = true
		self:Remove()
	end

	function ENT:OnTakeDamage(damageInfo)
		local item = self:GetItem()

		if item.OnEntityTakeDamage and item:OnEntityTakeDamage(self, damageInfo) == false then
			return
		end

		local damage = damageInfo:GetDamage()
		self:SetHealth(self:Health() - damage)

		if self:Health() <= 0 and !self.ixIsDestroying then
			self.ixIsDestroying = true
			self.ixDamageInfo = {damageInfo:GetAttacker(), damage, damageInfo:GetInflictor()}
			self:Remove()
		end
	end

	function ENT:SetItem(itemID)
		local itemTable = ix.Item.instances[itemID]

		if itemTable then
			local material = itemTable:GetMaterial(self)

			self:SetSkin(itemTable:GetSkin())
			self:SetModel(itemTable:GetModel())

			if material then
				self:SetMaterial(material)
			end

			self:SetItemID(itemID)
			self.ixItemID = itemID
			self:InitializeItemPhysics(itemTable)

			if itemTable.OnEntityCreated then
				itemTable:OnEntityCreated(self)
			end
		end
	end

	function ENT:OnRemove()
		self:RemoveAssemblyTrace()
		if !ix.shuttingDown and !self.ixIsSafe and self.ixItemID then
			local item = self:GetItem()

			if item then
				if self.ixIsDestroying then
					self:EmitSound("physics/cardboard/cardboard_box_break"..math.random(1, 3)..".wav")
					local position = self:LocalToWorld(self:OBBCenter())

					local effect = EffectData()
						effect:SetStart(position)
						effect:SetOrigin(position)
						effect:SetScale(3)
					util.Effect("GlassImpact", effect)

					if item.OnDestroyed then
						item:OnDestroyed(self)
					end

					ix.log.Add(self.ixDamageInfo[1], "itemDestroy", item:GetName(), item:GetID())
				end
				
				item:Remove()
			end
		end
	end

	function ENT:Think()
		local item = self:GetItem()

		if !item then
			self:Remove()
			return true
		end

		if item.Think then
			item:Think(self)
		end

		return true
	end

	function ENT:UpdateTransmitState()
		return TRANSMIT_PVS
	end

	net.Receive('item.entity.action', function(len, client)
		local entity = net.ReadEntity()
		local item = entity:GetItem()

		ix.Item:PerformItemEntityAction(client, item, entity, net.ReadUInt(item.functions_bits))
	end)
else
	function ENT:Initialize() self:UpdateAssemblyTrace() end
	function ENT:Think() self:UpdateAssemblyTrace() end
	function ENT:OnRemove() self:RemoveAssemblyTrace() end
	ENT.PopulateEntityInfo = true

	local shadeColor = Color(0, 0, 0, 200)
	local blockSize = 4
	local blockSpacing = 2

	function ENT:OnPopulateEntityInfo(tooltip)
		local item = self:GetItem()

		if !item then
			return
		end

		ix.hud.PopulateItemTooltip(tooltip, item)

		local name = tooltip:GetRow("name")
		local color = name and name:GetBackgroundColor() or ix.config.Get("color")

		-- set the arrow to be the same colour as the title/name row
		tooltip:SetArrowColor(color)

		if (item.width > 1 or item.height > 1) and hook.Run("ShouldDrawItemSize", item) != false then
			local sizeHeight = item.height * blockSize + item.height * blockSpacing
			local size = tooltip:Add("Panel")
			size:SetWide(tooltip:GetWide())

			if tooltip:IsMinimal() then
				size:SetTall(sizeHeight)
				size:Dock(TOP)
				size:SetZPos(-999)
			else
				size:SetTall(sizeHeight + 8)
				size:Dock(BOTTOM)
			end

			size.Paint = function(sizePanel, width, height)
				if !tooltip:IsMinimal() then
					surface.SetDrawColor(ColorAlpha(shadeColor, 60))
					surface.DrawRect(0, 0, width, height)
				end

				local x, y = width * 0.5 - 1, height * 0.5 - 1
				local itemWidth = item.width - 1
				local itemHeight = item.height - 1
				local heightDifference = ((itemHeight + 1) * blockSize + blockSpacing * itemHeight)

				x = x - (itemWidth * blockSize + blockSpacing * itemWidth) * 0.5
				y = y - heightDifference * 0.5

				for i = 0, itemHeight do
					for j = 0, itemWidth do
						local blockX, blockY = x + j * blockSize + j * blockSpacing, y + i * blockSize + i * blockSpacing

						surface.SetDrawColor(shadeColor)
						surface.DrawRect(blockX + 1, blockY + 1, blockSize, blockSize)

						surface.SetDrawColor(color)
						surface.DrawRect(blockX, blockY, blockSize, blockSize)
					end
				end
			end

			tooltip:SizeToContents()
		end
	end

	function ENT:DrawTranslucent()
		local itemTable = self:GetItem()

		if itemTable and itemTable.DrawEntity then
			itemTable:DrawEntity(self)
		end
	end

	function ENT:Draw()
		if ix.WeaponAssembly and ix.WeaponAssembly.DrawItem(self, self:GetItem(), self:WorldSpaceCenter(), self:GetAngles()) then return end
		self:DrawModel()
	end
end

function ENT:GetEntityMenu(client)
	local item = self:GetItem()
	local options = {}

	if !item then
		return false
	end

	item.player = client

	for k, v in SortedPairs(item.functions) do
		if v.OnCanRun and v.OnCanRun(item) == false then
			continue
		end

		-- we keep the localized phrase since we aren't using the callbacks - the name won't matter in this case
		options[L(v.name or k)] = function()
			local send = true

			if v.OnClick then
				send = v.OnClick(item)
			end

			if v.sound then
				surface.PlaySound(v.sound)
			end

			if send != false then
				net.Start('item.entity.action')
					net.WriteEntity(self)
					net.WriteUInt(v.index, item.functions_bits)
				net.SendToServer()
			end

			-- don't run callbacks since we're handling it manually
			return false
		end
	end

	item.player = nil

	return options
end

function ENT:GetData(key, default)
	local item = self:GetItem()

	return item:GetData(key, default)
end
