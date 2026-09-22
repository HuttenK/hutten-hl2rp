ix.Immersion = ix.Immersion or {}
local I = ix.Immersion
function I.Unit(value)
 value = tonumber(value) or 0
 if value ~= value then return 0 end
 return math.Clamp(value, 0, 1)
end
function I.Approach(current, target, dt, seconds)
 return current + (target-current) * (1-math.exp(-math.Clamp(dt,0,0.25)/seconds))
end
function I.Exertion(stamina, maximum, pain)
 return math.max(I.Unit((0.65-I.Unit(stamina/math.max(maximum,1)))/0.65), I.Unit(pain)*0.65)
end
function I.Exposure(light, adapted)
 -- Only a transient response: never raise the steady-state visibility of darkness.
 return math.Clamp((light-adapted)*0.065,-0.035,0.025)
end
function I.FootstepMix(speed, walking, equipped)
 return math.Clamp(0.65+speed/500+(equipped and 0.08 or 0),0.65,1.05)*(walking and 0.65 or 1), math.Clamp(96+speed/45,96,103)
end
function I.Equipped(client, slot)
 if not client.GetInventory then return end
 local inventory = client:GetInventory(slot)
 local ids = inventory and inventory:GetSlot(1,1)
 return ids and ix.Item and ix.Item.instances[ids[1]] or nil
end

function I.Rain(client)
 local override=hook.Run("GetImmersionRainIntensity",client)
 if override~=nil then return I.Unit(override) end
 if gWeather and gWeather.IsRaining and gWeather.GetPrecipitation and gWeather:IsRaining() then
  return I.Unit(gWeather:GetPrecipitation())
 end
 return 0
end
