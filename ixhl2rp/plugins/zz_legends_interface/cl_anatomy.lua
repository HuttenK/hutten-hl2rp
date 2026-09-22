-- Original scalable anatomy artwork; coordinates use a 100 x 240 canvas.
-- Front view: the character's left limbs appear on the viewer's right.
ix.Anatomy = {}
local A = ix.Anatomy
-- Rounded anatomical contours, with relaxed arms and a slightly open stance.
A.Shapes = {
 [1]={{43,5},{52,3},{60,7},{63,15},{61,24},{56,31},{44,32},{39,26},{38,17}},
 [2]={{39,36},{58,34},{68,39},{65,49},{69,65},{68,78},{56,76},{42,79},{29,84},{30,65},{33,46}},
 [3]={{30,89},{43,83},{58,81},{68,85},{66,100},{58,107},{50,103},{42,108},{30,104},{27,99}},
 [4]={{73,40},{80,44},{87,58},{95,79},{96,96},{92,115},{88,123},{81,121},{80,115},{84,108},{85,95},{82,80},{74,66},{69,54}},
 [5]={{27,44},{23,44},{16,57},{7,79},{4,98},{5,119},{10,126},{16,124},{18,117},{15,110},{16,98},{21,84},{27,71},{29,57}},
 [6]={{57,109},{67,111},{70,128},{70,144},{76,166},{79,192},{79,216},{83,229},{79,234},{71,232},{68,226},{67,204},{63,184},{58,169},{53,154},{50,132}},
 [7]={{34,111},{43,111},{47,121},{44,139},{41,155},{35,173},{32,196},{31,216},{28,227},{19,233},{12,230},{15,223},{21,213},{21,189},{23,167},{24,145},{27,126}}
}
-- Chaikin subdivision rounds the artwork once, rather than rebuilding it per frame.
for id,shape in pairs(A.Shapes) do
 for pass=1,2 do
  local rounded={}
  for i,p in ipairs(shape) do
   local q=shape[i%#shape+1]
   rounded[#rounded+1]={p[1]*0.75+q[1]*0.25,p[2]*0.75+q[2]*0.25}
   rounded[#rounded+1]={p[1]*0.25+q[1]*0.75,p[2]*0.25+q[2]*0.75}
  end
  shape=rounded
 end
 A.Shapes[id]=shape
end
function A.Read(character)
 local health=character and character.Health and character:Health()
 if not health or not health.body or not health.body.parts then return nil end
 local state={blood=1,parts={},health=health,painRemaining=0}
 local missing=ix.Amputation and ix.Amputation.GetLimb(character)
 for _,condition in pairs(health.hediffs or {}) do
  if condition.uniqueID=="bleeding" then
   local severity=tonumber(condition:GetSeverity()) or 0
   if severity==severity then state.blood=math.min(state.blood,1-math.Clamp(severity,0,1)) end
  end
  if condition.uniqueID=="painkiller" and (condition.tended_time or -1)>0 then
   state.painRemaining=math.max(state.painRemaining,(condition.tended_start or 0)+condition.tended_time-os.time())
  end
 end
 for _,part in ipairs(health.body.parts) do
  if not part.hidden then
   local maximum=health:GetMaxHealth(part.id)
   local current=health:GetPartHealth(part.id)
   local amputated=missing and missing.hitgroup==part.hitgroup or false
   local fractured=false
   for _,condition in pairs(health.hediffs or {}) do
    if condition.part==part.id and condition.isFracture and condition:GetSeverity()>0 then fractured=true break end
   end
   if amputated then current=0 end
   state.parts[#state.parts+1]={id=part.id,hitgroup=part.hitgroup,name=part.name,current=current,maximum=maximum,
    amputated=amputated,fractured=fractured,ratio=maximum>0 and math.Clamp(current/maximum,0,1) or 0}
  end
 end
 return state
end
function A.Color(ratio)
 if ratio>=0.99 then return Color(181,157,156) end
 if ratio>0.5 then return Color(222,179,119) end
 return Color(244,77,91)
end
-- Cache the stroke geometry separately for the compact HUD and large TAB diagram.
local meshes={}
local meshCount=0
local function Mesh(x,y,w,h)
 local key=x..":"..y..":"..w..":"..h
 if meshes[key] then return meshes[key] end
 local scale=math.min(w/100,h/240)
 local ox,oy=x+(w-100*scale)/2,y+(h-240*scale)/2
 local mesh={}
 for id,shape in pairs(A.Shapes) do
  mesh[id]={}
  for layer,width in ipairs({5.0,2.6,0.85}) do
   local segments={}; local radius=width*math.Clamp(scale,0.7,1.8)
   for i,p in ipairs(shape) do
    local q=shape[i%#shape+1]
    local dx,dy=q[1]-p[1],q[2]-p[2]
    local length=math.sqrt(dx*dx+dy*dy)
    if length>0 then
     local nx,ny=-dy/length*radius,dx/length*radius
     local px,py,qx,qy=ox+p[1]*scale,oy+p[2]*scale,ox+q[1]*scale,oy+q[2]*scale
     segments[#segments+1]={{x=px-nx,y=py-ny},{x=qx-nx,y=qy-ny},{x=qx+nx,y=qy+ny},{x=px+nx,y=py+ny}}
    end
   end
   mesh[id][layer]=segments
  end
 end
 -- Only two sizes are normally used; bound the cache during window resizing.
 if meshCount>=6 then meshes={}; meshCount=0 end
 meshCount=meshCount+1
 meshes[key]=mesh
 return mesh
end
function A.Draw(x,y,w,h,state,hovered)
 if not state or w<=0 or h<=0 then return end
 local mesh=Mesh(x,y,w,h)
 draw.NoTexture()
 for _,part in ipairs(state.parts) do
  local layers=mesh[part.hitgroup]
  if layers then
   local color=part.id==hovered and Color(255,224,217) or (part.amputated and Color(125,64,73) or (part.fractured and Color(244,77,91) or A.Color(part.ratio)))
   for layer,segments in ipairs(layers) do
    surface.SetDrawColor(color.r,color.g,color.b,({8,20,190})[layer])
    for _,segment in ipairs(segments) do
     surface.DrawPoly(segment)
    end
   end
  end
 end
end

-- Hit-test the same rounded contours and aspect-fit transform used by drawing.
function A.HitTest(mx,my,x,y,w,h,state)
 if not state or w<=0 or h<=0 then return nil end
 local scale=math.min(w/100,h/240)
 local px=(mx-x-(w-100*scale)/2)/scale
 local py=(my-y-(h-240*scale)/2)/scale
 for _,part in ipairs(state.parts) do
  local shape=A.Shapes[part.hitgroup]
  if shape then
   local inside=false
   for i,p in ipairs(shape) do
    local q=shape[i%#shape+1]
    if (p[2]>py)~=(q[2]>py) and px<(q[1]-p[1])*(py-p[2])/(q[2]-p[2])+p[1] then inside=not inside end
   end
   if inside then return part end
  end
 end
end
