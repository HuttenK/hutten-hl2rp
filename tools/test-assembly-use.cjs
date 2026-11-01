const fs=require('fs'),path=require('path');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const {normalize}=require('./glua.cjs');
const root=path.resolve(__dirname,'..');
const hooks=fs.readFileSync(path.join(root,'helix/gamemode/core/hooks/sv_hooks.lua'),'utf8');
const ent=fs.readFileSync(path.join(root,'helix/entities/entities/ix_item.lua'),'utf8');
const press=hooks.slice(hooks.indexOf('function GM:KeyPress'),hooks.indexOf('function GM:KeyRelease'));
const use=ent.slice(ent.indexOf('\tfunction ENT:Use'),ent.indexOf('\n\tfunction ENT:Delete'));
const fixture=`
GM={};ENT={};IN_USE=1;IN_RELOAD=2;started=0;pending=false
local mt={__add=function(a,b) return a end,__mul=function(a,b) return a end}
local vec=setmetatable({},mt)
function IsValid(x) return type(x)=='table' end
ix={config={Get=function() return .5 end}}
timer={Exists=function() return pending end}
hook={Run=function() return allowed end};allowed=true
local target=ENT
util={TraceLine=function() return {Entity=target} end}
client={GetShootPos=function() return vec end,GetAimVector=function() return vec end,
SteamID=function() return 'fixture' end,IsPlayer=function() return true end,
GetCharacter=function() return {} end}
function client:PerformInteraction(t,e,fn) started=started+1;pending=true;self.ixInteractionTarget=e end
ENT.ixAssemblyHull=true
function ENT:GetClass() return 'ix_item' end
function ENT:IsDoor() return false end
function ENT:GetItem() return {functions={take={OnCanRun=function() return true end}}} end
`;
const checks=`
GM:KeyPress(client,IN_USE);assert(started==1)
ENT:Use(client,client);assert(started==1)
pending=false;allowed=false;GM:KeyPress(client,IN_USE);assert(started==1)
allowed=true;ENT.ixAssemblyHull=nil;GM:KeyPress(client,IN_USE);assert(started==1)
`;
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
if(lauxlib.luaL_dostring(L,to_luastring(fixture+normalize(use+press)+checks))!==lua.LUA_OK)throw Error(to_jsstring(lua.lua_tostring(L,-1)));
console.log('PASS E starts assembled-item hold once, respects PlayerUse denial and leaves other items unchanged');
