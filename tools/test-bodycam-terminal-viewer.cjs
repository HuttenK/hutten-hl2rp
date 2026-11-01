const fs=require('fs'),path=require('path'),f=require('fengari'),parser=require('luaparse'),{normalize}=require('./glua.cjs');
process.chdir(path.resolve(__dirname,'..'));
const wrap=p=>'do local function includeFile()\n'+normalize(fs.readFileSync(p,'utf8'))+'\nend;includeFile() end';
const base=['tools/fixture.lua','tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/fixtures/tv.lua','helix/gamemode/core/libs/sh_propscreens.lua','tools/fixtures/cctv.lua','tools/fixtures/bodycams.lua','ixhl2rp/plugins/cctv/sh_state.lua','ixhl2rp/plugins/cctv/sh_surfaces.lua','ixhl2rp/plugins/bodycams/sh_bodycams.lua'];
const server=[...base,'ixhl2rp/plugins/cctv/entities/entities/ix_cctv_device.lua','ixhl2rp/plugins/cctv/sv_devices.lua','ixhl2rp/plugins/cctv/sv_surfaces.lua','ixhl2rp/plugins/cctv/sv_network.lua'];
const client=[...base,'tools/fixtures/tv-client.lua','tools/fixtures/tv-controls.lua','tools/fixtures/cctv-render.lua','ixhl2rp/plugins/cctv/cl_network.lua','ixhl2rp/plugins/cctv/cl_render.lua','ixhl2rp/plugins/cctv/cl_controls.lua','ixhl2rp/plugins/cctv/cl_terminal.lua','ixhl2rp/plugins/cctv/cl_placement.lua','ixhl2rp/plugins/cctv/cl_surfaces.lua'];
const serverSetup=`do local original=PLUGIN;PLUGIN=bodyPlugin;${wrap('ixhl2rp/plugins/bodycams/sv_bodycams.lua')};PLUGIN=original end
 ix.bodycams.RegisterHelmets();PLUGIN:LoadData();PLUGIN:PostLoadData()
 local P,C,B=PLUGIN,ix.CCTV,ix.bodycams;local viewer=admin();viewer.admin=false
 local terminal=makeDevice('terminal',Vector(20,0,64));local wearer=wearer('Сотрудник охраны');wearer.pos=Vector(8000,0,64)
 local helmet=giveHelmet(wearer);local camera=attachCamera(wearer,helmet,true)
`;
const clientSetup=`
 local P,C=PLUGIN,ix.CCTV;client.pos=Vector(80,0,64);client.admin=false
 local terminal=clientTerminal(100,Vector(20,0,64));P:OpenTerminalUI(100)
 local function button(kind,value) for _,b in ipairs(P:TerminalLayout(100)) do if b.kind==kind and b.value==value then return b end end end
 local function bodycam(id,name,on)
  P.devices[id]={id=id,kind='camera',bodycam=true,name=name or ('Шлем / '..id),on=on~=false,entityIndex=2000+id}
 end
`;
let count=0;
function suite(name,files,code){const L=f.lauxlib.luaL_newstate();f.lualib.luaL_openlibs(L);const source=files.map(wrap).join('\n')+'\n'+code;if(f.lauxlib.luaL_dostring(L,f.to_luastring(source))!==f.lua.LUA_OK)throw Error(name+': '+f.to_jsstring(f.lua.lua_tostring(L,-1)));console.log('PASS '+name);count++;}
function sv(name,code){suite(name,server,serverSetup+code)}
function cl(name,code){suite(name,client,clientSetup+code)}
sv('Ordinary terminal users receive only an active helmet feed, without changing any monitor',`
 local monitor=makeDevice('monitor',Vector(30,0,64));monitor.terminal=terminal.id;monitor.camera=0
 local feeds,grants=P:ResolveWatch(viewer,{terminal={id=terminal.id,camera=camera}})
 eq(#feeds,1);eq(feeds[1].id,camera);eq(feeds[1].bodycam,true);eq(grants[1].terminal,terminal.id);eq(grants[1].monitor,nil);eq(monitor.camera,0)
 local fixed=makeDevice('camera',Vector(8000,100,64));eq(#P:ResolveWatch(viewer,{terminal={id=terminal.id,camera=fixed.id}}),0)
 eq(#P:ResolveWatch(viewer,{terminal={id=monitor.id,camera=camera}}),0)
 eq(#P:ResolveWatch(viewer,{terminal={id=999,camera=camera}}),0)
 eq(#P:ResolveWatch(viewer,{preview=camera}),0)
`);
sv('Forged IDs and terminal access loss deny subscriptions even to administrators',`
 for _,value in ipairs({false,'1',{},-1,0,1.5,math.huge}) do eq(#P:ResolveWatch(viewer,{terminal={id=value,camera=camera}}),0);eq(#P:ResolveWatch(viewer,{terminal={id=terminal.id,camera=value}}),0) end
 for _,adminFlag in ipairs({false,true}) do
  viewer.admin=adminFlag;terminal.on=false;eq(#P:ResolveWatch(viewer,{terminal={id=terminal.id,camera=camera}}),0);terminal.on=true
  viewer.pos=Vector(9000,0,64);eq(#P:ResolveWatch(viewer,{terminal={id=terminal.id,camera=camera}}),0);viewer.pos=Vector(0,0,64)
  hook.Add('CanUseCCTVTerminal','test',function() return false end);eq(#P:ResolveWatch(viewer,{terminal={id=terminal.id,camera=camera}}),0);hook.Remove('CanUseCCTVTerminal','test')
 end
 util.TraceLine=function() return {Hit=true} end;eq(#P:ResolveWatch(viewer,{terminal={id=terminal.id,camera=camera}}),0)
`);
sv('PVS revalidates terminal power, range, visibility, hooks, life, character and current helmet',`
 local _,grants=P:ResolveWatch(viewer,{terminal={id=terminal.id,camera=camera}});P.watchers[viewer]={grants=grants,expires=clock+1}
 P:SetupPlayerVisibility(viewer);eq(#origins,1)
 local function denies(change,restore) change();origins={};P:SetupPlayerVisibility(viewer);eq(#origins,0);restore() end
 denies(function() terminal.on=false end,function() terminal.on=true end)
 denies(function() viewer.pos=Vector(9000,0,64) end,function() viewer.pos=Vector(0,0,64) end)
 denies(function() util.TraceLine=function() return {Hit=true} end end,function() util.TraceLine=function() return {Hit=false} end end)
 denies(function() hook.Add('CanUseCCTVTerminal','test',function() return false end) end,function() hook.Remove('CanUseCCTVTerminal','test') end)
 denies(function() viewer.dead=true end,function() viewer.dead=false end)
 denies(function() viewer.noCharacter=true end,function() viewer.noCharacter=false end)
 denies(function() helmet:SetData('helmetCameraOn',false) end,function() helmet:SetData('helmetCameraOn',true) end)
 denies(function() wearer.head=nil end,function() wearer.head=helmet.id end)
 denies(function() wearer.dead=true end,function() wearer.dead=false end)
 denies(function() P.devices[terminal.id]=nil end,function() P.devices[terminal.id]=terminal end)
 clock=clock+2;origins={};P:SetupPlayerVisibility(viewer);eq(#origins,0)
`);
sv('Terminal preview takes one shared slot, deduplicates monitor feeds and retains the four-feed limit',`
 local ids={}
 for i=1,6 do local c=makeDevice('camera',Vector(4000+i*100,0,64));local m=makeDevice('monitor',Vector(40+i*5,0,64));m.camera=c.id;ids[#ids+1]=m.id end
 P.devices[ids[1]].camera=camera
 local feeds,grants=P:ResolveWatch(viewer,{terminal={id=terminal.id,camera=camera},monitors=ids})
 eq(#feeds,4);eq(#grants,4);eq(feeds[1].id,camera);local seen={};for _,feed in ipairs(feeds) do assert(not seen[feed.id]);seen[feed.id]=true end
`);
sv('Watch replacement releases terminal PVS and malformed or oversized traffic stays bounded',`
 local payload={terminal={id=terminal.id,camera=camera}};net.ReadString=function() return util.TableToJSON(payload) end
 net.handlers.ixCCTVWatch(100,viewer);eq(#P.watchers[viewer].grants,1)
 clock=clock+.5;payload={monitors={},preview=0};net.handlers.ixCCTVWatch(100,viewer);eq(#P.watchers[viewer].grants,0)
 origins={};P:SetupPlayerVisibility(viewer);eq(#origins,0)
 local reads=0;net.ReadString=function() reads=reads+1;return util.TableToJSON({terminal='invalid'}) end
 clock=clock+.5;net.handlers.ixCCTVWatch(20000,viewer);eq(reads,0)
 net.handlers.ixCCTVWatch(100,viewer);eq(reads,1);eq(#P.watchers[viewer].grants,0)
`);
cl('Active roster includes remote dormant wearers, pages all cameras and excludes off and fixed cameras',`
 for i=1,31 do bodycam(i) end;bodycam(32,'Выключена',false)
 P.devices[33]={id=33,kind='camera',name='Fixed',on=true,pos=Vector(),ang=Angle()}
 P:ActivateTerminalButton(100,button('page','bodycams'));local rows=P:TerminalLayout(100)
 eq(#rows.bodycams,31);eq(rows.bodycamPages,6);eq(rows.state.bodycam,1);eq(C.Powered(P.devices[1]),false)
 local seen={};for page=1,rows.bodycamPages do
  for _,b in ipairs(P:TerminalLayout(100)) do if b.kind=='bodycam' then seen[b.value]=true end end
  P:ScrollTerminal(100,-1,400)
 end
 eq(table.Count(seen),31);eq(rows.state.bodycamPage,6)
 P:ActivateTerminalButton(100,button('bodycam',31));eq(P:TerminalBodycamPreview().camera,31)
 P.devices[31].on=false;eq(P:TerminalBodycamPreview().camera,1)
 for _,d in pairs(P.devices) do if d.bodycam then d.on=false end end
 eq(P:TerminalBodycamPreview(),nil);eq(P:TerminalLayout(100).state.bodycamPage,1)
`);
cl('Page and selection changes keep monitor assignments and immediately release old preview interest',`
 bodycam(1);bodycam(2);local m=clientMonitor(3,Vector(30,0,64),1);m.terminal=100
 local state=P:TerminalState(100);state.monitor=3;state.cameraPage=1
 P:ActivateTerminalButton(100,button('page','bodycams'));P.demand[1]=true
 P:ActivateTerminalButton(100,button('bodycam',2));eq(P.demand[1],nil);eq(P:TerminalBodycamPreview().camera,2);eq(m.camera,1)
 P.demand[2]=true;P:ActivateTerminalButton(100,button('page','monitors'));eq(P.demand[2],nil);eq(P:TerminalBodycamPreview(),nil);eq(state.monitor,3)
 P:ActivateTerminalButton(100,button('page','bodycams'));eq(state.bodycam,2)
 P.demand[2]=true;local host=P.terminalUI.host;P:CloseTerminalUI();eq(P.demand[2],nil);eq(P.terminalUI,nil);eq(host.valid,false)
`);
cl('Watch interest prioritizes one selected bodycam and caps shared demand while retaining nearby monitors',`
 bodycam(1);P:ActivateTerminalButton(100,button('page','bodycams'));P.ready=true
 for i=2,6 do P.devices[i]={id=i,kind='camera',name='Fixed',on=true,pos=Vector(),ang=Angle()};clientMonitor(100+i,Vector(30,0,64),i) end
 P.visible={102,103,104,105,106};P.UpdateInterest=function() end;clock=clock+1;hooks.Think.ixCCTVClient()
 eq(table.Count(P.demand),4);assert(P.demand[1]);local packet=net.packets[#net.packets];eq(packet.name,'ixCCTVWatch')
 local data=util.JSONToTable(packet.value);eq(data.terminal.id,100);eq(data.terminal.camera,1);eq(#data.monitors,3)
 P:ActivateTerminalButton(100,button('page','monitors'));hooks.Think.ixCCTVClient();eq(P.demand[1],nil);eq(table.Count(P.demand),4)
 clock=clock+.5;hooks.Think.ixCCTVClient();data=util.JSONToTable(net.packets[#net.packets].value);eq(data.terminal,nil)
`);
cl('Power loss, death, range and host removal all close preview and drop demand',`
 bodycam(1);P.ready=true;P.UpdateInterest=function() end
 local function opened() P:OpenTerminalUI(100);P:ActivateTerminalButton(100,button('page','bodycams'));P.demand[1]=true end
 opened();terminal.on=false;hooks.Think.ixCCTVClient();eq(P.terminalUI,nil);eq(P.demand[1],nil);terminal.on=true
 opened();client.dead=true;hooks.Think.ixCCTVClient();eq(P.terminalUI,nil);eq(P.demand[1],nil);client.dead=false
 opened();client.pos=Vector(9000,0,64);hooks.Think.ixCCTVClient();eq(P.terminalUI,nil);eq(P.demand[1],nil);client.pos=Vector(80,0,64)
 opened();P.terminalUI.host:Remove();eq(P.terminalUI,nil);eq(P.demand[1],nil)
`);
cl('Terminal page paints one inset feed without capture and keeps screen hit tests on real row coordinates',`
 bodycam(1,'Шлем / Иван Петров');P:ActivateTerminalButton(100,button('page','bodycams'))
 local calls=0;P.PaintFeed=function(_,id,w,h,caption,x,y) calls=calls+1;eq(id,1);eq(caption,'Шлем / Иван Петров');assert(x>=300 and y>=150 and x+w<=800 and y+h<=500) end
 P:PaintTerminal(terminal,800,580);eq(calls,1);eq(renderCalls,0);eq(allocations,0)
 local b=button('bodycam',1);aimAtTerminal(terminal,b.x+8,b.y+8);local x,y=P:TerminalCursor(100);eq(P:TerminalHit(100,x,y).value,1)
 P:CloseTerminalUI();P:PaintTerminal(terminal,800,580);eq(calls,1)
`);
cl('Inset feed offsets texture and captured recognition together, with default monitor origin unchanged',`
 P.devices[1]={id=1,kind='camera',name='Fixed',on=true,pos=Vector(),ang=Angle()}
 P.feeds[1]={id=1,received=clock};C.slots[1]={camera=1,updated=clock,material={}}
 local image,recognition
 surface.DrawTexturedRectUV=function(x,y,w,h) image={x,y,w,h} end
 P.PaintRecognition=function(_,feed,slot,x,y,w,h) recognition={x,y,w,h} end
 P:PaintFeed(1,480,270,'Inset',310,162);eq(image[1],310);eq(image[2],162);eq(recognition[1],310);eq(recognition[2],162)
 P:PaintFeed(1,320,180);eq(image[1],0);eq(image[2],0);eq(renderCalls,0)
`);
cl('Selected helmet and three monitor feeds share four reusable slots and the 16 capture-per-second budget',`
 local p=wearer('Owner');p:SetNW2Int('ixHelmetCamera',1);p:SetNW2Bool('ixHelmetCameraOn',true)
 bodycam(1);P.devices[1].entityIndex=p:EntIndex();P:ActivateTerminalButton(100,button('page','bodycams'))
 for id=2,4 do P.devices[id]={id=id,kind='camera',name='Fixed '..id,on=true,pos=Vector(1000,0,0),ang=Angle()};clientMonitor(100+id,Vector(30,0,64),id) end
 P.ready=true;P.visible={102,103,104};P.UpdateInterest=function() end
 local start=clock
 for n=1,120 do
  clock=start+n/60;hooks.Think.ixCCTVClient()
  for id=1,4 do P.feeds[id]={id=id,bodycam=id==1,ownerIndex=id==1 and p:EntIndex() or nil,pos=Vector(1000,0,0),ang=Angle(),received=clock,first=start-1} end
  hooks.PostRender.ixCCTVFeeds()
 end
 eq(allocations,4);assert(renderCalls>=24 and renderCalls<=32);eq(depth,0);eq(C.rendering,false)
 for id=1,4 do assert(P:FeedSlot(id).updated) end
 P:CloseTerminalUI();clock=clock+.2;hooks.Think.ixCCTVClient();hooks.PostRender.ixCCTVFeeds();eq(P:FeedSlot(1),nil);eq(allocations,4)
`);
for(const name of ['cl_terminal','cl_network','sv_network','cl_render'])parser.parse(normalize(fs.readFileSync('ixhl2rp/plugins/cctv/'+name+'.lua','utf8')),{luaVersion:'5.2'});
console.log(count+' bodycam terminal viewer suites passed; 4 runtime Lua files parse. Live GMod rendering remains untested.');
