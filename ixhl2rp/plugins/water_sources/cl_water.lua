local W=ix.water
-- SinkAdmin uses these fonts; its administrative registry remains a window.
surface.CreateFont("WaterTitle",{font="Tahoma",size=24,weight=700,extended=true})
surface.CreateFont("WaterText",{font="Tahoma",size=18,weight=500,extended=true})
surface.CreateFont("WaterSmall",{font="Tahoma",size=15,weight=500,extended=true})
function W.Interaction(p,e)
 local source=W.Source(e)
 if not source or not W.Near(p,e) then return end
 local toilet=source=="toilet"
 local rows={{id="drink",code=1,label=toilet and "Выпить из бачка (радиация)" or "Напиться",detail=toilet and "Опасно: питьё из туалета даёт радиацию" or "Питьевая вода",warning=toilet}}
 local items=W.Containers(p)
 for _,item in ipairs(items) do
  rows[#rows+1]={id="fill:"..item.id,code=2,item=item.id,label="Набрать: "..(item:GetName() or item.uniqueID),
   detail=math.floor(item.reagents.volume).." / "..math.floor(item.reagents.max_volume).." мл · питьевая вода"}
 end
 if #items==0 then rows[#rows+1]={id="empty",label="Набрать воду",detail="Нужна пустая или неполная ёмкость с водой",disabled=true} end
 if not toilet then rows[#rows+1]={id="wash",code=3,label="Вымыть руки",detail="Промыть руки под проточной водой"} end
 return {title=toilet and "Туалет" or "Умывальник",options=rows,use=function(option)
  net.Start("ixWaterChoose");net.WriteEntity(e);net.WriteUInt(option.code,2);net.WriteUInt(option.item or 0,32);net.WriteBool(toilet);net.SendToServer()
 end}
end
function PLUGIN:GetEquipmentInteraction(p,e) return W.Interaction(p,e) end
-- A late native +use response must never choose an action after looking away.
net.Receive("ixWaterMenu",function()
 net.ReadEntity();net.ReadBool()
 for i=1,net.ReadUInt(8) do net.ReadUInt(32);net.ReadString();net.ReadUInt(16);net.ReadUInt(16) end
end)
function PLUGIN:OnUnload()
 if IsValid(W.menu) then W.menu:Remove() end
 if IsValid(W.adminMenu) then W.adminMenu:Remove() end
 hook.Remove("InitPostEntity","ixWaterRegistrySync")
end
