const fs=require('fs'),path=require('path');
const {normalize}=require('./glua.cjs');
const root=path.resolve(__dirname,'..');
const captured=[];
require('./test-render-budget.cjs')((...args)=>captured.push(args));
const setup=captured.find(args=>args[0].startsWith('Distant ARC9'))[3];
const rate=normalize(fs.readFileSync(path.join(root,'tools/fixtures/arc9-upstream/tpik-rate-excerpt.lua'),'utf8'));
module.exports=suite=>{
 suite('Budget restores native helper policy if the imported ARC9 eligibility API disappears',
 ['ixhl2rp/plugins/render_efficiency/cl_budget.lua'],`
 eq(settings.arc9_tpik_helper_bone_force_full_fps:GetBool(),false)
 ARC9.TPIK.HelperHasCachedRoots=nil
 local w=weapon(person(2000));local timestamp=w.LastTPIKTime;local called=0
 ix.RenderBudget.RunTPIK(w,function(self) called=called+1;eq(self.LastTPIKTime,timestamp) end)
 eq(called,1);eq(settings.arc9_tpik_helper_bone_force_full_fps:GetBool(),true)
 ix.RenderBudget.RefreshPolicy();eq(settings.arc9_tpik_helper_bone_force_full_fps:GetBool(),true)
 `,setup);
 suite('Hot refresh migrates owned old wrappers without nesting or replacing an external decorator',
 ['ixhl2rp/plugins/render_efficiency/cl_budget.lua','ixhl2rp/plugins/arc9_helperbones.lua'],`
 local H=ix.arc9Helpers
 H.Capture=function() return nil end
 assert(owned.DoTPIK~=ownedLegacy);eq(H.wrapped[owned].budgetVersion,1)
 eq(external.DoTPIK,foreign);eq(H.CanBudget(),false)
 eq(settings.arc9_tpik_helper_bone_force_full_fps:GetBool(),true)
 owned:DoTPIK();eq(nativeCalls,1);eq(legacyCalls,0)
 external:DoTPIK();eq(nativeCalls,2);eq(legacyCalls,1)
 local installed=owned.DoTPIK
 for i=1,100 do H.Install(owned);H.Install(external) end
 eq(owned.DoTPIK,installed);eq(external.DoTPIK,foreign)
 external.valid=false;eq(H.CanBudget(),true);ix.RenderBudget.RefreshPolicy()
 eq(settings.arc9_tpik_helper_bone_force_full_fps:GetBool(),false)
 `,setup+`
 nativeCalls=0;legacyCalls=0
 local function native() nativeCalls=nativeCalls+1 end
 owned=weapon(person(2000));external=weapon(person(2100))
 ownedLegacy=function(self,...) legacyCalls=legacyCalls+1;return native(self,...) end
 local externalLegacy=function(self,...) legacyCalls=legacyCalls+1;return native(self,...) end
 foreign=function(self,...) return externalLegacy(self,...) end
 owned.DoTPIK=ownedLegacy;external.DoTPIK=foreign
 ix.arc9Helpers.wrapped={[owned]={wrapper=ownedLegacy,original=native},[external]={wrapper=externalLegacy,original=native}}
 `);
 suite('Near ordinary rigs retain native cadence while actual helper rigs preserve full-rate solves',
 ['ixhl2rp/plugins/render_efficiency/cl_budget.lua'],`
 local p=person(100);local w=weapon(p);local solve,apply=0,0
 local roots=false
 ARC9={TPIK={HelperHasCachedRoots=function(owner) eq(owner,p);return roots end}}
 local arc9_tpik_framerate_you={GetInt=function() return 60 end}
 local arc9_tpik_framerate_notyou={GetInt=function() return 20 end}
 local arc9_tpik_helper_bone_force_full_fps=settings.arc9_tpik_helper_bone_force_full_fps
 local TPIKHelperHasCachedRoots=ARC9.TPIK.HelperHasCachedRoots
 local function original(self)
  local ply=self:GetOwner()
  ${rate}
  if shouldfulltpik then solve=solve+1;self.LastTPIKTime=CurTime() end
  apply=apply+1
 end
 for i=0,99 do clock=10+i*.01;ix.RenderBudget.RunTPIK(w,original) end
 eq(apply,100);assert(solve>=18 and solve<=21,'ordinary rig forced full solves: '..solve)
 roots=true;solve=0
 for i=0,19 do clock=12+i*.01;ix.RenderBudget.RunTPIK(w,original) end
 eq(solve,20);eq(apply,120)
 `,setup);
 const holsters=[];
 require('./test-weapon-slots.cjs')((...args)=>holsters.push(args));
 const entry=holsters.find(args=>args[0].startsWith('Holstered duplicates'));
 const assertions=entry[2].replace(
  'W.DrawHolsters(plugin,client);eq(created,3);eq(draws,3)',
  `local originalLookup=client.LookupBone;local skeletonReady=false
   client.LookupBone=function(self,name) if skeletonReady then return originalLookup(self,name) end end
   W.DrawHolsters(plugin,client);eq(created,3);eq(draws,0)
   skeletonReady=true
   W.DrawHolsters(plugin,client);eq(created,3);eq(draws,3)`);
 suite('Holsters recover when the same model skeleton becomes available after first draw',entry[1],assertions,entry[3]);
};
