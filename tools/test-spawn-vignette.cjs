const fs=require('fs'),path=require('path');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const root=path.resolve(__dirname,'..');
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
const setup=`
PLUGIN={};ix={gui={}};draw={NoTexture=function() end};MOVETYPE_NOCLIP=8
local char={}; p={alive=true,hp=100,char=char}
function p:Alive() return self.alive end
function p:Health() return self.hp end
function p:GetCharacter() return self.char end
function p:GetMoveType() return 0 end
function LocalPlayer() return p end
function IsValid(v) return type(v)=='table' end
function FrameTime() return 0.016 end
function ScrW() return 1920 end;function ScrH() return 1080 end
function math.Clamp(v,a,b) return math.max(a,math.min(b,v)) end
unpack=table.unpack; rectangles=0;textures=0
surface={SetDrawColor=function() end,SetMaterial=function() end,
DrawRect=function() rectangles=rectangles+1 end,
DrawTexturedRect=function() textures=textures+1 end}
function Material(name) assert(name:find('vgui/gradient',1,true));return {IsError=function() return false end},0.001 end
`;
const source=fs.readFileSync(path.join(root,'helix/plugins/realistic_visuals/cl_hooks.lua'),'utf8');
const assertions=`
PLUGIN:HUDPaint();assert(rectangles==0 and textures==0)
p.hp=50;PLUGIN:HUDPaint();assert(rectangles==1 and textures==4)
p.char={};p.hp=10;rectangles=0;textures=0;PLUGIN:HUDPaint();assert(rectangles==0 and textures==0)
ix.gui.characterMenu={};p.hp=5;PLUGIN:HUDPaint();assert(rectangles==0 and textures==0)
ix.gui.characterMenu=nil;p.alive=false;PLUGIN:HUDPaint();p.alive=true;PLUGIN:HUDPaint();assert(rectangles==0 and textures==0)
`;
if(lauxlib.luaL_dostring(L,to_luastring(setup+'\ndo\n'+source+'\nend\n'+assertions))!==lua.LUA_OK)
throw Error(to_jsstring(lua.lua_tostring(L,-1)));
console.log('PASS spawn/character transitions do not flash; actual damage still draws four native vignette edges');
