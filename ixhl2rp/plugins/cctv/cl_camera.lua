local C=ix.CCTV
local glow=CreateMaterial("ixCCTVStatusLED","UnlitGeneric",{
 ["$basetexture"]="sprites/light_glow02",["$additive"]="1",["$vertexcolor"]="1",["$vertexalpha"]="1",["$ignorez"]="0"})
local red=Color(255,32,24,210)
local core=Color(255,100,80)
function C.DrawIndicator(entity)
 local plugin=ix.plugin.list.cctv
 local d=plugin and plugin.devices and plugin.devices[entity:GetNW2Int("ixCCTVID",0)]
 if not d or d.kind~="camera" or d.bodycam or d.entityIndex~=entity:EntIndex() or not C.Powered(d) then return end
 local pos=C.CameraIndicator(d);if not pos then return end
 -- Depth-tested sprite: no light entity, dynamic shadow or through-wall glow.
 render.SetMaterial(glow)
 render.DrawSprite(pos,2.2,2.2,red)
 render.DrawSprite(pos,.65,.65,core)
end

-- Native E reaches the server's Use handler; this only describes the action.
hook.Add("GetEquipmentInteraction","ixCCTVCameraRepair",function(p,entity)
 if not IsValid(entity) or entity:GetClass()~="ix_cctv_camera" then return end
 local plugin=ix.plugin.list.cctv
 local d=plugin and plugin.devices and plugin.devices[entity:GetNW2Int("ixCCTVID",0)]
 if not d or not d.broken then return end
 return {native=true,title=d.name or "Камера CCTV",status="ПОВРЕЖДЕНА",options={
  {id="repair",label="Починить камеру",detail="Отвёртка и комплект запчастей · допуск L1 · затяжка крепежа"}}}
end)
