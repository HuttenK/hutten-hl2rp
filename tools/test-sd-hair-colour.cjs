const {run,source,native,read,finish}=require('./restored-test-runner.cjs');
const shared='ixhl2rp/plugins/sd_hair_colour/sh_colour.lua';
const client='ixhl2rp/plugins/sd_hair_colour/cl_colour.lua';
const server='ixhl2rp/plugins/sd_hair_colour/sv_colour.lua';
const companion='addons/sd_dclass_companion/lua/autorun/sd_dclass_hair_colour.lua';
// GAMEMODE content is mounted from content/, unlike an addon's root. Checking
// only source/live hashes previously missed eight identically misplaced files.
const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'..');
for(const family of ['haircurly','haircurly2','haircurly3','hairlong01','hairshaved','hairshaved04','hairshaved06','hairshort01']) {
 const asset='materials/models/hutten/sd_hair/'+family+'.vtf';
 const mounted=path.join(root,'ixhl2rp/content',asset);
 if(!fs.existsSync(mounted))throw Error('Hair asset is outside the mounted gamemode content: '+asset);
 const data=fs.readFileSync(mounted);
 if(data.toString('ascii',0,3)!=='VTF')throw Error('Invalid hair texture '+asset);
 if(fs.existsSync(path.join(root,'ixhl2rp',asset)))throw Error('Unmounted hair asset remains: '+asset);
}
const fixture=source(['tools/geometry-fixture.lua'])+`
hook.stored={}
function hook.Add(event,id,fn) hook.stored[event]=hook.stored[event] or {};hook.stored[event][id]=fn end
function hook.Remove(event,id) if hook.stored[event] then hook.stored[event][id]=nil end end
function hook.Run(event,...) for _,fn in pairs(hook.stored[event] or {}) do fn(...) end end
local timers={};function timer.Create(id,_,__,fn) timers[id]=fn end
function timer.Remove(id) timers[id]=nil end
ents.GetAll=function() return {} end
resource={AddFile=function() end}
ix.char={vars={},vars_id={}};ix.type={string=1,character=2};ix.transmit={none=1,all=2,owner=4}
ix.db={AddToSchema=function() end};ix.faction={indices={}}
ix.command={stored={},Add=function(name,cmd) ix.command.stored[name]=cmd end}
bit={band=function(a,b) return a & b end,bor=function(a,b) return a | b end,bnot=function(a) return ~a end}
function table.Count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
net.ChooseOptimalBits=function() return 8 end
net.Start=function() end;net.WriteUInt=function() end;net.WriteCharVar=function() end
net.Broadcast=function() end
local CHAR=ix.meta.character;CHAR.vars={};CHAR.__index=CHAR
function CHAR:GetPlayer() return self.player end
function CHAR:GetID() return 14 end
function CHAR:GetModel() return self.model end
function CHAR:GetName() return 'Thomas' end
local queries={};mysql={Update=function(_,tableName)
 local q={tableName=tableName,values={}}
 function q:Update(k,v) self.values[k]=v end
 function q:Where(k,v) self.where={k,v} end
 function q:Callback(fn) self.callback=fn end
 function q:Execute() queries[#queries+1]=self;if self.callback then self.callback() end end
 return q
end}
local model='models/sd/citizens/citizen_male_01_hair1.mdl'
local function char(colour)
 return setmetatable({vars={sdHairColor=colour},model=model},CHAR)
end
local function entity(character,kind)
 local e={valid=true,character=character,kind=kind or 'player',model=model,sub={},vars={},writes=0,reads=0}
 if character then character.player=e end
 function e:IsPlayer() return self.kind=='player' end
 function e:GetCharacter() return self.character end
 function e:GetModel() return self.model end
 function e:GetClass() return self.kind end
 function e:GetMaterials() self.reads=self.reads+1;return self.names or {'models/sectorialdistrict/citizens/hairshort01','models/sectorialdistrict/citizens/hats','face'} end
 function e:GetSubMaterial(i) return self.sub[i] or '' end
 function e:SetSubMaterial(i,m) self.sub[i]=m;self.writes=self.writes+1 end
 function e:GetNetVar(k,d) if self.vars[k]==nil then return d end;return self.vars[k] end
 function e:SetNetVar(k,v) self.vars[k]=v end
 return e
end
`+native('helix/gamemode/core/meta/sh_character.lua','function ix.char.RegisterVar','-- Allows access to the character metatable')+
native('helix/gamemode/core/meta/sh_character.lua','\tfunction CHAR:Save','\t--- Networks this character')+
native('helix/gamemode/core/libs/sh_character.lua','\tfunction ix.char.RestoreVars','--- Creates a new empty').trim().replace(/end$/,'');
const clientFixture=`
SERVER=false;CLIENT=true
local created={};local originals={};local missing=false
file={Exists=function() return not missing end}
function Material(name)
 if created[name] then return created[name] end
 originals[name]=originals[name] or {name=name}
 local m=originals[name]
 function m:IsError() return false end
 function m:GetShader() return 'VertexLitGeneric' end
 -- Source exposes switches through $flags, never through GetFloat. A mock
 -- returning GetFloat('$alphatest')=1 hid the missing-cutout regression.
 function m:GetFloat(key) return ({['$alphatestreference']=.5})[key] end
 function m:GetInt(key) if key=='$flags' then return self.flags or 603988224 end end
 function m:GetTexture(key) return {GetName=function() return key=='$bumpmap' and 'hair_normal' or 'hair_detail' end} end
 return m
end
function CreateMaterial(name,shader,params)
 if not created[name] then
  local flags=2048
  for key,mask in pairs({['$alphatest']=256,['$nocull']=8192,['$translucent']=2097152,['$nodecal']=67108864,['$allowalphatocoverage']=536870912}) do
   if tonumber(params[key])==1 then flags=bit.bor(flags,mask) end
  end
  created[name]={params=params,flags=flags,flagWrites=0}
 end
 local m=created[name]
 function m:IsError() return false end
 function m:GetInt(key) if key=='$flags' then return self.flags end end
 function m:SetInt(key,value) assert(key=='$flags');self.flags=value;self.flagWrites=self.flagWrites+1 end
 function m:SetVector(key,v) self[key]=v end
 function m:Recompute() end
 return m
end
`;
function s(name,test){run(name,fixture+source([shared,server])+test)}
function c(name,test){run(name,fixture+source([shared])+clientFixture+source([client])+test)}
s('hair creation validates IDs and supported models',`
 local v=ix.char.vars.sdHairColor;ix.faction.indices[1]={GetModels=function() return {model,{'models/player/kleiner.mdl'}} end}
 local p={faction=1,gender=1,model=1}
 for _,choice in ipairs(ix.SDHair.presets) do eq(v:OnValidate(choice.id,p,{}),choice.id) end
 eq(v:OnValidate(nil,p,{}),'original')
 for _,value in ipairs({'arbitrary/material',false,123,{}}) do eq(v:OnValidate(value,p,{}),false) end
 p.model=2;eq(v:OnValidate('black',p,{}),'original');p.faction=999;eq(v:OnValidate('white',p,{}),'original')
 eq(v.Net.Transmit,ix.transmit.all)
`);
s('hair persistence uses actual character save and restore',`
 local a=char('ginger');a:Save();eq(queries[1].values.sd_hair_color,'ginger')
 local restored={};ix.char.RestoreVars(restored,queries[1].values);eq(restored.sdHairColor,'ginger')
 local b=char();b.vars=restored;eq(ix.SDHair.Saved(b),'ginger')
 eq(ix.SDHair.Saved(char()),'original');eq(ix.SDHair.Saved(char('unknown')),'original')
 hook.Run('OnCharacterCreated',{},a);eq(queries[2].values.sd_hair_color,'ginger');eq(queries[2].where[2],14)
`);
s('admin colour command validates, saves and updates only its target',`
 local cmd=ix.command.stored.CharSetHairColor;eq(cmd.adminOnly,true);eq(cmd.arguments[1],ix.type.character)
 local a,b=char('blond'),char('brown');local pa,pb=entity(a),entity(b)
 cmd:OnRun({},a,'BLACK');eq(a:GetSdHairColor(),'black');eq(pa.vars.sdHairColor,'black');eq(b:GetSdHairColor(),'brown');eq(#queries,1)
 cmd:OnRun({},a,'../bad');eq(a:GetSdHairColor(),'black');eq(#queries,1)
 cmd:OnRun({},a,'gray');eq(a:GetSdHairColor(),'grey')
 cmd:OnRun({},a,'original');eq(a:GetSdHairColor(),'original')
 a.model='models/player/kleiner.mdl';cmd:OnRun({},a,'white');eq(a:GetSdHairColor(),'original')
`);
s('downed and cart bodies follow edits while old corpses keep snapshots',`
 local a=char('brown');local p=entity(a);local corpse=entity(nil,'prop_ragdoll')
 hook.Run('OnCreatePlayerServerRagdoll',p,corpse);eq(corpse.vars.sdHairColor,'brown')
 local body,display=entity(nil,'prop_ragdoll'),entity(nil,'ix_cart_patient');p.ixRagdoll=body;body.ixPlayer=p
 local cart={valid=true,GetNW2Entity=function() return display end};ix.PushCart={PatientCart=function() return cart end}
 ix.SDHair.Copy(body,display);a:SetSdHairColor('white');eq(body.vars.sdHairColor,'white');eq(display.vars.sdHairColor,'white');eq(corpse.vars.sdHairColor,'brown')
 local other=char('black');p.character=other;hook.Run('PlayerLoadedCharacter',p,other);eq(p.vars.sdHairColor,'black');eq(corpse.vars.sdHairColor,'brown')
`);
c('players get independent hair-only overrides and cached materials',`
 local a,b=entity(char('blond')),entity(char('black'));a.sub[1]='helmet';a.sub[2]='face_override'
 ix.SDHair.Update(a);ix.SDHair.Update(b);assert(a.sub[0]~=b.sub[0]);eq(a.sub[1],'helmet');eq(a.sub[2],'face_override')
 local writes,reads,n=a.writes,a.reads,table.Count(created)
 for i=1,100 do ix.SDHair.Update(a) end
 eq(a.writes,writes);eq(a.reads,reads);eq(table.Count(created),n)
 for _,m in pairs(created) do eq(m.params['$phong'],0);eq(m.params['$alphatestreference'],'0.5');eq(m.params['$bumpmap'],'hair_normal') end
`);
c('original restores hair without changing skin or other overrides',`
 local p=entity(char('white'));ix.SDHair.Update(p);assert(p.sub[0]);p.sub[1]='headwear'
 p.character:SetSdHairColor('original');ix.SDHair.Update(p);eq(p.sub[0],nil);eq(p.sub[1],'headwear')
`);
c('hair cutouts and two-sided rendering survive packed Source flags',`
 local name='models/sectorialdistrict/citizens/hairlong01'
 local expected={['$alphatest']='1',['$nocull']='1',['$nodecal']='1',['$allowalphatocoverage']='1',['$translucent']='0'}
 assert(Material(name):GetFloat('$alphatest')==nil)
 local id=ix.SDHair.Material(name,'brown');assert(id:find('!ix_sd_hair_v2_',1,true)==1)
 local params=created[id:sub(2)].params
 for k,v in pairs(expected) do eq(params[k],v) end
 eq(params['$alphatestreference'],'0.5')
 -- Curly hair has no alpha-to-coverage; do not invent it or copy unrelated flags.
 local curly='models/sectorialdistrict/citizens/haircurly';Material(curly).flags=67117312
 local c=ix.SDHair.Material(curly,'black');local cp=created[c:sub(2)].params
 eq(cp['$alphatest'],'1');eq(cp['$nocull'],'1');eq(cp['$allowalphatocoverage'],'0');eq(cp['$translucent'],'0')
 eq(cp['$selfillum'],nil);eq(cp['$ignorez'],nil)
`);
c('model changes release old slots and colour new hairstyle',`
 local p=entity(char('ginger'));ix.SDHair.Update(p)
 p.model='models/sd/citizens/citizen_female_01_hair2.mdl';p.names={'face','models/sectorialdistrict/citizens/HairLong01_red'}
 ix.SDHair.Update(p);eq(p.sub[0],nil);assert(p.sub[1]:find('hairlong01_red_ginger',1,true))
 p.model='models/player/kleiner.mdl';ix.SDHair.Update(p);eq(p.sub[1],nil)
`);
c('hidden headwear copies and external replacements stay untouched',`
 local p=entity(char('blond'));p.sub[0]='!ix_height_hidden';ix.SDHair.Update(p);eq(p.sub[0],'!ix_height_hidden')
 p.sub[0]=nil;ix.SDHair.Update(p);assert(p.sub[0]~='')
 p.sub[0]='custom/hair';ix.SDHair.Update(p);eq(p.sub[0],'custom/hair');ix.SDHair.Clear();eq(p.sub[0],'custom/hair')
`);
c('ragdolls, cart displays and preview are independent of current player',`
 local body=entity(nil,'prop_ragdoll');body.vars.sdHairColor='grey';ix.SDHair.Update(body);assert(body.sub[0]:find('_grey',1,true))
 local cart=entity(nil,'ix_cart_patient');cart.vars.sdHairColor='ginger';ix.SDHair.Update(cart);assert(cart.sub[0]:find('_ginger',1,true))
 local preview=entity(nil,'preview');ix.SDHair.Apply(preview,'white');assert(preview.sub[0]:find('_white',1,true));eq(body.vars.sdHairColor,'grey')
`);
c('all skin hair slots including high indices are isolated; missing assets fail safely',`
 local p=entity(char('black'));p.names={};for i=1,44 do p.names[i]='face_'..i end
 p.names[38]='models/sectorialdistrict/citizens/hairshort01_white';ix.SDHair.Update(p);assert(p.sub[37]);eq(p.sub[0],nil)
 local q=entity(char('brown'));q.model='models/sd/citizens/citizen_male_02_hair1.mdl';missing=true;ix.SDHair.Update(q);eq(q.sub[0],nil)
 missing=false;ix.SDHair.Update(q);assert(q.sub[0]);ix.SDHair.Clear();eq(q.sub[0],nil);eq(p.sub[37],nil)
`);
c('Workshop repair fixes cached legacy hair without changing tint or unrelated flags',`
 local name='models/sectorialdistrict/citizens/hairlong01'
 local old=CreateMaterial('ix_sd_hair_v1_hairlong01_brown','VertexLitGeneric',{['$model']=1})
 old.flags=bit.bor(old.flags,16);old.tint=Vector(.2,.1,.05)
 local calls=0
 ix.SDHair.Material=function() calls=calls+1;return '!ix_sd_hair_v1_hairlong01_brown' end
`+source([companion])+`
 local result=ix.SDHair.Material(name,'brown')
 eq(result,'!ix_sd_hair_v1_hairlong01_brown');eq(old.flags,603988224+2048+16)
 eq(old.tint.x,.2);eq(old.flagWrites,1);eq(Material(name):GetInt('$flags'),603988224)
 for i=1,100 do hook.Run('PreRender');ix.SDHair.Material(name,'brown') end
 eq(old.flagWrites,1);eq(calls,101)
`);
c('Workshop repair leaves corrected materials alone and tolerates absent assets','\n'+source([companion])+`
 local name='models/sectorialdistrict/citizens/hairshort01'
 local id=ix.SDHair.Material(name,'black');local m=created[id:sub(2)]
 eq(m.flagWrites,0);eq(m.params['$phong'],0);assert(m['$color2'].x<.1)
 missing=true;eq(ix.SDHair.Material(name,'white'),nil)
 missing=false;assert(ix.SDHair.Material(name,'white'))
`);
c('Workshop repair tolerates addon and gamemode reloads without wrapper chains',`
 local name='models/sectorialdistrict/citizens/hairshort01'
 local calls=0;local original=function() calls=calls+1;return 'other/addon/material' end
 ix.SDHair.Material=original
`+source([companion,companion])+`
 eq(SDDClassHairColour.original,original);eq(ix.SDHair.Material(name,'brown'),'other/addon/material');eq(calls,1)
 ix.SDHair.Material=nil;hook.Run('PreRender');eq(ix.SDHair.Material,nil)
 ix.SDHair.Material=function() calls=calls+1;return nil end
 hook.Run('PreRender');eq(ix.SDHair.Material(name,'brown'),nil);eq(calls,2)
`);
// UI wiring is checked separately from renderer behaviour above.
const ui=read('ixhl2rp/plugins/zz_legends_interface/cl_menu.lua');
for(const text of ['"HAIR COLOUR", "ЦВЕТ ВОЛОС"','self.draft.sdHairColor = value','ix.SDHair.Apply(self.scene:GetEntity(), value)','"sdSkin", "sdHairColor"'])if(!ui.includes(text))throw Error('Missing menu integration '+text);
if(!read('helix/gamemode/game/cl_legends_theme.lua').includes('ix.SDHair.Apply(entity, ix.SDHair.Saved(character))'))throw Error('Missing saved portrait integration');
if(!read('ixhl2rp/plugins/pushcart/sv_patient.lua').includes('ix.SDHair.Copy(body, display)'))throw Error('Missing cart integration');
finish();
