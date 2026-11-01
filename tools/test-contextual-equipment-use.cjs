const {run,source,native,base,finish}=require('./restored-test-runner.cjs');
const client=source([...base,'tools/terminal-preview-fixture.lua','tools/fixtures/contextual-equipment-use.lua',
 'tools/fixtures/equipment-item-menu.lua','helix/gamemode/game/ui/generic.menu.lua',
 'ixhl2rp/plugins/facility_utilities/sh_core.lua','ixhl2rp/plugins/facility_utilities/cl_contextual.lua',
 'ixhl2rp/plugins/facility_utilities/cl_devices.lua','ixhl2rp/plugins/water_sources/sh_water.lua','ixhl2rp/plugins/water_sources/cl_water.lua',
 'ixhl2rp/plugins/decontamination/sh_plugin.lua','ixhl2rp/plugins/decontamination/cl_decon.lua'])+`
 local Q,F,W,D=ix.Facility.QuickUse,ix.Facility,ix.water,ix.Decon
 for kind,def in pairs(D.kinds) do F.kinds[kind]=def end
 local nativeHook=hook.Run
 hook.Run=function(event,...)
  if event=='GetEquipmentInteraction' then return W.Interaction(...) or D.Interaction(...) or F.DeviceInteraction(...) end
  return nativeHook(event,...)
 end
 F.Request=function(scope,action,data) requests=requests or {};requests[#requests+1]={scope,action,data} end
`;
exports.client=client;
function suite(name,code){run(name,client+code)}
if(require.main===module){
suite('Use opens native item options; remapped use, exact fill ID and toilet warning survive',`
 aimed=fixture('sink');bottle(10);bottle(21,'Термос');Q.Refresh(true);eq(panelsCreated,0)
 local cmd=command(true);Q.Input(cmd);eq(cmd:KeyDown(IN_USE),false);eq(cmd:KeyDown(IN_ATTACK),true)
 eq(#net.packets,0);eq(Q.menu.class,'simple.option');eq(Q.menu.x,ScrW()/2);eq(Q.menu.y,ScrH()/2)
 menuOption(Q.menu,'Набрать: Термос').DoClick()
 local packet=net.packets[#net.packets];eq(packet.name,'ixWaterChoose');eq(packet.entity,aimed);eq(packet.integers[1],2);eq(packet.integers[2],21);eq(packet.boolean,false)
 Q.Input(command(false));aimed=fixture('toilet',702);Q.Refresh(true);assert(Q.option.warning);assert(Q.option.detail:find('радиацию',1,true));eq(#Q.current.options,3)
 Q.Paint(Q.current,Q.option,Q.index);assert(painted[2].text:find('[F]',1,true));assert(painted[2].text:find('Действия',1,true))
`);
suite('Held use does not repeat or retarget; selecting an invalidated container cannot fall through to drinking',`
 aimed=fixture('sink');bottle(10);Q.Input(command(true));local menu=Q.menu;local fill=menuOption(menu,'Набрать: Фляга')
 Q.Input(command(true));eq(Q.menu,menu);p.items={};fill.DoClick();eq(#net.packets,0);eq(IsValid(menu),false)
 Q.Input(command(true));assert(not IsValid(Q.menu));Q.Input(command(false));Q.Input(command(true));assert(IsValid(Q.menu))
 aimed=fixture('sink',702);Q.menu:Think();assert(not IsValid(Q.menu));eq(#net.packets,0)
`);
suite('Physical held binding remains disarmed across native ClearButtons and menu transitions',`
 aimed=fixture('sink');physicalDown=true;Q.Input(command(true));Q.CloseMenu()
 gameMenu=true;Q.Input(command(false));eq(Q.useDown,true);gameMenu=false;Q.Input(command(true));assert(not IsValid(Q.menu))
 physicalDown=false;Q.Input(command(false));physicalDown=true;Q.Input(command(true));assert(IsValid(Q.menu));Q.CloseMenu()
 physicalDown=false;Q.Input(command(false));gameMenu=true;physicalDown=true;Q.Input(command(false));gameMenu=false;Q.Input(command(true));assert(not IsValid(Q.menu))
`);
suite('Wheel is untouched; foreign UI and placement states suppress equipment options',`
 aimed=fixture('sink');Q.Refresh(true);eq(Q.Cycle,nil);aimed=nil;eq(Q.Refresh(true),nil)
 local cases={
  function(v) gameMenu=v end,function(v) cursor=v end,function(v) consoleOpen=v end,function(v) trapping=v end,
  function(v) focus=v and {valid=true} or nil end,function(v) ix.gui.fieldlink=v and {valid=true} or nil end,
  function(v) ix.Fieldlink.camera=v end,function(v) ix.PoseStudio={placement=v} end,
  function(v) ix.PoseStudio={placementPending=v} end,function(v) ix.plugin.list.cctv.placing=v end,
  function(v) ix.plugin.list.tv_screen={placement=v} end,function(v) ix.plugin.list.sithelper={IsPlacingPose=function() return v end} end,
  function(v) F.connectionActive=v end,function(v) ix.CCTV.rendering=v end,
  function(v) p.dead=v end,function(v) p.restricted=v end,function(v) p.noCharacter=v end,
  function(v) mainMenu=v end,function(v) wall=v end}
 for _,set in ipairs(cases) do aimed=fixture('sink');set(true);eq(Q.Refresh(true),nil);eq(Q.current,nil);set(false) end
 aimed=fixture('sink');Q.Refresh(true);eq(traceData.start,p:GetShootPos());eq(traceData.filter[1] or traceData.filter,p)
`);
suite('Wheelchair and other vehicle exits receive use even after equipment captured the previous press',`
 aimed=fixture('sink');physicalDown=true;Q.Input(command(true));assert(IsValid(Q.menu))
 function p:InVehicle() return true end
 local cmd=command(true);Q.Input(cmd)
 eq(cmd:KeyDown(IN_USE),true);eq(Q.consumeUse,false);eq(Q.current,nil);eq(IsValid(Q.menu),false)
 Q.Input(command(false));cmd=command(true);Q.Input(cmd);eq(cmd:KeyDown(IN_USE),true)
 function p:InVehicle() return false end
 physicalDown=false;Q.Input(command(false));physicalDown=true;cmd=command(true);Q.Input(cmd)
 eq(cmd:KeyDown(IN_USE),false);assert(IsValid(Q.menu))
`);
suite('Unloaded client inventory does not throw or offer containers; medicine cannot be filled',`
 aimed=fixture('sink');bottle(1).reagents.reagents={{uniqueID='medicine',volume=20}}
 p.inventories=nil;function p:GetInventory() error('unloaded inventories') end
 local spec=W.Interaction(p,aimed);eq(#spec.options,3);eq(spec.options[2].disabled,true)
`);
suite('Late device snapshots cannot close admin workspaces or operate anything',`
 F.window={valid=true,Remove=function() error('must not close admin') end}
 local e=fixture('generator');local data={entity=e:EntIndex(),id=700,name='Резерв',kind='generator',fault=false,fuel=300,canStart=true,hasFuel=true,links={}}
 F.OpenDevice({device=data});eq(F.deviceSnapshots[e:EntIndex()].data,data);eq(requests,nil);eq(panelsCreated,0)
 F.OpenDevice({close=true});assert(F.window.valid);eq(next(F.deviceSnapshots),nil)
`);
suite('Generator command set preserves wiring, exact disconnect index, packing and repair requirements',`
 local d={kind='generator',fault=false,fuel=300,canStart=true,hasFuel=true,portable=true,links={}}
 local rows=F.DeviceOptions(d);eq(rows[1].id,'generator');eq(rows[2].id,'refuel');eq(rows[3].id,'connect');eq(rows[4].id,'carry');eq(rows[5].id,'pack')
 d.links={{index=3,name='Щиток'}};rows=F.DeviceOptions(d);eq(rows[4].index,3);eq(rows[4].id,'disconnect:3');eq(rows[#rows].id,'pack');eq(rows[#rows].disabled,true)
 d.fault=true;d.repairAllowed=true;d.hasTool=true;d.hasParts=false;rows=F.DeviceOptions(d);for _,row in ipairs(rows) do assert(row.id~='repair') end
 d.hasParts=true;rows=F.DeviceOptions(d);eq(rows[1].id,'repair')
 d.owner='Другой';d.mine=false;rows=F.DeviceOptions(d);for _,row in ipairs(rows) do assert(row.id~='repair') end
`);
suite('Battery action list offers paid outgoing cables, preserves recovery when faulty and blocks packing while attached',`
 local d={kind='battery',charge=3000,canStart=true,portable=true,links={},hasCable=false}
 local rows=F.DeviceOptions(d);eq(rows[1].id,'connect');eq(rows[1].disabled,true);eq(rows[2].id,'carry');eq(rows[3].id,'pack')
 d.hasCable=true;rows=F.DeviceOptions(d);eq(rows[1].disabled,false)
 d.links={{index=1,name='Камера',token=77,connected=false}};rows=F.DeviceOptions(d)
 eq(rows[2].id,'disconnect:1');eq(rows[2].expectedLink,77);eq(rows[#rows].disabled,true)
 d.fault=true;rows=F.DeviceOptions(d);eq(rows[2].id,'disconnect:1')
 d.links={};d.connected=true;rows=F.DeviceOptions(d);eq(rows[#rows].id,'pack');eq(rows[#rows].disabled,true)
`);
suite('Passive inspect and explicit action are different channels; Alt-use retains native admin path',`
 aimed=fixture('generator');local id=aimed:EntIndex()
 F.OpenDevice({device={entity=id,id=700,kind='generator',fault=false,fuel=300,canStart=true,hasFuel=true,links={}}})
 Q.Refresh(true);eq(net.packets[#net.packets].name,'ixFacilityInspect');local n=#net.packets
 Q.Input(command(true));eq(requests,nil);menuOption(Q.menu,'Запустить двигатель').DoClick();eq(requests[1][2],'generator');eq(#net.packets,n)
 Q.Input(command(false));local c=command(true,true);Q.Input(c);eq(c:KeyDown(IN_USE),true);eq(#requests,1)
`);
suite('Lost power/fault, expired snapshots and character swap discard actionable device state',`
 aimed=fixture('generator');local id=aimed:EntIndex()
 F.OpenDevice({device={entity=id,id=700,kind='generator',fault=false,fuel=300,canStart=true,links={}}});Q.Refresh(true);assert(Q.option)
 aimed.ixFacilityFault=true;Q.Refresh(true);eq(Q.option,nil)
 F.OpenDevice({device={entity=id,id=700,kind='generator',fault=true,repairAllowed=true,hasTool=true,hasParts=true}});Q.Refresh(true);eq(Q.current.options[1].id,'repair')
 aimed.ixFacilityFault=false;clock=clock+5;Q.Refresh(true);eq(Q.option,nil)
`);
suite('Decon uses native E and only the existing cycle bar; compact paint cannot overlap it at 640x480',`
 screenW=640;screenH=480;aimed=fixture('decon_shower');aimed.ixFacilityPowered=true;aimed.ixDeconUser=p
 ix.bar.actionEnd=clock+8;Q.Refresh(true);assert(Q.current.duringAction);local cmd=command(true);Q.Input(cmd);assert(cmd:KeyDown(IN_USE));eq(#net.packets,0)
 Q.Paint(Q.current,Q.option,Q.index);eq(#painted,2)
 for _,row in ipairs(painted) do assert(row.y+22<screenH*.72);assert(not row.text:find('ПРОМЫВКА',1,true)) end
 eq(panelsCreated,0)
`);
suite('Cyrillic contextual names fit the small-screen width and ordinary work hides duplicate hints',`
 screenW=640;screenH=480;aimed=fixture('sink');Q.Refresh(true);Q.current.title=string.rep('Длинное название ',12)
 Q.Paint(Q.current,Q.option,Q.index);assert(painted[1].text:find('…',1,true));for _,row in ipairs(painted) do assert(utf8.len(row.text)) end
 local n=#painted;ix.bar.actionEnd=clock+2;Q.Paint(Q.current,Q.option,Q.index);eq(#painted,n)
`);
suite('Facility unload removes the three contextual hooks and transient state',`
 F.QuickUse.useDown=true;F.QuickUse.consumeUse=true;F.StopMicrophone=function() end
 local removed={};hook.Remove=function(event,id) removed[id]=event end
 ${native('ixhl2rp/plugins/facility_utilities/cl_ui.lua','function PLUGIN:OnUnload()','\nend')}
 end
 PLUGIN:OnUnload();eq(removed.ixEquipmentContextUse,'CreateMove');eq(removed.ixEquipmentContextWheel,'PlayerBindPress');eq(removed.ixEquipmentContextHint,'HUDPaint');eq(Q.useDown,nil)
`);
const server=source([...base,...['sh_core','sh_repair','sv_store','sv_portables','sv_connections','sv_power','sv_doors','sv_comms','sv_jobs','sv_repair','sv_devices','sv_network'].map(v=>'ixhl2rp/plugins/facility_utilities/'+v+'.lua')]);
run('Passive device inspection cannot consume the mutation cooldown; forged, distant and oversized inspect packets fail',server+`
 local P,F=PLUGIN,ix.Facility;P.loaded=true;local p=admin();local d=device('generator');d.fuel=0;giveItem(p,'facility_fuel')
 function p:GetAimVector() return Vector(1,0,0) end
 local aim=d.entity;util.TraceLine=function(q) return q.mask==MASK_SOLID and {Entity=aim} or {Hit=false} end
 net.ReadUInt=function() return d.id end
 local inspect=net.handlers.ixFacilityInspect
 inspect(64,p);eq(p.ixFacilityInspectAt,nil)
 inspect(32,p);eq(p.ixFacilityNetAt,nil);assert(p.ixFacilityInspectAt>clock)
 net.payload=util.TableToJSON({scope='device',command='refuel',id=d.id})
 net.handlers.ixFacilityRequest(100,p);eq(d.fuel,300);eq(p.items.facility_fuel,nil)
 local n=#net.packets;inspect(32,p);eq(#net.packets,n)
 clock=clock+1;aim=nil;inspect(32,p);eq(#net.packets,n)
 clock=clock+1;aim=d.entity;p.pos=Vector(9999,0,0);inspect(32,p);eq(#net.packets,n)
`);
finish();
}
