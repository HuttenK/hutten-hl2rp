local I = ix.Immersion
if I.StopSounds then I.StopSounds() end
local defaults = {immersionExposure=40, immersionBreathing=35, immersionAmbience=25,
 immersionImpact=45, immersionEquipment=40, immersionMotion=35, immersionFootsteps=60}
local labels = {
 immersionExposure={"Lighting adaptation","Адаптация к освещению"},
 immersionBreathing={"Contextual breathing","Контекстное дыхание"},
 immersionAmbience={"Shelter and outdoor ambience","Атмосфера помещений и улицы"},
 immersionImpact={"Directional impact feedback","Направленные эффекты попаданий"},
 immersionEquipment={"Equipment lens effects","Эффекты линз снаряжения"},
 immersionMotion={"Subtle weapon movement","Лёгкое движение оружия"},
 immersionFootsteps={"Contextual footsteps","Контекстные шаги"}}
for key, value in pairs(defaults) do
 ix.option.Add(key,ix.type.number,value,{category="appearance",min=0,max=100,decimals=0})
 ix.lang.AddTable("en",{["opt"..key]=labels[key][1]})
 ix.lang.AddTable("ru",{["opt"..key]=labels[key][2]})
end
function I.Strength(key) return I.Unit((tonumber(ix.option.Get(key,defaults[key])) or 0)/100) end
function I.Active()
 local p=LocalPlayer()
 return ix.CinematicFX and ix.CinematicFX.Visible() and p:GetViewEntity()==p
  and not p:ShouldDrawLocalPlayer() and p:GetLocalVar("ragdoll",0)==0
end
local sounds={}
function I.StopSounds()
 for _,patch in pairs(sounds) do patch:Stop() end
 sounds={}
end
local function Loop(key,path,volume,pitch)
 local patch=sounds[key]
 if volume<0.001 then if patch then patch:Stop(); sounds[key]=nil end return end
 if not patch then
  patch=CreateSound(LocalPlayer(),path)
  if not patch then return end
  sounds[key]=patch; patch:PlayEx(0,pitch or 100)
 end
 patch:ChangeVolume(volume,0.25)
 patch:ChangePitch(pitch or 100,0.4)
end
local state={light=0,adapted=nil,outdoors=0,shelter=0,effort=0,wet=0}
I.State=state
local nextSample=0
local owner,character
local dirs={Vector(1,0,0),Vector(-1,0,0),Vector(0,1,0),Vector(0,-1,0)}
local function Sample(p)
 local eye=p:EyePos()
 local light=render.GetLightColor(eye)
 state.light=I.Unit(light.x*0.2126+light.y*0.7152+light.z*0.0722)
 state.adapted=state.adapted or state.light
 local roof=util.TraceLine({start=eye,endpos=eye+Vector(0,0,4096),filter=p,mask=MASK_SOLID_BRUSHONLY})
 state.sky=roof.HitSky or not roof.Hit
 local enclosure=0
 for _,dir in ipairs(dirs) do
  local trace=util.TraceLine({start=eye,endpos=eye+dir*512,filter=p,mask=MASK_SOLID_BRUSHONLY})
  enclosure=enclosure+(1-trace.Fraction)/4
 end
 state.enclosure=state.sky and 0 or enclosure
 state.rain=I.Rain(p)
 state.weatherAudio=gWeather and gWeather.GetCurrentWeather and IsValid(gWeather:GetCurrentWeather())
 state.lens=false; state.mask=false
 for _,slot in ipairs({"mask","glasses","head","torso"}) do
  local item=I.Equipped(p,slot)
  if item then
   state.mask=state.mask or item.isGasmask==true
   state.lens=state.lens or item.immersionLens==true
  end
 end
