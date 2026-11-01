const fs=require('fs'),path=require('path');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const root=path.resolve(__dirname,'..');
const L=lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
const source=fs.readFileSync(path.join(root,'addons/sd_dclass_companion/lua/autorun/sd_dclass_companion.lua'),'utf8');
const setup=`
SERVER=false; hooks={}; hook={Add=function(event,id,fn) hooks[id]=fn end}
timer={Create=function() end}; ents={GetAll=function() return {} end}
function IsValid(e) return e and e.valid end
function RealTime() return 10 end
function table.Copy(t) local r={} for k,v in pairs(t) do r[k]=v end return r end
local texture={GetName=function() return 'original' end,IsError=function() return false end,Width=function() return 4096 end}
function Material() return {IsError=function() return false end,GetTexture=function() return texture end,
GetFloat=function() return 1 end,GetKeyValues=function() return {} end,GetShader=function() return 'VertexLitGeneric' end} end
function CreateMaterial(name,shader,values)
 if name:find('sd_dclass_armor') then
  assert(values['$envmap']==nil and values['$envmaptint']=='[0 0 0]')
  assert(values['$basetexture']=='original');assert(values['$bumpmap']=='original');assert(values['$phongboost']=='0.18' and values.proxies==nil)
 end
 return {SetTexture=function() end}
end
function GetRenderTargetEx(name,w,h) assert(w==4096 and h==4096); return texture end
function math.Clamp(v,a,b) return math.max(a,math.min(b,v)) end
function DisableClipping() return false end
local noop=function() end
render={PushRenderTarget=noop,Clear=noop,PopRenderTarget=noop,SetMaterial=noop,DrawScreenQuad=noop}
cam={Start2D=noop,End2D=noop};draw={NoTexture=noop};surface={DrawRect=noop,DrawPoly=noop,SetDrawColor=noop,SetMaterial=noop,DrawTexturedRect=noop,DrawTexturedRectUV=noop}
function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
`;
const assertions=`
hooks['SDDClass.Build']()
local e={valid=true,model='models/sd/citizens/citizen_male_04_hair4.mdl',groups={[4]=11,[7]=0},subs={[0]='previous'}}
function e:GetModel() return self.model end
function e:GetBodyGroups() return {{name='Torso',id=4},{name='Legs',id=7}} end
function e:GetMaterials() return {'models/sectorialdistrict/citizens/city_top3','models/sectorialdistrict/citizens/city_top','models/sectorialdistrict/citizens/hlvr_armor_security'} end
function e:GetBodygroup(id) return self.groups[id] end
function e:GetSubMaterial(id) return self.subs[id] or '' end
function e:SetSubMaterial(id,value) self.subs[id]=value end
SDDClass.Apply(e);eq(e.subs[2],'!sd_dclass_armor_v2_securityArmor');eq(e.subs[0],'!sd_dclass_companion_worn_v3_jacket');eq(e.subs[1],nil)
e.groups[7]=4;SDDClass.Apply(e);eq(e.subs[1],'!sd_dclass_companion_worn_v3_pants')
e.groups[4]=1;SDDClass.Apply(e);eq(e.subs[0],'previous');eq(e.subs[1],'!sd_dclass_companion_worn_v3_pants')
e.groups[7]=0;SDDClass.Apply(e);eq(e.subs[1],'')
e.groups[4]=11;SDDClass.Apply(e);e.subs[0]='new-clothing';SDDClass.Apply(e)
e.groups[4]=0;SDDClass.Apply(e);eq(e.subs[0],'new-clothing')
e.groups[7]=4;SDDClass.Apply(e);e.model='models/other.mdl';SDDClass.Apply(e);eq(e.subs[1],'')
e.model='models/sd/citizens/citizen_female_01_hair1.mdl';SDDClass.Apply(e);eq(e.subs[1],'!sd_dclass_companion_worn_v3_pants')
`;
if(lauxlib.luaL_dostring(L,to_luastring(setup+'\ndo\n'+source+'\nend\n'+assertions))!==lua.LUA_OK)
 throw Error(to_jsstring(lua.lua_tostring(L,-1)));
console.log('PASS companion: independent clothing, restoration, external overrides, model switches, female models');
