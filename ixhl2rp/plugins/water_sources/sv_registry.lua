local P,W=PLUGIN,ix.water
local key="foundation_water_models_v1"
util.AddNetworkString("ixWaterModels")
util.AddNetworkString("ixWaterRegistryRequest")
util.AddNetworkString("ixWaterRegistryAdmin")

function W.SyncModels(p)
 net.Start("ixWaterModels");net.WriteUInt(table.Count(W.custom),8)
 for model,kind in pairs(W.custom) do net.WriteString(model);net.WriteBool(kind=="toilet") end
 if IsValid(p) then net.Send(p) else net.Broadcast() end
end
function W.LoadModels()
 local data=ix.data.Get(key,{},false,true)
 W.ApplyModels(data)
end
function W.OpenRegistry(p,message)
 if not IsValid(p) or not p:IsAdmin() then return false end
 W.SyncModels(p)
 net.Start("ixWaterRegistryAdmin");net.WriteString(message or "Настройки действуют для всех пропов этой модели на всех картах.");net.Send(p)
 return true
end
function W.ChangeModel(p,action,value,kind)
 if not IsValid(p) or not p:IsPlayer() or not p:IsAdmin() then return false,"Доступно только администраторам." end
 if action=="aim" then
  local tr=p:GetEyeTrace();local e=tr.Entity
  if not IsValid(e) or (e:GetClass()~="prop_physics" and e:GetClass()~="prop_dynamic" and e:GetClass()~="prop_dynamic_override")
   or p:GetShootPos():DistToSqr(tr.HitPos)>256^2 then return false,"Наведитесь на проп рядом с вами." end
  value=e:GetModel();action="add"
 end
 local model=W.ModelPath(value)
 if not model then return false,"Нужен путь модели: models/... .mdl, не более 180 символов." end
 if W.defaults[model] then return false,"Эта модель встроена: её тип нельзя изменить или удалить." end
 if action=="add" then
  if kind~="sink" and kind~="toilet" then return false,"Выберите умывальник или унитаз." end
  if not util.IsValidModel(model) then return false,"Модель не найдена в установленном контенте сервера." end
  if not W.custom[model] and table.Count(W.custom)>=W.modelLimit then return false,"Лимит дополнительных моделей: "..W.modelLimit.."." end
  W.custom[model]=kind
 elseif action=="remove" then
  if not W.custom[model] then return false,"Модель уже отсутствует в списке." end
  W.custom[model]=nil
 else return false,"Неизвестное действие." end
 W.ApplyModels(W.custom)
 -- The client never controls this key or a file path. The registry is shared
 -- across maps in this schema, matching ix.data's bIgnoreMap parameter.
 ix.data.Set(key,W.custom,false,true)
 W.SyncModels()
 return true,action=="remove" and "Модель удалена из дополнительных источников воды." or "Модель сохранена. На её пропах работает E."
end
net.Receive("ixWaterRegistryRequest",function(bits,p)
 if bits>1700 or not IsValid(p) or not p:IsPlayer() or CurTime()<(p.ixWaterRegistryAt or 0) then return end
 p.ixWaterRegistryAt=CurTime()+.5
 local action=net.ReadUInt(2)
 if action==0 then W.SyncModels(p);return end
 if not p:IsAdmin() then return end
 local value=net.ReadString();local kind=net.ReadBool() and "toilet" or "sink"
 local _,message=W.ChangeModel(p,({[1]="add",[2]="aim",[3]="remove"})[action],value,kind)
 W.OpenRegistry(p,message)
end)
function P:LoadData() W.LoadModels();W.SyncModels() end
hook.Add("PlayerInitialSpawn","ixWaterRegistryInitial",function(p)
 timer.Simple(2,function() if IsValid(p) then W.SyncModels(p) end end)
end)
W.LoadModels()
