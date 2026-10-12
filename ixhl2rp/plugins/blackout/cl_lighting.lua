local P=PLUGIN
if P.ClearLighting then P:ClearLighting() end
local function smooth(t) t=math.Clamp(t,0,1);return t*t*(3-2*t) end

-- Same world-space fade as the stencil, including unfeathered fragment joins.
function P:DarknessAt(pos)
 local darkness=0
 for _,z in ipairs(self.zones) do if pos:WithinAABox(z.min,z.max) then
  local mn,mx=z.fadeMin or z.min,z.fadeMax or z.max;local size=mx-mn
  local width=z.softness or self.maskSoftness or 24
  local side=math.Clamp(width,0,math.max(math.min(size.x,size.y)*.5-1,0))
  local top=math.Clamp(width,0,math.max(size.z-1,0));local fade=1
  if side>0 then fade=math.min(fade,(pos.x-mn.x)/side,(mx.x-pos.x)/side,(pos.y-mn.y)/side,(mx.y-pos.y)/side) end
  if top>0 then fade=math.min(fade,(mx.z-pos.z)/top) end
  darkness=math.max(darkness,math.Clamp(z.darkness or (self.maskDarkness or 220)/2.55,0,100)*.01*smooth(fade))
 end end
 return darkness
end

-- Engine viewmodel draws can reset modulation after PreDrawViewModel. Apply it
-- at the actual model draw, then restore it before weapon particles/reticles.
local active,late=true,false
local wrapped=setmetatable({}, {__mode="k"})
local opaqueModes=setmetatable({}, {__mode="k"})
local weaponsWrapped=setmetatable({}, {__mode="k"})
local handColors={}
local propClasses={prop_physics=true,prop_physics_multiplayer=true,prop_physics_override=true,prop_dynamic=true,prop_dynamic_override=true,prop_ragdoll=true}
local function depthPass(flags)
 return flags and bit.band(flags,bit.bor(STUDIO_SHADOWDEPTHTEXTURE,STUDIO_SSAODEPTHTEXTURE))~=0
end
local function viewDarkness()
 local p=LocalPlayer()
 if not IsValid(p) or p:ShouldDrawLocalPlayer() or (ix.CCTV and ix.CCTV.rendering)
  or (ARC9 and (ARC9.RTScopeRender or ARC9.PresetCam)) then return 0 end
 return P:DarknessAt(p:EyePos())
end
local function shaded(shade,fn,...)
 if shade<=0 then return fn(...) end
 local r,g,b=render.GetColorModulation()
 render.SetColorModulation(r*(1-shade),g*(1-shade),b*(1-shade))
 local args={...};local count=select("#",...)
 local ok,result=xpcall(function() return fn(unpack(args,1,count)) end,debug.traceback)
 render.SetColorModulation(r,g,b)
 if not ok then ErrorNoHalt(result.."\n");return end
 return result
