const {source,base}=require('./restored-test-runner.cjs');
module.exports=run=>{
 const setup=source(base)+`
 SERVER=false;CLIENT=true;unpack=unpack or table.unpack
 STUDIO_RENDER=1;STUDIO_SHADOWDEPTHTEXTURE=512;STUDIO_SSAODEPTHTEXTURE=256
 RENDERMODE_NORMAL=0;RENDERMODE_TRANSCOLOR=1;RENDERMODE_TRANSADD=5
 function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
 bit={band=function(a,b) return a & b end,bor=function(a,b) return a | b end}
 function string.StartWith(s,prefix) return s:sub(1,#prefix)==prefix end
 local P=PLUGIN;P.zones={{min=Vector(-100,-100,-100),max=Vector(100,100,100),darkness=90,softness=0}}
 local p=admin();function LocalPlayer() return p end
 function p:EyePos() return self.pos end;function p:ShouldDrawLocalPlayer() return self.thirdPerson end
 function p:GetNWBool() return self.flashlight end
 hooks={};hook.Add=function(event,id,fn) hooks[event]=hooks[event] or {};hooks[event][id]=fn end
 hook.Remove=function(event,id) if hooks[event] then hooks[event][id]=nil end end
 function fire(event,...) for _,fn in pairs(hooks[event] or {}) do fn(...) end end
 local rgb={.8,.7,.6};local blend=.6;local stencil=false;local writeColor=false;local writeAlpha=false;local depth=false
 render={GetColorModulation=function() return table.unpack(rgb) end,SetColorModulation=function(r,g,b) rgb={r,g,b} end,
 GetBlend=function() return blend end,SetBlend=function(v) blend=v end,SetStencilEnable=function(v) stencil=v end,
 OverrideColorWriteEnable=function(v) writeColor=v end,OverrideAlphaWriteEnable=function(v) writeAlpha=v end,
 OverrideDepthEnable=function(v) depth=v end,SetStencilWriteMask=function() end,ClearStencil=function() end,
 SetStencilTestMask=function() end,SetStencilReferenceValue=function() end,SetStencilCompareFunction=function() end,
 SetStencilPassOperation=function() end,SetStencilFailOperation=function() end,SetStencilZFailOperation=function() end,
 SetColorMaterial=function() end,CullMode=function() end,SetMaterial=function() end,DrawScreenQuad=function() end,
 GetRenderTarget=function() return render.target end,
 CopyRenderTargetToTexture=function(texture) assert(texture~=render.target);render.copies=(render.copies or 0)+1;render.copied=texture end,
 UpdateScreenEffectTexture=function() error('Shared screen capture may alias the active framebuffer') end}
 local width,height=1920,1080;function ScrW() return width end;function ScrH() return height end
 RT_SIZE_FULL_FRAME_BUFFER=1;MATERIAL_RT_DEPTH_NONE=2;IMAGE_FORMAT_RGB888=3
 local targets={};function GetRenderTargetEx(name,w,h,size,depth,flags,rtflags,format)
  eq(size,RT_SIZE_FULL_FRAME_BUFFER);eq(depth,MATERIAL_RT_DEPTH_NONE);eq(format,IMAGE_FORMAT_RGB888)
  local t={width=w,height=h,name=name,GetName=function(self) return self.name end};targets[#targets+1]=t;return t
 end
 local surfaceMaterial;surface={SetMaterial=function(m) surfaceMaterial=m end,SetDrawColor=function() end,DrawTexturedRect=function() end}
 local matrixDepth,modeDepth=0,0;cam={PushModelMatrix=function() matrixDepth=matrixDepth+1 end,PopModelMatrix=function() matrixDepth=matrixDepth-1 end,
 Start2D=function() modeDepth=modeDepth+1 end,End2D=function() modeDepth=modeDepth-1 end}
 local beamMatrix
 function Matrix() beamMatrix={SetTranslation=function(self,v) self.pos=v end,SetAngles=function(self,v) self.angle=v end,SetScale=function(self,v) self.scale=v end};return beamMatrix end
 function FrameNumber() return 10 end
 local materials={};function CreateMaterial(name,shader,data)
 local m={data=data,SetTexture=function() end,SetFloat=function(self,k,v) self[k]=v end};materials[name]=m;return m end
 local meshes={};function Mesh() local m={};meshes[#meshes+1]=m
 function m:BuildFromTriangles(v) self.vertices=v end;function m:Draw() self.draws=(self.draws or 0)+1 end;function m:Destroy() self.dead=true end;return m end
 local all={};function ents.GetAll() return all end
 function ErrorNoHalt(s) error(s) end
 local prop=entity(881,'prop',Vector());prop.class='prop_physics';all[1]=prop
 function prop:DrawModel() self.color={render.GetColorModulation()} end
 function prop:GetMaterials() return self.materials or {} end
 function prop:GetMaterial() return self.material or "" end
 function prop:GetSubMaterial(index) return (self.subMaterials or {})[index] or "" end
 function prop:GetRenderMode() return self.renderMode or RENDERMODE_NORMAL end
 function prop:SetRenderMode(mode) self.renderMode=mode;self.modeChanges=(self.modeChanges or 0)+1 end
 function prop:GetColor() return self.entityColor or Color(255,255,255,255) end
 local effect=entity(882,'fire',Vector());effect.class='env_fire';all[2]=effect
 local queued={};timer.Simple=function(_,fn) queued[#queued+1]=fn end
 `+source(['ixhl2rp/plugins/blackout/cl_lighting.lua']);
 const suite=(n,s)=>run(n,[],setup+s);
 suite('Viewmodels shade at the engine draw after modulation resets; hands and ARC9 geometry do not tint muzzle effects',`
  near(P:DarknessAt(Vector()),.9);eq(P:DarknessAt(Vector(200,0,0)),0)
  P.zones[2]={min=Vector(-100,-100,-100),max=Vector(100,100,100),darkness=40,softness=0};near(P:DarknessAt(Vector()),.9)
  P.zones[1].softness=20;P.zones[2]=nil
  near(P:DarknessAt(Vector(-90,0,0)),.45);eq(P:DarknessAt(Vector(-100,0,0)),0)
  near(P:DarknessAt(Vector(0,0,-100)),.9)
  local vm=entity(890,'vm',Vector());vm.class='predicted_viewmodel'
  function vm:DrawModel(flags) self.color={render.GetColorModulation()};self.flags=flags end
  local w=entity(891,'weapon',Vector());w.ARC9=true
  function w:DrawCustomModel(wm,x,y,flags) self.attachment={render.GetColorModulation()};return 'attachment' end
  function w:DrawTranslucentPass(wm) self.glass={render.GetColorModulation()};return 'glass' end
  local custom,trans=w.DrawCustomModel,w.DrawTranslucentPass
  -- Native engine draws reset entity modulation after the PreDrawViewModel hook.
  fire('PreDrawViewModels');fire('PreDrawViewModel',vm,p,w,1);near(rgb[1],.8)
  rgb={1,1,1};vm:RenderOverride(1);near(vm.color[1],.1);eq(vm.flags,1);near(rgb[1],1)
  eq(w:DrawCustomModel(false,nil,nil,1),'attachment');near(w.attachment[1],.1);near(rgb[1],1)
  -- ARC9 renders PCFs after DrawCustomModel and MuzzPCFs after DrawTranslucentPass.
  near(rgb[1],1);eq(w:DrawTranslucentPass(false),'glass');near(w.glass[1],.1);near(rgb[1],1)
  fire('PostDrawViewModel');fire('PreDrawPlayerHands',nil,vm,p,w,1);near(rgb[1],.1)
  fire('PostDrawPlayerHands');near(rgb[1],1);fire('PreDrawEffects');near(rgb[1],1)
  vm:RenderOverride(512);near(vm.color[1],1);w:DrawCustomModel(false,nil,nil,256);near(w.attachment[1],1)
  w:DrawCustomModel(true);near(w.attachment[1],1);w:DrawTranslucentPass(true);near(w.glass[1],1)
  ARC9={RTScopeRender=true};vm:RenderOverride(1);near(vm.color[1],1);ARC9=nil
  p.pos=Vector(200,0,0);vm:RenderOverride(1);near(vm.color[1],1)
  P:ClearLighting();eq(vm.RenderOverride,nil);eq(w.DrawCustomModel,custom);eq(w.DrawTranslucentPass,trans)
 `);
 suite('Model shading preserves previous overrides, restores colors after a draw error and leaves other addon replacements alone',`
  local vm=entity(892,'vm',Vector());local original=function() error('draw failure') end;vm.RenderOverride=original
  local errors=0;ErrorNoHalt=function() errors=errors+1 end
  fire('PreDrawViewModel',vm,p,nil,1);vm:RenderOverride(1);eq(errors,1);near(rgb[1],.8)
  local retained=vm.RenderOverride
  local replacement=function() retained(vm,1) end;vm.RenderOverride=replacement
  fire('PreDrawPlayerHands');near(rgb[1],.08);fire('PreDrawEffects');near(rgb[1],.8)
  P:ClearLighting();eq(vm.RenderOverride,replacement);local ok=pcall(replacement);eq(ok,false);near(rgb[1],.8)
 `);
 suite('Late prop shading leaves fire renderers untouched, preserves pre-existing overrides and cleans up safely on reload',`
  assert(prop.RenderOverride);eq(effect.RenderOverride,nil)
  prop:RenderOverride();near(prop.color[1],.8)
  fire('PreDrawTranslucentRenderables',false,false,false);prop:RenderOverride();near(prop.color[1],.08);near(rgb[1],.8)
  fire('PreDrawTranslucentRenderables',false,true,false);prop:RenderOverride();near(prop.color[1],.08)
  fire('PreDrawTranslucentRenderables',false,true,true);prop:RenderOverride();near(prop.color[1],.8)
  fire('PreDrawTranslucentRenderables',false,false,false)
  prop.pos=Vector(200,0,0);prop:RenderOverride();near(prop.color[1],.8)
  fire('PostDrawTranslucentRenderables');prop.pos=Vector();prop:RenderOverride();near(prop.color[1],.8)
  local extra=entity(883,'other',Vector());extra.class='prop_dynamic';local calls=0
  local original=function() calls=calls+1 end;extra.RenderOverride=original
  extra.GetMaterials=prop.GetMaterials;extra.GetMaterial=prop.GetMaterial;extra.GetSubMaterial=prop.GetSubMaterial
  extra.GetRenderMode=prop.GetRenderMode
  fire('OnEntityCreated',extra);table.remove(queued,1)();extra:RenderOverride();eq(calls,1)
  local delayed=entity(884,'late',Vector());delayed.class='prop_physics';fire('OnEntityCreated',delayed)
  P:ClearLighting();eq(prop.RenderOverride,nil);eq(extra.RenderOverride,original)
  table.remove(queued,1)();eq(delayed.RenderOverride,nil);near(rgb[1],.8)
 `);
 suite('Recorded alpha-255 TRANSCOLOR map props join the opaque flashlight capture instead of becoming late black silhouettes',`
  prop.class='prop_dynamic';prop.renderMode=RENDERMODE_TRANSCOLOR
  prop.entityColor=Color(255,255,255,255)
  -- Reproduce the render-list classification observed in the live stage captures.
  local opaqueDraws,lateDraws=0,0
  function prop:DrawModel()
   self.color={render.GetColorModulation()}
   if self:GetRenderMode()==RENDERMODE_NORMAL then opaqueDraws=opaqueDraws+1 else lateDraws=lateDraws+1 end
  end
  fire('PreRender');eq(prop:GetRenderMode(),RENDERMODE_NORMAL)
  if prop:GetRenderMode()==RENDERMODE_NORMAL then prop:RenderOverride(STUDIO_RENDER) end
  near(prop.color[1],.8);eq(opaqueDraws,1)
  render.CopyRenderTargetToTexture=function() eq(opaqueDraws,1);eq(lateDraws,0) end
  p.flashlight=true;ix.plugin.list.flashlight={localBeam={updatedAt=clock,fade=1,pos=Vector(),angle=Angle()}}
  assert(P:CaptureFlashlight({origin=Vector(),angles=Angle()}))
  fire('PreDrawTranslucentRenderables',false,false,false)
  if prop:GetRenderMode()==RENDERMODE_TRANSCOLOR then prop:RenderOverride(STUDIO_RENDER) end
  fire('PostDrawTranslucentRenderables');eq(lateDraws,0)
  fire('PreRender');eq(prop.modeChanges,1) -- no repeated render-list rebuilds
  eq(prop:GetColor().a,255)
  P:ClearLighting();eq(prop:GetRenderMode(),RENDERMODE_TRANSCOLOR);eq(hooks.PreRender.ixBlackoutOpaqueProps,nil)
 `);
 suite('Opaque classification preserves fades, material transparency, viewmodels and later addon changes, and restores outside blackout',`
  local vm=entity(894,'vm',Vector());vm.class='predicted_viewmodel';function vm:DrawModel() end
  -- Viewmodels deliberately have no mode/color methods in this fixture.
  fire('PreDrawViewModel',vm,p,nil,1)
  prop.renderMode=RENDERMODE_TRANSCOLOR;prop.entityColor=Color(255,255,255,128)
  fire('PreRender');eq(prop.renderMode,RENDERMODE_TRANSCOLOR);eq(prop.modeChanges,nil)
  prop.entityColor.a=255;fire('PreRender');eq(prop.renderMode,RENDERMODE_NORMAL)
  prop.entityColor.a=0;fire('PreRender');eq(prop.renderMode,RENDERMODE_TRANSCOLOR);eq(prop.entityColor.a,0)
  prop.entityColor.a=255;fire('PreRender');eq(prop.renderMode,RENDERMODE_NORMAL)
  prop.pos=Vector(200,0,0);fire('PreRender');eq(prop.renderMode,RENDERMODE_TRANSCOLOR)
  prop.pos=Vector();fire('PreRender');eq(prop.renderMode,RENDERMODE_NORMAL)
  local zones=P.zones;P.zones={};fire('PreRender');eq(prop.renderMode,RENDERMODE_TRANSCOLOR);P.zones=zones
  -- Do not rewrite model materials to make glass opaque, or touch glow/additive modes.
  prop.material='glass';prop.subMaterials={[0]='glass'};prop.renderMode=RENDERMODE_TRANSADD
  fire('PreRender');eq(prop.renderMode,RENDERMODE_TRANSADD);eq(prop.material,'glass');eq(prop.subMaterials[0],'glass')
  prop.renderMode=RENDERMODE_TRANSCOLOR;fire('PreRender');eq(prop.renderMode,RENDERMODE_NORMAL)
  prop.renderMode=RENDERMODE_TRANSADD;fire('PreRender');P:ClearLighting();eq(prop.renderMode,RENDERMODE_TRANSADD)
 `);
 suite('Opaque classification releases an overridden prop and restores surviving props on unload',`
  prop.renderMode=RENDERMODE_TRANSCOLOR;fire('PreRender');eq(prop.renderMode,RENDERMODE_NORMAL)
  local replacement=function() end;prop.RenderOverride=replacement
  fire('PreRender');eq(prop.renderMode,RENDERMODE_TRANSCOLOR)
  fire('PreRender');eq(prop.renderMode,RENDERMODE_TRANSCOLOR)
  P:ClearLighting();eq(prop.RenderOverride,replacement);eq(prop.renderMode,RENDERMODE_TRANSCOLOR)
 `);
 suite('Static blackout props reuse zone results and avoid a full render-mode sweep every frame',`
  local props={};local modeReads,darknessCalls=0,0
  local original=P.DarknessAt
  function P:DarknessAt(pos) darknessCalls=darknessCalls+1;return original(self,pos) end
  -- A synthetic busy map: 100 translucent and 900 ordinary opaque props.
  -- Count production operations, rather than timings of the Lua emulator.
  for i=1,1000 do
   local e=entity(1000+i,'prop',Vector());e.class='prop_dynamic'
   e.GetMaterials=prop.GetMaterials;e.GetMaterial=prop.GetMaterial;e.GetSubMaterial=prop.GetSubMaterial
   e.GetColor=prop.GetColor;e.SetRenderMode=prop.SetRenderMode
   function e:GetRenderMode() modeReads=modeReads+1;return self.renderMode or RENDERMODE_NORMAL end
   e.renderMode=i<=100 and RENDERMODE_TRANSCOLOR or RENDERMODE_NORMAL
   fire('OnEntityCreated',e);table.remove(queued,1)();props[i]=e
  end
  fire('PreRender');eq(darknessCalls,100);modeReads=0
  local start=clock
  for frame=1,60 do clock=start+frame/60;fire('PreRender') end
  eq(darknessCalls,100) -- formerly 6,100 full zone scans for these static props
  assert(modeReads<=16000,'too many mode reads: '..modeReads) -- formerly 60,000
  -- Drawing multiple passes shares the center result; materials remain live.
  props[1]:RenderOverride(STUDIO_RENDER);props[1]:RenderOverride(STUDIO_RENDER)
  eq(darknessCalls,100)
 `);
 suite('Cached blackout centers follow moving ragdolls and mutable vectors without delaying alpha fades',`
  prop.class='prop_ragdoll';prop.renderMode=RENDERMODE_TRANSCOLOR
  local original=P.DarknessAt;local calls=0
  function P:DarknessAt(pos) calls=calls+1;return original(self,pos) end
  fire('PreRender');eq(prop.renderMode,RENDERMODE_NORMAL);eq(calls,1)
  prop.pos.x=200;fire('PreRender');eq(prop.renderMode,RENDERMODE_TRANSCOLOR);eq(calls,2)
  prop.pos.x=0;fire('PreRender');eq(prop.renderMode,RENDERMODE_NORMAL);eq(calls,3)
  prop.entityColor=Color(255,255,255,128);fire('PreRender')
  eq(prop.renderMode,RENDERMODE_TRANSCOLOR);eq(calls,3)
  prop.entityColor.a=255;fire('PreRender');eq(prop.renderMode,RENDERMODE_NORMAL);eq(calls,3)
  -- A collision center change between PreRender and drawing is also observed.
  prop.pos.x=200;fire('PreDrawTranslucentRenderables',false,false,false);prop:RenderOverride(1)
  near(prop.color[1],.8);eq(calls,4)
 `);
 suite('Blackout scalar snapshots invalidate for edits to box bounds, fade joins, appearance, defaults and zone membership',`
  prop.renderMode=RENDERMODE_TRANSCOLOR;prop.pos=Vector(-90,0,0)
  local function verify()
   fire('PreRender');fire('PreDrawTranslucentRenderables',false,false,false);prop:RenderOverride(1)
   near(prop.color[1],.8*(1-P:DarknessAt(prop.pos)))
   fire('PostDrawTranslucentRenderables')
  end
  verify();near(prop.color[1],.08)
  local z=P.zones[1]
  z.softness=20;verify();near(prop.color[1],.44)
  z.darkness=40;verify();near(prop.color[1],.64)
  z.fadeMin=Vector(-110,-100,-100);verify();near(prop.color[1],.48)
  z.fadeMin.x=-100;verify();near(prop.color[1],.64)
  z.fadeMax=Vector(-80,100,100);verify()
  z.fadeMax.x=100;verify()
  z.min.x=-89;verify();near(prop.color[1],.8);eq(prop.renderMode,RENDERMODE_TRANSCOLOR)
  z.min.x=-100;z.max.x=-91;verify();near(prop.color[1],.8)
  z.max.x=100;z.darkness=nil;z.softness=nil;P.maskSoftness=20;P.maskDarkness=102;verify();near(prop.color[1],.64)
  P.maskSoftness=40;P.maskDarkness=204;verify();near(prop.color[1],.7)
  P.zones[2]={min=Vector(-100,-100,-100),max=Vector(100,100,100),darkness=95,softness=0}
  verify();near(prop.color[1],.04)
  P.zones[2]=nil;verify();near(prop.color[1],.7)
  P.zones={};verify();near(prop.color[1],.8);eq(prop.renderMode,RENDERMODE_TRANSCOLOR)
  -- Network delivery replaces the list; even a draw before PreRender sees it.
  P.zones={{min=Vector(-100,-100,-100),max=Vector(100,100,100),darkness=50,softness=0}}
  fire('PreDrawTranslucentRenderables',false,false,false);prop:RenderOverride(1);near(prop.color[1],.4)
 `);
 suite('New translucent modes use 100 ms reconciliation while visible changes register for the next render classification',`
  fire('PreRender');local start=clock
  prop.renderMode=RENDERMODE_TRANSCOLOR
  clock=start+.099;fire('PreRender');eq(prop.renderMode,RENDERMODE_TRANSCOLOR)
  clock=start+.101;fire('PreRender');eq(prop.renderMode,RENDERMODE_NORMAL)
  -- Once discovered, the prop always gets live classification, even if an
  -- addon temporarily changes its mode. No fade/restore polling is added.
  prop.renderMode=RENDERMODE_TRANSADD;fire('PreRender');eq(prop.renderMode,RENDERMODE_TRANSADD)
  prop.renderMode=RENDERMODE_TRANSCOLOR;fire('PreRender');eq(prop.renderMode,RENDERMODE_NORMAL)
  local visible=entity(894,'prop',Vector());visible.class='prop_dynamic'
  visible.GetMaterials=prop.GetMaterials;visible.GetMaterial=prop.GetMaterial;visible.GetSubMaterial=prop.GetSubMaterial
  visible.GetRenderMode=prop.GetRenderMode;visible.SetRenderMode=prop.SetRenderMode;visible.GetColor=prop.GetColor
  fire('OnEntityCreated',visible);table.remove(queued,1)()
  visible.renderMode=RENDERMODE_TRANSCOLOR;visible:RenderOverride(1);fire('PreRender')
  eq(visible.renderMode,RENDERMODE_NORMAL)
  visible.valid=false;fire('PreRender');P:ClearLighting()
 `);
 suite('No-zone rendering restores promoted props once and does not keep polling their modes or positions',`
  prop.renderMode=RENDERMODE_TRANSCOLOR;fire('PreRender');eq(prop.renderMode,RENDERMODE_NORMAL)
  P.zones={};fire('PreRender');eq(prop.renderMode,RENDERMODE_TRANSCOLOR)
  local mode,center=prop.GetRenderMode,prop.WorldSpaceCenter
  prop.GetRenderMode=function() error('no-zone prop mode polling') end
  prop.WorldSpaceCenter=function() error('no-zone prop position polling') end
  for i=1,60 do clock=clock+1/60;fire('PreRender') end
  prop.GetRenderMode=mode;prop.WorldSpaceCenter=center
  P.zones={{min=Vector(-100,-100,-100),max=Vector(100,100,100),darkness=90,softness=0}}
  fire('PreRender');eq(prop.renderMode,RENDERMODE_NORMAL)
  P:ClearLighting();eq(prop.renderMode,RENDERMODE_TRANSCOLOR)
 `);
 suite('Blackout suppresses baked cubemaps and imported specular gain per prop, restoring shared materials even after failure',`
  local reflected={values={['$envmap']='env_cubemap',['$envmaptint']=Vector(.8,.6,.4),['$phongboost']=6}}
  function reflected:IsError() return false end
  function reflected:GetVector(k) return self.values[k] end
  function reflected:GetString(k) return self.values[k] end
  function reflected:GetFloat(k) return self.values[k] end
  function reflected:SetVector(k,v) self.values[k]=v end
  function reflected:SetFloat(k,v) self.values[k]=v end
  function Material(name) eq(name,'bottle_glass');return reflected end
  prop.model='bottle.mdl';prop.materials={'bottle_original'};prop.subMaterials={[0]='bottle_glass'}
  local tint=reflected.values['$envmaptint']
  function prop:DrawModel()
   self.tint=reflected.values['$envmaptint'];self.boost=reflected.values['$phongboost'];self.color={render.GetColorModulation()}
  end
  -- Opaque reflection is reduced before capture, but diffuse color is left for the spatial veil.
  prop:RenderOverride(1);near(prop.tint.x,.08);near(prop.boost,1.5);near(prop.color[1],.8)
  eq(reflected.values['$envmaptint'],tint);eq(reflected.values['$phongboost'],6)
  fire('PreDrawTranslucentRenderables',false,false,false);prop:RenderOverride(1);near(prop.color[1],.08)
  prop.pos=Vector(200,0,0);prop:RenderOverride(1);eq(prop.tint,tint);eq(prop.boost,6);near(prop.color[1],.8)
  prop.pos=Vector();prop:RenderOverride(512);eq(prop.tint,tint);eq(prop.boost,6)
  function prop:DrawModel() error('material draw failed') end
  local errors=0;ErrorNoHalt=function() errors=errors+1 end;prop:RenderOverride(1);eq(errors,1)
  eq(reflected.values['$envmaptint'],tint);eq(reflected.values['$phongboost'],6);near(rgb[1],.8)
 `);
 suite('Flashlight relief is confined to a finite soft beam, allocates once, skips remote views and restores renderer state',`
  local view={origin=Vector(),angles=Angle()};local lamp={updatedAt=clock,fade=1,pos=Vector(),angle=Angle()};ix.plugin.list.flashlight={localBeam=lamp}
  eq(P:CaptureFlashlight(view),nil);eq(#meshes,0)
  p.flashlight=true;render.target={GetName=function() return 'cctv_feed' end};eq(P:CaptureFlashlight(view),nil);eq(#meshes,0);render.target=nil
  p.thirdPerson=true;eq(P:CaptureFlashlight(view),nil);p.thirdPerson=false
  view.origin=Vector(90,0,0);eq(P:CaptureFlashlight(view),nil);view.origin=Vector()
  lamp.updatedAt=clock-.3;eq(P:CaptureFlashlight(view),nil);lamp.updatedAt=clock
  ix.CCTV.rendering=true;eq(P:CaptureFlashlight(view),nil);ix.CCTV.rendering=false
  render.target={GetName=function() return '_rt_FullFrameFB' end} -- main HDR target must work
  local beam=P:CaptureFlashlight(view);eq(beam,lamp);eq(#meshes,24);eq(render.copies,1)
  local n=#meshes;P:CaptureFlashlight(view);eq(#meshes,n)
  eq(P:BeamRadius(.5,0),0);eq(P:BeamRadius(.5,1001),0);near(P:BeamRadius(.5,100)/100,P:BeamRadius(.5,500)/500);assert(P:BeamRadius(.1,250)>P:BeamRadius(.7,250))
  for _,m in ipairs(meshes) do for _,v in ipairs(m.vertices) do assert(v.pos.x>=0 and v.pos.x<1000);assert(v.pos.y==v.pos.y and v.pos.z==v.pos.z) end end
  local restored=0;local mat=materials.ixBlackoutLitScene_v3
  eq(#targets,1);eq(render.copied,targets[1]);eq(mat.data['$basetexture'],targets[1]:GetName())
  surface.DrawTexturedRect=function(x,y,w,h)
   eq(x,0);eq(y,0);eq(w,width);eq(h,height);eq(surfaceMaterial,mat);near(rgb[1],1)
   local alpha=mat['$alpha'];assert(alpha>=0 and alpha<=1);restored=restored+(1-restored)*alpha
  end
  P:RestoreFlashlight(beam);near(restored,.65);near(rgb[1],.8);near(blend,.6);eq(stencil,false);eq(writeColor,false);eq(writeAlpha,false);eq(depth,false);eq(matrixDepth,0);eq(modeDepth,0)
  for _,m in ipairs(meshes) do eq(m.draws,1) end
  -- A resolution change reuses the full-frame-sized target; the composite follows the viewport.
  width,height=2560,1440;P:CaptureFlashlight(view);eq(#targets,1);restored=0;P:RestoreFlashlight(beam);near(restored,.65)
  P:ClearLighting();for _,m in ipairs(meshes) do eq(m.dead,true) end
 `);
 const projectedSetup=`
  local light={valid=true,brightness=1.4,pos=Vector(7,3,2),angle=Angle(5,12,0),far=1837,hfov=40,vfov=32,near=2}
  function light:GetBrightness() return self.brightness end
  function light:GetPos() return self.pos end;function light:GetAngles() return self.angle end
  function light:GetFarZ() return self.far end;function light:GetNearZ() return self.near end
  function light:GetHorizontalFOV() return self.hfov end;function light:GetVerticalFOV() return self.vfov end
  -- Deliberately no GetFOV: ProjectedTexture exposes separate H/V getters.
  local view={origin=Vector(),angles=Angle()}
 `;
 suite('Dynamic Flashlight is recovered with the gamemode flashlight off and uses its actual animated lens and range',projectedSetup+`
  p.flashlight=false
  CFlash={Core={GetLight=function(owner) eq(owner,p);return light end}}
  local beam=P:CaptureFlashlight(view);assert(beam);eq(beam.source,'CFlash');eq(beam.pos,light.pos);eq(beam.angle,light.angle)
  eq(beam.fov,40);eq(beam.verticalFov,32);eq(beam.far,1837);eq(beam.fade,1)
  P:RestoreFlashlight(beam)
  eq(beamMatrix.pos,light.pos);eq(beamMatrix.angle,light.angle);near(beamMatrix.scale.x,1.837)
  near(beamMatrix.scale.y,1.837*math.tan(math.rad(20))/math.tan(math.rad(26)))
  near(beamMatrix.scale.z,1.837*math.tan(math.rad(16))/math.tan(math.rad(26)))
  light.pos=Vector(4,8,12);light.brightness=.3;beam=P:CaptureFlashlight(view);eq(beam.pos,light.pos);near(beam.fade,.3)
  local copies=render.copies
  light.brightness=0;eq(P:CaptureFlashlight(view),nil)
  light.brightness=1;light.near=0;eq(P:CaptureFlashlight(view),nil)
  light.near=2;light.valid=false;eq(P:CaptureFlashlight(view),nil);eq(render.copies,copies)
  light.valid=true;render.target={GetName=function() return 'scope' end};eq(P:CaptureFlashlight(view),nil);render.target=nil
  ix.CCTV.rendering=true;eq(P:CaptureFlashlight(view),nil);ix.CCTV.rendering=false
  p.dead=true;eq(P:CaptureFlashlight(view),nil)
 `);
 suite('ICF compatibility observes its update without changing addon behavior and releases stale, removed or disabled lights',projectedSetup+`
  p.flashlight=false;local enabled=true;ICF_IsFlashlightActive=function() return enabled end
  local calls=0
  local original=function(l,pos,angle,nearZ)
   eq(l,light);calls=calls+1;l.pos=pos;l.angle=angle;l.near=nearZ;return 'unchanged',nil,42
  end
  ICF_UpdateMainProjectedTexture=original
  fire('Think');local wrapper=ICF_UpdateMainProjectedTexture;assert(wrapper~=original)
  fire('Think');eq(ICF_UpdateMainProjectedTexture,wrapper)
  eq(P:CaptureFlashlight(view),nil)
  local a,b,c=ICF_UpdateMainProjectedTexture(light,Vector(2,4,6),Angle(1,2,3),4)
  eq(a,'unchanged');eq(b,nil);eq(c,42);eq(calls,1)
  local beam=P:CaptureFlashlight(view);assert(beam);eq(beam.source,'ICF');eq(beam.pos,light.pos);eq(beam.angle,light.angle)
  enabled=false;eq(P:CaptureFlashlight(view),nil);enabled=true
  clock=clock+.3;eq(P:CaptureFlashlight(view),nil)
  ICF_UpdateMainProjectedTexture(light,light.pos,light.angle,4);assert(P:CaptureFlashlight(view))
  light.valid=false;eq(P:CaptureFlashlight(view),nil);light.valid=true
  P:ClearLighting();eq(ICF_UpdateMainProjectedTexture,original);eq(hooks.Think.ixBlackoutFlashlightBridge,nil)
 `);
 suite('ICF addon refresh rebinds once and blackout unload leaves newer addon replacements intact',projectedSetup+`
  ICF_IsFlashlightActive=function() return true end
  ICF_UpdateMainProjectedTexture=function() return 1 end;fire('Think')
  local replacement=function() return 2 end;ICF_UpdateMainProjectedTexture=replacement;fire('Think')
  assert(ICF_UpdateMainProjectedTexture~=replacement);eq(ICF_UpdateMainProjectedTexture(light),2)
  assert(P:GetFlashlightBeam(p))
  local third=function() return 3 end;ICF_UpdateMainProjectedTexture=third;P:ClearLighting();eq(ICF_UpdateMainProjectedTexture,third)
 `);
 suite('Beam recovery fades gradually over most of the radius, without the former bright outer rim',`
  local count=24;local previous=0;local largest=0
  local reference=400*math.tan(math.rad(26))
  for level=1,count do
   local t=(level-.5)/count
   near(P:BeamRadius(t,400)/reference,1-.88*t)
   local recovered=P:BeamRecovery(level/count,1)
   assert(recovered>=previous);largest=math.max(largest,recovered-previous);previous=recovered
  end
  near(previous,.65);assert(largest<.041)
  assert(P:BeamRecovery(1/count,1)<.0035) -- preserve a soft outer ring, under 0.35 percent recovery
  near(P:BeamRecovery(.5,.5),.1625)
  near(P:BeamRecovery(0,1),0);near(P:BeamRecovery(1,1),.65)
  local function recoveryAtRadius(radius)
   local value=0
   for level=1,count do
    if radius<=P:BeamRadius((level-.5)/count,400)/reference then value=P:BeamRecovery(level/count,1) end
   end
   return value
  end
  near(recoveryAtRadius(1),0)
  assert(recoveryAtRadius(.95)<.01)
  assert(recoveryAtRadius(.8)<.1)
  assert(recoveryAtRadius(.5)>.35 and recoveryAtRadius(.5)<.45)
  near(recoveryAtRadius(.1),.65)
 `);
 suite('Beam meshes are closed and classify the same lit surface from opposing directions, with a full core and feathered boundary',`
  p.flashlight=true
  ix.plugin.list.flashlight={localBeam={updatedAt=clock,fade=1,pos=Vector(),angle=Angle()}}
  P:CaptureFlashlight({origin=Vector(),angles=Angle()})
  local volume=materials.ixBlackoutBeamVolume_v1
  eq(volume.data['$nocull'],'1');eq(volume.data['$ignorez'],'0');eq(volume.data['$translucent'],'0')
  local function contains(vertices,point,direction)
   local hits={}
   for i=1,#vertices,3 do
    local a,b,c=vertices[i].pos,vertices[i+1].pos,vertices[i+2].pos
    local ab,ac=b-a,c-a;local h=direction:Cross(ac);local det=ab:Dot(h)
    if math.abs(det)>1e-9 then
     local delta=point-a;local u=delta:Dot(h)/det;local q=delta:Cross(ab);local v=direction:Dot(q)/det
     if u>=-1e-8 and v>=-1e-8 and u+v<=1+1e-8 then
      local t=ac:Dot(q)/det;local duplicate=false
      for _,old in ipairs(hits) do if math.abs(old-t)<1e-6 then duplicate=true end end
      if t>1e-6 and not duplicate then hits[#hits+1]=t end
     end
    end
   end
   return #hits%2==1
  end
  for _,m in ipairs(meshes) do
   eq(#m.vertices,384)
   local edges={}
   local function key(v) return math.Round(v.x*1e5)..','..math.Round(v.y*1e5)..','..math.Round(v.z*1e5) end
   for i=1,#m.vertices,3 do for j=0,2 do
    local a,b=key(m.vertices[i+j].pos),key(m.vertices[i+(j+1)%3].pos);assert(a~=b)
    if a>b then a,b=b,a end;local k=a..'/'..b;edges[k]=(edges[k] or 0)+1
   end end
   for _,n in pairs(edges) do eq(n,2) end
   for _,direction in ipairs({Vector(1,0,0),Vector(-1,0,0),Vector(0,1,0),Vector(0,-1,0),Vector(0,0,1),Vector(0,0,-1),Vector(1,.7,.3):GetNormalized()}) do
    for _,distance in ipairs({40,200,400,590}) do
     eq(contains(m.vertices,Vector(distance,1,1),direction),true)
    end
    eq(contains(m.vertices,Vector(400,300,0),direction),false)
    eq(contains(m.vertices,Vector(-10,0,0),direction),false)
    eq(contains(m.vertices,Vector(1001,0,0),direction),false)
   end
  end
  local function coverage(point)
   local count=0;for _,m in ipairs(meshes) do if contains(m.vertices,point,Vector(1,.3,.2):GetNormalized()) then count=count+1 end end
   return count
  end
  eq(coverage(Vector(400,0,0)),24)
  local edge=coverage(Vector(400,150,0));assert(edge>0 and edge<24)
  eq(coverage(Vector(400,220,0)),0);eq(coverage(Vector(800,0,0)),12)
 `);
 suite('Flashlight uses the main player view after a CCTV capture and publishes beam freshness independent of render frame numbers',`
  function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
  local light={};PLUGIN=light
  local lamps={};function ProjectedTexture()
   local lamp={};lamps[#lamps+1]=lamp
   for _,name in ipairs({'Texture','NearZ','FarZ','FOV','Color','Brightness','EnableShadows','Pos','Angles','ConstantAttenuation','LinearAttenuation','QuadraticAttenuation'}) do
    lamp['Set'..name]=function(self,value) self[name]=value end
   end
   function lamp:Update() self.updated=true end;function lamp:Remove() self.removed=true end
   return lamp
  end
  function p:IsDormant() return false end
  function p:GetShootPos() return self:EyePos() end
  function p:EyeAngles() return Angle() end
  player.GetAll=function() return {p} end
  local main={origin=Vector(10,0,0),angles=Angle(0,30,0)}
  render.GetViewSetup=function(current) eq(current,false);return main end
  EyePos=function() error('Global EyePos contains remote camera position') end
  EyeAngles=function() error('Global EyeAngles contains remote camera angle') end
  ix.option={Get=function(_,default) return false end}
  util.TraceLine=function(tr) return {Hit=false} end
  function FrameTime() return .1 end
  function math.Approach(a,b,s) return a<b and math.min(b,a+s) or math.max(b,a-s) end
  ${source(['ixhl2rp/plugins/flashlight/cl_flashlight.lua'])}
  p.flashlight=true;light:Think();eq(#lamps,1);eq(lamps[1].updated,true)
  local expected=main.origin+main.angles:Right()*3-main.angles:Up()*2
  near(light.localBeam.pos:DistToSqr(expected),0);eq(light.localBeam.updatedAt,clock);near(lamps[1].Brightness,1.35*.65)
  eq(lamps[1].ConstantAttenuation,0);eq(lamps[1].LinearAttenuation,350);eq(lamps[1].QuadraticAttenuation,0)
  -- Source attenuation remains capped at one up close; improves throw at range.
  local function intensity(d,linear) return lamps[1].Brightness*math.min(1,linear/d)*math.Clamp((1000-d)/400,0,1) end
  near(intensity(40,350),intensity(40,100));near(intensity(100,350),intensity(100,100))
  assert(intensity(400,350)>intensity(400,100)*3);eq(intensity(1000,350),0)
  clock=clock+.1;light:Think();eq(#lamps,1);eq(light.localBeam.updatedAt,clock)
  p.flashlight=false;light:Think();eq(light.localBeam,nil);eq(lamps[1].removed,true)
  light:OnUnload();PLUGIN=P
 `);
 suite('Facility equipment draws casings once before darkness, with screen and indicator artwork in the emission pass',`
  ENT={};RENDERGROUP_BOTH=42
  ${source(['ixhl2rp/plugins/facility_utilities/entities/entities/ix_facility_device.lua'])}
  local e=entity(893,'generator',Vector());e.FacilityKind='generator';local draws,plates=0,0
  function e:DrawModel(flags) eq(flags,1);draws=draws+1 end
  for k,v in pairs(ENT) do e[k]=v end
  ix.CCTV.rendering=false;EyePos=function() return Vector() end
  ix.Facility={IsScreen=function() return false end,Hardware={DrawDevicePlate=function() plates=plates+1 end}}
  eq(e.RenderGroup,42);e:Draw(1);eq(draws,1);eq(plates,0)
  e:DrawTranslucent();eq(draws,1);eq(plates,1)
 `);

};
