// Regression for clean clients without the old Cellar character meshes.
module.exports=function(suite){
 const files=['tools/fixtures/sharedposes.lua','helix/plugins/act/sh_sharedposes.lua',
  'helix/plugins/act/sh_resolver.lua','ixhl2rp/plugins/sithelper/sh_plugin.lua'];
 const setup=`ix.util={Include=function() end}`;
 const env=`
 local R=ix.sharedPoses
 local male='models/sd/citizens/citizen_male_01_hair1.mdl'
 local female='models/sd/citizens/citizen_female_01_hair1.mdl'
 local stock='models/player/kleiner.mdl'
 local guard='models/arty/codmw2022/sp/mexican federal police/grunts/scp_oz_security_1.mdl'
 local rig={height=26,bones={},names={}}
 for i,name in ipairs({'Pelvis','Spine','Spine1','Spine2','Neck1','Head1','L_UpperArm','L_Forearm','L_Hand',
  'R_UpperArm','R_Forearm','R_Hand','L_Thigh','L_Calf','L_Foot','R_Thigh','R_Calf','R_Foot'}) do
  name='ValveBiped.Bip01_'..name;rig.names[name]=i;rig.bones[i]={name=name,parent=-1}
 end
 local mounted={[male]=true,[female]=true,[stock]=true}
 local clips={[male]={},[female]={},[stock]={sit_zen=1,sit_passive=2,sit_fist=3}}
 -- The real male stance library lacks these three slots; the female has them.
 for i,name in ipairs(PLUGIN.sitStances) do
  clips[female][name]=i
  if i~=10 and i~=11 and i~=21 then clips[male][name]=i end
 end
 local targetRig=rig
 R.Rig=function(model) return model==guard and targetRig or mounted[model] and rig or nil end
 R.Probe=function(model)
  if not mounted[model] then return end
  return {valid=true,LookupSequence=function(_,name) return clips[model][name] or -1 end}
 end
 local p={valid=true,native={ragdoll=0,sit_zen=1},count=2}
 function p:GetModel() return guard end
 function p:GetSequenceCount() return self.count end
 function p:LookupSequence(name) return self.native[name] or -1 end
 function p:GetSequenceName(id) for name,value in pairs(self.native) do if value==id then return name end end end
 `;
 suite('Shared sources: clean install exposes every sitting/lying slot without old Cellar meshes',files,env+`
  for option=1,24 do
   local name,id,pose=PLUGIN:ResolvePose(p,option)
   assert(name,'Unavailable pose '..option);eq(id,option==22 and 1 or 0)
   if option==22 then eq(pose,nil)
   else
    assert(pose);eq(pose.target,guard)
    if option<=21 then eq(pose.model,(option==10 or option==11 or option==21) and female or male)
    else eq(pose.model,stock) end
   end
  end
 `,setup);
 suite('Shared sources: a reference-only humanoid can borrow poses; native clips keep priority',files,env+`
  p.native={ragdoll=0};p.count=1
  local name,id,pose=PLUGIN:ResolvePose(p,16)
  eq(name,'stances_down02');eq(id,0);eq(pose.model,male)
  p.native.stances_down02=47;p.count=2
  name,id,pose=PLUGIN:ResolvePose(p,16);eq(name,'stances_down02');eq(id,47);eq(pose,nil)
  p.native.stances_sit01=0
  name,id,pose=PLUGIN:ResolvePose(p,1);eq(id,0);eq(pose,nil)
 `,setup);
 suite('Shared sources: unsupported rigs and arbitrary clips do not become selectable',files,env+`
  targetRig=table.Copy(rig);targetRig.names['ValveBiped.Bip01_Head1']=nil
  eq(PLUGIN:ResolvePose(p,1),nil)
  eq(R.Resolve(p,'unregistered_clip'),nil)
  eq(PLUGIN:ResolvePose(p,31),nil)
  eq(PLUGIN:ResolvePose({valid=false},1),nil)
 `,setup);
 suite('Shared sources: unavailable donors fail cleanly and are retried without restarting Lua',files,env+`
  mounted[male]=nil;mounted[female]=nil
  eq(PLUGIN:ResolvePose(p,16),nil);eq(PLUGIN:ResolvePose(p,22),'sit_zen')
  mounted[female]=true;clock=clock+6
  local name,_,pose=PLUGIN:ResolvePose(p,16);eq(name,'stances_down02');eq(pose.model,female)
 `,setup);
};
if(require.main===module){
 const r=require('./restored-test-runner.cjs');
 module.exports((name,files,assertions,setup='')=>r.run(name,setup+'\n'+r.source(files)+'\n'+assertions));
 r.finish();
}
