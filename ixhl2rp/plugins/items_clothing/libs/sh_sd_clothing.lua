-- SD 4 clothing layout verified against all 47 original character models.
ix.SDClothing = ix.SDClothing or {}
local C = ix.SDClothing
C.catalog = {
 ["sd_beanie_blue"] = {group=1, value=1, part="head_beanie_blue", model="models/sd/citizens/props/head_beanie_blue.mdl", slot="head"},
 ["sd_beanie_green"] = {group=1, value=2, part="head_beanie_green", model="models/sd/citizens/props/head_beanie_green.mdl", slot="head"},
 ["cap_baseball"] = {group=1, value=3, part="head_baseball", model="models/sd/citizens/props/head_baseball.mdl", slot="head"},
 ["helmet_construction"] = {group=1, value=4, part="head_construction", model="models/sd/citizens/props/head_construction.mdl", slot="head"},
 ["bandana_face"] = {group=2, value=1, part="face_scarf", model="models/sd/citizens/props/face_scarf.mdl", slot="mask"},
 ["medmask"] = {group=2, value=2, part="face_medmask", model="models/sd/citizens/props/face_medmask.mdl", slot="mask"},
 ["respirator_af"] = {group=2, value=3, part="face_respirator", model="models/sd/citizens/props/face_respirator.mdl", slot="mask"},
 ["gasmask_gp7"] = {group=2, value=4, part="face_gasmask_gp7", model="models/sd/citizens/props/face_gasmask_gp7.mdl", slot="mask"},
 ["gasmask_m40_af"] = {group=2, value=5, part="face_gasmask_m40", model="models/sd/citizens/props/face_gasmask_m40.mdl", slot="mask"},
 ["glasses_regular"] = {group=3, value=1, part="eyes_glasses_regular", model="models/sd/citizens/props/eyes_glasses_regular.mdl", slot="glasses"},
 ["sunglasses"] = {group=3, value=2, part="eyes_glasses_police", model="models/sd/citizens/props/eyes_glasses_police.mdl", slot="glasses"},
 ["torso_citizen"] = {group=4, value=0, part="torso_citizen_dirty", model="models/sd/citizens/props/torso_citizen_dirty.mdl", slot="torso"},
 ["sd_citizen_dirty_short"] = {group=4, value=1, part="torso_citizen_dirty_short", model="models/sd/citizens/props/torso_citizen_dirty.mdl", slot="torso"},
 ["sd_citizen_blue"] = {group=4, value=2, part="torso_citizen_blue", model="models/sd/citizens/props/torso_citizen_blue.mdl", slot="torso"},
 ["sd_citizen_blue_short"] = {group=4, value=3, part="torso_citizen_blue_short", model="models/sd/citizens/props/torso_citizen_blue.mdl", slot="torso"},
 ["sd_citizen_green"] = {group=4, value=4, part="torso_citizen_green", model="models/sd/citizens/props/torso_citizen_green.mdl", slot="torso"},
 ["sd_citizen_green_short"] = {group=4, value=5, part="torso_citizen_green_short", model="models/sd/citizens/props/torso_citizen_green.mdl", slot="torso"},
 ["jacket_citizen_blue"] = {group=4, value=6, part="torso_citizen_worker_blue", model="models/sd/citizens/props/torso_citizen_worker_blue.mdl", slot="torso"},
 ["sd_worker_blue_short"] = {group=4, value=7, part="torso_citizen_worker_blue_short", model="models/sd/citizens/props/torso_citizen_worker_blue.mdl", slot="torso"},
 ["jacket_citizen_yellow"] = {group=4, value=8, part="torso_citizen_worker_yellow", model="models/sd/citizens/props/torso_citizen_worker_yellow.mdl", slot="torso"},
 ["sd_worker_yellow_short"] = {group=4, value=9, part="torso_citizen_worker_yellow_short", model="models/sd/citizens/props/torso_citizen_worker_yellow.mdl", slot="torso"},
 ["labcoat"] = {group=4, value=10, part="torso_labcoat", model="models/sd/citizens/props/torso_labcoat.mdl", slot="torso"},
 ["sd_jacket_1"] = {group=4, value=11, part="torso_jacket_1", model="models/sd/citizens/props/torso_jacket_1.mdl", slot="torso"},
 ["sd_jacket_2"] = {group=4, value=12, part="torso_jacket_2", model="models/sd/citizens/props/torso_jacket_2.mdl", slot="torso"},
 ["sd_jacket_3"] = {group=4, value=13, part="torso_jacket_3", model="models/sd/citizens/props/torso_jacket_3.mdl", slot="torso"},
 ["sd_jacket_4"] = {group=4, value=14, part="torso_jacket_4", model="models/sd/citizens/props/torso_jacket_4.mdl", slot="torso"},
 ["sd_jacket_5"] = {group=4, value=15, part="torso_jacket_5", model="models/sd/citizens/props/torso_jacket_5.mdl", slot="torso"},
 ["sd_jacket_6"] = {group=4, value=16, part="torso_jacket_6", model="models/sd/citizens/props/torso_jacket_6.mdl", slot="torso"},
 ["sd_hoodie"] = {group=4, value=17, part="torso_hoodie", model="models/sd/citizens/props/torso_hoodie.mdl", slot="torso"},
 ["sd_cargo_jacket"] = {group=4, value=18, part="torso_cargo", model="models/sd/citizens/props/torso_cargo.mdl", slot="torso"},
 ["suit_jacket_brown"] = {group=4, value=19, part="torso_suit_1", model="models/sd/citizens/props/torso_suit_1.mdl", slot="torso"},
 ["suit_jacket_black"] = {group=4, value=20, part="torso_suit_2", model="models/sd/citizens/props/torso_suit_2.mdl", slot="torso"},
 ["suit_jacket_white"] = {group=4, value=21, part="torso_suit_3", model="models/sd/citizens/props/torso_suit_3.mdl", slot="torso"},
 ["coat_black"] = {group=4, value=22, part="torso_suit_4", model="models/sd/citizens/props/torso_suit_4.mdl", slot="torso"},
 ["coat_black_white"] = {group=4, value=23, part="torso_suit_5", model="models/sd/citizens/props/torso_suit_5.mdl", slot="torso"},
 ["pants_grey"] = {group=7, value=0, part="legs_casual_dirty", model="models/sd/citizens/props/legs_casual_dirty.mdl", slot="legs"},
 ["pants_blue"] = {group=7, value=1, part="legs_casual_blue", model="models/sd/citizens/props/legs_casual_blue.mdl", slot="legs"},
 ["sd_pants_yellow"] = {group=7, value=2, part="legs_casual_yellow", model="models/sd/citizens/props/legs_casual_yellow.mdl", slot="legs"},
 ["pants_red"] = {group=7, value=3, part="legs_casual_red", model="models/sd/citizens/props/legs_casual_red.mdl", slot="legs"},
 ["jeans_shoes"] = {group=7, value=4, part="legs_jeans", model="models/sd/citizens/props/legs_jeans.mdl", slot="legs"},
 ["jeans_boots"] = {group=7, value=5, part="legs_jeans_boots", model="models/sd/citizens/props/legs_jeans.mdl", slot="legs"},
 ["jeans_green_shoes"] = {group=7, value=6, part="legs_jeans_green", model="models/sd/citizens/props/legs_jeans_green.mdl", slot="legs"},
 ["jeans_green_boots"] = {group=7, value=7, part="legs_jeans_green_boots", model="models/sd/citizens/props/legs_jeans_green.mdl", slot="legs"},
 ["pants_cargo"] = {group=7, value=8, part="legs_cargo", model="models/sd/citizens/props/legs_cargo.mdl", slot="legs"},
 ["pants_cargo_green"] = {group=7, value=9, part="legs_cargo_green", model="models/sd/citizens/props/legs_cargo_green.mdl", slot="legs"},
 ["sd_tracksuit_pants"] = {group=7, value=10, part="legs_tracksuit", model="models/sd/citizens/props/legs_tracksuit.mdl", slot="legs"},
 ["trousers_brown"] = {group=7, value=11, part="legs_suit_1", model="models/sd/citizens/props/legs_suit_1.mdl", slot="legs"},
 ["trousers_black"] = {group=7, value=12, part="legs_suit_2", model="models/sd/citizens/props/legs_suit_2.mdl", slot="legs"},
 ["trousers_white"] = {group=7, value=13, part="legs_suit_3", model="models/sd/citizens/props/legs_suit_3.mdl", slot="legs"},
 ["gloves_fingerless"] = {group=9, value=1, part="hands_2", model="models/sd/citizens/props/hands_fingerless.mdl", slot="hands"},
 ["gloves_af"] = {group=9, value=2, part="hands_3", model="models/sd/citizens/props/hands.mdl", slot="hands"},
 ["sd_satchel"] = {group=11, value=1, part="satchel", model="models/props_c17/BriefCase001a.mdl", slot="satchel"},
}

