local F=ix.Facility
local H=F.Hardware
local mode,ghost,generators,nextScan=nil,nil,{},0
local cable=Material("cable/cable2")
local cableColor=Color(65,68,72)
local function drawCable(a,b,color,cache,filter,physical)
 if not cache.points or cache.a:DistToSqr(a)>.01 or cache.b:DistToSqr(b)>.01 or RealTime()>(cache.nextGround or 0) then
  cache.a=a;cache.b=b;cache.nextGround=RealTime()+2
  cache.points=F.CablePoints(a,b,function(start,finish)
   return util.TraceHull({start=start,endpos=finish,mins=Vector(-1,-1,-1),maxs=Vector(1,1,1),filter=filter,mask=MASK_SOLID_BRUSHONLY})
  end)
 end
 -- Physical cables must contribute their own depth to the zone stencil.
 if physical then render.OverrideDepthEnable(true,true) end
 render.StartBeam(#cache.points)
 local distance=0
 for i,point in ipairs(cache.points) do
  if i>1 then distance=distance+point:Distance(cache.points[i-1]) end
  render.AddBeam(point,1.6,distance/32,color)
 end
 render.EndBeam()
 if physical then render.OverrideDepthEnable(false) end
end
local function clear()
 if IsValid(ghost) then ghost:Remove() end
 ghost=nil;mode=nil;F.connectionActive=false
end
function F.CloseGeneratorPlacement() clear() end
net.Receive("ixFacilityMode",function()
 local kind,id=net.ReadString(),net.ReadUInt(32);clear()
 if kind~="place" and kind~="place_battery" and kind~="connect" and kind~="source" and kind~="disconnect" then return end
 F.connectionActive=true
 mode={kind=kind,placing=kind=="place" or kind=="place_battery",deviceKind=kind=="place_battery" and "battery" or "generator",id=id,yaw=LocalPlayer():EyeAngles().y,untilTime=RealTime()+120,nextClick=RealTime()+.3}
 if kind=="connect" then mode.start=net.ReadVector() end
 if IsValid(F.window) then F.window:Remove() end
 if IsValid(ix.gui.menu) then ix.gui.menu:Remove() end
 if mode.placing then
  ghost=ClientsideModel(F.kinds[mode.deviceKind].model,RENDERGROUP_TRANSLUCENT)
  if IsValid(ghost) then ghost:SetNoDraw(true) end
 end
end)
hook.Add("CreateMove","ixFacilityGeneratorInput",function(cmd)
 if not mode then return end
 local p=LocalPlayer()
 if not IsValid(p) or not p:Alive() or RealTime()>mode.untilTime then clear();return end
 local primary,secondary=cmd:KeyDown(IN_ATTACK),cmd:KeyDown(IN_ATTACK2)
 cmd:RemoveKey(IN_ATTACK);cmd:RemoveKey(IN_ATTACK2);cmd:RemoveKey(IN_USE)
 mode.yaw=math.NormalizeAngle(mode.yaw+cmd:GetMouseWheel()*5)
 if secondary and not mode.secondary then F.Request("connection","cancel");clear();return end
 if primary and not mode.primary and RealTime()>mode.nextClick and not vgui.CursorVisible() then
  mode.nextClick=RealTime()+.35
  F.Request("connection",mode.placing and "place" or "connect",{yaw=mode.yaw})
 end
 mode.primary=primary;mode.secondary=secondary
end)
hook.Add("PlayerBindPress","ixFacilityGeneratorBinds",function(_,bind)
 if mode and (bind:find("invnext",1,true) or bind:find("invprev",1,true) or bind=="+use") then return true end
end)
local function drawPhysicalCables(depth,sky,sky3d)
 if depth or sky3d or (ix.CCTV and ix.CCTV.rendering) then return end
 local p=LocalPlayer();if not IsValid(p) then return end
 if RealTime()>nextScan then generators=ents.FindByClass("ix_facility_generator");for _,battery in ipairs(ents.FindByClass("ix_facility_battery")) do generators[#generators+1]=battery end;nextScan=RealTime()+1 end
 render.SetMaterial(cable)
 for _,g in ipairs(generators) do if IsValid(g) then
  if p:GetPos():DistToSqr(g:GetPos())<900^2 then
   g.ixCableCurves=g.ixCableCurves or {}
   for i=1,F.cablePorts do local target=g:GetNW2Entity("ixGeneratorCable"..i)
    if IsValid(target) then
     local a=F.CableStart(g,g:GetNW2Vector("ixGeneratorCableStart"..i,g:WorldToLocal(F.GeneratorSocket(g))))
     local b=target:LocalToWorld(g:GetNW2Vector("ixGeneratorCablePoint"..i,target:WorldToLocal(target:WorldSpaceCenter())))
     g.ixCableCurves[i]=g.ixCableCurves[i] or {}
     drawCable(a,b,cableColor,g.ixCableCurves[i],{g,target},true)
    else g.ixCableCurves[i]=nil end
   end
  end
 end end
end
hook.Add("ixBlackoutWorldGeometry","ixFacilityGeneratorCables",drawPhysicalCables)
hook.Add("PostDrawTranslucentRenderables","ixFacilityGeneratorCables",function(depth,sky,sky3d)
 if depth or sky3d or (ix.CCTV and ix.CCTV.rendering) then return end
 local blackout=ix.plugin.list.blackout
 if not blackout or not blackout.drawsWorldGeometry then drawPhysicalCables(depth,sky,sky3d) end
 local p=LocalPlayer();if not IsValid(p) then return end
 local selected
 for _,g in ipairs(generators) do
  if IsValid(g) and mode and g:GetNW2Int("ixFacilityID",0)==mode.id then selected=g;break end
 end
 render.SetMaterial(cable)
 if not mode then return end
 local tr=p:GetEyeTrace()
 if mode.placing and IsValid(ghost) then
  local pos=F.GeneratorPlacement(p,tr,mode.yaw,ghost);mode.valid=pos~=nil
  ghost:SetPos(pos or tr.HitPos);ghost:SetAngles(Angle(0,mode.yaw,0))
  render.SetBlend(.55);render.SetColorModulation(pos and .2 or 1,pos and 1 or .2,.25)
  ghost:DrawModel();render.SetColorModulation(1,1,1);render.SetBlend(1)
 elseif mode.kind=="connect" and IsValid(selected) then
  local a,b=F.CableStart(selected,mode.start),tr.HitPos
  mode.distance=math.floor(a:Distance(b)/39.37*10)/10
  mode.valid=IsValid(tr.Entity) and a:DistToSqr(b)<=F.cableLength^2
  mode.curve=mode.curve or {}
  drawCable(a,b,mode.valid and Color(92,229,201) or Color(240,85,65),mode.curve,{selected,tr.Entity})
  render.DrawWireframeSphere(b,4,8,8,Color(92,229,201),false)
 elseif mode.kind=="source" or mode.kind=="disconnect" then
  mode.valid=IsValid(tr.Entity) and tr.HitPos:DistToSqr(p:GetShootPos())<=140^2
  render.DrawWireframeSphere(tr.HitPos,4,8,8,mode.valid and Color(92,229,201) or Color(240,85,65),false)
 end
end)
hook.Add("HUDPaint","ixFacilityGeneratorPlacement",function()
 if not mode or (ix.CCTV and ix.CCTV.rendering) then return end
 local w=math.min(780,ScrW()-40);local x,y=(ScrW()-w)/2,ScrH()-130
 local c=H.skins.generator;draw.RoundedBox(4,x,y,w,96,c.bg);surface.SetDrawColor(c.edge);surface.DrawOutlinedRect(x,y,w,96)
 H.Lamp(x+22,y+24,mode.valid,c.accent)
 H.Text(mode.placing and "УСТАНОВКА РЕЗЕРВНОГО ИСТОЧНИКА" or mode.kind=="disconnect" and "СНЯТИЕ КАБЕЛЯ" or "ПОДКЛЮЧЕНИЕ КАБЕЛЯ","FacilityTitle",x+44,y+12,c.text,w-58)
 H.Text(mode.placing and "ЛКМ — установить · Колесо — повернуть · ПКМ — отмена" or mode.kind=="source" and "ЛКМ по генератору / аккумулятору — начало кабеля · ПКМ — отмена" or mode.kind=="disconnect" and "ЛКМ по подключённому устройству — снять входящий кабель · ПКМ — отмена" or "ЛКМ по устройству / щитку — подключить · ПКМ — отмена","FacilityText",x+16,y+42,c.text,w-32)
 H.Text(mode.placing and (mode.valid and "Свободный ровный пол" or "Найдите свободный ровный пол рядом") or
  (mode.kind=="source" and "1 предмет = 1 подключение. Кабель расходуется только после второго клика." or mode.kind=="disconnect" and "Кабель вернётся в инвентарь. Снять также можно через E на источнике." or "Длина: "..tostring(mode.distance or 0).." / 15 м · Кабель не проходит сквозь стены"),"FacilityPlate",x+16,y+70,c.muted,w-32)
end)
hook.Add("ShutDown","ixFacilityGeneratorCleanup",clear)
