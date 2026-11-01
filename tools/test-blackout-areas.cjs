const {source}=require('./restored-test-runner.cjs');
module.exports=run=>{
 const setup=source(['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/fixtures/tv.lua','tools/fixtures/cctv.lua'])+`
 SERVER=true;CLIENT=false
 pending={};timer.Simple=function(_,fn) pending[#pending+1]=fn end
 function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
 local V=getmetatable(Vector());function V:WithinAABox(a,b) return self.x>=a.x and self.x<=b.x and self.y>=a.y and self.y<=b.y and self.z>=a.z and self.z<=b.z end
 ix.util={Include=function() end,SanitizeType=function(_,v) return v end};ix.lang={AddTable=function() end}
 ix.option={Add=function() end};ix.config.Add=function() end
 ix.type={bool=1,number=2,color=3,string=4,optional=8};ix.command={Add=function() end}
 ix.log.Add=function() end;ix.gui={};CAMI={PlayerHasAccess=function(p) return p.allowed end}
 net.WriteVector=function(v) net.packet.vectors=net.packet.vectors or {};table.insert(net.packet.vectors,v) end
 net.WriteTable=function(v) net.packet.properties=v end
 B={};A={};ix.plugin.list.blackout=B;ix.plugin.list.area=A
 function A:GetData() return ix.data.Get('areas') end
 function A:SetData(t) ix.data.Set('areas',t) end
 function hook.Run(event,...)
  for _,plugin in ipairs({B,A}) do
   if plugin[event] then local result,reason=plugin[event](plugin,...);if result~=nil then return result,reason end end
  end
 end
 PLUGIN=A
 `+source(['helix/plugins/area/sh_plugin.lua','helix/plugins/area/sh_geometry.lua','helix/plugins/area/sv_plugin.lua','helix/plugins/area/sv_hooks.lua','helix/plugins/area/sv_volumes.lua'])+`
 function table.Copy(t) if isvector(t) then return Vector(t.x,t.y,t.z) end;local r={} for k,v in pairs(t) do r[k]=istable(v) and table.Copy(v) or v end;return r end
 PLUGIN=B
 `+source(['ixhl2rp/plugins/blackout/sv_plugin.lua','ixhl2rp/plugins/blackout/sh_area.lua','ixhl2rp/plugins/blackout/sv_area.lua'])+`
 lights=0;powerUpdates=0
 B.LoadFuseboxes=function() end;B.SaveFuseboxes=function() end
 B.SetZoneLights=function() lights=lights+1 end
 ix.plugin.list.facility_utilities={RecomputePower=function() powerUpdates=powerUpdates+1 end}
 function restart(reverse)
  B.zonesLoaded=false;ix.area.loaded=false;B.zones={};ix.area.stored={}
  if reverse then B:LoadData();A:LoadData() else A:LoadData();B:LoadData() end
  B:PostLoadData()
 end
 function create(id,properties)
  return ix.area.Create(id,'blackout',Vector(100,100,100),Vector(0,0,0),nil,properties or {})
 end
 function request(id,kind,properties,allowed)
  local strings={id,kind};net.ReadString=function() return table.remove(strings,1) end
  local vecs={Vector(),Vector(100,100,100)};net.ReadVector=function() return table.remove(vecs,1) end
  net.payload=properties or {};local p=admin();p.allowed=allowed
  p.NotifyLocalized=p.Notify;net.handlers.ixAreaAdd(0,p);return p
 end
 function boxAt(pos)
  local e={valid=true,broken=false,pos=pos};function e:GetPos() return self.pos end
  function e:GetBroken() return self.broken end;function e:SetBroken(v) self.broken=v end
  B.fuseboxes[#B.fuseboxes+1]=e;return e
 end
 restart()
 `;
 const suite=(name,body)=>run(name,[],setup+body);
 suite('Area editor creates exact replicated power bounds with a one-time two-unit margin',`
  eq(ix.area.types.blackout,true);eq(ix.area.typeOptions.blackout.nonLocation,true)
  assert(create('Room'));local z=B.zones.Room;eq(z.min.x,-2);eq(z.min.y,-2);eq(z.min.z,-2)
  eq(z.max.x,102);eq(z.max.y,102);eq(z.max.z,102);eq(z.active,false);eq(z.areaID,'Room')
  local p=net.packets[#net.packets];eq(p.name,'ixAreaAdd');eq(p.vectors[1].x,-2);eq(p.vectors[2].z,102)
  eq(p.properties.display,false);eq(ix.area.stored.Room.startPosition.x,z.min.x)
  eq(stored.areas.Room.endPosition.z,102);eq(stored.blackout.Room.max.z,102)
  restart(true);restart(false);eq(B.zones.Room.min.x,-2);eq(B.zones.Room.max.z,102)
 `);
 suite('Blackout margins can be disabled or adjusted and invalid geometry is rejected before replacement',`
  assert(create('Zero',{blackoutMargin=0}));eq(B.zones.Zero.min.x,0)
  assert(create('Wide',{blackoutMargin=999}));eq(B.zones.Wide.min.x,-16)
  eq(create('NaN',{blackoutMargin=0/0}),false);eq(B.zones.NaN,nil);eq(ix.area.stored.NaN,nil)
  eq(ix.area.Create('Flat','blackout',Vector(),Vector(100,100,0),nil,{}),false)
  eq(ix.area.Create('Bad','blackout',Vector(),Vector(math.huge,100,100),nil,{}),false)
  eq(create('  '),false)
  local old=ix.area.stored.Wide
  eq(ix.area.Create('Wide','blackout',Vector(),Vector(),nil,{}),false);eq(ix.area.stored.Wide,old)
  ix.area.Create('Other','area',Vector(),Vector(100,100,100),nil,{})
  eq(ix.area.stored.Other.startPosition.x,0);eq(ix.area.stored.Other.endPosition.z,100)
 `);
 suite('Creation power switch synchronizes powerboxes; repaired states and remote isolation survive reload',`
  local box=boxAt(Vector(50,50,50));assert(create('Room',{blackoutStartOff=true}))
  eq(B.zones.Room.active,true);eq(box.broken,true)
  box.broken=false;B:RecomputeZones();eq(B.zones.Room.active,false)
  restart(true);eq(B.zones.Room.active,false);eq(box.broken,false)
  B.zones.Room.active=true;B.zones.Room.remoteIsolation=true;B.zones.Room.remotePrevious=false;B:SaveData()
  restart();eq(B.zones.Room.remoteIsolation,true);eq(B.zones.Room.remotePrevious,false);eq(B.zones.Room.active,true)
  eq(box.broken,false)
 `);
 suite('Legacy migration preserves names, unpadded bounds, inactive zones and circuits despite area-name collisions',`
  ix.area.Create('Old','area',Vector(-100,-100,-100),Vector(200,200,200),nil,{display=true})
  A:SaveData();stored.blackout={Old={min=Vector(),max=Vector(100,100,100),active=true},Quiet={min=Vector(500,500,500),max=Vector(600,600,600),active=false}}
  local circuit={zone='Old'};ix.plugin.list.facility_utilities.circuit=circuit
  restart(true)
  eq(ix.area.stored.Old.type,'area');eq(B.zones.Old.areaID,'Old [power 2]');eq(circuit.zone,'Old')
  eq(ix.area.stored['Old [power 2]'].type,'blackout');eq(B.zones.Old.min.x,0);eq(B.zones.Old.max.z,100)
  eq(B.zones.Quiet.active,false);eq(B.zones.Quiet.min.x,500)
  restart();eq(table.Count(ix.area.stored),3);eq(table.Count(B.zones),2)
  eq(B.zones.Old.min.x,0);eq(B.zones.Old.max.z,100)
  eq(create('Old'),false);eq(ix.area.stored.Old.type,'area')
 `);
 suite('Deleting either through areaedit or legacy removal clears saved zones and updates power immediately',`
  local box=boxAt(Vector(50,50,50));assert(create('Room',{blackoutStartOff=true}))
  local before=powerUpdates;ix.area.Remove('Room')
  eq(B.zones.Room,nil);eq(stored.blackout.Room,nil);eq(stored.areas.Room,nil);eq(box.broken,false)
  assert(powerUpdates>before);restart(true);eq(B.zones.Room,nil)
  assert(create('Again'));B:RemoveZone('Again');eq(ix.area.stored.Again,nil);eq(stored.areas.Again,nil)
  restart();eq(B.zones.Again,nil)
 `);
 suite('Area editor permissions, duplicate names and power-zone capacity remain server enforced',`
  request('Denied','blackout',{},false);eq(B.zones.Denied,nil)
  request('Allowed','blackout',{},true);assert(B.zones.Allowed)
  local original=B.zones.Allowed;request('Allowed','blackout',{blackoutStartOff=true},true);eq(B.zones.Allowed,original);eq(original.active,false)
  net.ReadString=function() return 'Allowed' end
  local p=admin();p.allowed=false;net.handlers.ixAreaRemove(0,p);assert(B.zones.Allowed)
  p.allowed=true;net.handlers.ixAreaRemove(0,p);eq(B.zones.Allowed,nil)
  for i=1,1024 do B.zones[tostring(i)]={min=Vector(),max=Vector(10,10,10),active=false} end
  eq(create('Overflow'),false);eq(ix.area.stored.Overflow,nil)
 `);
 suite('Power volumes do not steal character area labels while areaedit can select them for deletion',`
  assert(create('Power'));ix.area.Create('Location','area',Vector(),Vector(100,100,100),nil,{})
  local p=admin();p.pos=Vector(50,50,50);p.ixArea=''
  function p:OBBCenter() return Vector() end;function p:GetArea() return self.ixArea end
  allPlayers={p};A:AreaThink();eq(p.ixArea,'Location')
  PLUGIN=A;function LocalPlayer() return p end
  `+source(['helix/plugins/area/cl_plugin.lua'])+`
  local choices=A:GetEditableAreas();eq(#choices,2);eq(choices[1],'Location');eq(choices[2],'Power')
 `);
 suite('Power area deletion/replacement cannot resurrect deleted definitions at next map load',`
  assert(create('Room'));ix.area.Create('Room','area',Vector(),Vector(50,50,50),nil,{})
  eq(B.zones.Room,nil);restart();eq(B.zones.Room,nil);eq(ix.area.stored.Room.type,'area')
  stored.blackout.Stale={min=Vector(),max=Vector(50,50,50),active=true,areaID='Missing'}
  restart(true);eq(B.zones.Stale,nil);eq(ix.area.stored.Missing,nil)
 `);
 suite('Area form hides unrelated controls and submits only visible values with the captured second corner',`
  PLUGIN=A;vgui={Register=function(_,p) Editor=p end};ix.gui={}
  `+source(['helix/plugins/area/derma/cl_areaedit.lua'])+`
  local e=setmetatable({propertyRows={},properties={},typeEntry={GetSelected=function() return 'Power','blackout' end}}, {__index=Editor})
  for _,key in ipairs({'color','display','blackoutMargin','blackoutStartOff','zombieMax'}) do
   ix.area.properties[key]=ix.area.properties[key] or {type=ix.type.number}
   local row={valid=true,visible=true};function row:SetVisible(v) self.visible=v end;function row:IsVisible() return self.visible end
   e.propertyRows[key]=row;e.properties[key]=function() return key=='blackoutMargin' and 3 or true end
  end
  e.canvas={InvalidateLayout=function() end};e.SizeToContents=function() end;e:UpdatePropertyVisibility()
  eq(e.propertyRows.zombieMax.visible,false);eq(e.propertyRows.display.visible,false);eq(e.propertyRows.blackoutMargin.visible,true)
  e.nameEntry={GetValue=function() return 'New Room' end};e.Remove=function() end
  A.editStart=Vector(1,2,3);A.editEnd=Vector(90,91,92)
  A.GetPlayerAreaTrace=function() error('Second corner must stay frozen while choosing properties') end
  e:Submit();local packet=net.packets[#net.packets];eq(packet.vectors[2].z,92)
  eq(packet.properties.blackoutMargin,3);eq(packet.properties.zombieMax,nil);eq(packet.properties.display,nil)
  e.typeEntry.GetSelected=function() return 'Area','area' end;e:UpdatePropertyVisibility()
  eq(e.propertyRows.blackoutMargin.visible,false);eq(e.propertyRows.blackoutStartOff.visible,false);eq(e.propertyRows.display.visible,true)
 `);
 suite('Per-zone darkness edits preserve bounds and power state, validate access and survive reload',`
  create('Dim',{blackoutDarkness=35,blackoutSoftness=40,blackoutStartOff=true})
  local z=B.zones.Dim;eq(z.darkness,35);eq(z.softness,40)
  local p=admin();p.allowed=false;eq(B:UpdateAreaAppearance(p,'Dim',0,0),false);eq(z.darkness,35)
  p.allowed=true;eq(B:UpdateAreaAppearance(p,'Dim',101,24),false)
  eq(B:UpdateAreaAppearance(p,'Dim',50,0/0),false)
  assert(B:UpdateAreaAppearance(p,'Dim',60,50));eq(z.active,true);eq(z.min.x,-2);eq(z.max.z,102)
  restart(true);eq(B.zones.Dim.darkness,60);eq(B.zones.Dim.softness,50);eq(B.zones.Dim.min.x,-2)
  assert(B:UpdateAreaAppearance(p,'Dim',0,0));restart();eq(B.zones.Dim.darkness,0);eq(B.zones.Dim.softness,0)
 `);
 suite('Fine blackout fades are monotonic, blend to the requested strength, and retain strict bounds and union semantics',`
  PLUGIN=B;B.maskLayers=48;B.maskDarkness=220;B.maskSoftness=24
  function CreateMaterial() return {} end
  B.zones={{min=Vector(),max=Vector(200,200,200),darkness=86,softness=24}}
  hooks={};hook.Add=function(event,key,fn) hooks[event]=hooks[event] or {};hooks[event][key]=fn end
  `+source(['ixhl2rp/plugins/blackout/cl_plugin.lua'])+`
  local layers=B:BuildFadeLayers();eq(#layers,48)
  local function shade(pos,rows)
   local a=0
   for _,layer in ipairs(rows or layers) do
    local inside=false;for _,b in ipairs(layer.boxes) do if pos:WithinAABox(b.min,b.max) then inside=true end end
    if inside then a=a+(1-a)*layer.alpha/255 end
   end
   return a
  end
  eq(shade(Vector(-.1,100,50)),0);eq(shade(Vector(201,100,50)),0)
  assert(math.abs(shade(Vector(100,100,50))-.86)<.005)
  local old,changes=0,0
  for x=0,24,.25 do local value=shade(Vector(x,100,50));assert(value>=old);assert(value-old<.055)
   if value>old then changes=changes+1 end;old=value
  end
  assert(changes>35,'Fade must have far more than three visible steps')
  B.zones[2]={min=Vector(),max=Vector(200,200,200),darkness=40,softness=24}
  assert(math.abs(shade(Vector(100,100,50),B:BuildFadeLayers())-.86)<.005)
  B.zones={{min=Vector(),max=Vector(200,200,200),darkness=0,softness=24}};eq(#B:BuildFadeLayers(),0)
  B.zones[1].darkness=100;B.zones[1].softness=0;near(shade(Vector(10,10,10),B:BuildFadeLayers()),1)
  local box={min=Vector(80,-10,-10),max=Vector(100,10,10)}
  local view={origin=Vector(),angles=Angle(),fov=90,aspect=16/9,zfar=1000}
  eq(B:FadeVisible(box,view),true);view.angles=Angle(0,180,0);eq(B:FadeVisible(box,view),false)
  view.origin=Vector(90,0,0);eq(B:FadeVisible(box,view),true)
  view.origin=Vector(500,0,0);eq(B:FadeVisible(box,view),true)
  view.angles=Angle();eq(B:FadeVisible(box,view),false)
 `);
 suite('Height edits retain footprint, margin, appearance, identity and outage state while saving and refreshing the new volume',`
  assert(create('Room',{blackoutStartOff=true,blackoutDarkness=65,blackoutSoftness=18}))
  local z=B.zones.Room;z.remoteIsolation=true;z.remotePrevious=false
  local circuit={zone='Room'};ix.plugin.list.facility_utilities.circuit=circuit
  local p=admin();p.allowed=true;local before=powerUpdates;local beforeLights=lights
  assert(B:UpdateAreaHeight(p,'Room',-12.5,245.75))
  eq(B.zones.Room,z);eq(z.areaID,'Room');eq(circuit.zone,'Room')
  eq(z.min.x,-2);eq(z.min.y,-2);eq(z.max.x,102);eq(z.max.y,102)
  eq(z.min.z,-12.5);eq(z.max.z,245.75);eq(z.active,true);eq(z.remotePrevious,false)
  eq(z.darkness,65);eq(z.softness,18);eq(z.remoteIsolation,true)
  eq(ix.area.stored.Room.properties.blackoutMargin,2)
  assert(powerUpdates>before);assert(lights>beforeLights)
  local packet=net.packets[#net.packets];eq(packet.name,'ixAreaAdd')
  eq(packet.vectors[1].z,-12.5);eq(packet.vectors[2].z,245.75)
  eq(stored.areas.Room.startPosition.z,-12.5);eq(stored.blackout.Room.max.z,245.75)
  restart(true);restart(false);z=B.zones.Room
  eq(z.min.x,-2);eq(z.max.y,102);eq(z.min.z,-12.5);eq(z.max.z,245.75)
  eq(z.remoteIsolation,true);eq(z.remotePrevious,false);eq(z.darkness,65)
  assert(B:UpdateAreaHeight(p,'Room',-12.5,300));eq(z.min.x,-2);eq(z.min.z,-12.5);eq(z.max.z,300)
 `);
 suite('Height requests reject unauthorized, nonfinite, inverted, oversized and deleted areas before mutation',`
  create('Room');ix.area.Create('Location','area',Vector(),Vector(50,50,50),nil,{})
  local p=admin();p.allowed=false;eq(B:UpdateAreaHeight(p,'Room',-20,150),false)
  p.allowed=true;p.dead=true;eq(B:UpdateAreaHeight(p,'Room',-20,150),false);p.dead=false
  for _,values in ipairs({{0/0,150},{0,math.huge},{-math.huge,150},{-32769,150},{0,32769},{150,0},{20,20},{20,20.5}}) do
   eq(B:UpdateAreaHeight(p,'Room',values[1],values[2]),false)
  end
  eq(B:UpdateAreaHeight(p,'Missing',0,150),false);eq(B:UpdateAreaHeight(p,'Location',0,150),false)
  eq(B.zones.Room.min.z,-2);eq(B.zones.Room.max.z,102);eq(ix.area.stored.Location.endPosition.z,50)
  local floats={-30,250};net.ReadString=function() return 'Room' end;net.ReadFloat=function() return table.remove(floats,1) end
  net.handlers.ixBlackoutHeight(0,p);eq(B.zones.Room.min.z,-30);eq(B.zones.Room.max.z,250)
  eq(p.notices[#p.notices],'Высота зоны обновлена.')
  ix.area.Remove('Room');floats={0,100};net.handlers.ixBlackoutHeight(0,p);eq(B.zones.Room,nil)
 `);
 suite('Height menu offers precise floor and ceiling controls, previews without mutation, cancels cleanly and sends only Z values',`
  PLUGIN=B;SERVER=false;CLIENT=true;create('Room');ix.area.bEditing=true;ix.CCTV={}
  function ScrW() return 1920 end;function ScrH() return 1080 end
  TOP=1;BOTTOM=2;LEFT=3;RIGHT=4
  local widgets={}
  local function panel(kind)
   local p={valid=true,kind=kind,children={},value=0,enabled=true};widgets[#widgets+1]=p
   function p:Add(class) local child=panel(class);self.children[#self.children+1]=child;return child end
   function p:SetText(v) self.text=v end
   function p:SetTitle(v) self.title=v end
   function p:SetEnabled(v) self.enabled=v end
   function p:SetMinMax(a,b) self.minimum=a;self.maximum=b end
   function p:GetValue() return self.value end
   function p:SetValue(v) self.value=math.Clamp(v,self.minimum or -math.huge,self.maximum or math.huge);if self.OnValueChanged then self:OnValueChanged(self.value) end end
   function p:Remove() self.valid=false;if self.OnRemove then self:OnRemove() end end
   for _,method in ipairs({'Dock','SetTall','DockMargin','SetWide','SetDecimals','SetInterval','SetSize','SetPos','MakePopup','SetWrap'}) do p[method]=function() end end
   return p
  end
  vgui={Create=panel};local options={}
  function DermaMenu() return {AddOption=function(_,text,fn) options[text]=fn;return {SetIcon=function() end} end,Open=function() end} end
  local boxes={};render={DrawWireframeBox=function(_,_,mn,mx) boxes[#boxes+1]={min=mn,max=mx} end}
  net.WriteFloat=function(v) net.packet.floats=net.packet.floats or {};table.insert(net.packet.floats,v) end
  `+source(['ixhl2rp/plugins/blackout/cl_settings.lua'])+`
  B:AreaEditPopulateOptions('Room',ix.area.stored.Room,DermaMenu());assert(options['Настроить затемнение'])
  options['Изменить высоту']();local frame=B.heightEditor
  local inputs,plus,save,cancel={}
  for _,p in ipairs(widgets) do
   if p.kind=='DNumberWang' then inputs[#inputs+1]=p end
   if p.text=='+16' and not plus then plus=p end
   if p.text=='Применить' then save=p elseif p.text=='Отмена' then cancel=p end
  end
  eq(inputs[1]:GetValue(),-2);eq(inputs[2]:GetValue(),102)
  plus.DoClick();eq(inputs[1]:GetValue(),14)
  inputs[2]:SetValue(350);inputs[1]:SetValue(-30.5)
  local preview=hooks.PostDrawTranslucentRenderables.ixBlackoutHeightPreview
  preview(false,false,false);eq(boxes[1].min.z,-30.5);eq(boxes[1].max.z,350)
  eq(ix.area.stored.Room.startPosition.z,-2);eq(ix.area.stored.Room.endPosition.z,102)
  preview(true,false,false);eq(#boxes,1);ix.CCTV.rendering=true;preview(false,false,false);eq(#boxes,1);ix.CCTV.rendering=false
  inputs[2]:SetValue(-31);eq(save.enabled,false);local sent=#net.packets;save.DoClick();eq(#net.packets,sent)
  inputs[2]:SetValue(350);eq(save.enabled,true);save.DoClick()
  local packet=net.packets[#net.packets];eq(packet.name,'ixBlackoutHeight');eq(packet.value,'Room')
  eq(packet.floats[1],-30.5);eq(packet.floats[2],350);eq(#packet.floats,2)
  eq(frame.valid,false);eq(B.heightEditor,nil);eq(hooks.PostDrawTranslucentRenderables.ixBlackoutHeightPreview,nil)
  B:OpenAreaHeight('Room',ix.area.stored.Room);frame=B.heightEditor
  sent=#net.packets;frame:Remove();eq(#net.packets,sent);eq(ix.area.stored.Room.startPosition.z,-2)
  eq(hooks.PostDrawTranslucentRenderables.ixBlackoutHeightPreview,nil)
 `);
 suite('Compound power area uses both wings but never its empty corner, preserving power and margins',`
  create('L',{blackoutMargin=2,blackoutStartOff=true});local zone=B.zones.L
  zone.remoteIsolation=true;zone.remotePrevious=false
  local p=admin();p.allowed=true;p.NotifyLocalized=p.Notify
  local function add(a,b,revision)
   net.ReadString=function() return 'L' end;net.ReadUInt=function() return revision or 0 end
   net.ReadBool=function() return true end;local points={a,b};net.ReadVector=function() return table.remove(points,1) end
   net.handlers.ixAreaVolumeEdit(0,p)
  end
  add(Vector(100,0,0),Vector(220,40,100))
  local info=ix.area.stored.L;eq(#info.volumes,2);eq(info.volumeRevision,1)
  eq(info.volumes[1].min.x,-2);eq(info.volumes[2].min.x,98);eq(info.endPosition.x,222)
  eq(ix.area.Contains(info,Vector(180,20,50)),true);eq(ix.area.Contains(info,Vector(180,80,50)),false)
  eq(B:GetOwningZone(Vector(180,20,50)),zone);eq(B:GetOwningZone(Vector(180,80,50)),nil)
  eq(zone.active,true);eq(zone.remoteIsolation,true);eq(zone.remotePrevious,false)
  eq(#stored.areas.L.volumes,2);eq(#stored.blackout.L.volumes,2)
  restart(true);restart(false);eq(#B.zones.L.volumes,2);eq(B.zones.L.volumes[1].min.x,-2)
  assert(B:UpdateAreaHeight(p,'L',-10,170));info=ix.area.stored.L
  eq(#info.volumes,2);eq(info.volumes[2].max.z,170);eq(info.volumes[2].max.y,42)
  eq(ix.area.Contains(info,Vector(180,80,50)),false)
  assert(B:UpdateAreaAppearance(p,'L',45,11));eq(#ix.area.stored.L.volumes,2)
 `);
 suite('Volume mutations enforce permissions, geometry, revision, counts and keep the last box',`
  create('Room',{blackoutMargin=0});local p=admin();p.allowed=true;p.NotifyLocalized=p.Notify
  local revision=0;local remove=false;local index=2
  net.ReadString=function() return 'Room' end
  net.ReadUInt=function(bits) return bits==32 and revision or index end
  net.ReadBool=function() return not remove end
  local points={};net.ReadVector=function() return table.remove(points,1) end
  local function add(a,b) points={a,b};net.handlers.ixAreaVolumeEdit(0,p) end
  p.allowed=false;add(Vector(100,0,0),Vector(150,50,50));eq(ix.area.stored.Room.volumes,nil)
  p.allowed=true;add(Vector(100,0,0),Vector(150,50,0));eq(ix.area.stored.Room.volumes,nil)
  add(Vector(0/0,0,0),Vector(150,50,50));eq(ix.area.stored.Room.volumes,nil)
  add(Vector(100,0,0),Vector(150,50,50));eq(#ix.area.stored.Room.volumes,2)
  add(Vector(150,0,0),Vector(200,50,50));eq(#ix.area.stored.Room.volumes,2) -- stale revision
  revision=1;remove=true;index=40;net.handlers.ixAreaVolumeEdit(0,p);eq(#ix.area.stored.Room.volumes,2)
  index=1;net.handlers.ixAreaVolumeEdit(0,p);eq(#ix.area.stored.Room.volumes,1);eq(ix.area.stored.Room.startPosition.x,100)
  revision=2;index=1;net.handlers.ixAreaVolumeEdit(0,p);eq(#ix.area.stored.Room.volumes,1)
  local volumes={} for i=1,33 do volumes[i]={min=Vector(i*10,0,0),max=Vector(i*10+10,10,10)} end
  eq(ix.area.UpdateVolumes('Room',volumes),false);eq(#ix.area.stored.Room.volumes,1)
 `);
 suite('Logical area changes save without invoking deletion hooks and geometry union counts overlaps once',`
  ix.area.Create('Place','area',Vector(),Vector(100,100,100),nil,{display=true,color=Color(1,2,3)})
  local removed=0;function A:AreaDefinitionRemoved() removed=removed+1 end
  assert(ix.area.UpdateVolumes('Place',{{min=Vector(),max=Vector(100,100,100)},{min=Vector(50,0,0),max=Vector(150,100,100)}}))
  local info=ix.area.stored.Place;eq(removed,0);eq(info.properties.color.g,2);eq(ix.area.Measure(info),1500000)
  eq(ix.area.DistanceSqr(info,Vector(160,50,50)),100);eq(#stored.areas.Place.volumes,2)
  local shapes=ix.area.GetDisjointVolumes(info);eq(#shapes,2)
  for x=0,160,5 do for y=0,110,5 do
   local point=Vector(x,y,50);local expected=x<=150 and y<=100;eq(ix.area.Contains(info,point),expected)
  end end
 `);
 suite('Compound volumes round-trip in live sync and R-menu add/remove uses the selected area revision',`
  ix.area.Create('L','area',Vector(),Vector(100,40,100),nil,{display=true})
  assert(ix.area.UpdateVolumes('L',{{min=Vector(),max=Vector(100,40,100)},{min=Vector(0,0,0),max=Vector(40,100,100)}}))
  local info=ix.area.stored.L;local p=admin();p.pos=Vector(20,80,20)
  function p:OBBCenter() return Vector() end;function p:GetEyeTraceNoCursor() return {HitPos=Vector(0,100,0)} end
  function LocalPlayer() return p end
  PLUGIN=A;CLIENT=true;SERVER=false
  ix.util.NotifyLocalized=function(message) notice=message end
  function L(key,...) return key end;function ScrW() return 1920 end;function ScrH() return 1080 end
  menus={}
  function DermaMenu()
   local m={options={}}
   function m:AddOption(label,fn) local o={label=label,fn=fn,SetIcon=function() end};self.options[#self.options+1]=o;return o end
   function m:AddSubMenu(label) local sub=DermaMenu();self.sub=sub;return sub end
   function m:AddSpacer() end;function m:Open() end
   menus[#menus+1]=m;return m
  end
  function Derma_Query(_,_,_,_,_,yes) confirmation=yes end
  `+source(['helix/plugins/area/cl_plugin.lua','helix/plugins/area/cl_hooks.lua','helix/plugins/area/cl_volumes.lua'])+`
  A:StartEditing();eq(A:GetEditableAreas()[1],'L');A:EditReload()
  menus[1].options[1].fn();eq(A.editVolumeID,'L');eq(A.editVolumeRevision,1)
  A:EditClick();eq(A.editStart.y,100)
  A.GetPlayerAreaTrace=function() return {HitPos=Vector(40,140,100)} end
  A:EditClick();eq(A.editVolumeID,nil)
  local packet=net.packets[#net.packets];eq(packet.name,'ixAreaVolumeEdit');eq(packet.value,'L')
  eq(packet.integer,1);eq(packet.boolean,true);eq(packet.vectors[1].y,100);eq(packet.vectors[2].y,140)
  A:BeginVolume('L');A:EditRightClick();eq(A.editVolumeID,nil);eq(ix.area.bEditing,true)
  local option=menus[1].sub.options[2];option:OnCursorEntered();eq(A.volumePreview,info.volumes[2]);option:OnCursorExited();eq(A.volumePreview,nil)
  option.fn();confirmation();packet=net.packets[#net.packets];eq(packet.boolean,false);eq(packet.integer,2)
  local strings={'L','area'};local vectors={info.startPosition,info.endPosition}
  for _,box in ipairs(info.volumes) do vectors[#vectors+1]=box.min;vectors[#vectors+1]=box.max end
  net.ReadString=function() return table.remove(strings,1) end;net.ReadVector=function() return table.remove(vectors,1) end
  net.ReadTable=function() return info.properties end;net.ReadUInt=function(bits) return bits==32 and 9 or 2 end
  net.handlers.ixAreaAdd();eq(ix.area.stored.L.volumeRevision,9);eq(#ix.area.stored.L.volumes,2)
  eq(ix.area.Contains(ix.area.stored.L,Vector(80,80,20)),false);eq(A:GetEditableAreas()[1],'L')
  p.pos=Vector(80,80,20);eq(#A:GetEditableAreas(),0)
 `);
 suite('Compound blackout capacity counts volumes as well as zone names',`
  local parts={};for i=1,32 do parts[i]={min=Vector(i*20,0,0),max=Vector(i*20+10,10,10)} end
  for i=1,32 do B.zones[tostring(i)]={min=Vector(),max=Vector(650,10,10),volumes=parts} end
  eq(create('Overflow'),false);eq(ix.area.stored.Overflow,nil)
 `);
};
if(require.main===module){const r=require('./restored-test-runner.cjs');module.exports((name,_,code)=>r.run(name,code));r.finish();}
