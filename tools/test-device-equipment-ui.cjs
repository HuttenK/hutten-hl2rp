const {run,source,finish}=require('./restored-test-runner.cjs');
const setup=source(['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/terminal-preview-fixture.lua','tools/fixtures/device-equipment-ui.lua'])+`
 hook.Remove=function(event,id) hooks[id]=nil end
 local V=getmetatable(Vector());function V:DistToSqr(v) return (self-v):Dot(self-v) end
`+source(['ixhl2rp/plugins/water_sources/cl_water.lua','ixhl2rp/plugins/field_equipment/cl_equipment.lua','ixhl2rp/plugins/decontamination/sh_plugin.lua','ixhl2rp/plugins/decontamination/cl_decon.lua']);
function suite(name,code){run(name,setup+code)}
// Water and contextual input regressions now live in test-contextual-equipment-use.cjs.
suite('Armor insert controls preserve IDs, slots and install/remove direction',`
 local win=plate(984,{.6,-1,0});local b=buttons(win);eq(#b,4)
 b[2]:DoClick();eq(sent[1].name,'ixPlateChange');eq(sent[1].values[1][1],984);eq(sent[1].values[2][1],1);eq(sent[1].values[3],false);eq(b[2]:IsEnabled(),false)
 b[3]:DoClick();eq(sent[2].values[2][1],2);eq(sent[2].values[3],true)
 b[4]:DoClick();eq(sent[3].values[2][1],3);eq(sent[3].values[3],true)
 local empty=plate(10,{});eq(#buttons(empty),1);assert(texts(empty):find('без пластин',1,true))
`);
suite('Small-window production layouts keep close/actions inside bounds; Russian long names paint',`
 screenW=640;screenH=480
 local armor=plate(1,{1,.5,-1});PreviewLayout(armor)
 for _,b in ipairs(buttons(armor)) do local parent=b:GetParent();assert(b.x>=0 and b.y>=0);assert(b.x+b.w<=parent.w+.1);assert(b.y+b.h<=parent.h+.1) end
 PreviewSVG(armor)
`);
suite('Clinical readout truthfully distinguishes no power, fault, pending sensor and alarm',`
 local e=equipment('decon_sensor');local D=ix.Decon
 local status= D.Readout(e);eq(status,'ПИТАНИЕ ОТКЛЮЧЕНО')
 e.state.ixFacilityFault=true;status=D.Readout(e);eq(status,'НЕИСПРАВНО')
 e.state.ixFacilityFault=false;e.state.ixFacilityPowered=true;status=D.Readout(e);eq(status,'ОЖИДАНИЕ ПОКАЗАНИЙ')
 e.state.ixDeconStatus='ЗОНЫ 1 / SCP 2 / ФЛОРА 0 / ОСТАНКИ 1 / ТОКСИНЫ 0';e.state.ixDeconAlarm=true
 local detail,hint,warning;status,detail,hint,warning=D.Readout(e);eq(status,'ОБНАРУЖЕНА БИОУГРОЗА');eq(detail,e.state.ixDeconStatus);eq(warning,true)
`);
suite('Decon world draw removes billboard but preserves bounded shower effect',`
 local e=equipment('decon_shower');e.state.ixFacilityPowered=true;e.state.ixDeconUser={valid=true,GetPos=function() return Vector() end}
 ix.Decon.Draw(e);eq(e.draws,1);eq(sprayLines,12)
 ix.CCTV={rendering=true};ix.Decon.Draw(e);eq(sprayLines,12);eq(e.draws,2)
 ix.CCTV.rendering=false;e.pos=Vector(600,0,0);ix.Decon.Draw(e);eq(sprayLines,12)
`);
suite('Decon contextual status uses native E and keeps occupied fixtures unavailable',`
 ix.Facility={Near=function() return true end}
 local e=equipment('decon_shower');e.state.ixFacilityPowered=true
 local spec=ix.Decon.Interaction(playerMock,e);eq(spec.native,true);eq(spec.options[1].label,'Начать цикл')
 e.state.ixDeconUser=playerMock;spec=ix.Decon.Interaction(playerMock,e);eq(spec.duringAction,true);eq(spec.options[1].label,'Остановить цикл')
 e.state.ixDeconUser={valid=true};spec=ix.Decon.Interaction(playerMock,e);eq(spec.options[1].disabled,true)
 e.state.ixFacilityFault=true;eq(ix.Decon.Interaction(playerMock,e),nil)
`);
finish();
