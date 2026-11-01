const fs=require('fs'),path=require('path');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const src=fs.readFileSync(path.join(__dirname,'../ixhl2rp/plugins/holsteredweapons.lua'),'utf8');
const body=src.slice(src.indexOf('function PLUGIN:HolsterBoneFrame'),src.indexOf('function PLUGIN:ClearHolsters'));
const setup=`
PLUGIN={};local V={};V.__index=V
function Vector(x,y,z) return setmetatable({x=x,y=y,z=z},V) end
V.__sub=function(a,b) return Vector(a.x-b.x,a.y-b.y,a.z-b.z) end
function V:LengthSqr() return self.x*self.x+self.y*self.y+self.z*self.z end
function V:Normalize() local n=math.sqrt(self:LengthSqr());self.x=self.x/n;self.y=self.y/n;self.z=self.z/n end
function V:Cross(b) return Vector(self.y*b.z-self.z*b.y,self.z*b.x-self.x*b.z,self.x*b.y-self.y*b.x) end
function V:AngleEx(up) return {forward=self,up=up} end
function Angle(p,y,r) return {y=y,Right=function() return Vector(math.sin(math.rad(y)),-math.cos(math.rad(y)),0) end} end
local top=Vector(0,0,10);local yaw=0
client={GetRenderAngles=function() return {y=yaw} end,LookupBone=function() return 1 end,
GetBoneMatrix=function() return {GetTranslation=function() return top end} end}
base={GetTranslation=function() return Vector(0,0,0) end}
function check()
 local f=PLUGIN:HolsterBoneFrame(client,'spine',base)
 assert(math.abs(f.forward.x-1)<.001 and math.abs(f.forward.y)<.001)
 top=Vector(5,0,10);f=PLUGIN:HolsterBoneFrame(client,'spine',base)
 assert(f.forward.x>.8 and f.forward.z<-.4 and f.up.x>.4)
 top=Vector(0,0,10);yaw=90;f=PLUGIN:HolsterBoneFrame(client,'spine',base)
 assert(math.abs(f.forward.x)<.001 and f.forward.y>.99)
 f=PLUGIN:HolsterBoneFrame(client,'ValveBiped.Bip01_Pelvis',base);assert(f.y==90)
 top=Vector(0,0,0);f=PLUGIN:HolsterBoneFrame(client,'spine',base);assert(f.y==90)
end
`;
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
if(lauxlib.luaL_dostring(L,to_luastring(setup+body+'\ncheck()'))!==lua.LUA_OK)throw Error(to_jsstring(lua.lua_tostring(L,-1)));
console.log('PASS holster frame: upright yaw, crouch lean, turning, hip and degenerate fallback');