end
function I.Update()
 if not I.Active() then
  I.StopSounds(); state.adapted=nil; state.impact=nil; state.effort=0; state.wet=0
  owner=nil; character=nil; return
 end
 local p=LocalPlayer(); local c=p:GetCharacter()
 if owner~=p or character~=c then
  I.StopSounds(); state.adapted=nil; state.impact=nil; state.wet=0; state.effort=0
  state.outdoors=0; state.shelter=0; nextSample=0; owner=p; character=c
 end
 local dt=FrameTime()
 if RealTime()>=nextSample then Sample(p); nextSample=RealTime()+0.4 end
 state.adapted=I.Approach(state.adapted or state.light,state.light,dt,state.light> (state.adapted or 0) and 0.8 or 2.5)
 state.outdoors=I.Approach(state.outdoors,state.sky and 1 or 0,dt,1.5)
 state.shelter=I.Approach(state.shelter,state.enclosure or 0,dt,1.5)
 local health=c.Health and c:Health()
 local pain=health and health.GetPain and health:GetPain() or 0
 local effort=I.Exertion(p:GetLocalVar("stm",100),c.GetMaxStamina and c:GetMaxStamina() or 100,pain)
 state.effort=I.Approach(state.effort,effort,dt,effort>state.effort and 1.5 or 4)
 local submerged=p:WaterLevel()>=3
 -- Weather addons may supply a normalized rain intensity. No hard dependency on one weather framework.
 local rain=state.rain or 0
 local wetTarget=state.lens and ((submerged and 1) or (state.sky and rain) or 0) or 0
 state.wet=I.Approach(state.wet,wetTarget,dt,wetTarget>state.wet and 0.5 or 8)
 local breathing=I.Strength("immersionBreathing")*(submerged and 0 or 1)
 if ix.GasMask and ix.GasMask.Breathing then breathing=0 end
 Loop("breath","player/breathe1.wav",(state.effort*0.32+(state.mask and 0.055 or 0))*breathing,92+state.effort*12)
 local ambience=I.Strength("immersionAmbience")*((submerged or state.weatherAudio) and 0 or 1)
 Loop("outside","ambient/wind/wind_outdoors_1.wav",state.outdoors*0.14*ambience)
 Loop("inside","ambient/atmosphere/garage_tone.wav",state.shelter*0.08*ambience)
end
hook.Add("Think","ixContextualImmersion",I.Update)
hook.Add("ShutDown","ixContextualImmersion",I.StopSounds)
net.Receive("ixImmersionImpact",function()
 local strength=I.Unit(net.ReadFloat()); local directional=net.ReadBool()
 local source=directional and net.ReadVector() or nil
 if not I.Active() then return end
 state.impact={strength=strength,source=source,time=RealTime()}
end)
local left=Material("vgui/gradient-l")
local right=Material("vgui/gradient-r")
local top=Material("vgui/gradient-u")
local bottom=Material("vgui/gradient-d")
local grade={['$pp_colour_addr']=0,['$pp_colour_addg']=0,['$pp_colour_addb']=0,
 ['$pp_colour_brightness']=0,['$pp_colour_contrast']=1,['$pp_colour_colour']=1,
 ['$pp_colour_mulr']=0,['$pp_colour_mulg']=0,['$pp_colour_mulb']=0}
local function Edge(mat,x,y,w,h,r,g,b,a)
 surface.SetMaterial(mat); surface.SetDrawColor(r,g,b,a); surface.DrawTexturedRect(x,y,w,h)
