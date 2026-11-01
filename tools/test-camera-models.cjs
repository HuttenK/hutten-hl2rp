const {run,source,finish}=require('./restored-test-runner.cjs');
const base=source(['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/fixtures/tv.lua','helix/gamemode/core/libs/sh_propscreens.lua','tools/fixtures/cctv.lua','ixhl2rp/plugins/cctv/sh_state.lua','ixhl2rp/plugins/cctv/sh_surfaces.lua']);
const server=base+'\n'+source(['ixhl2rp/plugins/cctv/entities/entities/ix_cctv_device.lua','ixhl2rp/plugins/cctv/sv_devices.lua','ixhl2rp/plugins/cctv/sv_surfaces.lua','ixhl2rp/plugins/cctv/sv_network.lua']);
run('Requested CCTV body uses a fixed idle pose and the physical lens for capture and mount placement',server+`
 local C,P=ix.CCTV,PLUGIN;P:LoadData();local p=admin()
 eq(C.kinds.camera.model,'models/props_blackmesa/securitycamera.mdl')
 local tr={Hit=true,HitPos=Vector(80,0,64),HitNormal=Vector(-1,0,0)}
 local pos,ang=C.Placement(p,tr,'camera');local mount=LocalToWorld(C.cameraRig.wall,Angle(),pos,ang)
 vectorNear(mount,tr.HitPos+tr.HitNormal*.3)
 local d,e=makeDevice('camera',pos);e:SetAngles(ang)
 eq(e:GetModel(),C.cameraRig.model);eq(e.sequence,'idle');eq(e.cycle,0);eq(e.playbackRate,0)
 local lens,view=C.Lens(d);local expected,direction=LocalToWorld(Vector(18.58,0,7.46),Angle(25,0,0),pos,ang)
 vectorNear(lens,expected);vectorNear(view:Forward(),direction:Forward());eq(d.cameraRig,1)
`);
run('Legacy camera migration preserves feeds, names, monitor links and lens direction exactly once',server+`
 local C,P=ix.CCTV,PLUGIN
 for _,oldAngle in ipairs({Angle(),Angle(20,73,11),Angle(-60,-130,-20)}) do
  local origin=Vector(150,260,90);local oldLens=origin+oldAngle:Forward()*12
  stored.foundation_cctv_v1={nextID=9,devices={{id=3,kind='camera',name='North hall',on=false,fov=61,pos=origin,ang=oldAngle},
   {id=4,kind='terminal',name='Control',on=true,pos=Vector(),ang=Angle()},
   {id=5,kind='monitor',name='Display',on=true,terminal=4,camera=3,pos=Vector(),ang=Angle()}}}
  P:LoadData();local d=P.devices[3];eq(d.name,'North hall');eq(d.on,false);eq(d.fov,61);eq(P.devices[5].camera,3);eq(P.nextID,9)
  local lens,a=C.Lens(d);vectorNear(lens,oldLens);vectorNear(a:Forward(),oldAngle:Forward());vectorNear(a:Up(),oldAngle:Up())
  local migrated=d.entity:GetPos();P:SaveData();for _,row in ipairs(stored.foundation_cctv_v1.devices) do if row.id==3 then eq(row.cameraRig,1) end end
  P:LoadData();local lens2,a2=C.Lens(P.devices[3]);vectorNear(lens2,oldLens);vectorNear(a2:Forward(),oldAngle:Forward());vectorNear(P.devices[3].entity:GetPos(),migrated)
 end
`);
run('Previous default camera saves upgrade the mesh without moving the lens, light or linked feed',server+`
 local C,P=ix.CCTV,PLUGIN
 for _,revision in ipairs({0,1}) do
  local origin,angle=Vector(120,50,90),Angle(20,73,11)
  local lens,view=C.CameraLens(origin,angle,'models/props_glackmesa/securitycamera.mdl')
  stored.foundation_cctv_v1={devices={
   {id=3,kind='camera',name='Hall',model='models/props_glackmesa/securitycamera.mdl',cameraRig=revision==1 and 1 or nil,
    pos=origin,ang=angle,on=true,broken=true,fov=61},
   {id=4,kind='monitor',camera=3,pos=Vector(),ang=Angle()}}}
  P:LoadData();local d=P.devices[3]
  eq(d.entity:GetModel(),C.cameraRig.model);eq(d.name,'Hall');eq(d.broken,true);eq(d.fov,61);eq(P.devices[4].camera,3)
  vectorNear(d.entity:GetPos(),origin);local actual,a=C.Lens(d)
  vectorNear(actual,lens);vectorNear(a:Forward(),view:Forward());vectorNear(a:Up(),view:Up())
  local light=C.CameraIndicator(d);P:SaveData();P:LoadData();d=P.devices[3]
  eq(d.entity:GetModel(),C.cameraRig.model);vectorNear(d.entity:GetPos(),origin)
  vectorNear(C.Lens(d),lens);vectorNear(C.CameraIndicator(d),light)
 end
`);
run('Explicit custom saved cameras retain their model, placement and original optical convention',server+`
 util.IsValidModel=function(m) return m=='models/custom_camera.mdl' end
 stored.foundation_cctv_v1={devices={{id=3,kind='camera',name='Custom',model='models/custom_camera.mdl',pos=Vector(10,20,30),ang=Angle(5,30,2)}}}
 PLUGIN:LoadData();local d=PLUGIN.devices[3];eq(d.entity:GetModel(),'models/custom_camera.mdl');vectorNear(d.entity:GetPos(),Vector(10,20,30))
 local lens,ang=ix.CCTV.Lens(d);vectorNear(lens,d.entity:GetPos()+d.entity:GetAngles():Forward()*12)
 PLUGIN:SaveData();PLUGIN:LoadData();eq(PLUGIN.devices[3].entity:GetModel(),'models/custom_camera.mdl')
`);
run('Helmet mesh centers on the head and its local minus-Y lens faces the wearer view at varied angles',base+`\nix.bodycams={};\n`+source(['ixhl2rp/plugins/bodycams/sh_bodycams.lua'])+`
 local B=ix.bodycams;eq(B.model,'models/cod/bo1/interrogation_room/mtl_p_int_security_camera.mdl')
 for _,eye in ipairs({Angle(),Angle(40,72,8),Angle(-70,-170,-14)}) do
  local head=Vector(100,200,70);local pos,ang,lamp=B.MountTransform(head,eye)
  local center=LocalToWorld(B.mount.center*B.mount.scale,Angle(),pos,ang)
  vectorNear(center,head+eye:Right()*5+eye:Up()*3)
  local front=LocalToWorld(Vector(0,-1,0),Angle(),Vector(),ang)
  vectorNear(front,eye:Forward());assert(lamp:Distance(center)<3)
 end
`);
finish();
