function PLUGIN:LoadData()
	self:LoadCombineLocks()
end

function PLUGIN:SaveData()
	self:SaveCombineLocks()
end

-- Обесточенный замок нельзя переключать (E по самому замку). Дублирует защиту в
-- ENT:Toggle, но живёт в плагин-хуке: перезагружается обычным lua-рефрешем, тогда как
-- файл сущности (SENT) кэшируется движком и обновляется только после рестарта карты.
-- Замок может висеть на ВНЕШНЕЙ грани приграничной двери — вне AABB зоны, поэтому
-- судим о питании и по позиции самой двери, а не только по позиции замка.
function PLUGIN:PlayerUse(client, entity)
	if (!IsValid(entity) or entity:GetClass() != "ix_combinelock") then return end

	local blackout = ix.plugin.list["blackout"]
	if (!blackout or !blackout.IsPosBlackedOut) then return end

	local dark = blackout:IsPosBlackedOut(entity:GetPos())
		or (IsValid(entity.door) and blackout:IsPosBlackedOut(entity.door:GetPos()))

	if (dark) then
		if (IsValid(client) and (client.ixBlackoutNotify or 0) < CurTime()) then
			client.ixBlackoutNotify = CurTime() + 2
			client:NotifyLocalized("blackout.noPower")
		end

		return false
	end
end

netstream.Hook("ixCombineLockPlace", function(client, id, access)
	local has, itemTable = client:HasItemByID(id)

	if itemTable then
		local data = {}
			data.start = client:GetShootPos()
			data.endpos = data.start + client:GetAimVector() * 96
			data.filter = client

		local lock = scripted_ents.Get("ix_combinelock"):SpawnFunction(client, util.TraceLine(data))

		if IsValid(lock) then
			lock:SetAccess(access)
			client:EmitSound("physics/metal/weapon_impact_soft2.wav", 75, 80)
			itemTable:Remove()
		else
			return false
		end
	end
end)