end
hook.Add("RenderScreenspaceEffects","ixContextualImmersion",function()
 if not I.Active() then return end
 local p=LocalPlayer(); local w,h=ScrW(),ScrH()
 local exposure=I.Exposure(state.light,state.adapted or state.light)*I.Strength("immersionExposure")
 if math.abs(exposure)>0.0001 then grade['$pp_colour_brightness']=exposure; DrawColorModify(grade) end
 local lens=state.lens and I.Strength("immersionEquipment") or 0
 local impact=state.impact
 local pulse=impact and math.max(0,1-(RealTime()-impact.time)/0.85)^2*impact.strength*I.Strength("immersionImpact") or 0
 if lens==0 and pulse==0 then return end
 cam.Start2D()
 if lens>0 then
  -- Peripheral reflections and breathing condensation; the center stays unobscured.
  Edge(left,0,0,w*0.09,h,124,157,164,(5+state.effort*15)*lens)
  Edge(right,w*0.91,0,w*0.09,h,124,157,164,(5+state.effort*15)*lens)
  Edge(bottom,0,h*0.92,w,h*0.08,195,205,208,(5+state.effort*12)*lens)
  for n=1,12 do
   local x=(n%2==0 and 0.02 or 0.91)*w+(n*19%60)
   local y=((n*0.173+(ix.option.Get("disableAnimations",false) and 0 or RealTime()*0.012))%1)*h
   surface.SetDrawColor(182,204,210,38*state.wet*lens)
   surface.DrawLine(x,y,x+1,y+7+n%5)
  end
 end
 if lens>0 and pulse>0 then
  -- Brief lens stress glints, not invented persistent item damage.
  for n=1,4 do
   local x=(n%2==0 and 0.06 or 0.92)*w
   local y=(0.18+n*0.13)*h
   surface.SetDrawColor(211,222,229,110*pulse*lens)
   surface.DrawLine(x,y,x+w*0.018,y-h*0.045)
   surface.DrawLine(x+w*0.018,y-h*0.045,x+w*0.026,y-h*0.04)
  end
 end
 if pulse>0 then
  local side,front=0,0
  if impact.source then
   local delta=(impact.source-p:EyePos()):GetNormalized(); local ang=p:EyeAngles()
   side=delta:Dot(ang:Right()); front=delta:Dot(ang:Forward())
  end
  Edge(left,0,0,w*0.16,h,132,36,38,65*pulse*(impact.source and math.max(0,-side) or 0.5))
  Edge(right,w*0.84,0,w*0.16,h,132,36,38,65*pulse*(impact.source and math.max(0,side) or 0.5))
  Edge(top,0,0,w,h*0.13,132,36,38,55*pulse*(impact.source and math.max(0,front) or 0.5))
  Edge(bottom,0,h*0.87,w,h*0.13,132,36,38,55*pulse*(impact.source and math.max(0,-front) or 0.5))
 end
 cam.End2D()
end)
-- Called inside Helix's existing viewmodel path, after lower/raise rotation.
-- Never changes EyeAngles, aim, recoil or returns from a competing CalcView hook.
function I.WeaponMotion(p,weapon,pos,ang)
 if not I.Active() or ix.option.Get("disableAnimations",false) or not IsValid(weapon) then return end
 if weapon.GetViewModelPosition or weapon.CalcViewModelView or weapon.GetPDAEquipped or weapon.ARC9 or weapon.ArcCW then return end
 if p:KeyDown(IN_ATTACK2) or p:InVehicle() then return end
 local amount=I.Strength("immersionMotion")
 local speed=math.min(p:GetVelocity():Length2D()/220,1)
 local t=RealTime()
 local wave=math.sin(t*(1.8+state.effort))*(0.04+state.effort*0.06)+math.sin(t*7)*speed*0.10
 pos:Add(ang:Up()*wave*amount)
 ang:RotateAroundAxis(ang:Forward(),math.sin(t*3.5)*speed*0.18*amount)
end
hook.Add("EntityEmitSound","ixImmersionFootsteps",function(data)
 if not I.Active() or data.Entity~=LocalPlayer() then return end
 local path=string.lower(data.SoundName or "")
 if not string.find(path,"player/footsteps/",1,true) then return end
 local amount=I.Strength("immersionFootsteps")
 if amount==0 then return end
 local p=LocalPlayer()
 -- Retain Source's material-selected sample. No extra footsteps or audible stealth bypass.
 local volume,pitch=I.FootstepMix(p:GetVelocity():Length2D(),p:KeyDown(IN_WALK) or p:Crouching(),I.Equipped(p,"vest")~=nil)
 data.Volume=(data.Volume or 1)*(1+(volume-1)*amount)
 data.Pitch=math.Clamp((data.Pitch or 100)+(pitch-100)*amount,1,255)
 return true
end)
