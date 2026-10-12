local N=ix.FoundationNet
N.colors={bg=Color(8,15,21),panel=Color(17,28,36),line=Color(40,62,72),text=Color(229,240,239),muted=Color(133,159,169),red=Color(245,95,112),amber=Color(111,233,219)}
local C=N.colors
for name,size in pairs({Title=38,Text=26,Mono=20,Hero=70,Small=18}) do
 surface.CreateFont('Foundation'..name,{font=name=='Mono' and 'Consolas' or 'Bahnschrift',size=size,weight=name=='Hero' and 600 or 500,extended=true,antialias=true})
end
local artwork=N.artwork or {}
local cached={}
function N.Art(key,x,y,w,h,alpha,contain)
 local path=artwork[key];if not path then return false end
 cached[key]=cached[key] or Material(path,'smooth noclamp')
 local material=cached[key];if material:IsError() then return false end
 surface.SetMaterial(material);surface.SetDrawColor(255,255,255,alpha or 255)
 -- Crop, never stretch. Banners retain their photographic proportions.
 local ratio=material:Width()/math.max(1,material:Height());local target=w/h
 if contain then
  if target>ratio then local width=h*ratio;x=x+(w-width)/2;w=width else local height=w/ratio;y=y+(h-height)/2;h=height end
  target=w/h
 end
 local u,v=1,1;if target>ratio then v=ratio/target else u=target/ratio end
 surface.DrawTexturedRectUV(x,y,w,h,(1-u)/2,(1-v)/2,(1+u)/2,(1+v)/2);return true
end
function N.CutBox(x,y,w,h,color,cut)
 local d=cut or 12;draw.NoTexture();surface.SetDrawColor(color)
 surface.DrawPoly({{x=x,y=y},{x=x+w-d,y=y},{x=x+w,y=y+d},{x=x+w,y=y+h},{x=x+d,y=y+h},{x=x,y=y+h-d}})
end
local shapes={
 utilities={{{.2,.08},{.2,.9}},{{.5,.08},{.5,.9}},{{.8,.08},{.8,.9}},{{.08,.3},{.32,.3}},{{.38,.7},{.62,.7}},{{.68,.4},{.92,.4}}},
 home={{{.1,.45},{.5,.1},{.9,.45}},{{.22,.4},{.22,.9},{.78,.9},{.78,.4}},{{.43,.9},{.43,.65},{.6,.65},{.6,.9}}},
 power={{{.58,.05},{.18,.58},{.48,.58},{.4,.95},{.85,.4},{.55,.4},{.58,.05}}},
 infection={{{.25,.1},{.25,.25},{.75,.75},{.75,.9}},{{.75,.1},{.75,.25},{.25,.75},{.25,.9}},{{.25,.28},{.75,.28}},{{.34,.4},{.66,.4}},{{.34,.6},{.66,.6}},{{.25,.73},{.75,.73}}},
 logs={{{.23,.1},{.8,.1},{.8,.9},{.23,.9},{.23,.1}},{{.35,.32},{.65,.32}},{{.35,.5},{.65,.5}},{{.35,.68},{.57,.68}}},
 service={{{.18,.12},{.43,.32},{.36,.5},{.7,.85},{.85,.7},{.5,.36},{.55,.15},{.78,.1}},{{.13,.8},{.27,.66}}},
 web={{{.1,.5},{.9,.5}},{{.18,.25},{.82,.25}},{{.18,.75},{.82,.75}},{{.5,.06},{.32,.27},{.32,.73},{.5,.94},{.68,.73},{.68,.27},{.5,.06}}},
 map={{{.08,.25},{.35,.1},{.65,.28},{.92,.1},{.92,.78},{.65,.94},{.35,.78},{.08,.93},{.08,.25}},{{.35,.1},{.35,.78}},{{.65,.28},{.65,.94}}},
 editor={{{.18,.7},{.7,.18},{.86,.34},{.34,.86},{.14,.9},{.18,.7}},{{.6,.28},{.76,.44}}},
 exit={{{.45,.12},{.15,.12},{.15,.88},{.45,.88}},{{.4,.5},{.92,.5},{.7,.28}},{{.92,.5},{.7,.72}}},
 card={{{.08,.25},{.92,.25},{.92,.8},{.08,.8},{.08,.25}},{{.1,.43},{.9,.43}},{{.62,.63},{.8,.63}}}
}
function N.Icon(name,x,y,size,color)
 surface.SetDrawColor(color or C.amber)
 if name=='web' then surface.DrawCircle(x+size/2,y+size/2,size*.44,color or C.amber) end
 for _,path in ipairs(shapes[name] or shapes.logs) do for i=2,#path do
  local a,b=path[i-1],path[i];surface.DrawLine(x+a[1]*size,y+a[2]*size,x+b[1]*size,y+b[2]*size)
  surface.DrawLine(x+a[1]*size+1,y+a[2]*size,x+b[1]*size+1,y+b[2]*size)
 end end
end
function N.Hover(panel)
 local target=panel.foundationHover and 1 or 0
 panel.motion=Lerp(ix.option.Get('disableAnimations',false) and 1 or math.min(FrameTime()*12,1),panel.motion or 0,target)
 return panel.motion
end
function N.ButtonFace(panel,w,h,active)
 local t=N.Hover(panel)
 N.CutBox(0,0,w,h,active and Color(35,75,79) or Color(20+12*t,35+17*t,45+19*t),10)
 surface.SetDrawColor(active and C.amber or Color(54,88,99,120+100*t));surface.DrawLine(0,h-1,w-10,h-1)
 if active or t>.01 then surface.SetDrawColor(111,233,219,255*(active and 1 or t));surface.DrawRect(0,8,3,h-16) end
end
