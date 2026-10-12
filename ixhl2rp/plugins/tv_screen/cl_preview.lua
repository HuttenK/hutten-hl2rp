local P,T=PLUGIN,ix.TV
local cyan=Color(70,235,241,255)
local white=Color(235,255,255,255)
local shadow=Color(3,12,18,230)
local fill=Color(45,215,225,32)

function T.PreviewCorners(screen)
 local origin,ang,scale,height,center=T.ScreenPlane(screen);if not origin then return end
 local right,down=ang:Forward()*(1024*scale),ang:Right()*(height*scale)
 return center,{origin,origin+right,origin+right+down,origin+down}
end

-- Clip the projected polygon to the viewport before feeding it to surface.
-- A large or very close screen can otherwise produce enormous coordinates.
local function clipPolygon(points,w,h)
 for _,edge in ipairs({{'x',0,1},{'x',w,-1},{'y',0,1},{'y',h,-1}}) do
  local out={};local axis,bound,sign=edge[1],edge[2],edge[3]
  for i,a in ipairs(points) do
   local b=points[i%#points+1]
   local da,db=(a[axis]-bound)*sign,(b[axis]-bound)*sign
   if da>=0 then out[#out+1]=a end
   if (da>=0)~=(db>=0) then
    local t=da/(da-db);out[#out+1]={x=a.x+(b.x-a.x)*t,y=a.y+(b.y-a.y)*t}
   end
  end
  points=out;if #points<3 then return {} end
 end
 -- Surface polygons are one-sided. Reverse the winding when viewing the
 -- back of a screen so the placement guide stays visible from either side.
 local area=0
 for i,a in ipairs(points) do local b=points[i%#points+1];area=area+a.x*b.y-b.x*a.y end
 if area<0 then local out={};for i=#points,1,-1 do out[#out+1]=points[i] end;return out end
 return points
end
local function segment(a,b,w,h,color)
 if not a.visible or not b.visible then return end
 local dx,dy=b.x-a.x,b.y-a.y;local low,high=0,1
 for _,bound in ipairs({{-dx,a.x},{dx,w-a.x},{-dy,a.y},{dy,h-a.y}}) do
  local p,q=bound[1],bound[2]
  if p==0 then if q<0 then return end
  else local t=q/p;if p<0 then low=math.max(low,t) else high=math.min(high,t) end;if low>high then return end end
 end
 local x1,y1,x2,y2=a.x+dx*low,a.y+dy*low,a.x+dx*high,a.y+dy*high
 surface.SetDrawColor(shadow)
 for i=-2,2 do surface.DrawLine(x1+i,y1,x2+i,y2);surface.DrawLine(x1,y1+i,x2,y2+i) end
 surface.SetDrawColor(color);surface.DrawLine(x1,y1,x2,y2);surface.DrawLine(x1+1,y1,x2+1,y2)
 return true
end
function P:PaintScreenPreview()
 local ply=LocalPlayer();if not IsValid(ply) or not ply:IsAdmin() or gui.IsGameUIVisible() then return end
 local screen=self.placement and self.placementPreview or (IsValid(self.tvWindow) and self.editPreview)
 if not screen then return end
 local center,corners=T.PreviewCorners(screen);if not center then return end
 local w,h=ScrW(),ScrH();local points={};local allVisible=true;local visible=false
 for i,v in ipairs(corners) do points[i]=v:ToScreen();if not points[i].visible then allVisible=false end end
 draw.NoTexture()
 -- Existing screens play their channel while being adjusted. Keep only the
 -- boundary guide there; tint and central labels would cover the programme.
 if allVisible and self.placement then
  local polygon=clipPolygon(points,w,h)
  if #polygon>=3 then surface.SetDrawColor(fill);surface.DrawPoly(polygon);visible=true end
 end
 for i,a in ipairs(points) do if segment(a,points[i%4+1],w,h,cyan) then visible=true end end
 local c=center:ToScreen()
 if self.placement and c.visible and c.x>=0 and c.y>=0 and c.x<=w and c.y<=h then
  visible=true
  surface.SetDrawColor(shadow);surface.DrawRect(c.x-9,c.y-9,18,18)
  surface.SetDrawColor(white);surface.DrawOutlinedRect(c.x-5,c.y-5,10,10,2)
  surface.DrawLine(c.x-15,c.y,c.x-8,c.y);surface.DrawLine(c.x+8,c.y,c.x+15,c.y)
  surface.DrawLine(c.x,c.y-15,c.x,c.y-8);surface.DrawLine(c.x,c.y+8,c.x,c.y+15)
  local title=string.format('ЭКРАН  %.2f × %.2f',screen.config.w,screen.config.h)
  surface.SetFont('ixTVBody');local tw=surface.GetTextSize(title)
  local x=math.Clamp(c.x,tw*.5+10,math.max(tw*.5+10,w-tw*.5-10));local y=math.Clamp(c.y+25,8,h-28)
  draw.RoundedBox(4,x-tw*.5-8,y-4,tw+16,26,shadow)
  draw.SimpleText(title,'ixTVBody',x,y,white,TEXT_ALIGN_CENTER)
 end
 return visible
end
