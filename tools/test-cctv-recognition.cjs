const fs=require('fs'),path=require('path'),{normalize}=require('./glua.cjs');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const parser=require('luaparse');process.chdir(path.resolve(__dirname,'..'));
const read=f=>fs.readFileSync(f,'utf8');
const wrapped=f=>`do local function load()\n${normalize(read(f))}\nend;load() end`;
const base=['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/fixtures/tv.lua','helix/gamemode/core/libs/sh_propscreens.lua','tools/fixtures/cctv.lua','tools/fixtures/cctv-recognition.lua','helix/gamemode/game/inventory/sh_player.lua','ixhl2rp/schema/meta/sh_player.lua','ixhl2rp/plugins/cctv/sh_state.lua','ixhl2rp/plugins/cctv/sh_surfaces.lua','ixhl2rp/plugins/cctv/sh_recognition.lua'];
const server=[...base,'ixhl2rp/plugins/cctv/entities/entities/ix_cctv_device.lua','ixhl2rp/plugins/cctv/sv_devices.lua','ixhl2rp/plugins/cctv/sv_surfaces.lua','ixhl2rp/plugins/cctv/sv_recognition.lua','ixhl2rp/plugins/cctv/sv_network.lua'];
const client=[...base,'tools/fixtures/tv-client.lua','tools/fixtures/tv-controls.lua','tools/fixtures/cctv-render.lua','ixhl2rp/plugins/cctv/cl_network.lua','ixhl2rp/plugins/cctv/cl_render.lua','ixhl2rp/plugins/cctv/cl_recognition.lua'];
const runtime=['sh_plugin','sh_recognition','sv_recognition','cl_recognition','sv_network','cl_network','cl_render'].map(f=>'ixhl2rp/plugins/cctv/'+f+'.lua');
for(const f of runtime) parser.parse(normalize(read(f)),{luaVersion:'5.2'});
let passed=0;
function suite(name,files,code){
 const source=read('tools/fixture.lua')+'\n'+files.map(wrapped).join('\n')+'\n'+code;
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 const status=lauxlib.luaL_dostring(L,to_luastring(source));
 if(status!==lua.LUA_OK)throw Error(name+': '+to_jsstring(lua.lua_tostring(L,-1)));
 passed++;console.log('PASS '+name);
}
suite('Recognition handles numeric ragdoll IDs and recovery without passing numbers to engine IsValid',server,`
 local valid=IsValid
 function IsValid(object)
  if isnumber(object) then error('attempt to index local object (a number value)') end
  return valid(object)
 end
 eq(pcall(IsValid,123),false)
 for _,server in ipairs({true,false}) do
  SERVER=server;CLIENT=not server
  local p=person()
  for _,state in ipairs({{},{value=0},{value=-1},{value=123},{value={valid=true}},{value={valid=false}},{value=false}}) do
   p.vars.ragdoll=state.value
   local blocked=state.value==123 or (type(state.value)=='table' and state.value.valid==true)
   eq(ix.CCTV.Recognizable(p),not blocked)
  end
  p.vars.ragdoll=123;eq(ix.CCTV.Recognizable(p),false)
  p.vars.ragdoll=0;eq(ix.CCTV.Recognizable(p),true)
  p.vars.ragdoll=nil;eq(ix.CCTV.Recognizable(p),true)
 end
`);
suite('Equipped native cid slot is authoritative; borrowed card text never falls back to true character or PDA identity',server,`
 local C=ix.CCTV;local p=person('Secret real name');local card=giveCard(p,'Visible card name','military',3)
 local identity=C.EquippedCardIdentity(p);eq(identity.name,'Visible card name');eq(identity.department,'Военный отдел');eq(identity.level,3)
 eq(identity.cid,nil);eq(identity.number,nil);eq(identity.card,nil)
 p.cardSlot=nil;eq(C.EquippedCardIdentity(p),nil) -- card still exists in bag/instances
 p.cardSlot=card.id;card.data.revoked=true;eq(C.EquippedCardIdentity(p),nil);card.data.revoked=false
 for _,field in ipairs({'name','cid','number'}) do local old=card.data[field];card.data[field]='';eq(C.EquippedCardIdentity(p),nil);card.data[field]=old end
 card.data.cid='000-00';eq(C.EquippedCardIdentity(p),nil);card.data.cid='123-45'
 card.isKeycard=false;eq(C.EquippedCardIdentity(p),nil);card.isKeycard=true
 card.clearanceLevel=0/0;eq(C.EquippedCardIdentity(p),nil);card.clearanceLevel=2
 card.department='other';eq(C.EquippedCardIdentity(p),nil)
 p.inventories=nil;eq(C.EquippedCardIdentity(p),nil);eq(p:GetIDCard(),nil)
`);
suite('Recognition labels enforce valid UTF-8 and bounded character counts without splitting Cyrillic',server,`
 local C=ix.CCTV;local value=string.rep('Я',60);local clean=C.IdentityText(value,48)
 eq(utf8.len(clean),48);eq(#clean,96);eq(C.IdentityText('  Имя  ',48),'Имя')
 eq(C.IdentityText('evil\\nname',48),nil);eq(C.IdentityText(string.char(255),48),nil)
 eq(C.IdentityText(string.rep('a',1025),48),nil);eq(C.IdentityText(123,48),nil)
`);
suite('Watch packets identify only authorized demanded feeds, send privately and cap eight nearest people',server,`
 local P,C=PLUGIN,ix.CCTV;local viewer,camera,monitor=makeRecognitionView();allPlayers={}
 for i=1,12 do local p=person(nil,Vector(150+i*20,0,0));giveCard(p,'Card '..i);allPlayers[#allPlayers+1]=p end
 local outsider=person(nil,Vector(5000,0,0));outsider.admin=false
 eq(#P:ResolveWatch(outsider,{preview=camera.id,monitors={monitor.id}}),0);eq(camera.recognitionCache,nil)
 net.ReadString=function() return util.TableToJSON({monitors={monitor.id}}) end
 net.handlers.ixCCTVWatch(200,viewer);local packet=net.packets[#net.packets];eq(packet.target,viewer);eq(packet.name,'ixCCTVFeeds')
 local feeds=util.JSONToTable(packet.value);eq(#feeds,1);eq(#feeds[1].recognition.people,8)
 eq(feeds[1].recognition.people[1].name,'Card 1');eq(feeds[1].recognition.people[8].name,'Card 8')
 for _,v in ipairs(net.packets) do if v.name=='ixCCTVDevice' then assert(not util.JSONToTable(v.value).recognition) end end
 monitor.on=false;eq(#P:ResolveWatch(viewer,{monitors={monitor.id}}),0)
`);
suite('Server vision rejects occlusion, offscreen and distant heads, backsides, spectators, invalid players and camera wearer',server,`
 local P,C=PLUGIN,ix.CCTV;local viewer,camera,monitor=makeRecognitionView();local p=person();giveCard(p)
 local origin,ang=C.Lens(camera);assert(C.VisibleFace(p,origin,ang,75,camera.entity))
 util.TraceLine=function() return {Hit=true,Entity={valid=true}} end;eq(C.VisibleFace(p,origin,ang,75,camera.entity),nil)
 util.TraceLine=function() return {Hit=true,Entity=p,StartSolid=true} end;eq(C.VisibleFace(p,origin,ang,75,camera.entity),nil)
 util.TraceLine=function() return {Hit=true,Entity=p} end;assert(C.VisibleFace(p,origin,ang,75,camera.entity))
 util.TraceLine=function() return {Hit=false} end
 for _,pos in ipairs({Vector(-200,0,0),Vector(2500,0,0),Vector(200,1000,0),Vector(200,0,900)}) do p.pos=pos;eq(C.VisibleFace(p,origin,ang,75,camera.entity),nil) end
 p.pos=Vector(200,0,0);p.eyeAngle=Angle();eq(C.VisibleFace(p,origin,ang,75,camera.entity),nil);p.eyeAngle=Angle(0,180,0)
 for _,key in ipairs({'dead','hidden','noCharacter'}) do p[key]=true;eq(C.VisibleFace(p,origin,ang,75,camera.entity),nil);p[key]=false end
 p.move=MOVETYPE_NOCLIP;eq(C.VisibleFace(p,origin,ang,75,camera.entity),nil);p.move=MOVETYPE_WALK
 p.vars.ragdoll=123;eq(C.VisibleFace(p,origin,ang,75,camera.entity),nil);p.vars.ragdoll=nil
 eq(C.VisibleFace(p,origin,ang,75,p),nil)
 p.badBone=true;assert(C.VisibleFace(p,origin,ang,75,camera.entity));p.noHead=true;assert(C.VisibleFace(p,origin,ang,75,camera.entity))
`);
suite('Recognition cache shares broad scans but revalidates current lens, walls, player lifetime and cards on every grant',server,`
 local P,C=PLUGIN,ix.CCTV;local viewer,camera,monitor=makeRecognitionView();local p=person();local card=giveCard(p);allPlayers={p}
 local scans=0;player.GetAll=function() scans=scans+1;return allPlayers end
 local first=P:ResolveWatch(viewer,{monitors={monitor.id}});eq(scans,1);eq(first[1].recognition.people[1].name,'Borrowed identity')
 clock=clock+.1;local second=P:ResolveWatch(viewer,{monitors={monitor.id}});eq(scans,1);eq(second[1].recognition.ttl,C.recognition.ttl)
 camera.entity:SetAngles(Angle(-25,20,0));second=P:ResolveWatch(viewer,{monitors={monitor.id}});eq(#second[1].recognition.people,1);eq(scans,1)
 camera.entity:SetAngles(Angle(-25,90,0));second=P:ResolveWatch(viewer,{monitors={monitor.id}});eq(#second[1].recognition.people,0);eq(scans,1)
 camera.entity:SetAngles(Angle(-25,0,0));card.data.revoked=true
 second=P:ResolveWatch(viewer,{monitors={monitor.id}});eq(scans,1);eq(second[1].recognition.people[1].name,'НЕ ОПОЗНАН');eq(second[1].recognition.people[1].level,nil)
 util.TraceLine=function(v) return {Hit=v.endpos:DistToSqr(ix.CCTV.FacePosition(p))<1} end
 second=P:ResolveWatch(viewer,{monitors={monitor.id}});eq(#second[1].recognition.people,0);eq(scans,1)
 util.TraceLine=function() return {Hit=false} end;p.userid=p.userid+1
 second=P:ResolveWatch(viewer,{monitors={monitor.id}});eq(#second[1].recognition.people,0);eq(scans,1)
 clock=clock+.5;allPlayers={};second=P:ResolveWatch(viewer,{monitors={monitor.id}});eq(#second[1].recognition.people,0)
`);
suite('Staggered authorized viewers both recognize a moving camera across repeated shared-cache cycles',server,`
 local P,C=PLUGIN,ix.CCTV;local first,camera,monitor=makeRecognitionView()
 local second=person('Other observer',Vector(-90,0,0));second.admin=false
 local target=person(nil,Vector(200,0,0));giveCard(target,'Current visible card');allPlayers={target}
 local scans=0;player.GetAll=function() scans=scans+1;return allPlayers end
 local traces=0;util.TraceLine=function() traces=traces+1;return {Hit=false} end
 local start=clock
 for cycle=0,3 do
  clock=start+cycle*.6;camera.entity:SetPos(Vector(cycle*2,0,64))
  local a=P:ResolveWatch(first,{monitors={monitor.id}});eq(#a,1);eq(#a[1].recognition.people,1)
  eq(a[1].recognition.people[1].name,'Current visible card')
  clock=start+cycle*.6+.1;camera.entity:SetPos(Vector(cycle*2+1,0,64))
  local before=traces
  local b=P:ResolveWatch(second,{monitors={monitor.id}});eq(#b,1);eq(#b[1].recognition.people,1)
  eq(b[1].recognition.people[1].name,'Current visible card');eq(b[1].recognition.ttl,C.recognition.ttl)
  assert(traces-before<=1+C.recognition.limit) -- one monitor trace plus bounded candidate checks
  eq(scans,cycle+1)
 end
 eq(scans,4)
`);
suite('Projection follows capture camera orientation/FOV, produces square pixel bounds and rejects clipped faces',client,`
 local C=ix.CCTV;local origin=Vector(10,20,30)
 for _,angle in ipairs({Angle(),Angle(15,100,20),Angle(-20,-50,-10)}) do
  for _,fov in ipairs({30,75,110}) do
   local point=origin+angle:Forward()*200+angle:Right()*20+angle:Up()*10
   local b=C.FaceProjection(point,origin,angle,fov);assert(b);near(b.w*320,b.h*180)
   local tan=math.tan(math.rad(fov/2));near(b.x,.5+.5*20/(200*tan));near(b.y,.5-.5*10*(16/9)/(200*tan))
  end
 end
 eq(C.FaceProjection(Vector(1,0,0),Vector(),Angle(),75),nil)
 eq(C.FaceProjection(Vector(200,155,0),Vector(),Angle(),75),nil)
`);
const capture=`
 local P,C=PLUGIN,ix.CCTV;local p=person();p.eyeAngle=Angle(0,180,0)
 local d={id=1,kind='camera',name='Cam',on=true,pos=Vector(0,0,64),ang=Angle(-25,0,0)};P.devices[1]=d
 local entry={entity=p.id,userid=p.userid,name='Visible identity',department='Служба безопасности',level=2}
 local feed={id=1,pos=Vector(12,0,64),ang=Angle(),fov=75,received=clock,first=clock-1,recognition={ttl=.85,people={entry}}};P.feeds[1]=feed
 local slot={target={},camera=1};C.slots[1]=slot
 recognitionPaintRecorder()
`;
suite('Capture freezes labels with texture, independently rechecks PVS/LOS and never draws extra world views',client,capture+`
 P:CaptureFeed(feed,slot);eq(renderCalls,1);eq(#slot.recognition,1);local box=slot.recognition[1]
 P:PaintRecognition(feed,slot,0,30,320,180);eq(#outlines,1);near(outlines[1].x,(box.x-box.w/2)*320)
 local before=outlines[1].x;p.pos=Vector(200,40,0)
 recognitionPaintRecorder();P:PaintRecognition(feed,slot,0,30,320,180);near(outlines[1].x,before);eq(renderCalls,1)
 util.TraceLine=function() return {Hit=true} end;P:CaptureFeed(feed,slot);eq(#slot.recognition,0)
 util.TraceLine=function() return {Hit=false} end;p.dormant=true;P:CaptureFeed(feed,slot);eq(#slot.recognition,0)
 p.dormant=false;p.userid=p.userid+1;P:CaptureFeed(feed,slot);eq(#slot.recognition,0)
`);
suite('Letterboxed overlays remain within wide/tall screens, clear on card changes, expired grants and deleted players',client,capture+`
 P:CaptureFeed(feed,slot)
 for _,rect in ipairs({{0,30,320,180},{0,110,640,360},{0,0,140,78.75}}) do
  recognitionPaintRecorder();P:PaintRecognition(feed,slot,table.unpack(rect));eq(#outlines,1)
  for _,b in ipairs(rectangles) do assert(b.x>=rect[1] and b.y>=rect[2] and b.x+b.w<=rect[1]+rect[3] and b.y+b.h<=rect[2]+rect[4]) end
 end
 entry.name='New card';recognitionPaintRecorder();P:PaintRecognition(feed,slot,0,30,320,180);eq(#outlines,0)
 entry.name='Visible identity';p.valid=false;P:PaintRecognition(feed,slot,0,30,320,180);eq(#outlines,0);p.valid=true
 clock=clock+.5;P:PaintRecognition(feed,slot,0,30,320,180);eq(#outlines,0) -- stale frame
 clock=clock+.4;P:CaptureFeed(feed,slot);eq(#slot.recognition,0) -- stale server grant
`);
suite('PaintFeed gates recognition with camera power/signal, clears failed captures and resets grants on resync',client,capture+`
 P:CaptureFeed(feed,slot);recognitionPaintRecorder();P:PaintFeed(1,320,240);eq(#outlines,1)
 d.on=false;recognitionPaintRecorder();P:PaintFeed(1,320,240);eq(#outlines,0);d.on=true
 failRender=true;P:CaptureFeed(feed,slot);eq(slot.recognition,nil);eq(slot.updated,nil);eq(depth,0);eq(C.rendering,false)
 failRender=false;P:CaptureFeed(feed,slot);assert(slot.recognition)
 net.ReadString=function() return util.TableToJSON({}) end;net.handlers.ixCCTVReset();eq(next(P.feeds),nil)
`);
suite('Four active recognized feeds retain the shared 16 captures/s render pool',client,capture+`
 for id=1,4 do P.devices[id]=table.Copy(d);P.devices[id].id=id;P.demand[id]=true;P.feeds[id]=table.Copy(feed);P.feeds[id].id=id end
 C.slots={};local start=clock
 for n=1,120 do clock=start+n/60;for _,f in pairs(P.feeds) do f.received=clock end;hooks.PostRender.ixCCTVFeeds() end
 assert(renderCalls<=32 and renderCalls>=24);eq(allocations,4);eq(depth,0);eq(C.rendering,false)
 for id=1,4 do eq(#P:FeedSlot(id).recognition,1) end
`);
suite('Helmet feed uses the real interpolated bodycam lens for both capture and recognition, excludes wearer and stops when disabled',client,capture+`
 ix.bodycams={}
 ${wrapped('ixhl2rp/plugins/bodycams/sh_bodycams.lua')}
 local owner=person('Camera wearer',Vector(50,0,0));owner.eyeAngle=Angle()
 function owner:SetupBones() end
 function owner:GetModelScale() return 1 end
 function owner:GetBoneMatrix() local m=Matrix();m:SetTranslation(self:GetBonePosition());return m end
 function owner:LookupAttachment() return 1 end
 function owner:GetAttachment() return {Ang=Angle()} end
 function owner:GetNW2Int(key,default) return key=='ixHelmetCamera' and 1 or default end
 function owner:GetNW2Bool() return self.enabled~=false end
 d.bodycam=true;d.entity=owner;d.entityIndex=owner.id;feed.bodycam=true;feed.ownerIndex=owner.id
 feed.pos=Vector(-500,0,0);feed.ang=Angle(45,90,0) -- stale server lens; rendering must use the current wearer
 feed.recognition.people[2]={entity=owner.id,userid=owner.userid,name='Wearer'}
 local captureView=render.RenderView
 render.RenderView=function(v) lastView=v;captureView(v) end
 P:CaptureFeed(feed,slot);eq(#slot.recognition,1);eq(slot.owner,owner)
 local lens,angle=ix.bodycams.Lens(owner);vectorNear(lastView.origin,lens);near(lastView.angles.y,angle.y)
 local expected=C.FaceProjection(C.FacePosition(p),lastView.origin,lastView.angles,feed.fov)
 near(slot.recognition[1].x,expected.x);near(slot.recognition[1].y,expected.y)
 owner.enabled=false;P:CaptureFeed(feed,slot);eq(slot.recognition,nil);eq(slot.updated,nil)
 owner.enabled=true;owner.dormant=true;P:CaptureFeed(feed,slot);eq(slot.recognition,nil)
`);
console.log(passed+' CCTV recognition suites passed; engine video/face alignment still needs an in-game check.');
