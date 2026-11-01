module.exports = suite => {
suite('Sun glare draws only toward a visible sun and stops behind walls, in menus and NVG',
 ['ixhl2rp/plugins/zz_legends_visuals/cl_sun.lua'], `
 ix.FieldVisuals.DrawSun();assert(draws>0)
 local firstAlpha=lastAlpha
 local firstGhost=ghostBrightness
 assert(firstGhost>0 and firstGhost<12)
 assert(firstAlpha>0 and firstAlpha<18*.65*.15)
 for n=1,30 do ix.FieldVisuals.DrawSun() end
 assert(lastAlpha>firstAlpha*4)
 assert(ghostBrightness>firstGhost*4)
 local peakGhost=ghostBrightness
 local peak=lastAlpha;sun.obstruction=0;ix.FieldVisuals.DrawSun()
 assert(lastAlpha>0 and lastAlpha<peak)
 assert(ghostBrightness>0 and ghostBrightness<peakGhost)
 sun.obstruction=1;screenY=0;local edgeBefore=draws;ix.FieldVisuals.DrawSun();eq(draws,edgeBefore)
 screenY=540
 local before=draws;trace.Hit=true;trace.HitSky=false;ix.FieldVisuals.DrawSun();eq(draws,before)
 trace.HitSky=true;ix.FieldVisuals.DrawSun();assert(draws>before)
 before=draws;ArcticNVGs_Enabled=true;ix.FieldVisuals.DrawSun();eq(draws,before)
 ArcticNVGs_Enabled=false;visible=false;ix.FieldVisuals.DrawSun();eq(draws,before)
 visible=true;sun=nil;ix.FieldVisuals.DrawSun();eq(draws,before)
 sun={direction=vec,obstruction=1};facing=-1;ix.FieldVisuals.DrawSun();eq(draws,before)
 facing=1;values.fieldSunGlare=false;ix.FieldVisuals.DrawSun();eq(draws,before)
 values.fieldSunGlare=true;values.fieldSunGlareStrength=0;ix.FieldVisuals.DrawSun();eq(draws,before)
 `, `
 local visible=true;local draws=0;local facing=1;local values={};local trace={Hit=false};local lastAlpha=0;local screenY=540
 local currentBrightness=0;local ghostBrightness=0
 local vec={};setmetatable(vec,{__add=function() return vec end,__mul=function() return vec end})
 function vec:GetNormalized() return self end;function vec:Dot() return facing end
 function vec:ToScreen() return {x=960,y=screenY,visible=true} end
 local sun={direction=vec,obstruction=1}
 ix.FieldVisuals={Visible=function() return visible end}
 ix.option={Get=function(k,d) if values[k]~=nil then return values[k] end return d end}
 function Material() return {IsError=function() return false end} end
 function EyePos() return vec end;function EyeVector() return vec end;function LocalPlayer() return {} end
 function ScrW() return 1920 end;function ScrH() return 1080 end;function FrameTime() return .1 end
 function Lerp(t,a,b) return a+(b-a)*t end
 util.GetSunInfo=function() return sun end;util.TraceLine=function() return trace end
 surface={SetMaterial=function() end,SetDrawColor=function(r,g,b,a) lastAlpha=a;currentBrightness=math.max(r,g,b) end,
 DrawTexturedRect=function() draws=draws+1;assert(lastAlpha==255);ghostBrightness=currentBrightness end,DrawLine=function() end}
 `);
suite('Light lens isolates bright-pass buffers, restores targets, and respects independent controls',
 ['ixhl2rp/plugins/zz_legends_visuals/cl_lightlens.lua'], `
 assert(ix.FieldVisuals.DrawLightLens());eq(depth,0);eq(draws,3);eq(blurs,3);eq(copies,2)
 eq(uniforms['$c0_x'],.2);eq(uniforms['$c0_y'],.6)
 bw,bh=320,180;assert(ix.FieldVisuals.DrawLightLens());eq(current,"screen");eq(depth,0)
 values.fieldCinematic=false;assert(ix.FieldVisuals.DrawLightLens());eq(uniforms['$c0_x'],0)
 values.fieldLensDirt=false;local before=draws;assert(not ix.FieldVisuals.DrawLightLens());eq(draws,before)
 values.fieldCinematic=true;values.fieldCustomShaders=false;assert(not ix.FieldVisuals.DrawLightLens());eq(draws,before)
 values.fieldCustomShaders=true;ix.FieldVisuals.lightMaterials={};assert(not ix.FieldVisuals.DrawLightLens())
 `, `
 local values={};local uniforms={};local depth=0;local draws=0;local blurs=0;local copies=0;local camera=false;local current="screen";local saved
 ix.option={Get=function(k,d) if values[k]~=nil then return values[k] end return d end}
 local scene={};local targets={}
 local mat={SetTexture=function(_,k,v) assert(v) end,SetFloat=function(_,k,v) uniforms[k]=v end}
 ix.FieldVisuals={lightMaterials={bright=mat,glow=mat}}
 local bw,bh=480,270;local scratch={Width=function() return bw end,Height=function() return bh end}
 bit={bor=function(a,b) return a|b end};RT_SIZE_LITERAL=8;MATERIAL_RT_DEPTH_NONE=2;TEXTUREFLAGS_CLAMPS=nil;TEXTUREFLAGS_CLAMPT=nil;IMAGE_FORMAT_RGB888=2
 function GetRenderTargetEx(n,w,h,mode,depthMode,flags,rtFlags,format) eq(flags,12);eq(rtFlags,0);eq(format,2);eq(w,bw);eq(h,bh);eq(mode,8);eq(depthMode,2);targets[n]=targets[n] or {name=n};return targets[n] end
 function ScrW() return 1920 end;function ScrH() return 1080 end;function RealTime() return 10 end
 cam={Start2D=function() assert(not camera);camera=true end,End2D=function() assert(camera);camera=false end}
 surface={SetMaterial=function() assert(camera) end,SetDrawColor=function() end,
 DrawTexturedRect=function(x,y,w,h) assert(camera);if depth==1 then eq(uniforms["$c0_x"],current.name:find("directed_dirt") and 1 or 0) end;assert(depth==1 or current=="screen", "Composite went to an offscreen target");eq(x,0);eq(y,0);eq(w,depth==1 and bw or 1920);draws=draws+1 end}
 render={GetBloomTex1=function() return scratch end,GetScreenEffectTexture=function() return scene end,
 CopyRenderTargetToTexture=function(t) assert((depth==0 and t==scene) or (depth==1 and t~=scene));copies=copies+1 end,
 PushRenderTarget=function(t) eq(depth,0);saved=current;current=t;depth=1 end,PopRenderTarget=function() eq(depth,1);current=saved;depth=0 end,
 Clear=function() eq(depth,1) end,BlurRenderTarget=function(t) current=t;blurs=blurs+1 end}
 `);
const file = 'ixhl2rp/plugins/zz_legends_visuals/cl_shaders.lua';
const setup = `
 ix.FieldVisuals={};local values={};ix.option={Get=function(k,d) if values[k]~=nil then return values[k] end return d end}
 function RealTime() return 10 end
 local dx=95;local mounts=0;local draws=0;local copies=0;local writes=0;local mountOK=true
 local uniforms={};local failMaterial=false;local in2D=false
 cam={Start2D=function() assert(not in2D);in2D=true end,End2D=function() assert(in2D);in2D=false end}
 function include() return {stem='test',version='test',payload='payload'} end
 util.Base64Decode=function() return 'GMAD' end
 file={Read=function() return nil end,Write=function() writes=writes+1 end}
 game={MountGMA=function() mounts=mounts+1;return mountOK end}
 concommand={Add=function() end}
 render={GetDXLevel=function() return dx end,CopyRenderTargetToTexture=function(input) assert(type(input)=='table');copies=copies+1 end,
 GetScreenEffectTexture=function() return {} end,SetMaterial=function() assert(in2D) end,DrawScreenQuad=function() assert(in2D);draws=draws+1 end}
 function ScrW() return 1920 end;function ScrH() return 1080 end
 surface={SetMaterial=function() assert(in2D) end,SetDrawColor=function(r,g,b,a) eq(r,255);eq(a,255) end,
 DrawTexturedRect=function(x,y,w,h) assert(in2D);eq(x,0);eq(y,0);eq(w,ScrW());eq(h,ScrH());draws=draws+1 end}
 
 function CreateMaterial(_,shader,params)
  eq(shader,'screenspace_general');eq(params['$linearwrite'],'1');eq(params['$linearread_basetexture'],'1')
  eq(params['$vertextransform'],'1')
  return {IsError=function() return failMaterial end,SetFloat=function(_,k,v) uniforms[k]=v end,SetTexture=function() end}
 end
 `;
suite('Custom shader loader mounts once and updates dimensions and input on each draw',[file],`
 eq(mounts,1);eq(writes,1)
 eq(ix.FieldVisuals.DrawShader('world',.5,.45,0,0),true)
 eq(draws,1);eq(copies,1);eq(uniforms['$c0_z'],1/1920);eq(in2D,false)
 function ScrW() return 1280 end
 ix.FieldVisuals.DrawShader('nvg',.7,1,.02,18)
 eq(uniforms['$c1_x'],1/1280);eq(uniforms['$c0_z'],.02);eq(uniforms['$c0_w'],18)
 eq(ix.FieldVisuals.DrawShader('lens',.4,0,0,0),true);eq(draws,3);eq(uniforms['$c0_x'],.4);eq(uniforms['$c1_x'],1/1280)
 values.fieldCustomShaders=false;eq(ix.FieldVisuals.DrawShader('world',1,1,0,0),false);eq(draws,3)
 `,setup);
suite('Unsupported renderer never mounts or draws custom shaders',[file],`
 eq(mounts,0);eq(draws,0);eq(ix.FieldVisuals.DrawShader('world',1,1,0,0),false)
 `,setup+'dx=90');
suite('Failed shader mount falls back without drawing',[file],`
 eq(mounts,1);eq(ix.FieldVisuals.DrawShader('world',1,1,0,0),false);eq(copies,0)
 `,setup+'mountOK=false');
suite('Failed shader material falls back without drawing',[file],`
 eq(ix.FieldVisuals.DrawShader('world',1,1,0,0),false);eq(draws,0)
 `,setup+'failMaterial=true');
};
