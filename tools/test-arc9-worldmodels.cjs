const {read} = require('./restored-test-runner.cjs');
const runtime = require('./glua-runtime.cjs');
const plugin = 'ixhl2rp/plugins/arc9_worldmodels.lua';
const draw = read('tools/fixtures/arc9-upstream/cl_drawmodel.lua');
const model = read('tools/fixtures/arc9-upstream/cl_model.lua');
const wm = read('tools/fixtures/arc9-upstream/cl_wm.lua');
const loadNative = (text, file) => `assert(load([==[${runtime(text)}]==], '@lua/weapons/arc9_base/${file}'))()`;
// Execute the actual upstream LOD selector, complete draw methods and model
// assembly method. Engine entities/material drawing are mocked, not measured.
const setup = runtime(read('tools/geometry-fixture.lua')) + `
 SERVER=false;CLIENT=true
 settings={};hooks={};commands={};pending={};known={};created=0;drawn=0;frame=1;pixel=10
 function CreateClientConVar(n,v)
  settings[n]=settings[n] or {value=tonumber(v),GetBool=function(s) return s.value~=0 end,GetFloat=function(s) return s.value end}
  return settings[n]
 end
 function GetConVar(n) return settings[n] end
 CreateClientConVar('arc9_lod_distance','1');CreateClientConVar('arc9_drawprojectedlights','0')
 hook.Add=function(e,n,f) hooks[e..n]=f end;hook.Remove=function(e,n) hooks[e..n]=nil end
 concommand={Add=function(n,f) commands[n]=f end,Remove=function(n) commands[n]=nil end}
 timer.Simple=function(_,f) pending[#pending+1]=f end
 function flush() local q=pending;pending={};for _,f in ipairs(q) do f() end end
 ents.FindByClass=function() return known end
 render={ComputePixelDiameterOfSphere=function() return pixel end,RenderFlashlights=function() end}
 function FrameNumber() return frame end
 bit={band=function() return 0 end};STUDIO_RENDER=1;STUDIO_SSAODEPTHTEXTURE=2;STUDIO_SHADOWDEPTHTEXTURE=4
 function person()
  return {valid=true,IsPlayer=function() return true end,IsNPC=function() return false end,
   GetActiveWeapon=function(s) return s.weapon end,GetViewModel=function(s) return s.vm end}
 end
 viewer=person();function LocalPlayer() return viewer end
 ARC9={CSModelPile={}};SWEP={ModelVersion=0}
 function SWEP:GetProcessedValue() return nil end
 function makeModel(path)
  created=created+1
  local m={valid=true,path=path,atttbl={},slottbl={}}
  for _,method in ipairs({'SetNoDraw','ResetSequence','EnableMatrix','SetSkin','SetBodyGroups',
    'SetPos','SetAngles','SetRenderOrigin','SetRenderAngles','SetupBones','SetMaterial'}) do m[method]=function() end end
  function m:LookupSequence() return 0 end
  function m:GetMaterials() return nil end
  function m:DrawModel() drawn=drawn+1 end
  return m
 end
 ClientsideModel=makeModel
 Matrix=function() return {Scale=function() end} end
 function SafeRemoveEntity(m) if m then m.valid=false end end
 ${loadNative(draw.slice(0,draw.indexOf('function SWEP:GetActiveSightSlotTable()')), 'cl_drawmodel.lua')}
 ${loadNative('local swepGetProcessedValue = SWEP.GetProcessedValue\n'+model.slice(model.indexOf('function SWEP:SetupModel('),model.indexOf('SWEP.VModel = nil')), 'cl_model.lua')}
 ${loadNative(model.slice(model.indexOf('function SWEP:KillSpecificModel(')), 'cl_model.lua')}
 ${loadNative(wm.slice(0,wm.indexOf('hook.Add(')), 'cl_wm.lua')}
 function weapon(owner)
  owner=owner or person()
  local w=setmetatable({valid=true,ARC9=true,MirrorVMWM=true,owner=owner,WorldModel='css.mdl',ViewModel='eft.mdl',
   WorldModelOffset={Pos=Vector(),Ang=Angle()},pos=Vector(),builds=0,fallbacks=0,bodygroups=0,slots={{Installed='stock'},{Installed='suppressor'}}}, {__index=SWEP})
  owner.weapon=w;owner.vm=makeModel('first-person.mdl')
  function w:GetOwner() return self.owner end;function w:GetPos() return self.pos end
  function w:GetClass() return 'arc9_eft_test' end;function w:GetIsStatue() return false end
  function w:GetAnimationEntry() return {Source='idle'} end
  function w:GetAttachmentElements() return {} end;function w:GetSubSlotList() return self.slots end
  function w:GetFinalAttTable(s) return s.Installed and {Model=s.Installed..'.mdl'} or {} end
  function w:CreateAttachmentModel(world,att,slot,proxy,custom)
   local m=makeModel(att.Model);m.slottbl=slot
   table.insert(custom and self.CModel or world and self.WModel or self.VModel,m);return m
  end
  function w:CreateFlashlights() self.builds=self.builds+1 end
  function w:DoBodygroups() self.bodygroups=self.bodygroups+1 end
  function w:GetHiddenBones() return {} end;function w:GetActiveSightSlotTable() return {} end
  function w:GetAttachmentPos() return Vector(),Angle() end
  function w:DrawModel() self.fallbacks=self.fallbacks+1 end
  return w
 end
 function level(w,p) pixel=p;w.NextLODCheck=0;return w:ShouldLOD() end
`;