end
-- Cubemap reflections are baked with the map lights on. Vertex color shading
-- alone does not attenuate that shader term (notably translucent bottles).
-- Change material parameters only for this prop's draw, then restore them: a
-- second instance using the same material outside the zone must stay untouched.
local materialCache={}
local function propMaterials(e)
 local model=e:GetModel()
 if not model or model=="" then return {} end
 local list=materialCache[model]
 if not list then list=e:GetMaterials() or {};materialCache[model]=list end
 local result,seen={},{}
 local override=e:GetMaterial()
 for index,name in ipairs(list) do
  local sub=e:GetSubMaterial(index-1)
  local selected=override~="" and override or (sub~="" and sub or name)
  if not seen[selected] then seen[selected]=true;result[#result+1]=Material(selected) end
 end
 return result
end
local function drawProp(e,flags,draw)
 local darkness=not depthPass(flags) and P:DarknessAt(e:WorldSpaceCenter()) or 0
 if darkness<=0 then return draw(e,flags) end
 local changed={}
 for _,mat in ipairs(propMaterials(e)) do
  if not mat:IsError() then
   local tint=mat:GetVector("$envmaptint")
   if tint then
    changed[#changed+1]={mat,"$envmaptint",tint}
    mat:SetVector("$envmaptint",tint*(1-darkness))
   end
   -- Some imported props use 4-6x specular gain. Keep the live flashlight's
   -- highlight, without that gain blowing out metal against a dark room.
   local boost=mat:GetFloat("$phongboost")
   if boost and boost>1 then
    changed[#changed+1]={mat,"$phongboost",boost}
    mat:SetFloat("$phongboost",boost+(1-boost)*darkness)
   end
  end
 end
 local ok,result=xpcall(function() return shaded(late and darkness or 0,draw,e,flags) end,debug.traceback)
 for i=#changed,1,-1 do local row=changed[i]
  if isnumber(row[3]) then row[1]:SetFloat(row[2],row[3]) else row[1]:SetVector(row[2],row[3]) end
 end
 if not ok then ErrorNoHalt(result.."\n");return end
 return result
end
local function wrapModel(e,viewmodel)
 if not active or not IsValid(e) or wrapped[e] then return end
 if not viewmodel and not propClasses[e:GetClass()] then return end
 local old=e.RenderOverride
 local draw=old or function(ent,flags) ent:DrawModel(flags) end
 local fn=function(ent,flags)
  if not active then return draw(ent,flags) end
  if not viewmodel then return drawProp(ent,flags,draw) end
  return shaded(not depthPass(flags) and viewDarkness() or 0,draw,ent,flags)
 end
 wrapped[e]={original=old,wrapper=fn,viewmodel=viewmodel};e.RenderOverride=fn
end
local function restorePropMode(e)
 local original=opaqueModes[e]
 if original and IsValid(e) and e:GetRenderMode()==RENDERMODE_NORMAL then e:SetRenderMode(original) end
 opaqueModes[e]=nil
end
-- Some map props are TRANSCOLOR even at alpha 255. Source then draws their
-- solid surfaces after the opaque scene/flashlight capture, producing black
-- silhouettes. Classify them before render lists are built, so their opaque
-- materials get the same per-pixel blackout and beam recovery as the world.
-- Material transparency is untouched; entity fades return to their old mode.
hook.Add("PreRender","ixBlackoutOpaqueProps",function()
 for e,row in pairs(wrapped) do
  if not IsValid(e) then opaqueModes[e]=nil
  elseif not row.viewmodel then
   local mode=e:GetRenderMode()
   local eligible=(mode==RENDERMODE_TRANSCOLOR or (opaqueModes[e] and mode==RENDERMODE_NORMAL))
    and e.RenderOverride==row.wrapper and e:GetColor().a==255
    and P:DarknessAt(e:WorldSpaceCenter())>0
   if eligible then
    if mode==RENDERMODE_TRANSCOLOR then
     opaqueModes[e]=mode;e:SetRenderMode(RENDERMODE_NORMAL)
    end
   else restorePropMode(e) end
  end
 end
end)
local function wrapWeapon(w)
 if not IsValid(w) or not w.ARC9 then return end
 local rows=weaponsWrapped[w] or {};weaponsWrapped[w]=rows
 for _,name in ipairs({"DrawCustomModel","DrawTranslucentPass"}) do
  if isfunction(w[name]) and not rows[name] then
   local original=w[name]
   local fn=function(self,wm,...)
    if not active then return original(self,wm,...) end
    local shade=wm and 0 or viewDarkness()
    if name=="DrawCustomModel" and depthPass(select(3,...)) then shade=0 end
    return shaded(shade,original,self,wm,...)
   end
   rows[name]={original=original,wrapper=fn};w[name]=fn
  end
 end
end
hook.Add("PreDrawViewModel","ixBlackoutViewLighting",function(vm,_,weapon)
 wrapModel(vm,true);wrapWeapon(weapon)
end)
hook.Add("PreDrawPlayerHands","ixBlackoutHandLighting",function(_,_,_,_,flags)
 local r,g,b=render.GetColorModulation();handColors[#handColors+1]={r,g,b}
 local factor=1-(depthPass(flags) and 0 or viewDarkness())
 render.SetColorModulation(r*factor,g*factor,b*factor)
end)
local function endHands()
 local c=table.remove(handColors);if c then render.SetColorModulation(c[1],c[2],c[3]) end
end
hook.Add("PostDrawPlayerHands","ixBlackoutHandLighting",endHands)
hook.Add("PreDrawEffects","ixBlackoutLightingRestore",function() while #handColors>0 do endHands() end end)
hook.Add("PreDrawTranslucentRenderables","ixBlackoutLateProps",function(depth,sky,sky3d) late=not depth and not sky3d end)
hook.Add("PostDrawTranslucentRenderables","ixBlackoutLateProps",function() late=false end)
hook.Add("OnEntityCreated","ixBlackoutLateProps",function(e) timer.Simple(0,function() wrapModel(e) end) end)
for _,e in ipairs(ents.GetAll()) do wrapModel(e) end

-- Preserve the local flashlight's lit scene in a soft, depth-tested beam volume.
-- This avoids a second RenderView, per-frame traces, global exposure changes, or
-- extra projected lights. Remote/CCTV views never sample the player's framebuffer.
-- ICF keeps its main light private, but exposes its update function. Observe
-- that one light without replacing its settings, input or animation handling.
local icfLight,icfUpdatedAt,icfOriginal,icfWrapper
local function bindICF()
 local update=ICF_UpdateMainProjectedTexture
 if not active or not isfunction(update) or update==icfWrapper then return end
 icfLight=nil;icfOriginal=update
 local original=update
 icfWrapper=function(light,...)
  if active then icfLight=light;icfUpdatedAt=RealTime() end
  return original(light,...)
 end
 ICF_UpdateMainProjectedTexture=icfWrapper
end
bindICF()
hook.Add("Think","ixBlackoutFlashlightBridge",bindICF)
local function projectedBeam(light,source)
 if not IsValid(light) then return end
 local brightness=light:GetBrightness()
 if brightness<=0 or light:GetNearZ()<=0 or light:GetFarZ()<=0 then return end
 return {pos=light:GetPos(),angle=light:GetAngles(),far=light:GetFarZ(),
  fov=light:GetHorizontalFOV(),verticalFov=light:GetVerticalFOV(),
  fade=math.Clamp(brightness,0,1),source=source}
end
function P:GetFlashlightBeam(p)
 -- Dynamic Flashlight exposes the actual local projected light, including
 -- animated aim and power fade. A loaded addon with no light is not active.
 local core=CFlash and CFlash.Core
 if core and isfunction(core.GetLight) then
  local beam=projectedBeam(core.GetLight(p),"CFlash")
  if beam then return beam end
 end
 if isfunction(ICF_IsFlashlightActive) and ICF_IsFlashlightActive()
  and icfUpdatedAt and RealTime()-icfUpdatedAt<=.25 then
  local beam=projectedBeam(icfLight,"ICF")
  if beam then return beam end
 end
 local flashlight=ix.plugin.list.flashlight
 local beam=flashlight and flashlight.localBeam
 if p:GetNWBool("ixFieldFlashlight",false) and beam and beam.updatedAt
  and RealTime()-beam.updatedAt<=.25 and beam.fade>0 then return beam end
end
local beamMeshes={};local sceneMaterial,sceneTexture
local levels,sides=64,64
local beamVolumeMaterial=CreateMaterial("ixBlackoutBeamVolume_v1","UnlitGeneric",{
 ["$basetexture"]="color/white",["$nocull"]="1",["$ignorez"]="0",
 ["$translucent"]="0",["$vertexcolor"]="0",["$vertexalpha"]="0"})
function P:BeamRadius(t,x)
 if x<=0 or x>1000 then return 0 end
 -- Spread the feather across the beam instead of packing many brightness
 -- steps against its rim. Keep only a small full-strength central hotspot.
 return x*math.tan(math.rad(26))*(1-.88*math.Clamp(t,0,1))
end
function P:BeamRecovery(t,fade)
 -- Zero slope at both ends makes the outside edge fade into the blackout.
 return .65*math.Clamp(fade or 1,0,1)*smooth(t)
end
local function buildBeams()
 for level=1,levels do
  local threshold=(level-.5)/levels
  -- Fade the recovery only over the light's terminal 600-1000 unit fadeout.
  local far=1000-400*threshold
  local vertices={}
  local function triangle(a,b,c) for _,v in ipairs({a,b,c}) do vertices[#vertices+1]={pos=v,normal=Vector(1,0,0),u=0,v=0} end end
  local radius=P:BeamRadius(threshold,far)
  for side=0,sides-1 do
    local a,b=side*math.pi*2/sides,(side+1)*math.pi*2/sides
    local p1,p2=Vector(far,radius*math.cos(a),radius*math.sin(a)),Vector(far,radius*math.cos(b),radius*math.sin(b))
    triangle(Vector(0,0,0),p2,p1)
    -- Close the far end: an open cone loses its depth parity from some views.
    triangle(Vector(far,0,0),p1,p2)
  end
  local m=Mesh();m:BuildFromTriangles(vertices);beamMeshes[level]=m
 end
end
function P:CaptureFlashlight(view)
 local p=LocalPlayer()
 if not IsValid(p) or not p:Alive() or p:ShouldDrawLocalPlayer()
  or not view or not view.origin or view.origin:DistToSqr(p:EyePos())>16^2
  or (ix.CCTV and ix.CCTV.rendering) or (ARC9 and (ARC9.RTScopeRender or ARC9.PresetCam)) then return end
 -- HDR can render the main view into a full-frame target. Only reject auxiliary
 -- targets (CCTV, mirrors and scopes), not that normal engine framebuffer.
 local target=render.GetRenderTarget()
 if target and not string.StartWith(target:GetName():lower(),"_rt_fullframefb") then return end
 local beam=self:GetFlashlightBeam(p)
 if not beam then return end
 if #beamMeshes==0 then buildBeams() end
 -- Do not sample _rt_FullFrameFB while drawing into it, or treat its depth
 -- alpha as transparency. An RGB-only private copy has unambiguous opacity.
 if not sceneTexture then
  sceneTexture=GetRenderTargetEx("ixBlackoutSceneRGB_v1",ScrW(),ScrH(),RT_SIZE_FULL_FRAME_BUFFER,
   MATERIAL_RT_DEPTH_NONE,bit.bor(4,8,256),0,IMAGE_FORMAT_RGB888)
 end
 render.CopyRenderTargetToTexture(sceneTexture)
 if not sceneMaterial then sceneMaterial=CreateMaterial("ixBlackoutLitScene_v3","UnlitGeneric",{
  ["$basetexture"]=sceneTexture:GetName(),["$translucent"]="1",["$vertexalpha"]="1",["$vertexcolor"]="1",["$ignorez"]="1"}) end
 sceneMaterial:SetTexture("$basetexture",sceneTexture)
 return beam
end
function P:RestoreFlashlight(beam)
 local matrix=Matrix();matrix:SetTranslation(beam.pos);matrix:SetAngles(beam.angle)
 -- The cached cone is authored for the built-in 52 degree / 1000 unit light.
 -- Match addon lenses/range without rebuilding meshes or inventing a beam.
 local length=math.Clamp(beam.far or 1000,1,16384)/1000
 local function radius(fov) return length*math.tan(math.rad(math.Clamp(fov or 52,1,175)*.5))/math.tan(math.rad(26)) end
 matrix:SetScale(Vector(length,radius(beam.fov),radius(beam.verticalFov or beam.fov)))
 local previous=0;local oldBlend=render.GetBlend()
 local r,g,b=render.GetColorModulation();render.SetColorModulation(1,1,1)
 render.SetStencilEnable(true)
 for level,m in ipairs(beamMeshes) do
  render.SetStencilWriteMask(255);render.ClearStencil();render.SetStencilTestMask(1);render.SetStencilReferenceValue(0)
  render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_ALWAYS)
  render.SetStencilPassOperation(STENCILOPERATION_KEEP);render.SetStencilFailOperation(STENCILOPERATION_KEEP)
  render.SetStencilZFailOperation(STENCILOPERATION_INVERT)
  render.OverrideColorWriteEnable(true,false);render.OverrideAlphaWriteEnable(true,false)
  render.OverrideDepthEnable(true,false);render.SetMaterial(beamVolumeMaterial)
  cam.PushModelMatrix(matrix)
  m:Draw()
  cam.PopModelMatrix();render.OverrideDepthEnable(false)
  render.OverrideColorWriteEnable(false);render.OverrideAlphaWriteEnable(false)
  render.SetStencilWriteMask(0);render.SetStencilReferenceValue(1);render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
  render.SetStencilZFailOperation(STENCILOPERATION_KEEP)
  -- Bounded restoration prevents light-colored cabinets washing out, even at
  -- point-blank range. It never amplifies the captured lighting.
  local target=self:BeamRecovery(level/levels,beam.fade)
  sceneMaterial:SetFloat("$alpha",(target-previous)/math.max(1-previous,.001));previous=target
  render.SetBlend(1)
  cam.Start2D()
  surface.SetMaterial(sceneMaterial);surface.SetDrawColor(255,255,255,255)
  surface.DrawTexturedRect(0,0,ScrW(),ScrH())
  cam.End2D()
 end
 render.SetColorModulation(r,g,b);render.SetBlend(oldBlend);render.SetStencilWriteMask(255);render.SetStencilTestMask(255);render.SetStencilEnable(false)
end
function P:ClearLighting()
 active=false;late=false
 hook.Remove("PreRender","ixBlackoutOpaqueProps")
 for e in pairs(opaqueModes) do restorePropMode(e) end
 hook.Remove("Think","ixBlackoutFlashlightBridge")
 if icfWrapper and ICF_UpdateMainProjectedTexture==icfWrapper then ICF_UpdateMainProjectedTexture=icfOriginal end
 icfLight=nil
 for e,row in pairs(wrapped) do if IsValid(e) and e.RenderOverride==row.wrapper then e.RenderOverride=row.original end end
 for w,rows in pairs(weaponsWrapped) do if IsValid(w) then
  for name,row in pairs(rows) do if w[name]==row.wrapper then w[name]=row.original end end
 end end
 for _,m in ipairs(beamMeshes) do m:Destroy() end
 beamMeshes={};while #handColors>0 do endHands() end
 for event,id in pairs({PreDrawViewModels="ixBlackoutAllViewLighting",PreDrawViewModel="ixBlackoutViewLighting",PostDrawViewModel="ixBlackoutViewLighting",PreDrawPlayerHands="ixBlackoutHandLighting",PostDrawPlayerHands="ixBlackoutHandLighting",PreDrawEffects="ixBlackoutLightingRestore",PreDrawTranslucentRenderables="ixBlackoutLateProps",PostDrawTranslucentRenderables="ixBlackoutLateProps",OnEntityCreated="ixBlackoutLateProps"}) do hook.Remove(event,id) end
end
