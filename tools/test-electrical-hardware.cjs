const {run,source,base,finish}=require('./restored-test-runner.cjs');
const client=source([...base,'tools/terminal-preview-fixture.lua','tools/fixtures/electrical-hardware.lua',...['sh_core','sh_repair','sh_engineering_games','sh_engineering'].map(v=>'ixhl2rp/plugins/facility_utilities/'+v+'.lua'),'ixhl2rp/plugins/foundation_network/cl_design.lua',...['cl_hardware','cl_ui','cl_devices','cl_repair','cl_engineering'].map(v=>'ixhl2rp/plugins/facility_utilities/'+v+'.lua')])+`
 function ScrW() return 1024 end;function ScrH() return 768 end
 local user=admin();function LocalPlayer() return user end
`;
run('Cabinet terminals preserve probe protocol and eliminated wire segments cannot submit answers',client+`
 local F=ix.Facility;local data={token=22,round=4,kind='probe',stage=3,noParts=true,title='Щит',expires=100,entity=1,state={count=6,budget=3,possible={true,true,false,false,true,true},probes={}}}
 F.OpenEngineering(data);local win=hardwarePreviewFrame;PreviewLayout(win)
 local point=function(n) return HardwareFind(win,'facilityProbePoint',n) end
 local before=#net.packets;point(5).DoClick();eq(#net.packets,before);point(5).DoClick();eq(#net.packets,before)
 point(5).DoClick();point(1).DoClick();eq(#net.packets,before+1)
 local packet=net.packets[#net.packets];eq(packet.name,'ixFacilityEngineeringInput');eq(packet.value,'probe');eq(packet.integers[1],1);eq(packet.integers[2],5)
 before=#net.packets;HardwareFind(win,'facilityProbeSegment',3).DoClick();eq(#net.packets,before)
 HardwareFind(win,'facilityProbeSegment',6).DoClick();packet=net.packets[#net.packets];eq(packet.value,'answer');eq(packet.integers[1],6)
`);
run('Pressure handwheels clamp at detents and send the same packed values as server game',client+`
 local F=ix.Facility;F.OpenEngineering({token=22,round=1,kind='pressure',stage=1,title='Генератор',expires=100,entity=1,state={lo=30,hi=40,reading=20,runs=6,valves={0,0,0},history={}}})
 local win=hardwarePreviewFrame;PreviewLayout(win)
 for i=1,3 do local valve=HardwareFind(win,'facilityValve',i);for n=1,10 do valve.DoRightClick() end;for n=1,i do valve.DoClick() end end
 local test
 -- Use painted button label to identify the actual production check control.
 local old=draw.SimpleText;draw.SimpleText=function(text,...) if text=='Проверить давление' then test=true end;return old(text,...) end
 local function click(p) if p.Paint and p.DoClick then test=false;p:Paint(700,p:GetTall());if test then p.DoClick();return true end end;for _,child in ipairs(p:GetChildren()) do if click(child) then return true end end end
 assert(click(win));local packet=net.packets[#net.packets];eq(packet.value,'run');eq(packet.integers[1],ix.repair.games.pressure.Pack({1,2,3}))
`);
run('Hardware close and Escape cancel engineering once through the real session cleanup',client+`
 local F=ix.Facility;local data={token=24,round=2,kind='probe',stage=1,title='Щит',expires=100,entity=1,state={count=4,budget=5,possible={true,true,true,true},probes={}}}
 for _,mode in ipairs({'button','escape'}) do
  F.OpenEngineering(data);local win=hardwarePreviewFrame;local removed=0
  function win:Remove() if not self.valid then return end;self.valid=false;removed=removed+1;if self.OnRemove then self:OnRemove() end end
  local before=#net.packets
  if mode=='button' then HardwareFind(win,'hardwareClose',true).DoClick() else win:OnKeyCodePressed(KEY_ESCAPE) end
  eq(removed,1);eq(#net.packets,before+1);eq(net.packets[#net.packets].value,'cancel')
 end
`);
run('Native cabinet click targets stay separate at narrow width; Cyrillic labels elide on codepoint boundaries',client+`
 function ScrW() return 480 end
 ix.Facility.OpenEngineering({token=1,round=1,kind='probe',stage=5,title=string.rep('Электрощит',20),expires=100,entity=1,state={count=8,budget=3,possible={true,true,true,true,true,true,true,true},probes={}}})
 local win=hardwarePreviewFrame;PreviewLayout(win);local last
 for i=0,8 do local p=HardwareFind(win,'facilityProbePoint',i);assert(p.x>=0 and p.x+p.w<=win.probeBoard.w);if last then assert(p.x>=last.x+last.w) end;last=p end
 local H=ix.Facility.Hardware;local text=H.Fit(string.rep('Сектор ',30),'FacilityText',140);assert(utf8.len(text));surface.SetFont('FacilityText');assert(surface.GetTextSize(text)<=140)
`);
run('Clinical device skin inherits through scroll panels and unknown skins remain usable',client+`
 local F=ix.Facility;local c=F.Hardware.skins.clinical;assert(c.text.r<c.bg.r)
 local frame=vgui.Create('DFrame');frame:SetSize(600,500);F.Hardware.Frame(frame,'unknown','Тест','');local panel=frame:Add('DPanel');local label=F.Label(panel,'Читаемый текст')
 assert(label.ink);eq(F.Hardware.Skin(panel),F.Hardware.skins.power);PreviewSVG(frame)
`);
run('Device snapshots no longer construct a modal or restore native panel backgrounds',client+`
 local F=ix.Facility;F.OpenDevice({device={entity=99,id=1,kind='generator',name='Резерв',fuel=300,canStart=true,hasFuel=true,links={}}})
 eq(F.window,nil);eq(hardwarePreviewFrame,nil);eq(F.deviceSnapshots[99].data.fuel,300)
`);
run('Utilities paint is disposable and does not leak to another terminal page',client+`
 local F=ix.Facility;local root=vgui.Create('DPanel');root:SetSize(1200,900);root.body=root
 local original=function() end;root.Paint=original
 F.RenderTerminal(root,{page='jobs',jobs={}});PreviewLayout(root);eq(root.Paint,original);eq(root.facilitySkin,nil)
 assert(#root:GetChildren()>0);root:Clear();eq(root.Paint,original);eq(#root:GetChildren(),0)
`);
const server=source([...base,...['sh_core','sh_repair','sv_store','sv_connections','sv_power'].map(v=>'ixhl2rp/plugins/facility_utilities/'+v+'.lua')]);
run('Numeric display metadata mirrors generator fuel and battery charge without replacing existing state strings',server+`
 local p=PLUGIN;local g=device('generator');g.fuel=237;g.running=true;p:SyncDevice(g)
 eq(g.entity:GetNW2Float('ixFacilityFuel'),237);eq(g.entity:GetNW2Bool('ixFacilityRunning'),true)
 assert(g.entity:GetNW2String('ixFacilityState'):find('3:57',1,true));eq(g.fuel,237)
 local b=device('battery');b.charge=3990;p:SyncDevice(b);eq(b.entity:GetNW2Float('ixFacilityCharge'),3990);eq(b.charge,3990)
`);
run('Generator inspection plate follows the model transform and unsupported models get no guessed plate',client+`
 local H=ix.Facility.Hardware;local ent=entity(99,'models/props_c17/TrapPropeller_Engine.mdl',Vector(10,20,30));ent.ang=Angle(0,0,0)
 local a=H.DevicePlateGeometry(ent,'generator');ent.pos=ent.pos+Vector(100,-40,20);local b=H.DevicePlateGeometry(ent,'generator')
 near(b.x-a.x,100);near(b.y-a.y,-40);near(b.z-a.z,20)
 ent.ang=Angle(0,90,0);local c=H.DevicePlateGeometry(ent,'generator');assert(c:DistToSqr(b)>.01)
 ent.model='models/unknown.mdl';eq(H.DevicePlateGeometry(ent,'generator'),nil)
`);
run('Requested mobile generator plate and cable socket follow its actual local geometry',client+`
 local F=ix.Facility;local H=F.Hardware;local ent=entity(99,'models/props_se/junk/mobile_generator.mdl',Vector(10,20,30));ent.ang=Angle()
 local plate,ang,scale=H.DevicePlateGeometry(ent,'generator');near(scale,6/320)
 local center=plate+ang:Forward()*160*scale+ang:Right()*95*scale
 near(center.x,17.3);near(center.y,19.5);near(center.z,47.42)
 local socket=F.GeneratorSocket(ent);near(socket.x,.42);near(socket.y,.77);near(socket.z,35.35)
 ent.ang=Angle(0,90,0);local rotated=F.GeneratorSocket(ent);assert(rotated:DistToSqr(socket)>1)
 near(rotated:Distance(ent:GetPos()),socket:Distance(ent:GetPos()))
`);
run('Legacy generator floor migration is idempotent and retains fuel, owner and exact cable endpoint',server+`
 local F=ix.Facility;local link={kind='device',id=7,point=Vector(2,3,4)}
 local d={kind='generator',pos=Vector(10,20,17.07115),ang=Angle(),fuel=233,portable=true,owner=42,links={link}}
 assert(F.MigrateGeneratorGeometry(d));near(d.pos.z,9.945116);eq(d.generatorGeometry,2)
 eq(d.fuel,233);eq(d.owner,42);eq(d.links[1],link);near(link.point.z,4);eq(d.portable,true)
 eq(F.MigrateGeneratorGeometry(d),false);near(d.pos.z,9.945116)
 local fresh=PLUGIN:DeviceRecord('generator',Vector(0,0,22),Angle());eq(F.MigrateGeneratorGeometry(fresh),false);near(fresh.pos.z,22)
 local tilted={kind='generator',pos=Vector(10,20,30),ang=Angle(0,0,90)};assert(F.MigrateGeneratorGeometry(tilted))
 near((tilted.pos-Vector(10,20,30)):Length(),17.07115-9.945116)
`);
finish();
