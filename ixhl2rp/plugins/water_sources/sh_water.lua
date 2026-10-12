local W = ix.water
W.defaults = {
 ["models/props_c17/furnituresink001a.mdl"] = "sink",
 ["models/env/furniture/square_sink/sink_double.mdl"] = "sink",
 ["models/env/furniture/square_sink/sink_merged_b.mdl"] = "sink",
 ["models/env/furniture/ensuite1_sink/ensuite1_sink.mdl"] = "sink",
 ["models/props_se/propper/toilet05.mdl"] = "toilet",
 ["models/props_c17/furnituretoilet001a.mdl"] = "toilet"
}
W.modelLimit=128
function W.ModelPath(value)
 if not isstring(value) or #value>180 then return end
 local path=string.lower(string.Trim(value))
 if not path:match("^models/[%w_%-./]+%.mdl$") or path:find("..",1,true) or path:find("//",1,true) then return end
 return path
end
function W.ApplyModels(custom)
 W.models=table.Copy(W.defaults);W.custom={}
 local count=0
 for model,kind in pairs(istable(custom) and custom or {}) do
  local path=W.ModelPath(model)
  if path and not W.defaults[path] and (kind=="sink" or kind=="toilet") and count<W.modelLimit then
   W.models[path]=kind;W.custom[path]=kind;count=count+1
  end
 end
end
W.ApplyModels(W.custom)
function W.Source(e)
 if not IsValid(e) then return end
 local class = e:GetClass()
 if class == "ix_sink_trigger" then return "sink" end
 if class == "ix_toilet_trigger" then return "toilet" end
 if class == "prop_physics" or class == "prop_dynamic" or class == "prop_dynamic_override" then
  local model=string.lower(e:GetModel() or "")
  return W.models[model]
 end
end
function W.OtherActivity(p)
 local facility=ix.plugin.list.facility_utilities
 return IsValid(p) and (p.ixMedicalSession~=nil or (facility and facility.work and facility.work[p]~=nil))
end
function W.Active(p)
 return IsValid(p) and p:IsPlayer() and p:Alive() and p:GetCharacter() and not p:IsRestricted()
  and not W.OtherActivity(p)
  and not p:InVehicle() and not p:GetNetVar("isCreature") and not p:GetNetVar("forcedSequence")
  and p:GetLocalVar("ragdoll", 0) == 0 and not p:GetLocalVar("knocked", false)
end
function W.Near(p, e)
 if not W.Active(p) or not W.Source(e) or p:GetShootPos():DistToSqr(e:NearestPoint(p:GetShootPos())) > 96^2 then return false end
 return not util.TraceLine({start=p:GetShootPos(), endpos=e:WorldSpaceCenter(), filter={p,e}, mask=MASK_VISIBLE}).Hit
end
function W.Eligible(item)
 if not item or not item.isReagentHolder or not ix.Reagents:IsRefillable(item) or not item.reagents then return false end
 local holder = item.reagents
 if holder.max_volume - holder.volume < 1 then return false end
 -- Water can be topped up, including saved legacy water. Never dilute other
 -- drinks, medicines or reagents just because they occupy a refillable bottle.
 for _, r in pairs(holder.reagents or {}) do
  if r.volume >= .1 and r.uniqueID ~= "water" and r.uniqueID ~= "dirty_water" then return false end
 end
 return true
end
function W.Containers(p)
 local out = {}
 if not IsValid(p) or not p:GetCharacter() or not p.GetInventory then return out end
 -- Inventories arrive asynchronously; older Helix GetInventory can index nil.
 if CLIENT and not p.inventories then return out end
 local inventory = p:GetInventory("main")
 for _, item in pairs(inventory and inventory:GetItems() or {}) do
  if item:GetOwner() == p and W.Eligible(item) then out[#out+1] = item end
 end
 table.sort(out, function(a,b) return a.id < b.id end)
 return out
end
