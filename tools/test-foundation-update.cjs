const fs=require('fs'),path=require('path');
const {normalize}=require('./glua.cjs');
module.exports=suite=>{
const shared=`
 function isbool(v) return type(v)=='boolean' end
 function string.Explode(sep,s) local out={};for v in (s..sep):gmatch('(.-)'..sep) do out[#out+1]=v end;return out end
 ix.util={Include=function() end};ix.command={Add=function() end}
 net.packets={};net.Start=function(name) net.sent=name end;net.WriteString=function(v) net.out=v end;net.WriteBool=function(v) net.enabled=v end;net.WriteUInt=function() end
 net.Send=function(p) net.to=p;net.packets[#net.packets+1]={to=p,text=net.out,enabled=net.enabled} end;net.Broadcast=function() net.to='all' end;net.SendToServer=function() end
 function PLUGIN:SetData(data) self.saved=table.Copy(data) end;function PLUGIN:GetData() return self.saved end
 admin={valid=true,IsAdmin=function() return true end,Notify=function() end};guest={valid=true,IsAdmin=function() return false end}
 FACTION_MTF=3;guestFaction=3
 function admin:GetCharacter() return {GetFaction=function() return 1 end} end
 function guest:GetCharacter() if not guestNoCharacter then return {GetFaction=function() return guestFaction end} end end
 allPlayers={admin,guest}
 `;
const hud=['ixhl2rp/plugins/status_display/sh_plugin.lua','ixhl2rp/plugins/status_display/sv_status.lua'];
suite('Status HUD handles animated/reduced-motion rendering, narrow displays and hidden menus',
 ['tools/status-preview-fixture.lua',hud[0],'ixhl2rp/plugins/status_display/cl_status.lua'],`
 statusText=string.rep('Щ',64)..'\\n'..string.rep('W',64);net.handlers.ixStatusHUD();PLUGIN:HUDPaint()
 clock=22;ClearStatusDrawing();PLUGIN:HUDPaint();assert(StatusDrawCount()>200)
 assert(statusStats.glyphs>0);eq(statusStats.clippedGlyphs,0)
 eq(statusStats.rects,0);assert(statusStats.lines>40)
 local curved=0;for _ in pairs(statusStats.rotatedFonts) do curved=curved+1 end;eq(curved,3)
 local matrices,fonts=statusStats.matrices,statusStats.fonts
 ClearStatusDrawing();PLUGIN:HUDPaint();eq(statusStats.matrices,matrices);eq(statusStats.fonts,fonts)
 for _,size in ipairs({{1280,720},{2560,1080},{1024,768}}) do
  screenW,screenH=size[1],size[2];reduced=true;ClearStatusDrawing();PLUGIN:HUDPaint();assert(StatusDrawCount()>200)
  eq(statusStats.clippedGlyphs,0)
 end
 statusText=string.rep(string.rep('Щ',64)..'\\n',7)..string.rep('W',64);net.handlers.ixStatusHUD()
 for _,size in ipairs({{1280,720},{1920,1080},{1024,768}}) do
  screenW,screenH=size[1],size[2];ClearStatusDrawing();PLUGIN:HUDPaint();eq(statusStats.rects,0)
  eq(statusStats.clippedGlyphs,0)
 end
 ix.gui.menu={valid=true};ClearStatusDrawing();PLUGIN:HUDPaint();eq(StatusDrawCount(),0)
 ix.gui.menu=nil
 for _,faction in ipairs({1,2,0}) do statusFaction=faction;ClearStatusDrawing();PLUGIN:HUDPaint();eq(StatusDrawCount(),0) end
 statusFaction=3;ClearStatusDrawing();PLUGIN:HUDPaint();assert(StatusDrawCount()>200)
 statusNoCharacter=true;ClearStatusDrawing();PLUGIN:HUDPaint();eq(StatusDrawCount(),0)
 `);
suite('Status HUD validates Cyrillic limits and rejects unauthorized/stale updates; save, disable and late-join sync',hud,`
 eq(PLUGIN:ValidateStatus(string.rep('Я',64)),string.rep('Я',64));eq(PLUGIN:ValidateStatus(string.rep('Я',65)),nil)
 eq(PLUGIN:ValidateStatus(string.char(255)),nil);eq(PLUGIN:ValidateStatus('bad'..string.char(0)),nil)
 eq(PLUGIN:ValidateStatus(string.rep('a\\n',8)..'a'),nil)
 eq(PLUGIN:SetStatus(guest,'FORGED',true,0),false)
 eq(PLUGIN:SetStatus(admin,'Сектор А\\nГотовность 2',true,0),true);eq(net.to,guest);eq(PLUGIN.saved.text,PLUGIN.status.text)
 eq(net.packets[1].to,admin);eq(net.packets[1].text,'');eq(net.packets[1].enabled,false)
 eq(net.packets[2].to,guest);eq(net.packets[2].text,PLUGIN.status.text);eq(net.packets[2].enabled,true)
 eq(PLUGIN:SetStatus(admin,'stale',true,0),false);eq(PLUGIN.status.revision,1)
 net.to=nil;PLUGIN:OpenStatusEditor(guest);eq(net.to,nil)
 net.handlers.ixStatusHUDReady(0,guest);eq(net.to,guest);eq(net.out,'Сектор А\\nГотовность 2')
 PLUGIN:LoadData();eq(PLUGIN.status.text,'Сектор А\\nГотовность 2')
 guestFaction=2;PLUGIN:Think();eq(net.to,guest);eq(net.out,'');eq(net.enabled,false)
 local sent=#net.packets;clock=clock+1;PLUGIN:Think();eq(#net.packets,sent)
 guestFaction=3;clock=clock+1;PLUGIN:Think();eq(net.out,PLUGIN.status.text);eq(net.enabled,true)
 guestNoCharacter=true;PLUGIN:PlayerLoadedCharacter(guest);eq(net.out,'');eq(net.enabled,false)
 guestNoCharacter=false;guestFaction=1;PLUGIN:PlayerLoadedCharacter(guest);eq(net.out,'');eq(net.enabled,false)
 PLUGIN:OpenStatusEditor(admin);eq(net.to,admin);eq(net.out,PLUGIN.status.text);eq(PLUGIN:CanSeeStatus(admin),false)
 eq(PLUGIN:SetStatus(admin,'',false,1),true);eq(PLUGIN.saved.enabled,false);eq(PLUGIN.saved.text,'')
 `,shared);
const entity=shared+`
 local V={};V.__index=V
 function Vector(x,y,z) return setmetatable({x=x or 0,y=y or 0,z=z or 0},V) end
 function V:DistToSqr(b) return (self.x-b.x)^2+(self.y-b.y)^2+(self.z-b.z)^2 end
 function V:WithinAABox() return true end
 V.__add=function(a,b) return Vector(a.x+b.x,a.y+b.y,a.z+b.z) end
 V.__sub=function(a,b) return Vector(a.x-b.x,a.y-b.y,a.z-b.z) end
 V.__mul=function(a,b) return Vector(a.x*b,a.y*b,a.z*b) end
 function VectorRand() return {GetNormalized=function() return Vector(0,0,1) end} end
 function Angle() return {} end
 function math.Rand(a,b) return (a+b)/2 end
 function E(class,hp)
  local e={valid=true,class=class,hp=hp or 100,max=hp or 100,pos=Vector(),HasHealthRegeneration=true}
  function e:GetClass() return self.class end;function e:Health() return self.hp end;function e:SetHealth(v) self.hp=v end;function e:GetMaxHealth() return self.max end
  function e:GetPos() return self.pos end;function e:SetPos(v) self.pos=v end;function e:GetAngles() return {} end;function e:SetAngles() end
  function e:Spawn() end;function e:Activate() end;function e:Remove() self.valid=false end;function e:IsOnFire() return self.fire or false end
  function e:WaterLevel() return self.water or 0 end;function e:Ignite() self.fire=true end;function e:IsNPC() return self.class~='player' end
  function e:IsPlayer() return self.class=='player' end;function e:EmitSound() end
  function e:TakeDamageInfo(d) PLUGIN:EntityTakeDamage(self,d);self.hp=self.hp-d:GetDamage() end
  return e
 end
 DMG_BURN=8;DMG_SLOWBURN=16;MASK_SOLID=1;MASK_SOLID_BRUSHONLY=2
 function DamageInfo()
  local d={n=0,t=0};function d:SetDamage(v) self.n=v end;function d:GetDamage() return self.n end
  function d:SetDamageType(v) self.t=v end;function d:IsDamageType(v) return self.t==v end
  function d:SetAttacker(v) self.attacker=v end;function d:GetAttacker() return self.attacker end;function d:SetInflictor(v) self.inflictor=v end;return d
 end
 function damage(n,t) local d=DamageInfo();d:SetDamage(n);d:SetDamageType(t);return d end
 game={GetWorld=function() return E('world') end}
 ents.Create=function(c) return E(c) end;ents.GetAll=function() return {} end
 util.TraceLine=function(t) if t.start.z==24 then return {Hit=false} end;return {Hit=true,HitWorld=true,HitNormal=Vector(0,0,1),HitPos=Vector(192,0,0)} end
 util.TraceHull=function() return {Hit=false} end
 `;
const scp=['ixhl2rp/plugins/scp610_control/sh_plugin.lua','ixhl2rp/plugins/scp610_control/sv_control.lua'];
suite('SCP610 regeneration/fire tuning is scoped, finite, persistent and admin-controlled',scp,`
 PLUGIN:LoadData();eq(PLUGIN.settings.paused,false);eq(PLUGIN.settings.regeneration,0)
 eq(PLUGIN:ValidateSetting('regeneration',0/0),nil);eq(PLUGIN:ValidateSetting('maxGrowth',999),128)
 local npc=E('npc_vj_scp_610_6',1000);PLUGIN:Adapt(npc);eq(npc.HasHealthRegeneration,false)
 local bullet=damage(20,2);PLUGIN:EntityTakeDamage(npc,bullet);eq(bullet.n,20)
 local fire=damage(12,DMG_BURN);PLUGIN:EntityTakeDamage(npc,fire);eq(fire.n,180);eq(npc.ix610Sterilized,true)
 local normal=E('npc_zombie');local d=damage(12,DMG_BURN);PLUGIN:EntityTakeDamage(normal,d);eq(d.n,12);eq(normal.HasHealthRegeneration,true)
 local settings=table.Copy(PLUGIN.settings);settings.maxGrowth=3
 eq(PLUGIN:UpdateSettings(guest,settings,0),false);eq(PLUGIN:UpdateSettings(admin,settings,99),false)
 eq(PLUGIN:UpdateSettings(admin,settings,0),true);eq(PLUGIN.saved.settings.maxGrowth,3)
 PLUGIN.settings.regeneration=10;npc.hp=300;clock=100;PLUGIN:ControlTick();eq(npc.hp,300)
 `,entity);
suite('SCP610 automatic growth respects pause, caps, interval, walls and scorched ground; conversions are opt-in',scp,`
 local parent=E('npc_vj_scp_610_biomass');PLUGIN:Adapt(parent)
 eq(PLUGIN:TryGrowth(parent),false);clock=200
 PLUGIN.settings.paused=true;eq(PLUGIN:TryGrowth(parent),false);PLUGIN.settings.paused=false
 PLUGIN.settings.maxGrowth=1;eq(PLUGIN:TryGrowth(parent),false);PLUGIN.settings.maxGrowth=2
 eq(PLUGIN:TryGrowth(parent),true);local growth,npcs=PLUGIN:Counts();eq(growth,2);eq(npcs,0)
 eq(PLUGIN:TryGrowth(parent),false);eq(PLUGIN:CanSpawn('npc_vj_scp_610_biomass'),false)
 local victim=E('npc_citizen');parent:OnKilledEnemy(victim);eq(victim.valid,true)
 PLUGIN.settings.conversion=true;parent:OnKilledEnemy(victim);eq(victim.valid,false)
 local wall=E('npc_vj_scp_610_pillar');PLUGIN:Adapt(wall);PLUGIN.settings.maxGrowth=24;clock=500
 util.TraceHull=function() return {Hit=true} end;eq(PLUGIN:TryGrowth(wall),false)
 util.TraceHull=function() return {Hit=false} end;clock=800;PLUGIN.scorched={{pos=Vector(192,0,0),expires=1000}};eq(PLUGIN:TryGrowth(wall),false)
 local count=PLUGIN:Purge();assert(count>=3);eq(PLUGIN.settings.paused,true);eq(next(PLUGIN.entities),nil)
 `,entity);
suite('SCP610 death callbacks cannot recreate burned entities; pending corpses cancel on fire or pause',scp,`
 local parent=E('npc_vj_scp_610_biomass');PLUGIN:Adapt(parent);parent:OnDeath(nil,nil,'Finish');eq(PLUGIN:Counts(),1)
 local dead=E('npc_vj_scp_610_6');PLUGIN:Adapt(dead);local corpse=E('prop_ragdoll')
 dead:CustomOnDeath_AfterCorpseSpawned(nil,nil,corpse);eq(PLUGIN.pending[corpse],nil)
 PLUGIN.settings.deathSpawns=true;dead:CustomOnDeath_AfterCorpseSpawned(nil,nil,corpse);assert(PLUGIN.pending[corpse])
 PLUGIN:EntityTakeDamage(corpse,damage(1,DMG_BURN));eq(PLUGIN.pending[corpse],nil)
 PLUGIN:EntityTakeDamage(dead,damage(1,DMG_BURN));dead:CustomOnDeath_AfterCorpseSpawned(nil,nil,corpse);eq(PLUGIN.pending[corpse],nil)
 local tripod=E('npc_vj_scp_610_tripod');tripod.CustomOnKilled=function() error('burned tripod exploded') end
 PLUGIN:Adapt(tripod);PLUGIN:EntityTakeDamage(tripod,damage(1,DMG_BURN));tripod:CustomOnKilled()
 `,entity);
suite('Flame projectile supports touch and physical collisions, bounded range, damage cadence and extinction',scp,`
 local owner=E('player');local projectile=E('arc9_codww2_flamethrower_fx');function projectile:GetOwner() return owner end
 projectile.SpawnPosition=Vector();PLUGIN:AdaptProjectile(projectile)
 local target=E('npc_vj_scp_610_tripod',3000);projectile:StartTouch(target);eq(projectile.valid,false);eq(target.hp,2460)
 PLUGIN:FlameTouch(projectile,target);eq(target.hp,2460)
 clock=clock+.6;PLUGIN:BurnTick();eq(target.hp,1920)
 target.water=1;clock=clock+.6;PLUGIN:BurnTick();eq(PLUGIN.burns[target],nil)
 local p=E('arc9_codww2_flamethrower_fx');p.GetOwner=projectile.GetOwner;PLUGIN:AdaptProjectile(p)
 local t=E('npc_vj_scp_610_1');p:PhysicsCollide({HitEntity=t});eq(t.hp,4)
 p.SpawnPosition=Vector();p.pos=Vector(1000,0,0);clock=clock+1;PLUGIN:FlameTouch(p,t);eq(t.hp,4)
 `,entity);
suite('Flamethrower fuel conserves partial canisters and blocks foreign inventory, active firing and overflow',
 ['ixhl2rp/plugins/scp610_control/items/thermal_fuel.lua'],`
 local fuel=setmetatable({player=admin,data={fuel=1000}},{__index=ITEM})
 function fuel:GetData(k,d) if self.data[k]~=nil then return self.data[k] end;return d end;function fuel:SetData(k,v) self.data[k]=v end
 function fuel:GetEntity() end;function fuel:Remove() self.removed=true end
 local bound={isFlamethrower=true,IsEquipped=function() return true end,SetData=function(self,k,v) self[k]=v end}
 local gun={valid=true,ixInventoryReady=true,ixItem=bound,clip=750,GetOwner=function() return admin end,GetClass=function() return 'arc9_codww2_flamethrower' end}
 function gun:Clip1() return self.clip end;function gun:SetClip1(v) self.clip=v end;function gun:SetLoadedRounds(v) self.loaded=v end
 admin.Alive=function() return true end;admin.GetCharacter=function() return {} end;admin.GetItems=function() return {fuel} end
 admin.GetActiveWeapon=function() return gun end;admin.KeyDown=function() return false end;admin.EmitSound=function() end
 CLIENT=true;SERVER=false;gun.ixInventoryReady=nil;gun.ixItem=nil;eq(ITEM.functions.refuel.OnCanRun(fuel),true)
 CLIENT=false;SERVER=true;eq(fuel:RefuelWeapon(),nil);gun.ixInventoryReady=true;gun.ixItem=bound
 eq(ITEM.functions.refuel.OnCanRun(fuel),true);ITEM.functions.refuel.OnRun(fuel);eq(gun.clip,1000);eq(fuel:GetFuel(),750);eq(bound.ammo,1000)
 gun.ARC9CODWW2UnlimitedFuel=true;gun.clip=500;eq(fuel:RefuelWeapon(),nil);ITEM.functions.refuel.OnRun(fuel);eq(fuel:GetFuel(),750)
 gun.ARC9CODWW2UnlimitedFuel=nil;gun.clip=0;clock=clock+2;ITEM.functions.refuel.OnRun(fuel);eq(gun.clip,750);eq(fuel:GetFuel(),0);eq(fuel.removed,true)
 fuel.data.fuel=1000;gun.clip=500;admin.KeyDown=function() return true end;eq(fuel:RefuelWeapon(),nil)
 admin.KeyDown=function() return false end;admin.GetItems=function() return {} end;eq(fuel:RefuelWeapon(),nil)
 `,shared+`ITEM={functions={},AddData=function() end};ix.transmit={owner=1}`);
// Reuse the existing zone fixture, including real init and cleanup methods.
let zones=fs.readFileSync(path.join(__dirname,'test-zones.cjs'),'utf8');
let zoneSetup=zones.match(/const setup = `([\s\S]*?)`;/)[1]+zones.match(/const infectionSetup=setup\+`([\s\S]*?)`;/)[1];
suite('Burning clears dormant infestation without loot, persists removal and respects indestructible zones',
 ['ixhl2rp/plugins/infectionzone/sv_plugin.lua'],`
 local function plant(name) local p={valid=true,ixInfectionFlora=name,GetPos=function() return Vector() end,EmitSound=function() end,Remove=function(self) self.valid=false end};return p end
 local a,b=plant('zone'),plant('zone');PLUGIN.flora.zone={[a]=true,[b]=true};PLUGIN.remaining.zone=25;PLUGIN.zombies.zone={}
 ix.area.stored.zone={type='infection',properties={}};PLUGIN:EntityTakeDamage(a,burn);eq(PLUGIN.remaining.zone,24);assert(ix.area.stored.zone)
 PLUGIN:EntityTakeDamage(b,burn);eq(ix.area.stored.zone,nil);eq(PLUGIN.remaining.zone,nil)
 local c=plant('permanent');PLUGIN.flora.permanent={[c]=true};PLUGIN.remaining.permanent=25;ix.area.stored.permanent={type='infection',properties={indestructible=true}}
 PLUGIN:EntityTakeDamage(c,burn);assert(ix.area.stored.permanent);eq(PLUGIN.remaining.permanent,25)
 local d=plant('__waste');PLUGIN.flora.__waste={[d]=true};PLUGIN:EntityTakeDamage(d,burn);eq(d.valid,false)
 `,zoneSetup+`
 DMG_BURN=8;DMG_SLOWBURN=16
 burn={GetDamage=function() return 60 end,GetAttacker=function() end,IsDamageType=function(_,v) return v==8 end}
 function EffectData() return {SetOrigin=function() end,SetNormal=function() end} end
 function VectorRand() return {GetNormalized=function() return Vector(0,0,1) end} end
 util.Effect=function() end
 `);
suite('Infestation admin pause stops new flora and zombies while gas can be disabled independently',
 ['ixhl2rp/plugins/infectionzone/sv_plugin.lua'],`
 ix.plugin.list.scp610_control={settings={paused=true,zoneGas=false}}
 ix.area.stored.test={type='infection',properties={},startPosition=Vector(-1,-1,-1),endPosition=Vector(1,1,1)}
 local c={Alive=function() return true end,GetCharacter=function() return {} end,GetPos=function() return Vector() end,OBBCenter=function() return Vector() end,
 GetNetVar=function() return true end,SetNetVar=function(_,k,v) eq(v,false) end}
 allPlayers={c};PLUGIN.UpdateToxicExposure=function(_,p,inside) eq(inside,false) end
 ents.Create=function() error('spawn during admin pause') end
 PLUGIN:InfectionTick();eq(PLUGIN.remaining.test,25)
 `,zoneSetup+`
 PLUGIN.defaults.zombieMax=6;PLUGIN.defaults.zombieInterval=8;PLUGIN.defaults.floraMax=40;PLUGIN.defaults.floraInterval=5;PLUGIN.defaults.infestationTotal=25;PLUGIN.defaults.activeRadius=2048
 `);
suite('Terminal compressed edits accept full articles and reject oversized or malformed messages',
 ['ixhl2rp/plugins/foundation_network/sv_network.lua'],`
 local called=0;PLUGIN.Action=function(_,p,action,payload) called=called+1;eq(action,'editWeb');eq(payload.entity,terminal) end
 net.handlers.ixFoundationRequest(1000,admin);eq(called,1)
 clock=clock+1;size=60001;net.handlers.ixFoundationRequest(1000,admin);eq(called,1)
 clock=clock+1;size=100;raw=string.rep('a',100001);net.handlers.ixFoundationRequest(1000,admin);eq(called,1)
 clock=clock+1;raw=nil;net.handlers.ixFoundationRequest(1000,admin);eq(called,1)
 `,shared+`
 PLUGIN.Text=function(v) return v end;PLUGIN.sessions={};terminal={valid=true};size=100;raw=string.rep('a',64000)
 net.ReadString=function() return 'editWeb' end;net.ReadUInt=function() return size end;net.ReadEntity=function() return terminal end;net.ReadData=function() return 'packed' end
 util.Decompress=function(_,bound) eq(bound,100000);return raw end;util.JSONToTable=function() return {} end
 `);
};
