// Isolated Lua checks: no live server is contacted or ending triggered.
const fs = require('fs'), path = require('path');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const intro = 'ixhl2rp/plugins/z_intro/', ending = 'ixhl2rp/plugins/z_endingnotext/';
function run(name, setup, files, checks) {
 const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
 const source = [read('tools/fixture.lua'), setup, ...files.map(f => `do\n${read(f)}\nend`), checks, 'return "complete"'].join('\n');
 const status = lauxlib.luaL_dostring(L, to_luastring(source));
 if (status !== lua.LUA_OK) throw Error(name + ': ' + to_jsstring(lua.lua_tostring(L, -1)));
 if (to_jsstring(lua.lua_tostring(L, -1)) !== 'complete') throw Error('Assertions did not finish');
 lua.lua_close(L); console.log('PASS ' + name);
}
run('Only admins can broadcast the two cinematics; intro does not freeze players', `
 ix.command={list={},Add=function(name,cmd) ix.command.list[name]=cmd end}
 net.Start=function(name) net.channel=name end
 broadcasts=0;net.Broadcast=function() broadcasts=broadcasts+1 end
 Format=string.format;function ServerLog(text) log=text end
 function actor(admin,character)
  local p={valid=true}
  function p:IsAdmin() return admin end
  function p:ChatPrint(text) self.notice=text end
  function p:Name() return 'Tester' end
  function p:SteamID() return 'STEAM_TEST' end
  function p:Freeze(value) self.frozen=value end
  function p:GetCharacter() return character end
  return p
 end
 resets=0;local health={Reset=function() resets=resets+1 end}
 admin=actor(true,{Health=function() return health end});guest=actor(false,nil)
 allPlayers={admin,guest}
`, [intro+'sh_plugin.lua', ending+'sh_plugin.lua'], `
 eq(broadcasts,0)
 for _,name in ipairs({'StartIntro','StartEndingNoText'}) do
  local cmd=ix.command.list[name]
  assert(cmd:OnCheckAccess(admin));assert(not cmd:OnCheckAccess(guest));assert(not cmd:OnCheckAccess(nil))
  cmd:OnRun(guest);cmd:OnRun(nil);eq(broadcasts,0);eq(admin.frozen,nil)
 end
 ix.command.list.StartIntro:OnRun(admin);eq(broadcasts,1);eq(net.channel,'autonomous.intro');eq(admin.frozen,nil)
 ix.command.list.StartEndingNoText:OnRun(admin);eq(broadcasts,2);eq(net.channel,'autonomous.ending.notext')
 eq(admin.frozen,true);eq(guest.frozen,true);eq(resets,1);assert(log)
`);
const clientSetup = `
 SERVER=false;CLIENT=true;ix.gui={};ix.UI={Scale=function(v) return v end}
 ix.util={GetMaterial=function(p) return {path=p} end}
 surface={fonts={},CreateFont=function(name,data) surface.fonts[name]=data end}
 function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
 function ScrW() return 1920 end;function ScrH() return 1080 end
 pending={};timer.Simple=function(delay,fn) pending[#pending+1]=fn end
 function flush() local work=pending;pending={} for _,fn in ipairs(work) do fn() end end
 sound={PlayFile=function(_,_,callback) sound.callback=callback end}
 function audio()
  local channel={valid=true,volume=1}
  function channel:Stop() self.stopped=true end
  function channel:EnableLooping(value) self.loop=value end
  function channel:SetVolume(value) self.volume=value end
  function channel:GetVolume() return self.volume end
  return channel
 end
 vgui={registered={}}
 function vgui.Register(name,panel) vgui.registered[name]=panel end
 local base={}
 function base:SetSize() end;function base:SetPos() end;function base:SetCursor() end
 function base:MakePopup() self.popup=true end
 function base:SetAlpha(value) self.opacity=value end
 function base:GetAlpha() return self.opacity end
 function base:AlphaTo(value,_,_,callback) self.opacity=value;if callback then callback() end end
 function base:CreateAnimation(_,data)
  self.animation=data
  return {CreateAnimation=function(self) return self end}
 end
 function base:Remove() self:OnRemove();self.valid=false;self.popup=false end
 function vgui.Create(name)
  local definition=assert(vgui.registered[name])
  local p=setmetatable({valid=true},{__index=function(_,key) return definition[key] or base[key] end})
  p:Init();return p
 end
 KEY_SPACE=65;input={IsKeyDown=function() return spaceDown end}
 function RunConsoleCommand(cmd) command=cmd end
`;
run('Intro works without credits, replaces its previous panel and releases audio/input', clientSetup,
 [intro+'derma/cl_intro.lua'], `
 assert(surface.fonts['intro.slide.text']);eq(surface.fonts['credits.book'],nil)
 local p=vgui.Create('ui.cellar.intro');eq(#p.slides,4);eq(ix.gui.intro,p)
 local channel=audio();sound.callback(channel);eq(p.channel,channel)
 local nextPanel=vgui.Create('ui.cellar.intro');assert(channel.stopped);assert(not p.valid);eq(ix.gui.intro,nextPanel)
 local delayed=sound.callback;nextPanel:Remove();local late=audio();delayed(late);assert(late.stopped);eq(ix.gui.intro,nil)
 flush()
 local last=vgui.Create('ui.cellar.intro');local track=audio();sound.callback(track);flush()
 last.current_slide=#last.slides;last:move_slide();flush()
 assert(not last.valid);assert(not last.popup);assert(track.stopped);eq(ix.gui.intro,nil)
`);
run('Ending preserves five slides and only offers disconnect at the end; stale audio is stopped', clientSetup,
 [ending+'derma/cl_ending.lua'], `
 local p=vgui.Create('ui.cellar.ending.notext');eq(#p.slides,5);spaceDown=true;p:Think();eq(command,nil)
 flush();local channel=audio();sound.callback(channel);eq(p.channel_slides,channel)
 p.current_slide=#p.slides;p:move_slide();eq(p.allow_disconnect,false);flush();eq(p.allow_disconnect,true)
 p:Think();eq(command,'disconnect')
 p:Remove();assert(channel.stopped);eq(ix.gui.ending_notext,nil)
 local other=vgui.Create('ui.cellar.ending.notext');flush();local delayed=sound.callback
 other:Remove();local late=audio();delayed(late);assert(late.stopped)
`);
console.log('3 cinematic suites passed. Live rendering and mounted Workshop media still require an in-game check.');
