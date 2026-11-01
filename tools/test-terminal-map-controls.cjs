const r=require('./restored-test-runner.cjs');
const geometry=r.source(['tools/geometry-fixture.lua']);
const client=geometry+`
 SERVER=false;CLIENT=true;ix.FoundationNet={}
 function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
 function RealTime() return clock end;function SysTime() return clock end
 vgui={Register=function(_,p) mapPanel=p end}
 game={GetMap=function() return 'fixture' end,GetWorld=function() return {GetBrushSurfaces=function() return {} end} end}
 local fontSize=22
 surface={CreateFont=function() end,SetFont=function(font) fontSize=tonumber(font:match('%d+')) or 22 end,
  GetTextSize=function(s) return utf8.len(s)*fontSize*.55,fontSize end}
 local function panel()
  local p=setmetatable({valid=true,SetTall=function() end,GetTall=function() return 620 end,GetWide=function() return 1724 end},{__index=mapPanel})
  p:Init();p.geometry={ready=true,faces={},edges={},low=Vector(-1000,-1000,-1000),high=Vector(1000,1000,2000)}
  p:SetData({origin={0,0,900},areas={},terminals={},alerts={}});return p
 end
`+r.source(['ixhl2rp/plugins/foundation_network/cl_map.lua']);
r.run('Height grows from the map bottom, independent of player floor and camera panning',client+`
 local p=panel();local N=ix.FoundationNet
 local low,high=N.MapSliceBounds(p);near(low,-1008);near(high,-832);near(p:GetLayerFraction(),0)
 p:SetLayerFraction(.5);local b,h=N.MapSliceBounds(p);near(b,low);assert(h>high)
 p.center.z=15000;local b2,h2=N.MapSliceBounds(p);near(b2,b);near(h2,h)
 p:Floor(1);b2,h2=N.MapSliceBounds(p);near(b2,b);near(h2,h+128)
 p:SetLayerFraction(1);eq(N.MapSliceBounds(p),nil);near(p:GetLayerFraction(),1)
 p:Home();near(p:GetLayerFraction(),0);near(select(2,N.MapSliceBounds(p)),-832)
`);
r.run('Player cap clamps slider, floor buttons, reset, full-map toggle, updates and schematic overlays',client+`
 local p=panel();local N=ix.FoundationNet;p.data.maxHeight=400
 p.data.areas={{name='Allowed',min={-200,-200,0},max={200,200,300}},
  {name='Restricted',min={-200,-200,600},max={200,200,900}}}
 p.data.terminals={{pos={0,0,700}}};p.data.alerts={{name='Secret',kind='infection',active=true,pos={0,0,700}}}
 p:SetLayerFraction(1);near(select(2,N.MapSliceBounds(p)),400);assert(p:GetLayerFraction()<1)
 p:Floor(100);near(select(2,N.MapSliceBounds(p)),400)
 for _,full in ipairs({false,true}) do
  p:ResetOrbit(full);near(select(2,N.MapSliceBounds(p)),400)
  clock=clock+1;N.RenderMap(p);assert(p.mapReady,p.renderError)
  for _,v in ipairs(p.mapView.labels) do assert(v.text~='Restricted' and v.text~='T1' and not v.incident) end
 end
 p.cutaway=false;near(select(2,N.MapSliceBounds(p)),400)
 p.data.maxHeight=-1500;p:SetData(p.data);local low,high=N.MapSliceBounds(p);near(high,-1500);assert(low<high)
 p.data.canSetHeight=true;p:SetData(p.data);eq(N.MapSliceBounds(p),nil);near(p:MaxLayerFraction(),1)
 p:SetLayerFraction(.9);assert(select(2,N.MapSliceBounds(p))>400)
 p.data.canSetHeight=false;p.data.maxHeight=400;p:SetData(p.data);near(select(2,N.MapSliceBounds(p)),400)
`);
r.run('Area names wrap inside rotated room polygons, avoid overlaps, and preserve complete Cyrillic text',client+`
 local N=ix.FoundationNet
 local function room(text,x,y,w,h,angle)
  local poly={};local c,s=math.cos(angle),math.sin(angle)
  for _,p in ipairs({{-w/2,-h/2},{w/2,-h/2},{w/2,h/2},{-w/2,h/2}}) do
   poly[#poly+1]={x=x+p[1]*c-p[2]*s,y=y+p[1]*s+p[2]*c}
  end
  return {text=text,x=x,y=y,size=w*h,area=true,polygon=poly}
 end
 for _,angle in ipairs({0,.3,.8,1.3}) do
  local a=room('Контрольно-пропускной пункт Альфа',300,200,440,300,angle)
  local b=room('Перекрывающаяся зона',305,205,260,180,angle)
  local tiny=room('Маленькая зона',700,400,20,20,angle)
  local view={width=1000,height=600,labels={a,b,tiny}}
  local result=N.LayoutMapAreaLabels(view);eq(#result,1)
  local label=result[1];eq(label.source,a);assert(#label.lines>=2);eq(table.concat(label.lines,' '),a.text)
  local box=label.box
  for _,corner in ipairs({{box.x,box.y},{box.x+box.w,box.y},{box.x+box.w,box.y+box.h},{box.x,box.y+box.h}}) do
   local sign
   for i,point in ipairs(a.polygon) do
    local next=a.polygon[i%4+1];local cross=(next.x-point.x)*(corner[2]-point.y)-(next.y-point.y)*(corner[1]-point.x)
    sign=sign or (cross>=0);eq(cross>=0,sign)
   end
  end
  tiny=room('Маленькая зона',700,400,240,160,angle)
  view.labels={a,tiny};eq(#N.LayoutMapAreaLabels(view),2)
 end
`);
r.run('Admin ceiling requires a valid session, survives a restart, remains map-specific and accepts safe reset',geometry+`
 local map='site_a';local disk={};local writes=0
 game={GetMap=function() return map end};SortedPairs=pairs
 ix.area={stored={}};ix.data={Get=function(_,default) return disk[map] or default end,Set=function(_,v) disk[map]={maxHeight=v.maxHeight};writes=writes+1 end}
 local person={admin=false,IsAdmin=function(s) return s.admin end,GetPos=function() return Vector() end,Notify=function() end}
 local session={token='right'}
 function PLUGIN:Session(p,token) if token=='right' then return session,{},{} end end
 function PLUGIN:SendPage(p,s) snapshot=self:MapSnapshot(p) end
 function PLUGIN:Action() error('Unexpected delegation') end
`+r.source(['ixhl2rp/plugins/foundation_network/sv_map.lua'])+`
 local p=PLUGIN
 p:Action(person,'mapHeightLimit',{token='right',height=500,webAdmin=true});eq(writes,0)
 person.admin=true;p:Action(person,'mapHeightLimit',{token='wrong',height=500});eq(writes,0)
 for _,height in ipairs({0/0,math.huge,32769,'500',{},false}) do p:Action(person,'mapHeightLimit',{token='right',height=height}) end;eq(writes,0)
 p:Action(person,'mapHeightLimit',{token='right',height=500.9});eq(writes,1);eq(snapshot.maxHeight,500);eq(snapshot.canSetHeight,true)
 person.admin=false;eq(p:MapSnapshot(person).canSetHeight,false);eq(p:MapSnapshot(person).maxHeight,500)
 p.mapSettingsMap=nil;p.mapSettings=nil;eq(p:MapSnapshot(person).maxHeight,500)
 map='site_b';eq(p:MapSnapshot(person).maxHeight,nil);map='site_a';eq(p:MapSnapshot(person).maxHeight,500)
 person.admin=true;clock=clock+1;p:Action(person,'mapHeightLimit',{token='right',clear=true});eq(writes,2);eq(snapshot.maxHeight,nil)
 p.mapSettingsMap=nil;eq(p:MapSnapshot(person).maxHeight,nil)
`);
r.run('Map page exposes ceiling controls only to admins and submits the selected top height',r.source([
 'tools/geometry-fixture.lua','tools/terminal-preview-fixture.lua',
 'ixhl2rp/plugins/foundation_network/cl_design.lua','ixhl2rp/plugins/foundation_network/cl_map.lua',
 'ixhl2rp/plugins/foundation_network/cl_network.lua'])+`
 game={GetMap=function() return 'fixture' end,GetWorld=function() return {GetBrushSurfaces=function() return {} end} end}
 local N=ix.FoundationNet;local p=vgui.Create('ixFoundationNetwork');p.bootAt=0
 local data={route='scip://map',name='Tester',level=3,token='test',title='КАРТА',mapData={origin={0,0,0},name='fixture',canSetHeight=true,areas={},alerts={},terminals={}}}
 local function find(root,title)
  if root.text==title then return root end
  for _,child in ipairs(root:GetChildren()) do local found=find(child,title);if found then return found end end
 end
 p:ApplyPage(data);PreviewLayout(p)
 local setter=find(p,'Предел игроков: текущая высота');local clear=find(p,'Снять предел высоты');assert(setter and clear)
 local action,payload;N.Request=function(a,d) action,payload=a,d end
 p.mapPanel:SetLayerFraction(.5);local _,top=N.MapSliceBounds(p.mapPanel);setter:DoClick()
 eq(action,'mapHeightLimit');near(payload.height,top);clear:DoClick();eq(payload.clear,true)
 p.busyAt=clock;p.requestAction='mapHeightLimit'
 p:ApplyPage({route='scip://map',token='test',mapUpdate=true,mapData=data.mapData});eq(p.busyAt,nil);eq(p.requestAction,nil)
 data.mapData.canSetHeight=false;p:ApplyPage(data);eq(find(p,'Предел игроков: текущая высота'),nil);eq(find(p,'Снять предел высоты'),nil)
`);
r.finish();
