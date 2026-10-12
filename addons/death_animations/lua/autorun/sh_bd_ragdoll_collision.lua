if SERVER then AddCSLuaFile() end

-- Physical bodies remain traceable by tools and the physgun. Only the
-- animation helper is intangible; do not use SOLID_NONE on the real body.
BDRagdolls = BDRagdolls or {}
function BDRagdolls.IsBody(entity)
    return IsValid(entity) and entity:GetClass() == "prop_ragdoll"
end

function BDRagdolls.Configure(entity)
    if not BDRagdolls.IsBody(entity) then return end
    -- WEAPON already excludes player movement collisions. A blanket
    -- ShouldCollide(player, body)=false also risks filtering tool traces.
    entity:SetCustomCollisionCheck(false)
    if SERVER then
        entity:SetNotSolid(false)
        entity:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    end
end

hook.Remove("ShouldCollide", "BD_RagdollNoPlayerCollide")

hook.Add("OnEntityCreated", "BD_RagdollCustomCollide", function(entity)
    timer.Simple(0, function() BDRagdolls.Configure(entity) end)
end)

hook.Add("InitPostEntity", "BD_RagdollCustomCollide", function()
    for _, entity in ipairs(ents.FindByClass("prop_ragdoll")) do
        BDRagdolls.Configure(entity)
    end
end)

if SERVER then
    local function releaseBody(_, entity)
        if not BDRagdolls.IsBody(entity) then return end
        entity.BD_AnimationInterrupted = true
        if IsValid(entity.AnimModule) then entity.AnimModule:Remove() end
        BDRagdolls.Configure(entity)
    end
    -- These are success notifications, not permission overrides. Helix prop
    -- protection still decides who can use a physgun on a body.
    hook.Add("OnPhysgunPickup", "BD_ReleaseAnimatedBody", releaseBody)
    hook.Add("GravGunOnPickedUp", "BD_ReleaseAnimatedBody", releaseBody)
    hook.Add("PhysgunDrop", "BD_RestoreBodyCollision", function(_, entity)
        timer.Simple(0, function() BDRagdolls.Configure(entity) end)
    end)
end
