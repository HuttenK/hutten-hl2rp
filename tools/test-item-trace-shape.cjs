const fs=require('fs'),path=require('path');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const source=fs.readFileSync(path.join(__dirname,'../helix/entities/entities/ix_item.lua'),'utf8');
const body=source.slice(source.indexOf('function ENT:UpdateAssemblyTrace'),source.indexOf('\nif SERVER then'));
const fixture=`
ENT={length=0};created=0;destroyed=0;hitEnabled=true
local mt={};function Vector(x,y,z) return setmetatable({x=x,y=y,z=z},mt) end
mt.__unm=function(a) return Vector(-a.x,-a.y,-a.z) end
mt.__add=function(a,b) return Vector(a.x+b.x,a.y+b.y,a.z+b.z) end
function IsValid(v) return type(v)=='table' and v.valid end
function CreatePhysCollideBox(a,b)
 created=created+1;assert(a.x==-22 or a.x==-7)
 return {valid=true,Destroy=function(s) s.valid=false;destroyed=destroyed+1 end,
 TraceBox=function(s,pos,ang,start,finish,mins,maxs)
  assert(mins.z==0 and maxs.z>=0)
  if hitEnabled then return Vector(1,2,3),Vector(0,0,1),.25 end
 end}
end
function ENT:GetAssemblyHullLength() return self.length end
function ENT:SetCollisionBounds(a,b) self.bounds={a,b} end
function ENT:EnableCustomCollisions(v) self.custom=v end
function ENT:GetPos() return Vector(0,0,0) end
function ENT:GetAngles() return {} end
`;
const checks=`
ENT:UpdateAssemblyTrace();assert(created==0)
ENT.length=22;ENT:UpdateAssemblyTrace();assert(created==1 and ENT.custom)
local hit=ENT:TestCollision(Vector(0,0,10),Vector(0,0,-20),false,Vector(0,0,0))
assert(hit.Fraction==.25 and hit.HitPos.z==3 and created==1)
hitEnabled=false;assert(ENT:TestCollision(Vector(0,0,10),Vector(0,0,-20),false,Vector(0,0,0))==nil)
ENT.length=7;ENT:UpdateAssemblyTrace();assert(created==2 and destroyed==1)
ENT:RemoveAssemblyTrace();assert(destroyed==2)
`;
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
if(lauxlib.luaL_dostring(L,to_luastring(fixture+body+checks))!==lua.LUA_OK)throw Error(to_jsstring(lua.lua_tostring(L,-1)));
console.log('PASS shared item trace shape: delayed network setup, ray hit/miss, rebuild and cleanup');
