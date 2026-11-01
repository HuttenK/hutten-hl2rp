module.exports = suite => {
const setup = `
 local V={}; V.__index=V
 function Vector(x,y,z) return setmetatable({x=x or 0,y=y or 0,z=z or 0},V) end
 function V:WithinAABox(a,b) return self.x>=a.x and self.x<=b.x and self.y>=a.y and self.y<=b.y and self.z>=a.z and self.z<=b.z end
 function V:DistToSqr(b) return (self.x-b.x)^2+(self.y-b.y)^2+(self.z-b.z)^2 end
 function V:Length() return math.sqrt(self:DistToSqr(Vector())) end
 function V:Distance(b) return math.sqrt(self:DistToSqr(b)) end
 function V:GetNormalized() local l=self:Length(); return self*(1/math.max(l,.0001)) end
 function V:Normalize() local l=self:Length(); self.x=self.x/l;self.y=self.y/l;self.z=self.z/l end
 function V:Dot(b) return self.x*b.x+self.y*b.y+self.z*b.z end
 V.__add=function(a,b) return Vector(a.x+b.x,a.y+b.y,a.z+b.z) end
 V.__sub=function(a,b) return Vector(a.x-b.x,a.y-b.y,a.z-b.z) end
 V.__mul=function(a,b) return Vector(a.x*b,a.y*b,a.z*b) end
 function Angle() return {} end
 function Color() return {} end
 vector_up=Vector(0,0,1)
 function AddCSLuaFile() end; function include() end
 hook.Add=function() end; hook.Remove=function() end
 ix.util={Include=function() end}; ix.data={Set=function() end,Get=function() return {} end}
 ix.area={stored={},Remove=function(name) ix.area.stored[name]=nil end}
 ix.command={Add=function() end}; ix.type={number=1,string=2,optional=4}
 util.PrecacheModel=function() end; util.IsValidModel=function() return true end
 ents.GetAll=function() return {} end
 timers={}; later={}
 timer.Create=function(name,_,_,fn) timers[name]=fn end
 timer.Simple=function(_,fn) later[#later+1]=fn end
 timer.Remove=function(name) timers[name]=nil end
 net.Start=function() end;net.Broadcast=function() end;net.Send=function() end
 net.WriteVector=function() end;net.SendPVS=function() end;net.WriteUInt=function() end
 net.WriteBool=function() end
 function PLUGIN:SetData() end; function PLUGIN:GetData() return {} end
 function table.Count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
 COLLISION_GROUP_NONE=0; COLLISION_GROUP_WORLD=1
 `+require('./restored-test-runner.cjs').source(['helix/plugins/area/sh_geometry.lua'])+'\n';
const power='helix/gamemode/core/libs/sv_devicepower.lua';
suite('Power inhibitors preserve original field state across EMP expiry and overlapping blackouts', [power], `
 local blackouts=2
 ix.plugin.list.blackout={IsPosBlackedOut=function() return blackouts>0 end}
 local e={valid=true,on=true,mode=2,GetPos=function() return Vector() end,GetClass=function() return 'ix_forcefield' end}
 function e:GetDTInt() return self.mode end;function e:SetDTInt(_,v) self.mode=v end
 function e:SetSkin(v) self.skin=v end;function e:SetCollisionGroup(v) self.collision=v end
 ix.DevicePower.Refresh(e); eq(e.on,false)
 e.ixHackedUntil=clock+30;blackouts=1; ix.DevicePower.Refresh(e);eq(e.on,false)
 clock=clock+31; ix.DevicePower.Refresh(e);eq(e.on,false)
 blackouts=0;ix.DevicePower.Refresh(e);eq(e.on,true);eq(e.mode,2)
 e.on=false;blackouts=1;ix.DevicePower.Refresh(e);blackouts=0;ix.DevicePower.Refresh(e);eq(e.on,false)
 local cmb={valid=true,mode=2,GetClass=function() return 'ent_cmb_forcefield' end,GetPos=e.GetPos}
 function cmb:GetMode() return self.mode end;function cmb:SetForcefield(v) self.mode=v end;function cmb:GetBroken() return self.broken end
 cmb.ixHackedUntil=clock+30;ix.DevicePower.Refresh(cmb);eq(cmb.mode,3)
 cmb.broken=true;clock=clock+31;ix.DevicePower.Refresh(cmb);eq(cmb.mode,3)
 `,setup);
suite('Blackout restores lights only after final covering zone; removal restores immediately; reload is idempotent',
 ['ixhl2rp/plugins/blackout/sv_plugin.lua'], `
 local a={min=Vector(-1,-1,-1),max=Vector(1,1,1),active=true}
 local b={min=a.min,max=a.max,active=true};PLUGIN.zones={a=a,b=b}
 function PLUGIN:IsPosBlackedOut() return self.zones.a and self.zones.a.active or self.zones.b and self.zones.b.active or false end
 local light={valid=true,state=true,GetClass=function() return 'light_dynamic' end,GetPos=function() return Vector() end}
 function light:GetSaveTable() return {m_bOn=self.state} end
 function light:Input(s) self.state=s=='TurnOn' end
 ents.GetAll=function() return {light} end
 PLUGIN:RefreshLights();eq(light.state,false)
 a.active=false;PLUGIN:RefreshLights();eq(light.state,false)
 PLUGIN:RemoveZone('b');eq(light.state,true)
 a.active=true;light.state=false;PLUGIN:RefreshLights();a.active=false;PLUGIN:RefreshLights();eq(light.state,false)
 local spawned=0;function PLUGIN:SpawnFusebox() spawned=spawned+1 end
 ix.data.Get=function() return {{}} end
 PLUGIN.fuseboxesLoaded=false;PLUGIN:LoadFuseboxes();PLUGIN:LoadFuseboxes();eq(spawned,1)
 local broken=false;local box={GetBroken=function() return broken end}
 PLUGIN.zones={a=a};PLUGIN.BoxesInZone=function() return {box} end
 a.active=true;a.remoteIsolation=true;a.remotePrevious=true
 PLUGIN:RecomputeZones();eq(a.active,true);eq(a.remotePrevious,false)
 broken=true;PLUGIN:RecomputeZones();eq(a.active,true);eq(a.remotePrevious,true)
 a.remoteIsolation=nil;a.active=a.remotePrevious;PLUGIN:RecomputeZones();eq(a.active,true)
 broken=false;PLUGIN:RecomputeZones();eq(a.active,false)
 `,setup+`ix.DevicePower={RefreshAll=function() end}`);
suite('EMP obstruction rejection, no-op success flag and lock revision protection',
 [power,'ixhl2rp/plugins/emp_hack/sv_plugin.lua'], `
 local target={valid=true,GetClass=function() return 'ix_combinelock' end,WorldSpaceCenter=function() return Vector(100,0,0) end,locked=false}
 function target:GetLocked() return self.locked end
 function target:SetLocked(v) self.locked=v;self.ixLockRevision=(self.ixLockRevision or 0)+1 end
 local c={valid=true,Alive=function() return true end,GetCharacter=function() return {} end,Notify=function() end,
 GetEyeTrace=function() return {HitPos=Vector(50,0,0)} end,GetShootPos=function() return Vector() end,GetAimVector=function() return Vector(1,0,0) end}
 ents.FindByClass=function(class) return class=='ix_combinelock' and {target} or {} end
 util.TraceLine=function() return {Hit=true} end
 eq(PLUGIN:FindHackable(c,450),nil)
 util.TraceLine=function() return {Hit=false} end
 eq(PLUGIN:FindHackable(c,450),target)
 eq(PLUGIN.handlers.ix_combinelock(target),false)
 target.locked=true;eq(PLUGIN.handlers.ix_combinelock(target),true)
 local saved=PLUGIN.affected[target];target:SetLocked(true);target:SetLocked(false)
 PLUGIN:Restore(target,saved);eq(target.locked,false)
 target.locked=true;PLUGIN.handlers.ix_combinelock(target);PLUGIN:Restore(target,PLUGIN.affected[target]);eq(target.locked,true)
 `,setup);
const scanner='ixhl2rp/plugins/contrabandscanner/entities/entities/ix_contrabandscanner/init.lua';
const scannerSetup=setup+`
 ENT={};ix.contraband={plugin={defaults={}},IsItemIllegal=function() return true end}
 ix.DevicePower={IsDisabled=function() return disabled end}
 `;
suite('Scanner detects full crossings between samples, rejects outside/teleport paths and resets while unpowered', [scanner], `
 local e=setmetatable({inside={},cooldown={},samples={},alarms=0},{__index=ENT})
 function e:GetScanDepth() return 28 end;function e:GetScanWidth() return 80 end;function e:GetScanHeight() return 86 end
 function e:WorldToLocal(v) return v end;function e:SetDisabled(v) self.disabled=v end
 function e:GetAlarming() return false end;function e:SetAlarming() end;function e:NextThink() end
 function e:HasContraband() return true end;function e:TriggerAlarm() self.alarms=self.alarms+1 end
 local ch={};local c={valid=true,pos=Vector(-20,0,0),Alive=function() return true end,GetCharacter=function() return ch end}
 function c:GetPos() return self.pos end;allPlayers={c}
 e:Think();c.pos=Vector(20,0,0);clock=clock+.2;e:Think();eq(e.alarms,1)
 assert(not e:SegmentCrosses(Vector(-20,100,0),Vector(20,100,0)))
 disabled=true;e:Think();eq(next(e.samples),nil);eq(e.disabled,true)
 disabled=false;c.pos=Vector(-500,0,0);e:Think();c.pos=Vector(500,0,0);clock=clock+.2;e:Think();eq(e.alarms,1)
 c.pos=Vector(0,0,0);disabled=true;e:Think();disabled=false;e:Think();eq(e.alarms,2)
 `,scannerSetup);
const infection='ixhl2rp/plugins/infectionzone/sv_plugin.lua';
const infectionSetup=setup+`
 PLUGIN.floraModels={'test.mdl'};PLUGIN.defaults={collectTime=3,collectRange=160,floraGrowTime=1,floraHealth=40,wasteWaveDelay=4,wasteWaveCount=5,wasteWaveRadius=140}
 IN_USE=32
 `;
suite('Waste item is consumed exactly once on successful unpack and retained on failure',
 ['ixhl2rp/plugins/infectionzone/items/trashbag.lua'], `
 local item={player={valid=true},removed=0,Remove=function(self) self.removed=self.removed+1 end}
 eq(ITEM.functions.unpack.OnRun(item),false);eq(item.removed,0)
 ix.plugin.list.infectionzone={UnpackWaste=function() return false end}
 eq(ITEM.functions.unpack.OnRun(item),false);eq(item.removed,0)
 ix.plugin.list.infectionzone.UnpackWaste=function() return true end
 eq(ITEM.functions.unpack.OnRun(item),true);eq(item.removed,1)
 `,setup+`ITEM={functions={}};function Model(p) return p end`);
suite('Infection collection cancels on action replacement, character change and release without spending items', [infection], `
 local char={};local prop={valid=true,ixInfectionFlora='test',GetPos=function() return Vector() end}
 local c={valid=true,Alive=function() return true end,GetCharacter=function() return char end,HasItem=function() return true end,
 GetPos=function() return Vector() end,KeyDown=function(self) return self.held end,GetEyeTrace=function() return {Entity=prop} end,held=true}
 function c:SetAction() PLUGIN:PlayerActionChanged(self) end
 local collected=0;function PLUGIN:CollectFlora() collected=collected+1 end
 PLUGIN:PlayerUse(c,prop);assert(PLUGIN.collections[c]);c:SetAction('other');eq(PLUGIN.collections[c],nil)
 PLUGIN:PlayerUse(c,prop);char={};PLUGIN:CollectionTick();eq(PLUGIN.collections[c],nil)
 PLUGIN:PlayerUse(c,prop);c.held=false;PLUGIN:CollectionTick();eq(collected,0)
 c.held=true;PLUGIN:PlayerUse(c,prop);clock=clock+4;PLUGIN:CollectionTick();eq(collected,1);eq(c.ixCollectingFlora,nil)
 `,infectionSetup);
suite('Infection deletion removes owned flora/NPCs and stale progress; waste creation has a global cap', [infection], `
 local function entity() return {valid=true,Remove=function(self) self.valid=false end} end
 local plant,npc=entity(),entity();PLUGIN.flora.old={[plant]=true};PLUGIN.zombies.old={[npc]=true};PLUGIN.remaining.old=12
 PLUGIN:AreaDefinitionRemoved('old');eq(plant.valid,false);eq(npc.valid,false);eq(PLUGIN.remaining.old,nil)
 PLUGIN.flora.__waste={};for n=1,48 do PLUGIN.flora.__waste[entity()]=true end
 eq(PLUGIN:SpawnFloraAt(Vector(),vector_up,'__waste'),nil)
 local generation=PLUGIN.wasteGeneration;PLUGIN:CleanFlora('__waste');eq(next(PLUGIN.flora.__waste),nil);eq(PLUGIN.wasteGeneration,generation+1)
 `,infectionSetup);
suite('Waste secondary growth yields no bags and failed reward creation preserves flora', [infection], `
 local bag={GetData=function() return 10 end,SetData=function(self,_,v) self.uses=v end}
 local client={valid=true,Alive=function() return true end,GetCharacter=function() return {} end,HasItem=function() return true,bag end,EmitSound=function() end,Notify=function() end}
 local prop={valid=true,ixInfectionFlora='__waste',ixNoWasteYield=true,GetPos=function() return Vector() end,Remove=function(self) self.valid=false end}
 local rewards=0;ix.Item={Instance=function() rewards=rewards+1 end}
 PLUGIN:CollectFlora(prop,client);eq(prop.valid,false);eq(rewards,0);eq(bag.uses,9)
 prop.valid=true;prop.ixNoWasteYield=false;PLUGIN:CollectFlora(prop,client);eq(prop.valid,true);eq(rewards,1);eq(bag.uses,9)
 `,infectionSetup);
suite('Cinematic and NVG passes respect menus, native optics and options; gain stays bounded',
 ['ixhl2rp/plugins/zz_legends_visuals/cl_visuals.lua'], `
 PLUGIN:RenderScreenspaceEffects();eq(grades,1);eq(worldBlooms,1)
 ArcticNVGs_Enabled=true;PLUGIN:RenderScreenspaceEffects();eq(grades,1);eq(worldBlooms,1)
 local V=ix.FieldVisuals
 for i=1,80 do V.DrawNVG({},1);clock=clock+.1 end
 assert(V.gain>=0 and V.gain<=1);assert(brightness<=.32);assert(brightness>=.04)
 local g=grades;ix.gui.menu={valid=true};V.DrawNVG({},1);eq(brightness,0);eq(grades,g)
 ix.gui.menu=nil;values.fieldNVGPolish=false;eq(V.DrawNVG({},1),false);eq(rebuilds,1)
 values.fieldNVGPolish=true;eq(V.DrawNVG({},5),false)
 values.fieldCinematic=false;ArcticNVGs_Enabled=false;PLUGIN:RenderScreenspaceEffects();eq(grades,g)
 values.fieldCinematic=true;local shaderPasses=0
 local noiseLevel,noisePhase
 V.DrawShader=function(name,a,b,c,d) shaderPasses=shaderPasses+1;if name=='nvg' then noiseLevel=c;noisePhase=d end;return true end
 PLUGIN:RenderScreenspaceEffects();eq(shaderPasses,1);eq(grades,g);eq(worldBlooms,2)
 values.fieldLightBloom=0;PLUGIN:RenderScreenspaceEffects();eq(worldBlooms,2);shaderPasses=1
 values.fieldLightBloom=.20
 V.DrawNVG({},1);eq(shaderPasses,2);eq(grades,g)
 assert(noiseLevel>=.06 and noiseLevel<=.16);assert(noisePhase>=0 and noisePhase<256)
 values.fieldNVGGrain=false;V.DrawNVG({},1);eq(noiseLevel,0)
 values.fieldNVGGrain=true;values.disableAnimations=true;V.DrawNVG({},1);eq(noisePhase,0)
 values.fieldLens=true;values.fieldCinematic=false;ArcticNVGs_Enabled=false
 local lensCalls=0
 V.DrawShader=function(name,amount) eq(name,'lens');assert(amount>0 and amount<=1);lensCalls=lensCalls+1;return true end
 PLUGIN:RenderScreenspaceEffects();eq(lensCalls,1)
 values.fieldLensStrength=0;PLUGIN:RenderScreenspaceEffects();eq(lensCalls,1)
 values.fieldLensStrength=9;PLUGIN:RenderScreenspaceEffects();eq(lensCalls,2)
 ArcticNVGs_Enabled=true;PLUGIN:RenderScreenspaceEffects();eq(lensCalls,2)
 ArcticNVGs_Enabled=false;ix.gui.menu={valid=true};PLUGIN:RenderScreenspaceEffects();eq(lensCalls,2)
 ix.gui.menu=nil;values.fieldLens=false;PLUGIN:RenderScreenspaceEffects();eq(lensCalls,2)
 values.fieldLens=true;values.fieldCinematic=true;values.fieldLensStrength=.4
 local sequence={};V.DrawShader=function(name) sequence[#sequence+1]=name;return true end
 PLUGIN:RenderScreenspaceEffects();eq(sequence[1],'world');eq(sequence[2],'lens')
 -- Alive critical players must not run the decorative full-screen pipeline.
 local c=LocalPlayer();local before=#sequence
 ix.Downed={Active=function() return critical end,CrawlWindow=function() return crawl end}
 critical=true;assert(not V.Visible());PLUGIN:RenderScreenspaceEffects();eq(#sequence,before)
 crawl=true;assert(V.Visible());PLUGIN:RenderScreenspaceEffects();eq(#sequence,before+2)
 critical=false;crawl=false
 c.vars.knocked=true;assert(not V.Visible());PLUGIN:RenderScreenspaceEffects();eq(#sequence,before+2)
 c.vars.knocked=false;c.vars.ragdoll=42;assert(not V.Visible());PLUGIN:RenderScreenspaceEffects();eq(#sequence,before+2)
 V.DrawNVG({},1);eq(brightness,0);eq(#sequence,before+2)
 c.vars.ragdoll=0;assert(V.Visible());PLUGIN:RenderScreenspaceEffects();eq(#sequence,before+4)
 `,setup+`
 function RealTime() return clock end
 CLIENT=true;SERVER=false;values={fieldLens=false};grades=0;rebuilds=0;worldBlooms=0
 ix.gui={};ix.option={Get=function(k,d) if values[k]==nil then return d end return values[k] end}
 local c={valid=true,Alive=function() return true end,GetCharacter=function() return {} end,GetNWFloat=function() return 0 end,GetNetVar=function() return false end}
 c.vars={};function c:GetLocalVar(k,d) if self.vars[k]~=nil then return self.vars[k] end return d end
 function LocalPlayer() return c end;gui={IsGameUIVisible=function() return false end}
 function FrameTime() return .1 end;function EyePos() return Vector() end
 function Lerp(t,a,b) return a+(b-a)*t end
 render={GetLightColor=function() return Vector(.1,.1,.1) end}
 ArcticNVGs_Lamp={SetBrightness=function(_,v) brightness=v end,SetEnableShadows=function() end,Update=function() end}
 function ArcticNVGs_RebuildLamp() rebuilds=rebuilds+1 end
 function DrawColorModify(t) grades=grades+1;assert(t['$pp_colour_contrast']<=1.6) end
 function DrawBloom(threshold,amount) if threshold==.75 then worldBlooms=worldBlooms+1;assert(amount>0 and amount<=.5) end end
 `);
suite('Flashlight keeps native binding, refuses unavailable equipment and clears after death',
 ['ixhl2rp/plugins/flashlight/sh_plugin.lua'], `
 local c={valid=true,on=false,alive=true,has=true,GetCharacter=function() return {} end,IsRestricted=function() return false end,IsCombine=function() return false end,EmitSound=function() end}
 function c:Alive() return self.alive end;function c:HasItem() return self.has end
 function c:GetNWBool() return self.on end;function c:SetNWBool(_,v) self.on=v end
 eq(PLUGIN:PlayerSwitchFlashlight(c,true),false);eq(c.on,true)
 clock=clock+1;PLUGIN:PlayerSwitchFlashlight(c,true);eq(c.on,false)
 clock=clock+1;c.has=false;PLUGIN:PlayerSwitchFlashlight(c,true);eq(c.on,false)
 c.on=true;PLUGIN:PlayerDeath(c);eq(c.on,false)
 c.on=true;c.alive=false;allPlayers={c};timers.ixFieldFlashlightCheck();eq(c.on,false)
 `,setup);
};
