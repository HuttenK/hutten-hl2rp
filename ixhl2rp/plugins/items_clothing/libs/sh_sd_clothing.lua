-- SD 4 clothing layout verified against all 47 original character models.
ix.SDClothing = ix.SDClothing or {}
local C = ix.SDClothing
C.catalog = {
 ["sd_satchel"] = {group=11, value=1, part="satchel", model="models/props_c17/BriefCase001a.mdl", slot="satchel"}
}

function C.Apply(item)
 local r = assert(C.catalog[item.uniqueID], "Missing SD clothing entry")
 item.model = r.model
 item.equip_inv, item.equip_slot = r.slot, nil
 item.sdClothing = true
 item.bodyGroups = {}
 item.bodyGroupsSD = {[r.group] = r.value}
end
