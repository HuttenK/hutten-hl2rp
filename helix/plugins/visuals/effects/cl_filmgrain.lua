-- Native, restrained world-only presentation. No external noise or shader assets.
hook.Remove("RenderScreenspaceEffects", "autonomous.filmgrain")
local C={}
ix.CinematicFX=C
local options={
 cinematicEffects={true,"Cinematic effects","Кинематографические эффекты"},
 cinematicGrain={20,"Film grain intensity","Интенсивность зерна"},
 cinematicVignette={15,"Edge shading intensity","Затемнение краёв"},
 cinematicGrade={20,"Color grading intensity","Интенсивность цветокоррекции"},
 cinematicLens={false,"Lens flare and lens dirt","Блики и загрязнение объектива"}
}
for key,info in pairs(options) do
 ix.lang.AddTable("en",{["opt"..key]=info[2]})
 ix.lang.AddTable("ru",{["opt"..key]=info[3]})
 ix.option.Add(key,type(info[1])=="boolean" and ix.type.bool or ix.type.number,info[1],{category="appearance",min=0,max=100,decimals=0})
end
function C.Strength(key)
 local value=tonumber(ix.option.Get(key,options[key][1])) or 0
 if value~=value then return 0 end
 return math.Clamp(value,0,100)/100
end
function C.Visible()
 local p=LocalPlayer()
 return ix.option.Get("cinematicEffects",true) and IsValid(p) and p.GetCharacter and p:GetCharacter() and p:Alive()
  and not gui.IsGameUIVisible() and not IsValid(ix.gui.fieldlink) and not IsValid(ix.gui.menu) and not IsValid(ix.gui.characterMenu)
  and not IsValid(ix.gui.levelup) and not (ix.infoMenu and ix.infoMenu.open)
end
local tiles
local seed=19273
local function RandomByte()
 -- Local deterministic generator: never reseed or consume gameplay randomness.
 seed=(seed*16807)%2147483647
 return seed%256
end
local function BuildTiles()
 tiles={}
 for frame=1,2 do
  local rt=GetRenderTargetEx("hutten_grain_v1_"..frame,64,64,RT_SIZE_NO_CHANGE,MATERIAL_RT_DEPTH_NONE,0,0,IMAGE_FORMAT_RGBA8888)
  render.PushRenderTarget(rt)
  render.Clear(0,0,0,255,true,false)
  cam.Start2D()
  for y=0,63 do for x=0,63 do
   local value=RandomByte()
   surface.SetDrawColor(value,value,value,255); surface.DrawRect(x,y,1,1)
  end end
  cam.End2D()
  render.PopRenderTarget()
  tiles[frame]=CreateMaterial("hutten_grain_material_v1_"..frame,"UnlitGeneric",{
   ["$basetexture"]=rt:GetName(),["$translucent"]="1",["$vertexalpha"]="1",["$vertexcolor"]="1",["$ignorez"]="1"
  })
 end
end
-- Material also returns load time; parenthesize the final call to keep it out of the array.
local edges={Material("vgui/gradient-l"),Material("vgui/gradient-r"),Material("vgui/gradient-u"),(Material("vgui/gradient-d"))}
local grade={ ["$pp_colour_addr"]=0,["$pp_colour_addg"]=0,["$pp_colour_addb"]=0,
 ["$pp_colour_brightness"]=0,["$pp_colour_contrast"]=1,["$pp_colour_colour"]=1,
 ["$pp_colour_mulr"]=0,["$pp_colour_mulg"]=0,["$pp_colour_mulb"]=0 }
function C.Draw()
 if not C.Visible() then return end
 local grain,vignette,grading=C.Strength("cinematicGrain"),C.Strength("cinematicVignette"),C.Strength("cinematicGrade")
 if grain==0 and vignette==0 and grading==0 then return end
 if grading>0 then
  grade["$pp_colour_contrast"]=1+0.035*grading
  grade["$pp_colour_colour"]=1-0.10*grading
  DrawColorModify(grade)
 end
 if grain>0 and not tiles then BuildTiles() end
 local w,h=ScrW(),ScrH()
 cam.Start2D()
 if grain>0 then
  local tick=ix.option.Get("disableAnimations",false) and 0 or math.floor(RealTime()*24)
  local u,v=(tick*17%64)/64,(tick*29%64)/64
  surface.SetMaterial(tiles[tick%2+1]); surface.SetDrawColor(255,255,255,6*grain)
  -- Native-size grains tiled over the view, never a stretched fullscreen TV image.
  surface.DrawTexturedRectUV(0,0,w,h,u,v,u+w/64,v+h/64)
 end
 if vignette>0 then
  surface.SetDrawColor(0,0,0,90*vignette)
  for i,mat in ipairs(edges) do
   surface.SetMaterial(mat)
   if i==1 then surface.DrawTexturedRect(0,0,w*0.16,h)
   elseif i==2 then surface.DrawTexturedRect(w*0.84,0,w*0.16,h)
   elseif i==3 then surface.DrawTexturedRect(0,0,w,h*0.13)
   else surface.DrawTexturedRect(0,h*0.87,w,h*0.13) end
  end
 end
 cam.End2D()
end
hook.Add("RenderScreenspaceEffects","HuttenCinematicWorld",C.Draw)
