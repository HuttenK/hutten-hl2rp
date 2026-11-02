const fs=require('fs'),path=require('path');
module.exports=suite=>{
 const files=['helix/gamemode/core/libs/sh_anims.lua','helix/gamemode/core/hooks/sh_hooks.lua'];
 const source=files.map(p=>fs.readFileSync(path.join(__dirname,'..',p),'utf8')).join('\n');
 const enums=[...new Set(source.match(/\b(?:ACT|IN|MOVETYPE)_[A-Z0-9_]+\b/g))].map((n,i)=>`${n}=${i+1}`).join('\n');
 const setup=enums+`
 function Vector(x,y,z) return {x=x,y=y,z=z} end
 function Angle(p,y,r) return {p=p,y=y,r=r} end
 local originalMeta=FindMetaTable
 function FindMetaTable(name)
  if name=='Vector' then return {Angle=function() return {0,0,0} end} end
  return originalMeta(name)
 end
 math.NormalizeAngle=function(n) return n end
 GM={BaseClass={}}
 for _,name in ipairs({'HandlePlayerNoClipping','HandlePlayerDriving','HandlePlayerVaulting','HandlePlayerJumping','HandlePlayerSwimming','HandlePlayerDucking'}) do
  GM.BaseClass[name]=function() return false end
 end
 GM.BaseClass.TranslateActivity=function(_,_,act) return act end
 function subject()
  local p={valid=true,model='models/test/citizen.mdl',count=100,selections=0,ixAnimModelClass='citizen_male'}
  function p:GetModel() return self.model end
  function p:GetSequenceCount() return self.count end
  function p:GetTable() return self end
  function p:GetActiveWeapon() return nil end
  function p:GetNetVar(k) if k=='forcedSequence' then return self.forced end end
  function p:GetSequence() return 99 end
  function p:SetCycle(n) self.cycle=n end
  function p:EyeAngles() return {0,0,0} end
  function p:SetPoseParameter() end
  function p:IsWepRaised() return false end
  function p:OnGround() return true end
  function p:GetMoveType() return MOVETYPE_WALK end
  function p:InVehicle() return false end
  function p:LookupSequence() return self.named or 42 end
  function p:SelectWeightedSequence()
   self.selections=self.selections+1
   return self.missing and -1 or 40+self.selections%2
  end
  p.ixAnimResolvedModel=p.model
  return p
 end
 `;
 for(const realm of ['server','client']){
  const realmSetup=setup+`\nSERVER=${realm==='server'} CLIENT=${realm==='client'}\n`;
  suite(`Core animation resolver loads without ARC9 and keeps stable, per-model choices (${realm})`,files,`
   local p=subject();local resolve=ix.anim.ResolveMainSequence
   eq(resolve(p,100,-1),41)
   for frame=1,120 do eq(resolve(p,100,-1),41) end
   eq(p.selections,1)
   eq(resolve(p,101,-1),40);eq(p.selections,2)
   p.count=101;resolve(p,101,-1);eq(p.selections,3)
   p.model='models/test/other.mdl';resolve(p,101,-1);eq(p.selections,4)
   eq(resolve(p,nil,0),0);eq(p.ixMainSequenceChoice,nil)
   p.missing=true;eq(resolve(p,102,33),33);eq(p.ixMainSequenceChoice,nil)
   eq(resolve(p,102,-1),nil);eq(p.ixMainSequenceChoice,nil)
   p.missing=false;eq(resolve(p,102,-1),41)
   local other=subject();eq(resolve(other,102,-1),41);eq(other.selections,1)
  `,realmSetup);
  suite(`CalcMainActivity handles numeric, named, forced and crawl poses without an addon (${realm})`,files,`
   local p=subject();p.ixAnimTable={[ACT_MP_STAND_IDLE]={100,100},[ACT_MP_WALK]={101,101}}
   local speed=0;local velocity={Length2DSqr=function() return speed end}
   local act,seq=GM:CalcMainActivity(p,velocity);eq(act,ACT_MP_STAND_IDLE);eq(seq,41)
   for frame=1,20 do local _,s=GM:CalcMainActivity(p,velocity);eq(s,41) end
   eq(p.selections,1)
   speed=1;act,seq=GM:CalcMainActivity(p,velocity);eq(act,ACT_MP_WALK);eq(seq,40)
   speed=0;p.ixAnimTable[ACT_MP_STAND_IDLE]={'sit','sit'}
   act,seq=GM:CalcMainActivity(p,velocity);eq(seq,42);eq(p.ixMainSequenceChoice,nil)
   p.named=0;act,seq=GM:CalcMainActivity(p,velocity);eq(seq,0)
   p.named=-1;act,seq=GM:CalcMainActivity(p,velocity);eq(seq,-1)
   p.forced=0;act,seq=GM:CalcMainActivity(p,velocity);eq(act,-1);eq(seq,0);eq(p.cycle,0)
   p.forced=nil;ix.Downed={CrawlActivity=function() return 76 end}
   act,seq=GM:CalcMainActivity(p,velocity);eq(act,ACT_MP_CROUCH_IDLE);eq(seq,76)
  `,realmSetup);
 }
};
