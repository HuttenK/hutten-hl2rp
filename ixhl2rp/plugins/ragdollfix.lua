local PLUGIN = PLUGIN

PLUGIN.name = "Ragdoll Fixes"
PLUGIN.author = "SchwarzKruppzo"
PLUGIN.description = ""

if SERVER then
	local playerMeta = FindMetaTable("Player")

	function playerMeta:CreateServerRagdoll(bDontSetPlayer)
		local entity = ents.Create("prop_ragdoll")
		if (!IsValid(entity)) then return end
		entity:SetPos(self:GetPos())
		entity:SetAngles(self:EyeAngles())
		entity:SetModel(self:GetModel())
		entity:SetModelScale(self:GetModelScale(), 0)
		entity:SetSkin(self:GetSkin())

		for k, v in ipairs(self:GetBodyGroups()) do
			entity:SetBodygroup(v.id, self:GetBodygroup(v.id))
		end

		entity:Spawn()

		if (!bDontSetPlayer) then
			entity:SetNetVar("player", self)
		end

		entity:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		entity:SetNotSolid(false)
		entity:SetCustomCollisionCheck(false)
		entity:Activate()

		hook.Run("OnCreatePlayerServerRagdoll", self, entity)

		local velocity = self:GetVelocity()

		for i = 0, entity:GetPhysicsObjectCount() - 1 do
			local physObj = entity:GetPhysicsObjectNum(i)

			if (IsValid(physObj)) then
				physObj:SetVelocity(velocity)

				local index = entity:TranslatePhysBoneToBone(i)

				local playerBone = index and index >= 0 and self:LookupBone(entity:GetBoneName(index))
				if (playerBone) then
					local position, angles = self:GetBonePosition(playerBone)
					if (position and angles) then
						physObj:SetPos(position)
						physObj:SetAngles(angles)
					end
				end
			end
		end

		return entity
	end
end
