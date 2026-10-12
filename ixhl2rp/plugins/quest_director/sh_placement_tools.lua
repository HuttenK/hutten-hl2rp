local PLUGIN, Q = PLUGIN, ix.questDirector

function Q:IsPlacementEntity(entity)
    return IsValid(entity) and (entity:GetClass() == "ix_quest_object" or entity:GetClass() == "ix_quest_actor")
end

function Q:ManagedPlacement(entity)
    if not self:IsPlacementEntity(entity) then return end
    local id = entity.ixQuestPlacement
    if id and self.entities[id] == entity then return self.placements[id], id end
end

-- Match the normal localized C-menu Remove entry. Its quest-specific receiver
-- also deletes the saved placement; native Remove is suppressed below so the
-- menu contains one removal action and a restart cannot resurrect the entity.
-- Never mutate anything while building the menu (Filter/CanProperty).
properties.Add("ixquest_remove", {
    MenuLabel = "#remove", Order = 1000, MenuIcon = "icon16/delete.png",
    Filter = function(_, entity, client)
        if not Q:IsPlacementEntity(entity) or not Q.CanEdit(client) then return false end
        return CLIENT or Q:ManagedPlacement(entity) ~= nil
    end,
    Action = function(self, entity)
        self:MsgStart() net.WriteEntity(entity) self:MsgEnd()
    end,
    Receive = function(self, _, client)
        local entity = net.ReadEntity()
        if not self:Filter(entity, client) or not properties.CanBeTargeted(entity, client) then return end
        local _, message = Q:RemovePlacement(client, entity.ixQuestPlacement)
        client:Notify(message)
    end
})

function PLUGIN:CanProperty(client, property, entity)
    if Q:IsPlacementEntity(entity) then return property == "ixquest_remove" and Q.CanEdit(client) end
end

function PLUGIN:PhysgunPickup(client, entity)
    if not Q:IsPlacementEntity(entity) then return end
    if not Q.CanEdit(client) or Q.storageFault or (SERVER and not Q:ManagedPlacement(entity)) then return false end
    -- Abstain for editors so Helix's prop protection and collision setup still run.
end

function PLUGIN:CanPlayerUnfreeze(_, entity)
    if Q:IsPlacementEntity(entity) then return false end
end

function PLUGIN:CanTool(client, trace)
    if trace and Q:IsPlacementEntity(trace.Entity) then return false end
end

function PLUGIN:GravGunPickupAllowed(_, entity)
    if Q:IsPlacementEntity(entity) then return false end
end
PLUGIN.GravGunPunt = PLUGIN.GravGunPickupAllowed

if not SERVER then return end

function Q:InitializePlacementPhysics(entity)
    entity:PhysicsInit(SOLID_VPHYSICS)
    local physics = entity:GetPhysicsObject()
    local solid = SOLID_VPHYSICS
    if not IsValid(physics) then
        -- Decorative models also need a physics object for the physgun.
        local mins, maxs = entity:GetModelBounds()
        entity:PhysicsInitBox(mins, maxs)
        entity:SetCollisionBounds(mins, maxs)
        physics = entity:GetPhysicsObject()
        solid = SOLID_BBOX -- Clients must trace bounds even without a model physics mesh.
    end
    entity:SetUseType(SIMPLE_USE)
    if IsValid(physics) then
        entity:SetMoveType(MOVETYPE_VPHYSICS) entity:SetSolid(solid)
        physics:EnableMotion(false)
    else
        entity:SetMoveType(MOVETYPE_NONE) entity:SetSolid(SOLID_BBOX)
    end
end

function Q:FinishPlacementMove(client, entity)
    local placement, id = self:ManagedPlacement(entity)
    if not placement then return false end
    entity.ixQDPhysgunHolder = nil
    local physics = entity:GetPhysicsObject()
    if IsValid(physics) then physics:EnableMotion(false) end
    local pos, ang = entity:GetPos(), entity:GetAngles()
    if self.storageFault or not self.CanEdit(client) or not util.IsInWorld(pos) then
        entity:SetPos(Vector(unpack(placement.pos))) entity:SetAngles(Angle(unpack(placement.ang)))
        return false
    end
    local oldPos, oldAng = placement.pos, placement.ang
    if pos.x == oldPos[1] and pos.y == oldPos[2] and pos.z == oldPos[3]
        and ang.p == oldAng[1] and ang.y == oldAng[2] and ang.r == oldAng[3] then return true end
    placement.pos, placement.ang = {pos.x, pos.y, pos.z}, {ang.p, ang.y, ang.r}
    self.definitionsDirty = true
    self:Log(client, "physgun move", id) self:Save()
    return true
end

function PLUGIN:OnPhysgunPickup(client, entity)
    if Q:ManagedPlacement(entity) and Q.CanEdit(client) then
        entity.ixQDPhysgunHolder = client
        entity.ixQDMoveGeneration = (entity.ixQDMoveGeneration or 0) + 1
    end
end

function PLUGIN:PhysgunDrop(client, entity)
    Q:FinishPlacementMove(client, entity)
end

function PLUGIN:OnPhysgunFreeze(_, _, entity, client)
    if not Q:ManagedPlacement(entity) then return end
    local generation = entity.ixQDMoveGeneration
    -- Let Helix freeze and register the physics object before persisting it.
    timer.Simple(0, function()
        if IsValid(entity) and entity.ixQDMoveGeneration == generation then Q:FinishPlacementMove(client, entity) end
    end)
end

function Q:FinishHeldPlacements(client)
    for _, entity in pairs(self.entities) do
        if IsValid(entity) and entity.ixQDPhysgunHolder == client then self:FinishPlacementMove(client, entity) end
    end
end
