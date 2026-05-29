ITEM.name = "Кепка армии Надзора"
ITEM.model = "models/autonomous/africa/items/prop_army_cap.mdl"
ITEM.skin = 3
ITEM.width = 2
ITEM.height = 2
ITEM.iconCam = {
	pos = Vector(31.341981887817, -0.18476867675781, 291.82946777344),
	ang = Angle(83.76683807373, 179.64495849609, 0),
	fov = 4.0238345864177,
}
ITEM.rarity = 3
ITEM.description = "item.torso_citizen.desc"
ITEM.equip_inv = 'head'
ITEM.equip_slot = nil
-ITEM.bodyGroups = {
-	[1] = 1
-}


ITEM.displayID = ix.Appearance:New("citizen_shirt", {
    slot = ix.Appearance.Slot.Torso,
    layer = ix.Appearance.Layer.Top,
    bodyMask = "Torso_OnlyHands",
    variants = {
        male = {
            model = "models/autonomous/male_torso_bundle1.mdl",
            bodyGroups = { [0] = 0 }
        },
        female = {
            model = "models/autonomous/female_torso_bundle1.mdl",
            bodyGroups = { [0] = 0 }
        },
    }
})


ITEM.BreakDown = true
ITEM.BreakDownType = "cloth"
