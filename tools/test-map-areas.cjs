const fs=require('fs'),path=require('path');
module.exports=function(suite){
const geometry=fs.readFileSync(path.join(__dirname,'geometry-fixture.lua'),'utf8');
suite('Map snapshot separates named areas from active incidents and clears restored incidents', ['helix/plugins/area/sh_geometry.lua','ixhl2rp/plugins/foundation_network/sv_map.lua'],`
 local function area(kind,z) return {type=kind,startPosition=Vector(-100,-100,z or 0),endPosition=Vector(100,100,(z or 0)+128),properties={}} end
 local stored=ix.area.stored
 stored.Lobby=area('area');stored.Lobby.properties.color={r=30,g=180,b=210}
 stored.Hidden=area('area');stored.Hidden.bNoReplicate=true
 stored.Quiet=area('infection');stored.Quiet.properties.infestationTotal=50
 stored.Cleared=area('infection');inf.remaining.Cleared=0
 stored.Pool=area('infection');inf.remaining.Pool=5;inf.suppressed={Pool=clock+100}
 stored.Flora=area('infection');inf.remaining.Flora=0;local live={valid=true};inf.flora.Flora={[live]=true}
 stored.Infected=area('infection');local infected={valid=true};inf.zombies.Infected={[infected]=true}
 stored.Permanent=area('infection');stored.Permanent.properties.indestructible=true
 stored.Stale=area('infection');inf.flora.Stale={[{valid=false}]=true}
 stored.PowerDefinition=area('blackout')
 stored.Other=area('restriction')
 local off={min=Vector(100,200,300),max=Vector(300,400,500),active=true}
 grid.zones={PowerOff=off,PowerOn={min=off.min,max=off.max,active=false}}
 local waste={valid=true,ixWasteExpires=clock+10,GetPos=function() return Vector(500,600,0) end}
 inf.flora.__waste={[waste]=true,[{valid=true,ixWasteExpires=clock-1}]=true}
 local data=PLUGIN:MapSnapshot(person);eq(#data.areas,1);eq(data.areas[1].name,'Lobby');eq(data.areas[1].color[2],180)
 eq(#data.alerts,6);eq(data.zones,nil)
 local seen={} for _,v in ipairs(data.alerts) do seen[v.name]=v;eq(v.active,true);eq(v.min,nil);eq(v.max,nil) end
 assert(seen.PowerOff and seen.Pool and seen.Flora and seen.Infected and seen.Permanent and seen['Биоотходы'])
 eq(seen.PowerOn,nil);eq(seen.Quiet,nil);eq(seen.Cleared,nil);eq(seen.Stale,nil)
 eq(seen.PowerOff.pos[1],200);eq(seen.PowerOff.pos[2],300);eq(seen.PowerOff.pos[3],400)
 eq(seen.PowerOff.low,300);eq(seen.PowerOff.high,500)
 off.active=false;inf.remaining.Pool=0;live.valid=false;infected.valid=false;waste.valid=false;stored.Permanent=nil
 eq(#PLUGIN:MapSnapshot(person).alerts,0)
 local areaHelpers=ix.area;ix.plugin.list={};ix.area=nil;data=PLUGIN:MapSnapshot(person);eq(#data.areas,0);eq(#data.alerts,0)
 ix.area=areaHelpers;ix.area.stored={};for i=1,160 do ix.area.stored['Area'..i]=area('area') end
 data=PLUGIN:MapSnapshot(person);eq(#data.areas,128);assert(data.truncated)
 `,geometry+`
 SortedPairs=pairs;game={GetMap=function() return 'fixture' end}
 person={GetPos=function() return Vector() end,IsAdmin=function() return false end};ix.area={stored={}}
 ix.data={Get=function(_,default) return default end}
 grid={zones={}};inf={remaining={},flora={},zombies={}};ix.plugin.list={blackout=grid,infectionzone=inf}
 `);
suite('Map draws only named area perimeters, filters incident markers by state/floor/layer and refreshes them', ['ixhl2rp/plugins/foundation_network/cl_map.lua'],`
 local N=ix.FoundationNet
 local p=setmetatable({valid=true,SetTall=function() end,GetTall=function() return 620 end,GetWide=function() return 1724 end},{__index=mapPanel})
 p:Init();p.geometry={ready=true,faces={},edges={}}
 local data={origin={0,0,0},name='fixture',terminals={},areas={
  {name='Lobby',min={-200,-200,0},max={200,200,128}},
  {name='Upstairs',min={-200,-200,512},max={200,200,640}}},alerts={
  {name='Outage',kind='power',active=true,pos={-400,100,300},low=0,high=600},
  {name='Flora',kind='infection',active=true,pos={400,100,0},low=0,high=128},
  {name='Normal',kind='power',active=false,pos={0,0,0}},
  {name='OtherFloor',kind='infection',active=true,pos={0,0,800},low=700,high=900}}}
 -- Old telemetry must never bring back hazard perimeters.
 data.zones={{name='Legacy',kind='infection',min={-100,-100,0},max={100,100,100},active=true}}
 local function refresh() clock=clock+1;p:SetData(data);N.RenderMap(p);assert(p.mapReady,p.renderError) end
 local function strokes() local n=0 for _,g in ipairs(p.mapView.groups) do n=n+#g.quads/8 end return n end
 local function label(name) for _,v in ipairs(p.mapView.labels) do if v.text:find(name,1,true) then return v end end end
 refresh();eq(strokes(),4);assert(label('Lobby'));eq(label('Upstairs'),nil);eq(label('Legacy'),nil)
 near(label('Lobby').x,1724/2);near(label('Lobby').y,550/2);eq(label('Lobby').area,true)
 assert(label('Outage'));assert(label('Flora'));eq(label('Normal'),nil);eq(label('OtherFloor'),nil)
 eq(#p.markers,3) -- two incidents and the player; areas are labels, not incidents
 p.layers.areas=false;refresh();eq(strokes(),0);eq(label('Lobby'),nil);assert(label('Flora'))
 p.layers.power=false;refresh();eq(label('Outage'),nil);assert(label('Flora'))
 p.layers.infection=false;refresh();eq(#p.markers,1)
 p.layers={areas=true,power=true,infection=true,terminals=true};p.cutaway=false;p.threeD=true
 refresh();eq(strokes(),8);assert(label('Upstairs'));assert(label('OtherFloor'))
 local right,up=N.MapAxes(p.yaw,p.pitch)
 local cx,cy=N.MapProject(Vector(0,0,512),p.center,right,up,550*.5*p.orbitZoom/p.radius,1724,550)
 near(label('Upstairs').x,cx);near(label('Upstairs').y,cy)
 data.alerts={};refresh();eq(#p.markers,1);eq(label('Flora'),nil);eq(label('Outage'),nil);eq(strokes(),8)
 p.cutaway=true;p.threeD=false;p:Floor(4);refresh();eq(strokes(),8);assert(label('Upstairs'));assert(label('Lobby'))
 `,geometry+`
 SERVER=false;CLIENT=true;ix.FoundationNet={}
 function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
 function RealTime() return clock end;function SysTime() return clock end
 vgui={Register=function(_,p) mapPanel=p end};game={GetMap=function() return 'fixture' end,GetWorld=function() return {GetBrushSurfaces=function() return {} end} end}
 `);
suite('Compound terminal areas get one label in a visible volume across floors, pans and updates', ['ixhl2rp/plugins/foundation_network/cl_map.lua'],`
 local N=ix.FoundationNet
 local p=setmetatable({valid=true,SetTall=function() end,GetTall=function() return 620 end,GetWide=function() return 1724 end},{__index=mapPanel})
 p:Init();p.geometry={ready=true,faces={},edges={}}
 local data={origin={0,0,0},name='fixture',terminals={},alerts={},areas={
  {name='Ward',min={-900,-200,0},max={-500,200,128}},
  {name='Ward',min={-500,-300,0},max={300,300,128}},
  {name='Ward',min={300,-100,0},max={500,100,128}},
  {name='Ward',min={-1000,-600,512},max={1000,600,640}},
  {name='Laboratory',min={600,-100,0},max={900,100,128}}}}
 local function refresh() clock=clock+1;p:SetData(data);N.RenderMap(p);assert(p.mapReady,p.renderError) end
 local function labels()
  local named={};local count=0
  for _,v in ipairs(p.mapView.labels) do if v.area then assert(not named[v.text],'Duplicate area name');named[v.text]=v;count=count+1 end end
  return named,count
 end
 local function strokes() local n=0;for _,g in ipairs(p.mapView.groups) do n=n+#g.quads/8 end;return n end
 refresh();local named,count=labels();eq(count,2);eq(strokes(),16)
 near(named.Ward.x,862+100*275/1400);near(named.Ward.y,275)
 -- A bigger offscreen volume must not steal the label from visible additions.
 data.areas[2]={name='Ward',min={12000,-500,0},max={14000,500,128}}
 refresh();named,count=labels();eq(count,2);near(named.Ward.x,862+700*275/1400)
 p:Floor(4);refresh();named,count=labels();eq(count,2);near(named.Ward.x,862)
 p.cutaway=false;p.threeD=true;refresh();named,count=labels();eq(count,2)
 data.areas[3].name='New room';refresh();named,count=labels();eq(count,3);assert(named['New room'])
 p.layers.areas=false;refresh();named,count=labels();eq(count,0);eq(strokes(),0)
 `,geometry+`
 SERVER=false;CLIENT=true;ix.FoundationNet={}
 function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
 function RealTime() return clock end;function SysTime() return clock end
 vgui={Register=function(_,p) mapPanel=p end};game={GetMap=function() return 'fixture' end,GetWorld=function() return {GetBrushSurfaces=function() return {} end} end}
 `);
suite('Plant tooltip handles empty/unknown IDs, delayed definitions, invalid status and entity removal', ['ixhl2rp/entities/entities/ix_plant.lua'],`
 local p=setmetatable({valid=true,id='',status=1,water=27.4},{__index=ENT})
 function p:GetPlant() return self.id end;function p:GetGrowStatus() return self.status end;function p:GetWater() return self.water end
 local function container()
  local c={rows={}}
  function c:AddRow(id)
   local row={SetImportant=function() end,SetBackgroundColor=function() end,SizeToContents=function() end,SetText=function(s,v) assert(type(v)=='string');s.text=v end}
   self.rows[id]=row;return row
  end
  return c
 end
 local c=container();p:OnPopulateEntityInfo(c);eq(next(c.rows),nil)
 p.id='removed';p:OnPopulateEntityInfo(c);eq(next(c.rows),nil)
 ix.Farming=nil;p:OnPopulateEntityInfo(c);eq(next(c.rows),nil)
 local definitions={};ix.Farming={GetPlant=function(_,id) return definitions[id] end}
 p.id='tomato';p:OnPopulateEntityInfo(c);eq(next(c.rows),nil)
 definitions.tomato={Name='Tomato',Description='Fresh plant'};p:OnPopulateEntityInfo(c)
 eq(c.rows.name.text,'Tomato');eq(c.rows.desc.text,'Fresh plant');eq(c.rows.status.text,'plantGrowActive')
 p.status=4;c.rows.status:Think();eq(c.rows.status.text,'plantGrowHarvestable')
 p.status=99;c.rows.status:Think();eq(c.rows.status.text,'')
 p.water=5;c.rows.water:Think();eq(c.rows.water.text,'plantWaterLabel:5')
 p.valid=false;p.GetGrowStatus=function() error('Removed entity') end;p.GetWater=p.GetGrowStatus
 c.rows.status:Think();c.rows.water:Think()
 p.valid=true;p.GetGrowStatus=function() return 99 end;p.GetWater=function() return 0 end
 local invalid=container();p:OnPopulateEntityInfo(invalid);eq(invalid.rows.status,nil);assert(invalid.rows.name)
 `,`
 SERVER=false;CLIENT=true;ENT={};AddCSLuaFile=function() end;DEFINE_BASECLASS=function() end
 function Color(...) return {...} end;function L(s,n) assert(type(s)=='string');return n and s..':'..n or s end
 ix.Farming={GetPlant=function() return nil end}
 `);
};
