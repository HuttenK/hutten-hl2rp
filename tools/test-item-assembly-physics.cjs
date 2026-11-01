const fs=require('fs'),path=require('path');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const {normalize}=require('./glua.cjs');
const source=fs.readFileSync(path.join(__dirname,'../helix/entities/entities/ix_item.lua'),'utf8');
const body=source.slice(source.indexOf('\tfunction ENT:InitializeItemPhysics'),source.indexOf('\n\tfunction ENT:Use'));
const fixture=`
ENT={};MOVETYPE_VPHYSICS=6;SOLID_VPHYSICS=6;SIMPLE_USE=1
function Vector(x,y,z) return {x=x,y=y,z=z} end
function IsValid(v) return v and v.valid end
invalidBoundsMin=Vector(-8,-8,-8);invalidBoundsMax=Vector(8,8,8)
ix={arc9Inventory={IsClass=function() return true end}}
weapons={Get=function() return {MirrorVMWM=true,HoldType='ar2'} end}
function ENT:SetAssemblyHullLength(v) self.length=v end
function ENT:UpdateAssemblyTrace() end
function ENT:SetMoveType(v) self.move=v end
function ENT:PhysicsInitBox(a,b)
 self.box={a,b};self.phys={valid=true,SetMass=function(s,v) s.mass=v end,
 EnableMotion=function(s,v) s.motion=v end,Wake=function(s) s.awake=true end}
end
function ENT:PhysicsInit() self.modelPhysics=(self.modelPhysics or 0)+1;self.phys=nil end
function ENT:SetSolid(v) self.solid=v end
function ENT:EnableCustomCollisions(v) self.custom=v end
function ENT:GetPhysicsObject() return self.phys end
function ENT:GetItem() return self.item end
function ENT:SetUseType() end
function ENT:SetHealth() end
`;
const checks=`
ENT.item={isWeapon=true,class='arc9_fixture'}
ENT:InitializeItemPhysics(ENT.item)
assert(ENT.box[1].x==-22 and ENT.phys.motion and ENT.phys.awake)
ENT:Initialize()
assert(not ENT.modelPhysics and ENT.phys.awake and ENT.custom and ENT.move==6)
ENT.item={};ENT:Initialize()
assert(ENT.box[1].x==-8 and ENT.phys.motion and ENT.phys.awake)
`;
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
if(lauxlib.luaL_dostring(L,to_luastring(fixture+normalize(body)+checks))!==lua.LUA_OK)throw Error(to_jsstring(lua.lua_tostring(L,-1)));
console.log('PASS assembled item hull survives Spawn initialization; fallback physics wakes');