function C.Apply(item)
 local r = assert(C.catalog[item.uniqueID], "Missing SD clothing entry")
 item.model = r.model
 item.equip_inv, item.equip_slot = r.slot, nil
 item.sdClothing = true
 item.bodyGroups = {}
 item.bodyGroupsSD = {[r.group] = r.value}
end

C.retired = {
 ["bandana_east"] = "sd_beanie_green",
 ["cap_medical"] = "sd_beanie_blue",
 ["cap_military"] = "cap_baseball",
 ["gasmask_early"] = "respirator_af",
 ["gasmask_m40"] = "gasmask_m40_af",
 ["gasmask_standard"] = "gasmask_gp7",
 ["glasses_aviators"] = "sunglasses",
 ["hat_boonie"] = "cap_baseball",
 ["hat_cowboy"] = "cap_baseball",
 ["hat_east"] = "sd_beanie_green",
 ["hazmat_medic"] = "labcoat",
 ["hazmat_regular"] = "sd_cargo_jacket",
 ["head_bandana"] = "sd_beanie_blue",
 ["head_bandana_full"] = "sd_beanie_green",
 ["head_ow"] = "cap_baseball",
 ["jacket_military"] = "sd_cargo_jacket",
 ["legs_citizen"] = "pants_grey",
 ["legs_denimshorts"] = "jeans_shoes",
 ["legs_smokingskirt"] = "trousers_black",
 ["legs_suitjacket"] = "trousers_brown",
 ["poncho"] = "sd_beanie_green",
 ["qamis"] = "sd_hoodie",
 ["shemagh"] = "bandana_face",
 ["shirt_hawaii"] = "sd_citizen_blue_short",
 ["shirt_military"] = "sd_worker_blue_short",
 ["shorts"] = "sd_tracksuit_pants",
 ["torso_loyaljacket_everva"] = "sd_jacket_1",
 ["torso_smoking"] = "suit_jacket_black",
 ["torso_suitjacket"] = "suit_jacket_brown",
 ["tshirt_white"] = "sd_citizen_dirty_short",
 ["uniform_militia"] = "sd_cargo_jacket",
 ["wrap_east"] = "sd_beanie_green",
}
ix.Item.legacyIDs = ix.Item.legacyIDs or {}
for old, replacement in pairs(C.retired) do ix.Item.legacyIDs[old] = replacement end

if SERVER then
 -- One old pants definition incorrectly used the head slot. Recover that
 -- saved placement through ordinary transfers, preserving items if full.
 function C.RepairLegacySlots(client)
  for _, inventory in pairs(client:GetInventories()) do
   if inventory.isEquipment then
    for _, itemID in ipairs(inventory:GetItemsID()) do
     local item = ix.Item.instances[itemID]
     if item and item.sdClothing and item.equip_inv ~= inventory.type then
      local x, y = item.x, item.y
      local w, h = inventory:GetItemSize(item)
      for _, slot in ipairs({item.equip_inv, "main"}) do
       local target = client:GetInventory(slot)
       if target and inventory:Transfer(item.id, target) then
        target:SendDeltaTransfer(item.id, inventory, x, y, w, h)
        break
       end
      end
     end
    end
   end
  end
 end
end
