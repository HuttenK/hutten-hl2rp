// Executes the mounted addons' actual callbacks without changing their files.
const fs=require('fs'),path=require('path'),runtime=require('./glua-runtime.cjs');
const {run,finish}=require('./restored-test-runner.cjs');
const root=process.argv[2];if(!root)throw Error('Supply the read-only SCP addon directory');
let base;
require('./test-scp-medical.cjs')((name,files,assertions,setup)=>{if(!base)base=setup;});
const read=relative=>fs.readFileSync(path.join(root,relative),'utf8').replace(/\r\n/g,'\n');
const cb=name=>'SCP CB SNPCS/lua/entities/'+name+'/init.lua';
function fn(file,name){
 const source=read(file),start=source.indexOf('function ENT:'+name+'('),end=source.indexOf('\n-----',start);
 if(start<0||end<0)throw Error('Native callback boundary not found: '+name);
 return runtime(source.slice(start,end));
}
const soundBoundary=`function npc:EmitSound() end;function npc:SelectFromTable(t) return t[1] end;npc.tbl_Sounds={}`;
for(const name of ['npc_cpt_scp_008_1','npc_cpt_scp_1048','npc_cpt_scp_049','npc_cpt_scp_106']){
 run('Actual '+name+' hit callback cannot start native player execution or teleport timers',base+`
 local p=newPatient();local npc=scpNPC('${name}');ENT=npc
 ${soundBoundary}
 `+fn(cb(name),'OnHitEntity')+`
 local count=#timers;ix.SCPMedicine.Patch(npc);npc:OnHitEntity({p})
 eq(#timers,count);eq(p.SCP_Infected_008,nil);eq(p.SCP_Inflicted_1048a,nil)
 `);
}
run('Actual 008 gas Infect callback becomes a saved, curable condition',base+`
 local p=newPatient();local npc=scpNPC('npc_cpt_scp_008');ENT=npc
 `+fn(cb('npc_cpt_scp_008'),'Infect')+`
 ix.SCPMedicine.Patch(npc);local count=#timers;npc:Infect(p)
 eq(#timers,count);assert(findCondition(p.character.hp,'scp_infection'))
 ix.Medicine.Apply(medicalItem(p,'scp_008_serum'),p,p,2)
 eq(findCondition(p.character.hp,'scp_infection'),nil)
 `);
run('Actual 106 grab events preserve the floor position and leave a living treatable casualty',base+`
 local p=newPatient();local npc=scpNPC('npc_cpt_scp_106');ENT=npc
 function npc:GetEnemy() return p end
 function p:SetPos() error('native pull must not move patient below the floor') end
 `+fn(cb('npc_cpt_scp_106'),'HandleEvents')+`
 ix.SCPMedicine.Patch(npc);npc:HandleEvents('grab','pull');npc:HandleEvents('grab','kill')
 assert(p.critical);assert(findCondition(p.character.hp,'scp_corrosion'));eq(npc.GrabbedVictim,NULL)
 npc:HandleEvents('grab','kill')
 `);
const combat=runtime(fs.readFileSync('ixhl2rp/plugins/!healthsystem/sv_combat.lua','utf8'));
run('Actual CPT damage reaches medical 939 injuries and nonfatal 173 paralysis, preserving native hit sounds',base+'\ndo\n'+combat+'\nend\n'+`
 local p=newPatient();p.pos=Vector(100,0,0);local npc=scpNPC('npc_cpt_scp_939_a');npc.IsPossessed=true;ENT=npc
 npc.ViewAngle=90;npc.tbl_Sounds={};${soundBoundary}
 function npc:GetForward() return Vector(1,0,0) end
 function npc:Visible() return true end
 function npc:CustomChecksBeforeDamage() return true end
 function npc:OnHitEntity() end;function npc:OnDoDamage() end
 function p:OBBCenter() return Vector(0,0,40) end
 function p:NearestPoint() return self:GetPos()+self:OBBCenter() end
 function p:ViewPunch() end
 function p:LastHitGroup() error('must not use stale bullet hitgroup for CPT melee') end
 function p:TakeDamageInfo(d) assert(PLUGIN:EntityTakeDamage(self,d)) end
 function AdaptCPTBaseDamage(d) return d end
 table_insert=table.insert;table_HasValue=function() return false end;DMG_FROST=99
 function table.Empty(t) for k in pairs(t) do t[k]=nil end end
 ents.FindInSphere=function() return {p} end
 function DamageInfo()
  local d=scpDamage(npc,0)
  function d:SetAttacker(v) self.attacker=v end;function d:SetInflictor(v) self.inflictor=v end
  function d:SetDamageType(v) self.damageType=v end;function d:SetDamagePosition(v) self.position=v end
  return d
 end
 util.TraceLine=function() return {Entity=p,HitGroup=5} end
 `+fn('CPTBase/lua/entities/npc_cpt_base/init.lua','DoDamage')+`
 npc:DoDamage(200,90,DMG_SLASH)
 eq(p.character.data.amputation,'rarm');assert(findCondition(p.character.hp,'cut'));assert(p.character.hp:GetBleedRate()>0)
 p.character.hp:Reset();p.character.data.amputation=nil;p.critical=nil;p.vars={}
 npc.class='npc_cpt_scp_173';npc.tbl_Sounds={NeckBreak={'neck'},Strike={'strike'}}
 `+fn(cb('npc_cpt_scp_173'),'OnHitEntity')+`
 npc:DoDamage(200,200,DMG_SLASH)
 assert(p.critical);assert(p:Alive());assert(ix.SCPMedicine.IsParalyzed(p.character.hp))
 eq(p.character.hp:GetConsciousness(),1);eq(#p.chat,1)
 npc:DoDamage(200,200,DMG_SLASH);eq(#p.chat,1);assert(p:Alive())
 `);
finish();
