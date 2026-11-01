const fs=require('fs'),path=require('path'),{normalize}=require('./glua.cjs');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const parser=require('luaparse');
const root=path.resolve(__dirname,'..');process.chdir(root);
const read=f=>fs.readFileSync(f,'utf8');
const wrapped=f=>`do local function load()\n${normalize(read(f))}\nend;load() end`;
const base=['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/fixtures/tv.lua','helix/gamemode/core/libs/sh_propscreens.lua','tools/fixtures/cctv.lua','tools/fixtures/bodycams.lua','ixhl2rp/plugins/cctv/sh_state.lua','ixhl2rp/plugins/cctv/sh_surfaces.lua','ixhl2rp/plugins/bodycams/sh_bodycams.lua'];
const server=[...base,'ixhl2rp/plugins/cctv/entities/entities/ix_cctv_device.lua','ixhl2rp/plugins/cctv/sv_devices.lua','ixhl2rp/plugins/cctv/sv_surfaces.lua','ixhl2rp/plugins/cctv/sv_network.lua'];
const bodyServer=`do local original=PLUGIN;PLUGIN=bodyPlugin;${wrapped('ixhl2rp/plugins/bodycams/sv_bodycams.lua')};PLUGIN=original end\nix.bodycams.RegisterHelmets();PLUGIN:LoadData();PLUGIN:PostLoadData()`;
const runtime=[...fs.readdirSync('ixhl2rp/plugins/bodycams').filter(f=>f.endsWith('.lua')).map(f=>'ixhl2rp/plugins/bodycams/'+f),'ixhl2rp/plugins/bodycams/items/helmet_bodycam.lua',...['sh_state','sv_devices','sv_network','cl_render','cl_controls','cl_network'].map(f=>'ixhl2rp/plugins/cctv/'+f+'.lua')];
for(const f of runtime)parser.parse(normalize(read(f)),{luaVersion:'5.2'});
let passed=0;
function suite(name,files,code){
 const source=read('tools/fixture.lua')+'\n'+files.map(wrapped).join('\n')+'\n'+code;
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 const status=lauxlib.luaL_dostring(L,to_luastring(source));
 if(status!==lua.LUA_OK)throw Error(name+': '+to_jsstring(lua.lua_tostring(L,-1)));
 passed++;console.log('PASS '+name);
}
function test(name,code){suite(name,server,bodyServer+'\n'+code)}
test('Helmet metadata, registered item actions/data and attach consume exactly one physical camera',`
 local B=ix.bodycams;local p=wearer();local h=giveHelmet(p)
 assert(B.Compatible(h));assert(B.Compatible(ix.Item.stored.custom_helmet));eq(B.Compatible(ix.Item.stored.baseball_cap),false)
 assert(h.vars.helmetCamera and h.vars.helmetCameraOn);assert(h.functions.bodycamOn and #h.functions_id==4)
 local item=ix.Item:Instance('helmet_bodycam');p:AddItem(item);assert(B.Change(p,h,'attach',item));eq(item.removed,true)
 eq(B.Attached(h),true);eq(B.Enabled(h),false);eq(p:GetNW2Bool('ixHelmetCameraOn'),false)
 eq(B.Change(p,h,'attach'),false);tick();eq(B.Change(p,h,'attach'),false)
 eq(table.Count(ix.Item.instances),1);eq(table.Count(PLUGIN.devices),1)
 local data=table.Copy(h.data);eq(data.helmetCamera,true);eq(data.helmetCameraOn,false)
`);
test('Attach validates possession/type/living state and failure preserves camera and helmet',`
 local B=ix.bodycams;local p=wearer();local thief=wearer();local h=giveHelmet(p)
 local camera=ix.Item:Instance('helmet_bodycam');p:AddItem(camera)
 eq(B.Change(thief,h,'attach',camera),false);eq(camera.removed,nil)
 p.restricted=true;eq(B.Change(p,h,'attach',camera),false);p.restricted=false
 camera.failRemove=true;tick();eq(B.Change(p,h,'attach',camera),false);eq(B.Attached(h),false)
 camera.failRemove=false;p.dead=true;tick();eq(B.Change(p,h,'attach',camera),false);p.dead=false
 local cap=giveHelmet(p,'baseball_cap');tick();eq(B.Change(p,cap,'attach',camera),false);eq(camera.removed,nil)
`);
test('Detach rollback handles full inventory/creation failure and duplicate actions without duplication',`
 local B=ix.bodycams;local p=wearer();local h=giveHelmet(p);local id=attachCamera(p,h,true)
 local monitor=makeDevice('monitor');monitor.camera=id
 p.full=true;tick();eq(B.Change(p,h,'detach'),false);eq(B.Attached(h),true);eq(table.Count(ix.Item.instances),1);assert(PLUGIN.devices[id])
 p.full=false;ix.Item.failInstance=true;tick();eq(B.Change(p,h,'detach'),false);eq(B.Enabled(h),true)
 ix.Item.failInstance=false;tick();assert(B.Change(p,h,'detach'));eq(B.Attached(h),false);eq(B.Enabled(h),false)
 eq(table.Count(ix.Item.instances),2);eq(PLUGIN.devices[id],nil);eq(monitor.camera,0);eq(p:GetNW2Int('ixHelmetCamera'),0)
 eq(B.Change(p,h,'detach'),false);tick();eq(B.Change(p,h,'detach'),false);eq(table.Count(ix.Item.instances),2)
`);
test('Toggle retains helmet-owned state and monitor assignment, with no powered feed when off or unwearing',`
 local B,C=ix.bodycams,ix.CCTV;local p=wearer();local h=giveHelmet(p);local id=attachCamera(p,h,true)
 local d=PLUGIN.devices[id];local mon=makeDevice('monitor');mon.camera=id
 assert(C.Powered(d));tick();assert(B.Change(p,h,'off'));eq(C.Powered(d),false);eq(mon.camera,id);eq(C.Lens(d),nil)
 tick();assert(B.Change(p,h,'toggle'));assert(C.Powered(d));eq(B.records[p],id)
 p.head=nil;h.inventory_type='main';eq(C.Powered(d),false);bodyPlugin:OnItemUnequipped(p,h)
 eq(PLUGIN.devices[id],nil);eq(mon.camera,0);eq(B.Enabled(h),true)
 h.inventory_type='head';p.head=h.id;B.Refresh(p);assert(B.records[p]~=id);assert(C.Powered(PLUGIN.devices[B.records[p]]))
`);
test('Trade/drop/character changes end old feed and keep attachment with helmet rather than wearer',`
 local B=ix.bodycams;local p=wearer('First');local other=wearer('Second');local h=giveHelmet(p);local id=attachCamera(p,h,true)
 p.items[h.id]=nil;p.head=nil;bodyPlugin:InventoryItemRemoved(nil,h);eq(PLUGIN.devices[id],nil)
 other:AddItem(h);h.inventory_type='head';other.head=h.id;B.Refresh(other);local nextID=B.records[other]
 assert(nextID and nextID~=id);eq(PLUGIN.devices[nextID].entity,other);assert(PLUGIN.devices[nextID].name:find('Second'))
 h.entity=entity(900,'model');eq(ix.CCTV.Powered(PLUGIN.devices[nextID]),false);B.Refresh(other);eq(B.records[other],nil)
 h.entity=nil;B.Refresh(other);assert(B.records[other]);bodyPlugin:PrePlayerLoadedCharacter(other);eq(B.records[other],nil)
 B.Refresh(other);eq(B.records[other],nil);other.unloaded=true;bodyPlugin:PlayerLoadedCharacter(other);eq(B.records[other],nil)
 other.unloaded=false;B.Refresh(other);assert(B.records[other]);other.noCharacter=true;B.Refresh(other);eq(B.records[other],nil)
`);
test('Dead, ragdolled, knocked, critical, hidden and noclip spectators cannot supply remote footage',`
 local B,C=ix.bodycams,ix.CCTV;local p=wearer();local h=giveHelmet(p);attachCamera(p,h,true)
 local function invalidate(change,reset)
  B.Refresh(p);local d=PLUGIN.devices[B.records[p]];assert(d);change();eq(C.Powered(d),false);eq(C.Lens(d),nil);B.Refresh(p);eq(B.records[p],nil);reset()
 end
 invalidate(function() p.dead=true end,function() p.dead=false end)
 invalidate(function() p.critical=true end,function() p.critical=false end)
 invalidate(function() p.vars.knocked=true end,function() p.vars.knocked=false end)
 invalidate(function() p.vars.ragdoll=123 end,function() p.vars.ragdoll=0 end)
 invalidate(function() p.hidden=true end,function() p.hidden=false end)
 invalidate(function() p.move=MOVETYPE_NOCLIP end,function() p.move=MOVETYPE_WALK end)
 invalidate(function() p.move=MOVETYPE_OBSERVER end,function() p.move=MOVETYPE_WALK end)
 B.Refresh(p);bodyPlugin:OnCharacterFallover(p,{valid=true},true);eq(B.records[p],nil)
 B.Refresh(p);bodyPlugin:PlayerDisconnected(p);eq(B.records[p],nil)
`);
test('Dynamic rows cannot mutate/remove wearers or persist as static map cameras',`
 local B=ix.bodycams;local p=wearer();local h=giveHelmet(p);local id=attachCamera(p,h,true)
 local mon=makeDevice('monitor');mon.camera=id
 eq(PLUGIN:Action(p,'remove',{id=id}),false)
 eq(PLUGIN:Action(p,'configure',{id=id,name='x',on=true,ang={p=20,y=20,r=20},fov=80}),false)
 eq(PLUGIN:Action(p,'surfacePreset',{id=id,config={x=0,y=0,z=0,p=0,yaw=0,r=0,w=20,h=20}}),false)
 p.trace={Hit=true,HitPos=Vector(45,0,64),HitNormal=Vector(-1,0,0),Entity=entity(800,'model',Vector(50,0,64))}
 eq(PLUGIN:Action(p,'placeSurface',{id=id}),false)
 PLUGIN:SaveData();eq(#stored.foundation_cctv_v1.devices,1);eq(stored.foundation_cctv_v1.devices[1].camera,0)
 eq(mon.camera,id);eq(stored.foundation_cctv_v1.devices[1].bodycam,false)
 PLUGIN:OnUnload();eq(p.valid,true)
`);
test('Bodycam subscriptions use the ordinary monitor authorization, shared feed cap and PVS expiry',`
 local B,C=ix.bodycams,ix.CCTV;local source=wearer();source.pos=Vector(4000,0,64);local h=giveHelmet(source);local id=attachCamera(source,h,true)
 local viewer=wearer();viewer.admin=false;viewer.pos=Vector(0,0,64)
 local monitor=makeDevice('monitor',Vector(40,0,64));monitor.camera=id
 -- Client dormancy must not revoke the server-side grant needed to bring the
 -- remote wearer into PVS in the first place.
 source.dormant=true;assert(B.Available(source))
 local feeds,grants=PLUGIN:ResolveWatch(viewer,{preview=id,monitors={monitor.id}})
 eq(#feeds,1);eq(feeds[1].bodycam,true);eq(feeds[1].ownerIndex,source:EntIndex())
 eq(#PLUGIN:ResolveWatch(viewer,{preview=id,monitors={}}),0)
 PLUGIN.watchers[viewer]={grants=grants,expires=clock+1.5};PLUGIN:SetupPlayerVisibility(viewer);eq(#origins,1)
 util.TraceLine=function() return {Hit=true} end;PLUGIN:SetupPlayerVisibility(viewer);eq(#origins,1)
 util.TraceLine=function() return {Hit=false} end;tick();B.Change(source,h,'off');PLUGIN:SetupPlayerVisibility(viewer);eq(#origins,1)
 tick();B.Change(source,h,'on');clock=clock+2;PLUGIN:SetupPlayerVisibility(viewer);eq(#origins,1)
`);
test('Wearable power ignores blackout, destination monitors require power, lens moves and never traces through wall',`
 local B,C=ix.bodycams,ix.CCTV;local p=wearer();local h=giveHelmet(p);local id=attachCamera(p,h,true);local d=PLUGIN.devices[id]
 ix.plugin.list.blackout={IsPosBlackedOut=function() return true end}
 assert(C.Powered(d));local mon=makeDevice('monitor');eq(C.Powered(mon),false)
 local pos,ang=C.Lens(d);p.eyeAngle=Angle(15,90,0)
 local unchangedPos,unchangedAng=C.Lens(d);vectorNear(pos,unchangedPos);near(unchangedAng.y,ang.y)
 p.pos=Vector(100,200,64);p.headAngle=Angle(10,90,8);local nextPos,nextAng=C.Lens(d)
 assert(pos:DistToSqr(nextPos)>100);near(nextAng.y,90)
 local hit=Vector(101,200,64);util.TraceLine=function() return {Hit=true,HitPos=hit} end
 vectorNear(C.Lens(d),hit-p.headAngle:Forward()*2)
 util.TraceLine=function() return {StartSolid=true} end;eq(C.Lens(d),nil)
`);
test('Polling recovers CCTV reload safely without deleting static row using a previous dynamic ID',`
 local B=ix.bodycams;local p=wearer();local h=giveHelmet(p);local id=attachCamera(p,h,true)
 local old=PLUGIN.devices[id];PLUGIN.devices[id]={id=id,kind='monitor',entity=entity(999,'model')};local static=PLUGIN.devices[id]
 B.Refresh(p);eq(PLUGIN.devices[id],static);assert(B.records[p]~=id);eq(old.entity.valid,true)
 local active=B.records[p];allPlayers={p};p.head=nil;clock=clock+1;bodyPlugin:Think();eq(PLUGIN.devices[active],nil)
`);
test('Head-frame fallback follows bone angles, rejects missing or stale bones and never uses aim',`
 local B=ix.bodycams;local p=wearer()
 p.EyeAngles=function() error('Aim is not a head attachment') end
 p.GetShootPos=function() error('FPV origin is not the head') end
 p.LookupAttachment=function() return 0 end
 local matrix=Matrix();matrix:SetTranslation(p:GetPos()+Vector(0,0,64));matrix:SetAngles(Angle(12,70,9))
 function matrix:GetAngles() return Angle(12,70,9) end
 p.GetBoneMatrix=function() return matrix end
 local pos,ang=B.HeadFrame(p);vectorNear(pos,matrix:GetTranslation());near(ang.y,70);near(ang.r,9)
 matrix:SetTranslation(Vector(9000,0,0));eq(B.HeadFrame(p),nil)
 p.GetBoneMatrix=function() end;eq(B.HeadFrame(p),nil)
`);
const client=[...base,'tools/fixtures/tv-client.lua','tools/fixtures/tv-controls.lua','tools/fixtures/cctv-render.lua','ixhl2rp/plugins/cctv/cl_network.lua','ixhl2rp/plugins/cctv/cl_render.lua','ixhl2rp/plugins/cctv/cl_controls.lua','ixhl2rp/plugins/cctv/cl_terminal.lua','ixhl2rp/plugins/cctv/cl_placement.lua','ixhl2rp/plugins/cctv/cl_surfaces.lua'];
suite('Existing terminal lists helmet feeds, switches the same monitors and displays off as no signal',client,`
 SERVER=false;CLIENT=true
 local P=PLUGIN;local p=wearer('Operator');p:SetNW2Int('ixHelmetCamera',77);p:SetNW2Bool('ixHelmetCameraOn',true)
 P.devices[77]={id=77,kind='camera',bodycam=true,name='Helmet / Operator',on=true,entityIndex=p:EntIndex()}
 client.pos=Vector(80,0,64)
 local term=clientTerminal(100,Vector(20,0,64));local monitor=clientMonitor(120,Vector(40,0,64),77);monitor.terminal=100
 P:OpenTerminalUI(100)
 local layout=P:TerminalLayout(100);eq(#layout.cameras,1);eq(layout.cameras[1].bodycam,true)
 local bx,by
 for _,row in ipairs(layout) do if row.kind=='camera' and row.value==77 then bx,by=row.x+8,row.y+8 end end
 assert(bx and by);local button=P:TerminalHit(100,bx,by);eq(button.value,77);eq(button.detail,'В ЭФИРЕ')
 P.Request=function(_,action,data) lastAction=action;lastData=data end
 P:ActivateTerminalButton(100,button);eq(lastAction,'switch');eq(lastData.camera,77);eq(lastData.terminal,100)
 p:SetNW2Bool('ixHelmetCameraOn',false);eq(P:TerminalHit(100,bx,by).detail,'НЕТ СИГНАЛА')
`);
suite('Client captures interpolate granted wearer only, suppress that player only, and restore on failure',client,`
 SERVER=false;CLIENT=true
 local P,C,B=PLUGIN,ix.CCTV,ix.bodycams;local p=wearer();p:SetNW2Int('ixHelmetCamera',77);p:SetNW2Bool('ixHelmetCameraOn',true)
 P.devices[77]={id=77,kind='camera',bodycam=true,on=true,entityIndex=p:EntIndex()}
 local feed={id=77,bodycam=true,ownerIndex=p:EntIndex(),pos=Vector(9000,0,0),ang=Angle()};local slot={target={}}
 local original=render.RenderView
 render.RenderView=function(v)
  vectorNear(v.origin,B.Lens(p));eq(hooks.PrePlayerDraw.ixCCTVHelmetWearer(p),true)
  eq(hooks.PrePlayerDraw.ixCCTVHelmetWearer(client),nil);original(v)
 end
 P:CaptureFeed(feed,slot);assert(slot.updated);eq(C.captureOwner,nil);eq(hooks.PrePlayerDraw.ixCCTVHelmetWearer(p),nil)
 failRender=true;P:CaptureFeed(feed,slot);eq(slot.updated,nil);eq(C.captureOwner,nil);eq(C.rendering,false);eq(depth,0)
 failRender=false;p:SetNW2Bool('ixHelmetCameraOn',false);local count=renderCalls;P:CaptureFeed(feed,slot);eq(renderCalls,count);eq(slot.updated,nil)
 P:OnUnload();eq(hooks.PrePlayerDraw.ixCCTVHelmetWearer,nil)
`);
suite('Dormant bodycam loses its old image immediately and resumes only after a fresh capture',client,`
 SERVER=false;CLIENT=true
 local P,C,B=PLUGIN,ix.CCTV,ix.bodycams;local p=wearer();p:SetNW2Int('ixHelmetCamera',77);p:SetNW2Bool('ixHelmetCameraOn',true)
 P.devices[77]={id=77,kind='camera',bodycam=true,on=true,entityIndex=p:EntIndex()}
 local feed={id=77,bodycam=true,ownerIndex=p:EntIndex(),pos=Vector(9000,0,0),ang=Angle(),received=clock}
 local slot={target={},camera=77};C.slots[1]=slot;P.feeds[77]=feed
 local images=0;surface.DrawTexturedRectUV=function() images=images+1 end
 draw.SimpleText=function(text,font) if font=='ixCCTVTitle' then message=text end end
 P:CaptureFeed(feed,slot);P:PaintFeed(77,320,180);eq(images,1);eq(renderCalls,1)
 p.dormant=true;eq(B.Available(p),false)
 -- Reject even if the main monitor paints before the next scheduled capture.
 P:PaintFeed(77,320,180);eq(images,1);eq(slot.updated,nil);eq(message,'НЕТ СИГНАЛА')
 clock=clock+.2;P:CaptureFeed(feed,slot);eq(renderCalls,1);eq(slot.updated,nil);eq(slot.lastTry,clock)
 p.dormant=false;P:PaintFeed(77,320,180);eq(images,1)
 P:CaptureFeed(feed,slot);P:PaintFeed(77,320,180);eq(renderCalls,2);eq(images,2);eq(slot.owner,p)
 p:SetNW2Bool('ixHelmetCameraOn',false);P:PaintFeed(77,320,180);eq(images,2);eq(slot.updated,nil)
`);
suite('Solid or invalid wearable lens never falls back to server coordinates or displays its prior frame',client,`
 SERVER=false;CLIENT=true
 local P,C,B=PLUGIN,ix.CCTV,ix.bodycams;local p=wearer();p:SetNW2Int('ixHelmetCamera',77);p:SetNW2Bool('ixHelmetCameraOn',true)
 P.devices[77]={id=77,kind='camera',bodycam=true,on=true,entityIndex=p:EntIndex()}
 local feed={id=77,bodycam=true,ownerIndex=p:EntIndex(),pos=Vector(9000,0,0),ang=Angle(),received=clock}
 local slot={target={},camera=77};C.slots[1]=slot;P.feeds[77]=feed
 local images=0;surface.DrawTexturedRectUV=function() images=images+1 end
 draw.SimpleText=function(text,font) if font=='ixCCTVTitle' then message=text end end
 P:CaptureFeed(feed,slot);P:PaintFeed(77,320,180);eq(images,1);eq(renderCalls,1)
 local trace,Lens=util.TraceLine,B.Lens
 util.TraceLine=function() return {StartSolid=true} end
 clock=clock+.2;P:CaptureFeed(feed,slot);eq(renderCalls,1);eq(slot.updated,nil);eq(slot.lastTry,clock)
 P:PaintFeed(77,320,180);eq(images,1);eq(message,'НЕТ СИГНАЛА')
 util.TraceLine=trace
 for _,invalid in ipairs({function() end,function() return Vector(),nil end,function() return Vector(0/0,0,0),Angle() end}) do
  B.Lens=invalid;P:CaptureFeed(feed,slot);eq(renderCalls,1);eq(slot.updated,nil)
 end
 B.Lens=Lens;P:PaintFeed(77,320,180);eq(images,1)
 P:CaptureFeed(feed,slot);P:PaintFeed(77,320,180);eq(images,2);eq(renderCalls,2)
`);
suite('Wearable grant, device owner and current network camera identity must agree even after entity index reuse',client,`
 SERVER=false;CLIENT=true
 local P,C=PLUGIN,ix.CCTV;local p=wearer();local other=wearer()
 p:SetNW2Int('ixHelmetCamera',77);p:SetNW2Bool('ixHelmetCameraOn',true)
 other:SetNW2Int('ixHelmetCamera',88);other:SetNW2Bool('ixHelmetCameraOn',true)
 local d={id=77,kind='camera',bodycam=true,on=true,entityIndex=p:EntIndex()};P.devices[77]=d
 local feed={id=77,bodycam=true,ownerIndex=p:EntIndex(),pos=Vector(9000,0,0),ang=Angle(),received=clock}
 local slot={target={},camera=77};C.slots[1]=slot;P.feeds[77]=feed
 local images=0;surface.DrawTexturedRectUV=function() images=images+1 end
 local function rejected(change,restore)
  P:CaptureFeed(feed,slot);assert(slot.updated);local before=renderCalls
  change();P:PaintFeed(77,320,180);eq(slot.updated,nil);local painted=images
  clock=clock+.15;P:CaptureFeed(feed,slot);eq(renderCalls,before);eq(slot.updated,nil);eq(slot.lastTry,clock)
  P:PaintFeed(77,320,180);eq(images,painted);restore()
 end
 rejected(function() feed.ownerIndex=other:EntIndex() end,function() feed.ownerIndex=p:EntIndex() end)
 rejected(function() d.entityIndex=other:EntIndex() end,function() d.entityIndex=p:EntIndex() end)
 rejected(function() p.valid=false end,function() p.valid=true end)
 rejected(function() d.id=88 end,function() d.id=77 end)
 rejected(function() d.bodycam=false end,function() d.bodycam=true end)
 rejected(function() feed.bodycam=false end,function() feed.bodycam=true end)
 rejected(function() p:SetNW2Int('ixHelmetCamera',88) end,function() p:SetNW2Int('ixHelmetCamera',77) end)
 -- The old index is now a different entity. An old device pointer must not
 -- authorize it; without the pointer, its new camera ID must still reject it.
 d.entity=p
 rejected(function() entities[p:EntIndex()]=other end,function() entities[p:EntIndex()]=p end)
 d.entity=nil;local oldID=other.id;other.id=p.id
 rejected(function() entities[p.id]=other end,function() entities[p.id]=p end)
 other.id=oldID
`);
suite('Visible head mount follows bone position, indicates on/off, reuses model and cleans up',client,`
 SERVER=false;CLIENT=true
 local original=PLUGIN;PLUGIN=bodyPlugin
 ${wrapped('ixhl2rp/plugins/bodycams/cl_bodycams.lua')}
 PLUGIN=original
 local p=wearer();p:SetNW2Int('ixHelmetCamera',77);p:SetNW2Bool('ixHelmetCameraOn',true)
 function p:LookupBone(name) eq(name,'ValveBiped.Bip01_Head1');return self.missingBone and nil or 6 end
 local matrix=Matrix();matrix:SetTranslation(Vector(200,100,65))
 p.pos=Vector(200,100,0);p.headAngle=Angle(12,35,15);p.eyeAngle=Angle(40,90,0)
 function p:GetBoneMatrix() if not self.missingMatrix then return matrix end end
 local created=0;local baseModel=ClientsideModel
 ClientsideModel=function(path)
  created=created+1;local m=baseModel(path)
  function m:SetModelScale(value) self.scale=value end
  function m:SetupBones() end
  function m:DrawModel() self.draws=(self.draws or 0)+1 end
  return m
 end
 render.SetMaterial=function() end;render.DrawSprite=function(_,_,_,color) lastLED=color end
 bodyPlugin:PostPlayerDraw(p);local model=ix.bodycams.models[p];assert(IsValid(model));near(model.scale,.28);eq(created,1);eq(lastLED[1],238)
 eq(model:GetModel(),'models/cod/bo1/interrogation_room/mtl_p_int_security_camera.mdl')
 local mountedCenter=LocalToWorld(ix.bodycams.mount.center*model.scale,Angle(),model:GetPos(),model:GetAngles())
 vectorNear(mountedCenter,matrix:GetTranslation()+p.headAngle:Right()*5+p.headAngle:Up()*3)
 p:SetNW2Bool('ixHelmetCameraOn',false);bodyPlugin:PostPlayerDraw(p);eq(created,1);eq(lastLED[1],70)
 ix.CCTV.captureOwner=p;bodyPlugin:PostPlayerDraw(p);eq(model.draws,2);ix.CCTV.captureOwner=nil
 p:SetNW2Int('ixHelmetCamera',0);clock=clock+2;bodyPlugin:Think();eq(IsValid(model),false);eq(ix.bodycams.models[p],nil)
 p:SetNW2Int('ixHelmetCamera',77);p.missingMatrix=true;bodyPlugin:PostPlayerDraw(p);eq(created,1)
`);
console.log(`${passed} bodycam suites passed; ${runtime.length} Lua files parse. Engine visuals require in-game validation.`);