module.exports = suite => {
 suite('Native ARC9 reproduces CSS fallback and an attachmentless world assembly', [], `
  local w=weapon();eq(level(w,.5),2);w:DrawWorldModel();eq(w.fallbacks,1);eq(w.WModel,nil)
  eq(level(w,1),1.5);w:DrawWorldModel();eq(#w.WModel,1)
  eq(level(w,10),0);w:DrawWorldModel();eq(#w.WModel,1) -- native cache remains incomplete
 `,setup);
 suite('Held ARC9 keeps the full assembly at LOD 2 without disabling intermediate animation LOD', [plugin], `
  local w=weapon();ix.arc9WorldModels.Install(w)
  eq(level(w,.5),1.5);w:DrawWorldModel();eq(w.fallbacks,0);eq(#w.WModel,3);eq(w.builds,1)
  eq(w.WModel[2].path,'stock.mdl');eq(w.WModel[3].path,'suppressor.mdl');eq(w.LastWMDrawn,frame)
  local assembly=w.WModel;local totalCreated=created
  for i=1,100 do frame=i;w:DrawWorldModel() end
  eq(w.WModel,assembly);eq(w.builds,1);eq(created,totalCreated);eq(w.LastWMDrawn,100)
  eq(level(w,10),0);eq(level(w,1.4),1);eq(level(w,1),1.5)
  eq(level(w,.1),1.5);eq(w.LastLOD,2) -- only returned LOD is capped; native cache is not rewritten
 `,setup);
 suite('Existing bare receiver repairs once; re-created models and attachment changes rebuild normally', [plugin], `
  local w=weapon();w:SetupModel(true,1);eq(#w.WModel,1)
  local old=w.WModel;local vm={makeModel('view-attachment.mdl')};w.VModel=vm
  ix.arc9WorldModels.Install(w);level(w,.5);w:DrawWorldModel()
  eq(old[1].valid,false);eq(#w.WModel,3);eq(w.VModel,vm);eq(vm[1].valid,true);eq(w.builds,1)
  w:DrawWorldModel();eq(w.builds,1)
  w.slots={{Installed='new-stock'}};w:SetupModel(true,1.5)
  eq(#w.WModel,2);eq(w.WModel[2].path,'new-stock.mdl');eq(w.builds,2)
  w:DrawWorldModel();eq(w.builds,2)
  -- Native invalidation on an attachment update, independent of this adapter.
  w:KillSpecificModel(true);w:DrawWorldModel();assert(w.WModel,'missing after native invalidation');eq(#w.WModel,2);eq(w.builds,3)
 `,setup);
 suite('Local viewmodels, previews, NPCs, holstered and dropped weapons retain native contracts', [plugin], `
  local w=weapon(viewer);ix.arc9WorldModels.Install(w);eq(level(w,.5),-1)
  w:SetupModel(false,1);eq(#w.VModel,2);eq(w.WModel,nil)
  w:SetupModel(true,1,true);eq(#w.CModel,1) -- no takeover of custom preview assembly
  w.owner=person();w.owner.weapon=w;w:SetupModel(true,0);local full=w.WModel
  w.owner.weapon=nil;eq(level(w,.5),2);w:DrawWorldModel();eq(w.fallbacks,1);eq(w.WModel,full)
  w.owner.IsPlayer=function() return false end;w.owner.weapon=w
  eq(level(w,.5),2);w:DrawWorldModel();eq(w.fallbacks,2)
  w.owner.valid=false;eq(level(w,.5),2);w:DrawWorldModel();eq(w.fallbacks,3)
  w.owner=person();w.owner.weapon=w;w.MirrorVMWM=false
  eq(level(w,.5),2);w:DrawWorldModel();eq(w.fallbacks,4)
 `,setup);
 suite('Fresh distant creation, drop/pickup and disabling do not retain incomplete assemblies', [plugin], `
  local w=weapon();known={w};flush();eq(level(w,.5),1.5);w:DrawWorldModel();eq(#w.WModel,3)
  settings.ix_arc9_worldmodels.value=0;eq(level(w,.5),2);w:DrawWorldModel();eq(w.fallbacks,1)
  w:SetupModel(true,1);eq(#w.WModel,1)
  settings.ix_arc9_worldmodels.value=1;w:DrawWorldModel();eq(#w.WModel,3)
  w.owner.weapon=nil;w:SetupModel(true,1);eq(#w.WModel,1)
  w.owner.weapon=w;w:DrawWorldModel();eq(#w.WModel,3)
 `,setup);
 suite('Custom renderers remain untouched; installation and shutdown preserve wrapper ownership', [plugin], `
  local w=weapon();local original=w.ShouldLOD
  ix.arc9WorldModels.Install(w);local wrapped=w.ShouldLOD
  ix.arc9WorldModels.Install(w);eq(w.ShouldLOD,wrapped)
  local other=weapon();other.DrawCustomModel=function() end
  ix.arc9WorldModels.Install(other);eq(other.ShouldLOD,original)
  local external=function(self) return wrapped(self) end;w.ShouldLOD=external
  ix.arc9WorldModels.Stop();eq(w.ShouldLOD,external);eq(level(w,.5),2)
  eq(w.SetupModel,SWEP.SetupModel);eq(w.DrawWorldModel,SWEP.DrawWorldModel)
  eq(commands.ix_arc9_worldmodel_info,nil);flush();eq(other.ShouldLOD,original)
 `,setup);
 suite('Visible-player discovery and deferred creation install only once; stopped callbacks stay inactive', [plugin], `
  local w=weapon();hooks.PrePlayerDrawixARC9WorldModels(w.owner)
  eq(level(w,.5),1.5)
  local later=weapon();hooks.OnEntityCreatedixARC9WorldModels(later);eq(level(later,.5),2)
  flush();eq(level(later,.5),1.5)
  local stopped=weapon();hooks.OnEntityCreatedixARC9WorldModels(stopped)
  PLUGIN:OnUnload();flush();eq(level(stopped,.5),2)
 `,setup);
 suite('A far-camera LOD cached for the main view cannot replace a held weapon with CSS', [plugin], `
  local w=weapon();ix.arc9WorldModels.Install(w)
  level(w,.5);w:DrawWorldModel();eq(w.LastLOD,2)
  -- Native ARC9 reuses this value for 0.5 seconds across rendering views.
  pixel=10;eq(w:ShouldLOD(),1.5);w:DrawWorldModel();eq(w.fallbacks,0);eq(#w.WModel,3)
  clock=clock+.6;eq(w:ShouldLOD(),0);w:DrawWorldModel();eq(w.fallbacks,0);eq(w.builds,1)
 `,setup);
 suite('Server loads metadata only, with no simulation, hooks or networking changes', [plugin], `
  eq(ix.arc9WorldModels,nil);eq(next(hooks),nil);eq(next(commands),nil);eq(#pending,0)
 `,setup+'\nSERVER=true;CLIENT=false');
};
