const fs=require('fs');
const path=require('path');
const {normalize}=require('./glua.cjs');
const compatibility='ixhl2rp/plugins/arc9_eft_grenade_network.lua';
const reload=normalize(fs.readFileSync(path.join(__dirname,'..',compatibility),'utf8'));

module.exports=function(suite){
 for(const type of ['m18','m18y']){
  const entity='tools/fixtures/eft-smoke-upstream/arc9_eft_grenade_'+type+'.lua';
  suite('EFT '+type+': installed smoke ignition, particle lifetime and registry cleanup survive missing support table',
   [compatibility,entity], `
    local grenade=setmetatable({valid=true,StopParticles=function(self) self.stopped=true end},{__index=ENT})
    grenade:Initialize(); clock=clock+2
    grenade:Think()
    eq(grenade.Defused,true); eq(ARC9EFT.Smokeslist[1],grenade)
    eq(particles.smoke_exhaust_01,1); eq(#delayed,1); eq(delayed[1].delay,90)
    grenade:Think(); eq(#ARC9EFT.Smokeslist,1); eq(particles.smoke_exhaust_01,1)
    delayed[1].fn(); eq(grenade.stopped,true)
    -- Reloading compatibility must preserve another addon's table and entries.
    local registry=ARC9EFT.Smokeslist; ARC9EFT.externalValue=42
    reloadCompatibility(); eq(ARC9EFT.Smokeslist,registry); eq(ARC9EFT.externalValue,42)
    local survivor=setmetatable({valid=true,StopParticles=function() error('removed entity callback') end},{__index=ENT})
    survivor:Initialize(); clock=clock+2; survivor:Think()
    eq(#registry,2); eq(particles.smoke_exhaust_01,2)
    grenade.valid=false
    timers.ixEFTSmokeRegistryCleanup()
    eq(#registry,1); eq(registry[1],survivor)
    survivor.valid=false; delayed[2].fn(); timers.ixEFTSmokeRegistryCleanup(); eq(#registry,0)
    -- The shim can also load without any EFT namespace yet.
    ARC9EFT=nil; reloadCompatibility(); assert(istable(ARC9EFT.Smokeslist))
    `, `
    SERVER=false; CLIENT=true; ENT={}; ARC9EFT={}; particles={}; delayed={}; timers={}
    function AddCSLuaFile() end
    function Color(...) return {...} end
    killicon={Add=function() end}; PATTACH_ABSORIGIN_FOLLOW=1
    function PrecacheParticleSystem() end
    function ParticleEffectAttach(name) particles[name]=(particles[name] or 0)+1 end
    timer.Simple=function(delay,fn) delayed[#delayed+1]={delay=delay,fn=fn} end
    timer.Create=function(name,delay,repetitions,fn) eq(delay,5); eq(repetitions,0); timers[name]=fn end
    function reloadCompatibility()
    ${reload}
    end
    `);
  suite('EFT '+type+': compatibility retains native server smoke trails, timers and explosion channel',
   [compatibility,entity], `
    local grenade=setmetatable({valid=true,SpawnTime=clock,Owner={},
     EmitSound=function(self,sound) self.sound=sound end,GetPos=function() return {} end},{__index=ENT})
    grenade:StartSmoke()
    eq(networks.arc9eftexplosion,true); eq(ARC9EFT,nil); eq(timerCount,0)
    eq(grenade.Defused,true); eq(grenade.sound,grenade.closeSound); near(grenade.nextloopsound,clock+.9)
    eq(#created,2); eq(created[1].class,'ai_sound'); eq(created[2].class,'env_smoketrail')
    eq(created[2].parent,grenade); eq(created[2].spawned,true)
    eq(created[2].values.emittime,'90')
    eq(created[2].values.startcolor,${JSON.stringify(type==='m18y'?'130 130 0':'0 130 0')})
    eq(created[2].fire[1],'kill'); eq(created[2].fire[3],91)
    `, `
    ENT={}; ARC9EFT=nil; networks={}; timerCount=0; created={}
    function AddCSLuaFile() end; function PrecacheParticleSystem() end
    util.AddNetworkString=function(name) networks[name]=true end
    timer.Create=function() timerCount=timerCount+1 end
    ents.Create=function(class)
     local entity={class=class,values={},SetKeyValue=function(self,key,value) self.values[key]=value end,
      SetOwner=function() end,SetPos=function() end,SetParent=function(self,parent) self.parent=parent end,
      Spawn=function(self) self.spawned=true end,Fire=function(self,...) self.fire={...} end}
     created[#created+1]=entity; return entity
    end
    `);
 }
};
