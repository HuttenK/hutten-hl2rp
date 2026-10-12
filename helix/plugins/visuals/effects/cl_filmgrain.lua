-- Native, restrained world-only presentation. No external noise or shader assets.
hook.Remove("RenderScreenspaceEffects", "autonomous.filmgrain")
local C={}
ix.CinematicFX=C
local options={
 cinematicEffects={true,"Cinematic effects","Кинематографические эффекты"},
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
-- Material also returns load time; parenthesize the final call to keep it out of the array.
local edges={Material("vgui/gradient-l"),Material("vgui/gradient-r"),Material("vgui/gradient-u"),(Material("vgui/gradient-d"))}
local grade={ ["$pp_colour_addr"]=0,["$pp_colour_addg"]=0,["$pp_colour_addb"]=0,
 ["$pp_colour_brightness"]=0,["$pp_colour_contrast"]=1,["$pp_colour_colour"]=1,
 ["$pp_colour_mulr"]=0,["$pp_colour_mulg"]=0,["$pp_colour_mulb"]=0 }
function C.Draw()
 if not C.Visible() or ArcticNVGs_Enabled then return end
 local client=LocalPlayer()
 if client:GetNWFloat("ixToxicLevel",0)>.01 or client:GetNetVar("ixInToxicZone",false) then return end
 local vignette,grading=C.Strength("cinematicVignette"),C.Strength("cinematicGrade")
 if ix.FieldVisuals then
  -- One owner for edge shading: do not stack the legacy and Fieldlink options.
  if not ix.option.Get("fieldCinematic",true) or ix.option.Get("fieldCinematicStrength",.5)<=0 then return end
  vignette=math.Clamp(ix.option.Get("fieldEdgeShading",.35),0,1)
 end
 if vignette==0 and grading==0 then return end
 if grading>0 and not ix.FieldVisuals then
  grade["$pp_colour_contrast"]=1+0.035*grading
  grade["$pp_colour_colour"]=1-0.10*grading
  DrawColorModify(grade)
 end
 local w,h=ScrW(),ScrH()
 cam.Start2D()
 -- No world grain: tiled scrolling noise forms a visible grid in dark scenes.
 if vignette>0 then
  surface.SetDrawColor(0,0,0,35*vignette)
  for i,mat in ipairs(edges) do
   if not mat:IsError() then
   surface.SetMaterial(mat)
   if i==1 then surface.DrawTexturedRect(0,0,w*0.24,h)
   elseif i==2 then surface.DrawTexturedRect(w*0.76,0,w*0.24,h)
   elseif i==3 then surface.DrawTexturedRect(0,0,w,h*0.22)
   else surface.DrawTexturedRect(0,h*0.78,w,h*0.22) end
   end
  end
 end
 cam.End2D()
end
hook.Add("RenderScreenspaceEffects","HuttenCinematicWorld",C.Draw)
