const fs=require('fs'),path=require('path');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const root=path.resolve(__dirname,'..');
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
const setup=`
ix={arc9Inventory={IsClass=function() return true end}}; hooks={};timer={Create=function() end}
hook={Add=function(event,name,fn) hooks[event]=fn end};vgui={Register=function() end}
function IsValid(v) return type(v)=='table' and v.valid end
function istable(v) return type(v)=='table' end
function table.Copy(v) if type(v)~='table' then return v end;local t={};for k,x in pairs(v) do t[k]=table.Copy(x) end;return t end
local player={valid=true};function LocalPlayer() return player end
clock=0;function RealTime() return clock end
weapons={Get=function() return {MirrorVMWM=true} end}
util={TableToJSON=function(t) return t[1] and t[1].Installed or '{}' end}
ARC9={PresetCam='old'}; created=0;removed=0
PLUGIN={}
function PLUGIN:CreatePreviewWeapon(source,tree)
 created=created+1
 if fail then return nil end
 return {valid=true,class=source:GetClass(),rounds=source:Clip1(),tree=tree,
 SetPos=function(s,p) s.pos=p end, SetAngles=function(s,a) s.angles=a end,
 DrawCustomModel=function() if drawfail then error('fixture') end end}
end
function PLUGIN:RemovePreviewWeapon(m) if IsValid(m) then m.valid=false;removed=removed+1 end end
function ErrorNoHalt() end
`;
const assertions=`
local A=ix.WeaponAssembly;local host={valid=true};local tree={{Installed='stock'}}
local one=A.Get(host,'arc9_test',tree,3);assert(one.rounds==3 and one.tree==tree and created==1)
assert(A.Get(host,'arc9_test',tree,3)==one and created==1)
local two=A.Get(host,'arc9_test',{{Installed='optic'}},3);assert(two~=one and removed==1)
local root={valid=true,slottbl={},OptimizPrevWMPos='stale',invalidations=0}
function root:InvalidateBoneCache() self.invalidations=self.invalidations+1 end
function root:SetPos(p) self.pos=p end
function root:SetAngles(a) self.angles=a end
function root:SetRenderOrigin(p) self.origin=p end
function root:SetRenderAngles(a) self.renderAngles=a end
function root:SetupBones() assert(self.invalidations>0);self.builtAt=self.pos end
two.CModel={root}
function two:GetAttachmentPos(slot,wm,idle,offset,p,a) return p,a end
local p1,a1={},{};assert(A.Draw(two,p1,a1));assert(two.pos==p1 and two.angles==a1)
local p2,a2={},{};assert(A.Draw(two,p2,a2));assert(two.pos==p2 and two.angles==a2);assert(root.builtAt==p2 and root.origin==p2 and root.OptimizPrevWMPos==nil)
assert(ARC9.PresetCam=='old')
drawfail=true;assert(not A.Draw(two,{},{}));assert(ARC9.PresetCam=='old');drawfail=false
A.Remove(host);assert(removed==2);A.Remove(host);assert(removed==2)
fail=true;assert(not A.Get(host,'arc9_test',nil,0));local count=created
assert(not A.Get(host,'arc9_test',nil,0) and created==count)
clock=6;fail=false;assert(A.Get(host,'arc9_test',nil,0));assert(created==count+1)
hooks.EntityRemoved(host);assert(removed==3)
assert(A.Supports({class='arc9_test',isWeapon=true}));assert(not A.Supports({class='arc9_test'}))
`;
const source=fs.readFileSync(path.join(root,'ixhl2rp/plugins/arccw_item_atts/cl_display.lua'),'utf8');
if(lauxlib.luaL_dostring(L,to_luastring(setup+'\ndo\n'+source+'\nend\n'+assertions))!==lua.LUA_OK)
throw Error(to_jsstring(lua.lua_tostring(L,-1)));
console.log('PASS weapon assembly caching, configuration changes, isolated preview state, retry throttling and cleanup');
