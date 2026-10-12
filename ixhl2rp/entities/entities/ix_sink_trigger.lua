AddCSLuaFile()
DEFINE_BASECLASS("base_anim")

ENT.PrintName       = "Sink Trigger"
ENT.Category = "HL2 RP"

ENT.Spawnable       = false
ENT.AdminOnly       = true
ENT.DoAttach        = false
ENT.PhysgunPickupDisabled = false

ENT.RenderGroup = RENDERGROUP_BOTH -- translucent

function ENT:Initialize()
	if SERVER then
		self:SetModel("models/hunter/blocks/cube025x05x025.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:DrawShadow(false)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then 
			phys:EnableMotion(false) 
		end

		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	end
end

function ENT:OnTakeDamage()
	return false
end

function ENT:ShouldNotCollide(pPlayer)
	return false
end

-- The shared water plugin owns validation, selection and completion.
function ENT:Use(client)
 if SERVER and ix.water and ix.water.Open then ix.water.Open(client, self) end
end

properties.Add("sinktrigger", {
	MenuLabel = "Вода (кран)",
	Order = 400,
	MenuIcon = "icon16/contrast_low.png",

	Filter = function(self, entity, client)
		return entity:GetClass() == "prop_physics" and client:IsUserGroup("founder")
	end,

	Action = function(self, entity)
		self:MsgStart()
			net.WriteEntity(entity)
		self:MsgEnd()
	end,

	Receive = function(self, length, client)
		local entity = net.ReadEntity()

		if (!IsValid(entity)) then return end
		if (!self:Filter(entity, client)) then return end
		
		if entity.PermaID then
			client:NotifyLocalized("permaall.cantConvert")

			return
		end

		local pos, ang = entity:GetPos(), entity:GetAngles()

		entity:Remove()

		local sink = ents.Create("ix_sink_trigger")
		sink:SetPos(pos)
		sink:SetAngles(ang)
		sink:Spawn()
	end
})


if not CLIENT then return end

function ENT:Draw() end

ENT.PopulateEntityInfo = true

function ENT:OnPopulateEntityInfo(tooltip)
 local title = tooltip:AddRow("hint")
 title:SetText("E — напиться / выбрать ёмкость / вымыть руки · грязная вода")
 title:SizeToContents()
end
