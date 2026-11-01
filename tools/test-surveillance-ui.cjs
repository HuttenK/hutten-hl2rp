const fs=require('fs'),f=require('fengari'),{normalize}=require('./glua.cjs');
const common=['tools/fixture.lua','tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/fixtures/tv.lua','helix/gamemode/core/libs/sh_propscreens.lua','tools/fixtures/cctv.lua','tools/fixtures/tv-client.lua','tools/fixtures/tv-controls.lua','tools/fixtures/cctv-render.lua'];
const cctv=['ixhl2rp/plugins/cctv/sh_state.lua','ixhl2rp/plugins/cctv/sh_surfaces.lua','ixhl2rp/plugins/cctv/cl_network.lua','ixhl2rp/plugins/cctv/cl_render.lua','ixhl2rp/plugins/cctv/cl_controls.lua','ixhl2rp/plugins/cctv/cl_terminal.lua','ixhl2rp/plugins/cctv/cl_placement.lua','ixhl2rp/plugins/cctv/cl_surfaces.lua'];
const tv=['helix/gamemode/core/libs/sh_broadcastmedia.lua','ixhl2rp/plugins/tv_screen/sh_state.lua','ixhl2rp/plugins/tv_screen/cl_html.lua','ixhl2rp/plugins/tv_screen/cl_subtitles.lua','ixhl2rp/plugins/tv_screen/cl_display.lua','ixhl2rp/plugins/tv_screen/cl_plugin.lua','ixhl2rp/plugins/tv_screen/cl_controls.lua'];
let count=0;function suite(name,files,assertions){
 const source=[...common,...files].map(p=>'do local function includeFile()\n'+normalize(fs.readFileSync(p,'utf8'))+'\nend;includeFile() end').join('\n')+'\n'+assertions;
 const L=f.lauxlib.luaL_newstate();f.lualib.luaL_openlibs(L);
 if(f.lauxlib.luaL_dostring(L,f.to_luastring(source))!==f.lua.LUA_OK)throw Error(name+': '+f.to_jsstring(f.lua.lua_tostring(L,-1)));
 console.log('PASS '+name);count++;
}
suite('CCTV selector lamp tracks the current device without stale list recreation',cctv,`
 local P,C=PLUGIN,ix.CCTV
 P.devices[1]={id=1,kind='camera',name='Первая',on=true,pos=Vector(),ang=Angle(),fov=75}
 P.devices[2]={id=2,kind='camera',name='Вторая',on=true,pos=Vector(),ang=Angle(),fov=75}
 P:OpenAdminUI(1)
 local first=uiFind('DButton','001 / Первая');local second=uiFind('DButton','002 / Вторая')
 C.Desk.Key=function(_,_,_,_,selected) selectedLamp=selected end
 first:Paint(240,38);eq(selectedLamp,true);second:Paint(240,38);eq(selectedLamp,false)
 second:DoClick();first:Paint(240,38);eq(selectedLamp,false);second:Paint(240,38);eq(selectedLamp,true)
 eq(P.preview,2);eq(renderCalls,0)
`);
suite('Broadcast transport keys stay separate at compact and full widths and target the same channel',tv,`
 local P=PLUGIN;P.channels={[1]={id=1,name='Общий эфир',source='',sound='',loop=true,volume=1,playing=false}}
 P:OpenTVAdmin('channels',1)
 local play=uiFind('DButton','▶  Запустить на этом канале');local stop=uiFind('DButton','■  Остановить эфир');eq(play.parent,stop.parent)
 for _,button in ipairs({play,stop}) do button.SetPos=function(self,x,y) self.x=x;self.y=y end end
 for _,width in ipairs({630,726}) do
  play.parent:PerformLayout(width,44)
  assert(play.x>=0 and play.x+play.w<stop.x and stop.x+stop.w<=width);eq(play.h,44);eq(stop.h,44)
 end
 P.Request=function(_,action,data) lastAction=action;lastData=data end
 play:DoClick();eq(lastAction,'play');eq(lastData.channel,1);stop:DoClick();eq(lastAction,'stop');eq(lastData.channel,1)
`);
suite('Escape discards CCTV screen calibration preview and releases interest without saving',cctv,`
 local P,C=PLUGIN,ix.CCTV;local ent=entity(700,'models/test.mdl',Vector(50,0,64))
 local d=clientSurface(100,ent,{x=8,y=0,z=0,p=0,yaw=90,r=90,w=32,h=23.2})
 P.Request=function() error('Cancellation must not save') end
 P:OpenSurfaceEditor(100);local frame=P.window;P.editSurface.config.w=40
 frame:OnKeyCodePressed(KEY_ESCAPE);eq(IsValid(frame),false);eq(P.editSurface,nil);eq(d.config.w,32);eq(P.nextInterest,0)
`);
console.log(count+' surveillance UI interaction suites passed. Native rendering remains a live check.');
