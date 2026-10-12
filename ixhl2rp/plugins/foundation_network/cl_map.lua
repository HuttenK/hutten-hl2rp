local N=ix.FoundationNet
-- Schematic fallback and live overlays, independent of the player's PVS.
-- The optional solid renderer runs before the terminal enters its own target.
function N.MapSurfaceVertices(info)
 local material=info:GetMaterial();local name=material and material:GetName():lower() or ''
 if name:find('tools/',1,true) or name:find('sky',1,true) then return end
 local vertices=info:GetVertices();if not vertices or #vertices<3 then return end
 for _,v in ipairs(vertices) do
  if v.x~=v.x or v.y~=v.y or v.z~=v.z or math.abs(v.x)>100000 or math.abs(v.y)>100000 or math.abs(v.z)>100000 then return end
 end
 return vertices
end
function N.BeginMapGeometry()
 if N.geometry and N.geometry.version==6 and N.geometry.name==game.GetMap() then return N.geometry end
 if N.geometry then for _,m in ipairs(N.geometry.meshes or {}) do m:Destroy() end end
 local ok,surfaces=pcall(function() return game.GetWorld():GetBrushSurfaces() end)
 N.geometry={version=6,name=game.GetMap(),surfaces=ok and surfaces or {},next=1,faces={},edges={},edgeIndex={},histogram={x={},y={},z={}},samples=0,
  low=Vector(math.huge,math.huge,math.huge),high=Vector(-math.huge,-math.huge,-math.huge)}
 if not ok or not surfaces or #surfaces==0 then N.geometry.error='Геометрия BSP недоступна' end
 return N.geometry
end
local function pointKey(v) return string.format('%.1f,%.1f,%.1f',v.x,v.y,v.z) end
function N.StepMapGeometry(g)
 if g.ready or g.error then return end
 local deadline=SysTime()+.002;local count=0
 while g.next<=#g.surfaces and count<128 do
  local v=N.MapSurfaceVertices(g.surfaces[g.next]);g.next=g.next+1;count=count+1
  if v then
   local normal=(v[2]-v[1]):Cross(v[3]-v[1]):GetNormalized()
   local lo,hi=math.huge,-math.huge
   for i,a in ipairs(v) do
    g.samples=g.samples+1
    for _,axis in ipairs({'x','y','z'}) do local bin=math.floor(a[axis]/256);local counts=g.histogram[axis];counts[bin]=(counts[bin] or 0)+1 end
    lo=math.min(lo,a.z);hi=math.max(hi,a.z)
    g.low.x=math.min(g.low.x,a.x);g.low.y=math.min(g.low.y,a.y);g.low.z=math.min(g.low.z,a.z)
    g.high.x=math.max(g.high.x,a.x);g.high.y=math.max(g.high.y,a.y);g.high.z=math.max(g.high.z,a.z)
    local b=v[i%#v+1];local ka,kb=pointKey(a),pointKey(b);local key=ka<kb and ka..'/'..kb or kb..'/'..ka
    local old=g.edgeIndex[key]
    if old then
     -- Hide seams between coplanar faces; retain corners and brush boundaries.
     if math.abs(old.normal:Dot(normal))<.98 then old.corner=true end
     old.shared=true
    else local edge={a=a,b=b,normal=normal};g.edges[#g.edges+1]=edge;g.edgeIndex[key]=edge end
   end
   g.faces[#g.faces+1]={vertices=v,low=lo,high=hi}
  end
  if #g.faces>=180000 then g.limited=true;break end
  if SysTime()>=deadline then break end
 end
 if g.next>#g.surfaces or g.limited then
  g.ready=true;g.surfaces={};g.edgeIndex=nil
  if #g.faces==0 then g.error='Нет доступных поверхностей' end
  -- Huge backdrop faces and remote 3D-skybox geometry should not make the
  -- facility thumbnail microscopic. This changes framing, never geometry.
  g.detailLow=Vector();g.detailHigh=Vector()
  for _,axis in ipairs({'x','y','z'}) do
   local keys={};for bin in pairs(g.histogram[axis]) do keys[#keys+1]=bin end;table.sort(keys)
   local total,low,high=0,nil,nil
   for _,bin in ipairs(keys) do
    total=total+g.histogram[axis][bin]
    if not low and total>=g.samples*.02 then low=bin*256 end
    if not high and total>=g.samples*.98 then high=(bin+1)*256 end
   end
   g.detailLow[axis]=low or g.low[axis];g.detailHigh[axis]=high or g.high[axis]
  end
  g.histogram=nil
 end
end
-- Intersect a convex BSP face with a horizontal plane. Unlike a height grid,
-- this retains actual wall edges, narrow corridors and disconnected rooms.
function N.MapSection(vertices,z)
 local hits={}
 for i,a in ipairs(vertices) do
  local b=vertices[i%#vertices+1];local da,db=a.z-z,b.z-z
  if (da<=0 and db>0) or (db<=0 and da>0) then
   local t=(z-a.z)/(b.z-a.z);hits[#hits+1]=a+(b-a)*t
  end
 end
 if #hits>=2 and (hits[1]-hits[2]):LengthSqr()>.01 then return hits[1],hits[2] end
end
function N.MapAxes(yaw,pitch)
 local y,p=math.rad(yaw),math.rad(pitch)
 return Vector(math.sin(y),-math.cos(y),0),Vector(math.sin(p)*math.cos(y),math.sin(p)*math.sin(y),math.cos(p))
end
function N.MapProject(v,center,right,up,scale,w,h)
 local d=v-center;return w*.5+d:Dot(right)*scale,h*.5-d:Dot(up)*scale
end
function N.MapClipHeight(a,b,low,high)
 local dz=b.z-a.z
 if math.abs(dz)<.00001 then if a.z>=low and a.z<=high then return a,b end;return end
 local t1,t2=(low-a.z)/dz,(high-a.z)/dz
 if t1>t2 then t1,t2=t2,t1 end
 t1,t2=math.max(0,t1),math.min(1,t2)
 if t1<=t2 then return a+(b-a)*t1,a+(b-a)*t2 end
end
-- Liang-Barsky clipping prevents high zoom lines from spilling outside the map.
function N.MapClipLine(x1,y1,x2,y2,w,h)
 local dx,dy=x2-x1,y2-y1;local a,b=0,1
 for _,pair in ipairs({{-dx,x1},{dx,w-x1},{-dy,y1},{dy,h-y1}}) do
  local p,q=pair[1],pair[2]
  if p==0 then if q<0 then return end
  else local t=q/p;if p<0 then a=math.max(a,t) else b=math.min(b,t) end;if a>b then return end end
 end
 return x1+dx*a,y1+dy*a,x1+dx*b,y1+dy*b
end
local minimumSlice=176
local function finite(v,fallback)
 v=tonumber(v);if not v or v~=v or math.abs(v)==math.huge then return fallback end
 return v
end
function N.MapSliceBounds(panel)
 if not panel.cutaway or not panel.center then return end
 local half=math.Clamp(finite(panel.sliceSpan,minimumSlice),minimumSlice,131072)*.5
 local middle=panel.center.z-40
 return middle-half,middle+half
end
function N.MapMaxSliceSpan(panel)
 local e=N.Map3D and N.Map3D.engine
 local low,high
 if e and e.Bake.IsReady() and N.Map3D.MapBounds then low,high=N.Map3D.MapBounds(false)
 elseif panel.geometry then low,high=panel.geometry.low,panel.geometry.high end
 local middle=panel.center and panel.center.z-40 or 0
 if low and high and finite(low.z) and finite(high.z) and high.z>=low.z then
  return math.Clamp(2*math.max(math.abs(low.z-middle),math.abs(high.z-middle))+32,1024,131072)
 end
 return 8192
end
local PANEL={}
function PANEL:Init()
 self:SetTall(660);self.foundationControl='map';self.layers={areas=true,power=true,infection=true,terminals=true}
 self.useSolid=N.Map3D~=nil;self.mapProps=true;self.sliceSpan=minimumSlice
 self.yaw=45;self.pitch=55;self.orbitZoom=1;self.threeD=self.useSolid;self.cutaway=true;self.nextSync=RealTime()+5
 self.geometry=N.BeginMapGeometry()
end
function PANEL:SetData(data) self.data=data;self.dirty=true;if not self.center then self:Home() end end
function PANEL:Home()
 if not self.data then return end
 local o=self.data.origin;self.center=Vector(o[1],o[2],o[3]);self.radius=1400;self.orbitZoom=1;self.cutaway=true;self.sliceSpan=minimumSlice;self.dirty=true
end
function PANEL:SetLayerFraction(value)
 value=math.Clamp(finite(value,0),0,1);self.cutaway=value<1
 -- A quadratic track leaves more travel for the first few storeys. Maps
 -- do not have uniform floor heights, so expose a height band, not a count.
 if self.cutaway then self.sliceSpan=minimumSlice+(N.MapMaxSliceSpan(self)-minimumSlice)*value^2 end
 self.dirty=true
end
function PANEL:GetLayerFraction()
 if not self.cutaway then return 1 end
 return math.sqrt(math.Clamp((finite(self.sliceSpan,minimumSlice)-minimumSlice)/(N.MapMaxSliceSpan(self)-minimumSlice),0,1))
end
function N.SetupMapLayerSlider(slider,panel)
 slider.foundationControl='slider'
 local function change(self,x)
  self.dragX=math.Clamp(x,24,math.max(25,self:GetWide()-24))
  panel:SetLayerFraction((self.dragX-24)/math.max(1,self:GetWide()-48))
 end
 slider.OnSurfacePressed=function(self,key,x)
  if key~=MOUSE_LEFT then return end
  self.dragging=true;change(self,x)
 end
 slider.OnSurfaceDrag=function(self,dx)
  if self.dragging then change(self,(self.dragX or 24)+dx) end
 end
 slider.OnSurfaceReleased=function(self) self.dragging=false end
 slider.OnSurfaceWheel=function(_,delta) panel:SetLayerFraction(panel:GetLayerFraction()+delta*.02);return true end
 slider.Paint=function(self,w,h)
  local c=Color(96,226,216);local low,high=N.MapSliceBounds(panel)
  local info=low and ('Z '..math.floor(low)..' … '..math.ceil(high)..'  /  высота '..math.floor(high-low)) or 'Весь объект'
  draw.SimpleText('ВИДИМЫЕ ЭТАЖИ','FoundationMono',24,2,c)
  draw.SimpleText(info,'FoundationMono',w-24,2,Color(207,228,236),TEXT_ALIGN_RIGHT)
  local x=24+(w-48)*panel:GetLayerFraction()
  surface.SetDrawColor(31,60,72);surface.DrawRect(24,36,w-48,4)
  surface.SetDrawColor(c);surface.DrawRect(24,36,x-24,4);surface.DrawRect(x-5,28,10,20)
  draw.SimpleText('Один срез','FoundationMono',24,52,Color(174,193,204))
  draw.SimpleText('Все этажи','FoundationMono',w-24,52,Color(174,193,204),TEXT_ALIGN_RIGHT)
 end
end
function PANEL:ResetOrbit(full)
 local e=self.useSolid and N.Map3D and N.Map3D.engine
 if e and e.Bake.IsReady() and e.Bake.GetBounds then
  local low,high
  if N.Map3D.MapBounds then low,high=N.Map3D.MapBounds(full)
  elseif full and e.Bake.GetWorldBounds then low,high=e.Bake.GetWorldBounds() else low,high=e.Bake.GetBounds() end
  self.center=(low+high)*.5;self.radius=math.max((high-low):Length()*.53,256)
  self.orbitZoom=1;self.cutaway=false;self.threeD=true;self.dirty=true;return
 end
 local g=self.geometry;if not g.ready or g.error then return end
 local low,high=g.low,g.high
 if full==false then low,high=g.detailLow or low,g.detailHigh or high end
 local sky=N.Map3D and N.Map3D.SkyFilter and N.Map3D.SkyFilter()
 if sky then low,high=sky.low,sky.high end
 self.center=(low+high)*.5;self.radius=math.max((high-low):Length()*.53,256)
 self.orbitZoom=1;self.cutaway=false;self.threeD=true;self.dirty=true
end
function PANEL:Zoom(delta) self.orbitZoom=math.Clamp(self.orbitZoom*(delta>0 and 1.18 or 1/1.18),.25,32);self.dirty=true end
function PANEL:OnSurfaceWheel(delta) self:Zoom(delta);return true end
function PANEL:OnSurfaceDrag(dx,dy,key)
 if not self.center then return end
 if not self.threeD or self.panMode or key==MOUSE_RIGHT then
  local right,up=N.MapAxes(self.threeD and self.yaw or -90,self.threeD and self.pitch or 90)
  local pixels=math.max(1,self:GetTall()-70)
  self.center=self.center+(up*dy-right*dx)*(2*self.radius/self.orbitZoom/pixels)
 else self.yaw=(self.yaw+dx*.3)%360;self.pitch=math.Clamp(self.pitch+dy*.25,5,89) end
 self.dirty=true
end
function PANEL:Floor(delta) if self.center then self.center.z=self.center.z+delta*128;self.cutaway=true;self.dirty=true end end
function PANEL:Pan(x,y) if self.center then self.center=self.center+Vector(x,y,0)*self.radius/self.orbitZoom*.15;self.dirty=true end end
function PANEL:Scan() self:ResetOrbit() end
function PANEL:Think()
 N.StepMapGeometry(self.geometry)
 if self.data and RealTime()>=self.nextSync then self.nextSync=RealTime()+5;N.Request('mapSync') end
end
local function world(v) return Vector(v[1],v[2],v[3]) end
local colors={areas=Color(102,231,208),power=Color(255,198,68),infection=Color(255,90,89),terminals=Color(87,222,211)}
-- Map strokes are now painted in the same VGUI pass as the terminal labels.
-- Never reuse the old intermediate texture/material after client Lua refresh.
N.mapRT=nil;N.mapMaterial=nil
local mapBackground=Color(5,13,20,255)
local gridColor=Color(20,36,47,255)
local contextColor=Color(112,170,191,255)
local outlineColor=Color(193,238,250,255)
local cutColor=Color(232,255,255,255)
local areaTextColor=Color(240,251,255,255)
local areaLabelBackground=Color(5,13,20,255)
local warningBlack=Color(8,12,15,255)
-- Convex vector pieces, built once. No glyph/font dependency or downloaded art.
local warningShapes={power={{{.58,.04},{.55,.58},{.17,.58}},{{.43,.42},{.85,.42},{.39,.97}}},infection={}}
local warningCuts={}
local warningRing={}
local function arcShape(cx,cy,outer,inner,first,last,steps)
 for i=0,steps-1 do
  local a,b=math.rad(first+(last-first)*i/steps),math.rad(first+(last-first)*(i+1)/steps)
  warningRing[#warningRing+1]={{cx+math.cos(a)*outer,cy+math.sin(a)*outer},
   {cx+math.cos(b)*outer,cy+math.sin(b)*outer},{cx+math.cos(b)*inner,cy+math.sin(b)*inner},{cx+math.cos(a)*inner,cy+math.sin(a)*inner}}
 end
end
local function circleShape(target,cx,cy,radius)
 local points={}
 for i=0,23 do
  local a=math.rad(i*15)
  points[#points+1]={cx+math.cos(a)*radius,cy+math.sin(a)*radius}
 end
 target[#target+1]=points
end
arcShape(.5,.5,.19,.145,0,360,24)
for _,angle in ipairs({-90,30,150}) do
 local a=math.rad(angle)
 circleShape(warningShapes.infection,.5+math.cos(a)*.2,.5+math.sin(a)*.2,.3)
 circleShape(warningCuts,.5+math.cos(a)*.3,.5+math.sin(a)*.3,.22)
end
circleShape(warningCuts,.5,.5,.065)
local warningStripes={}
for i=0,5 do
 local x=i*12
 for _,y in ipairs({0,64}) do warningStripes[#warningStripes+1]={{x, y},{x+6,y},{x+12,y+8},{x+6,y+8}} end
 for _,xside in ipairs({0,64}) do warningStripes[#warningStripes+1]={{xside,x},{xside+8,x+6},{xside+8,x+12},{xside,x+6}} end
end
local warningVertices={}
local function warningPoly(points,x,y,size)
 local vertices=warningVertices[#points]
 if not vertices then vertices={};for i=1,#points do vertices[i]={} end;warningVertices[#points]=vertices end
 for i,p in ipairs(points) do local v=vertices[i];v.x=x+p[1]*size;v.y=y+p[2]*size end
 surface.DrawPoly(vertices)
end
function N.PaintMapIncident(v)
 local x,y=v.x-36,v.y-36;local c=colors[v.incident]
 draw.NoTexture()
 surface.SetDrawColor(warningBlack);surface.DrawRect(x-3,y-3,78,78)
 surface.SetDrawColor(c);surface.DrawRect(x,y,72,72)
 surface.SetDrawColor(warningBlack)
 for _,shape in ipairs(warningStripes) do warningPoly(shape,x,y,1) end
 surface.DrawRect(x+8,y+8,56,56)
 surface.SetDrawColor(c);surface.DrawRect(x+12,y+12,48,48)
 surface.SetDrawColor(warningBlack)
 for _,shape in ipairs(warningShapes[v.incident]) do warningPoly(shape,x+15,y+15,42) end
 if v.incident=='infection' then
  surface.SetDrawColor(c)
  for _,shape in ipairs(warningCuts) do warningPoly(shape,x+15,y+15,42) end
  surface.SetDrawColor(warningBlack)
  for _,shape in ipairs(warningRing) do warningPoly(shape,x+15,y+15,42) end
 end
end

-- Called before the terminal's render target is entered. Render the solid BSP
-- offscreen, then cache the native screen-space overlays independently of fades.
function N.RenderMap(panel)
 if not IsValid(panel) or not panel.center or not panel.data then return end
 local g=panel.geometry
 local w,h=panel:GetWide(),panel:GetTall()-70
 if w<=0 or h<=0 then return end
 local sliceLow,sliceHigh=N.MapSliceBounds(panel)
 local sky=N.Map3D and N.Map3D.SkyFilter and N.Map3D.SkyFilter()
 local key=table.concat({'terminal-map-v9',w,h,panel.radius,panel.yaw,panel.pitch,panel.orbitZoom,panel.center.x,panel.center.y,panel.center.z,tostring(sliceLow),tostring(sliceHigh),tostring(sky),tostring(panel.threeD),tostring(panel.cutaway),tostring(panel.useSolid),tostring(panel.layers.areas),tostring(panel.layers.power),tostring(panel.layers.infection),tostring(panel.layers.terminals)},':')
 if RealTime()<(panel.nextRender or 0) then return end
 panel.nextRender=RealTime()+.06
 local solid=panel.useSolid and N.Map3D and N.Map3D.Draw(panel,w,h,key) or false
 if (not g.ready or g.error) and not solid then
  panel.solidReady=false;panel.mapReady=false;return
 end
 if key==panel.renderKey and not panel.dirty and panel.solidReady==solid then return end
 panel.solidReady=solid
 local view={width=w,height=h,grid={},groups={},labels={},markers={},rects={}}
 local right,up=N.MapAxes(panel.threeD and panel.yaw or -90,panel.threeD and panel.pitch or 90)
 local scale=h*.5*panel.orbitZoom/panel.radius
 local function project(v) return N.MapProject(v,panel.center,right,up,scale,w,h) end
 local group
 local function ink(color)
  group={color=color,quads={},seen={}};view.groups[#view.groups+1]=group
 end
 local function line(a,b,width)
  if sky then
   local da,db=a:Dot(sky.normal)-sky.distance,b:Dot(sky.normal)-sky.distance
   if da<0 and db<0 then return end
   if da<0 then a=a+(b-a)*(da/(da-db)) elseif db<0 then b=a+(b-a)*(da/(da-db)) end
  end
  local ax,ay=project(a);local bx,by=project(b);local x1,y1,x2,y2=N.MapClipLine(ax,ay,bx,by,w,h)
  if not x1 then return end
  local dx,dy=x2-x1,y2-y1;local length=math.sqrt(dx*dx+dy*dy)
  if length<.25 then return end
  -- Different storeys can project to the same stroke. Deduplicate at half a
  -- UI pixel so direct painting does not redraw those edges every frame.
  local ka=math.floor(x1*2+.5)..','..math.floor(y1*2+.5)
  local kb=math.floor(x2*2+.5)..','..math.floor(y2*2+.5)
  local id=ka<kb and ka..'/'..kb or kb..'/'..ka
  if group.seen[id] then return end;group.seen[id]=true
  -- Flat coordinate arrays avoid per-vertex allocation during every Paint.
  local half=(width or 2.8)*.5;local nx,ny=-dy/length*half,dx/length*half
  local q=group.quads;local n=#q
  q[n+1]=math.Clamp(x1-nx,0,w);q[n+2]=math.Clamp(y1-ny,0,h)
  q[n+3]=math.Clamp(x2-nx,0,w);q[n+4]=math.Clamp(y2-ny,0,h)
  q[n+5]=math.Clamp(x2+nx,0,w);q[n+6]=math.Clamp(y2+ny,0,h)
  q[n+7]=math.Clamp(x1+nx,0,w);q[n+8]=math.Clamp(y1+ny,0,h)
 end
 local function label(text,x,y,color) view.labels[#view.labels+1]={text=text,x=x,y=y,color=color} end
 local ok,err=xpcall(function()
  local spacing=128*scale;while spacing<48 do spacing=spacing*2 end
  for x=w*.5%spacing,w,spacing do view.grid[#view.grid+1]={x,0,x,h} end
  for y=h*.5%spacing,h,spacing do view.grid[#view.grid+1]={0,y,w,y} end
  local section=sliceHigh or panel.center.z+48
  if not solid then
  if panel.cutaway and not panel.threeD and sliceHigh-sliceLow<=minimumSlice then
   if panel.sectionZ~=section then
    panel.sectionZ=section;panel.sections={}
    for _,face in ipairs(g.faces) do if face.low<=section and face.high>=section then
     local a,b=N.MapSection(face.vertices,section);if a then panel.sections[#panel.sections+1]={a,b} end
    end end
   end
   -- Dim context plus a bright exact cut through walls at chest height.
   ink(contextColor)
   for _,edge in ipairs(g.edges) do if not edge.shared or edge.corner then
    local a,b=N.MapClipHeight(edge.a,edge.b,sliceLow,sliceHigh);if a then line(a,b,2) end
   end end
   ink(cutColor)
   for _,edge in ipairs(panel.sections) do line(edge[1],edge[2],3.4) end
   view.sectionEmpty=#panel.sections==0
  else
   ink(outlineColor)
   for _,edge in ipairs(g.edges) do if not edge.shared or edge.corner then
    if panel.cutaway then
     local a,b=N.MapClipHeight(edge.a,edge.b,sliceLow,sliceHigh);if a then line(a,b) end
    else line(edge.a,edge.b) end
   end end
   view.sectionEmpty=false
  end
  end
  local function marker(v,title,color,id)
   if sky and v:Dot(sky.normal)<sky.distance then return end
   local x,y=project(v)
   if id=='power' or id=='infection' then
    if x<40 or y<40 or x>w-40 or y>h-40 then return end
    view.labels[#view.labels+1]={text=title,x=x,y=y,color=color,incident=id}
   else
    if x<10 or y<10 or x>w-180 or y>h-40 then return end
    view.rects[#view.rects+1]={x=x-5,y=y-5,w=10,h=10,color=color}
    label(title,x+14,y-12,color)
   end
   view.markers[#view.markers+1]={x=x/w,y=y/h,title=title,id=id}
  end
  if panel.layers.areas then for _,z in ipairs(panel.data.areas or {}) do
   local a,b=world(z.min),world(z.max);local c=colors.areas
   if z.color then c=Color(math.Clamp(tonumber(z.color[1]) or 102,80,255),math.Clamp(tonumber(z.color[2]) or 231,80,255),math.Clamp(tonumber(z.color[3]) or 208,80,255)) end
   if (not sky or ((a+b)*.5):Dot(sky.normal)>=sky.distance) and (not panel.cutaway or (b.z>=sliceLow and a.z<=sliceHigh)) then
    local height=panel.cutaway and math.Clamp(section,a.z,b.z) or a.z
    local corners={Vector(a.x,a.y,height),Vector(b.x,a.y,height),Vector(b.x,b.y,height),Vector(a.x,b.y,height)}
    ink(c);for i=1,4 do line(corners[i],corners[i%4+1],2.2) end
    local x,y=project(Vector((a.x+b.x)*.5,(a.y+b.y)*.5,height))
    if x>=0 and y>=0 and x<=w and y<=h then
     view.labels[#view.labels+1]={text=z.name,x=x,y=y,color=c,area=true}
    end
   end
  end end
  for _,v in ipairs(panel.data.alerts or {}) do
   if v.active==true and (v.kind=='power' or v.kind=='infection') and panel.layers[v.kind] then
    local pos=world(v.pos);local low,high=v.low or pos.z,v.high or pos.z
    if not panel.cutaway or (high>=sliceLow and low<=sliceHigh) then
     if panel.cutaway then pos.z=math.Clamp(pos.z,math.max(low,sliceLow),math.min(high,sliceHigh)) end
     marker(pos,v.name..(v.kind=='power' and ' / НЕТ ПИТАНИЯ' or ' / ЗАРАЖЕНИЕ'),colors[v.kind],v.kind)
    end
   end
  end
  if panel.layers.terminals then for i,t in ipairs(panel.data.terminals or {}) do
   local pos=world(t.pos);if not panel.cutaway or (pos.z>=sliceLow and pos.z<=sliceHigh) then marker(pos,'T'..i..(t.off and ' / OFF' or ''),colors.terminals,'terminals') end
  end end
  local playerPos=world(panel.data.origin)
  if not panel.cutaway or (playerPos.z>=sliceLow and playerPos.z<=sliceHigh) then marker(playerPos,'ВЫ',Color(255,255,255)) end
  label(solid and 'ОБЪЁМНАЯ КАРТА' or (panel.threeD and 'AXONOMETRIC' or 'FLOOR PLAN'),28,24,Color(176,226,238))
  label(panel.threeD and 'ПОВОРОТ '..math.floor(panel.yaw)..'°' or 'N ↑',w-245,24,Color(188,221,230))
  local units=128;while units*scale<100 do units=units*2 end
  view.rects[#view.rects+1]={x=28,y=h-44,w=units*scale,h=2,color=Color(188,221,230)}
  label(units..' units',28,h-78,Color(188,221,230))
 end,debug.traceback)
 panel.mapReady=ok;panel.renderError=not ok and tostring(err) or nil
 if ok then
  for _,g in ipairs(view.groups) do g.seen=nil end
  panel.mapView=view;panel.markers=view.markers;panel.sectionEmpty=view.sectionEmpty
  panel.renderKey=key;panel.dirty=false
 end
end

local paintQuad={{},{},{},{}}
function N.PaintMap(panel,w,h)
 -- Called only from the map's VGUI Paint context, under the terminal clip tree.
 draw.NoTexture();surface.SetDrawColor(mapBackground);surface.DrawRect(0,0,w,h)
 local view=panel.mapView
 if not panel.mapReady or not view or view.width~=w or view.height~=h-70 then return end
 if panel.solidReady and panel.solidMaterial then
  surface.SetDrawColor(255,255,255,255);surface.SetMaterial(panel.solidMaterial)
  surface.DrawTexturedRectUV(0,0,w,h-70,0,0,panel.solidU,panel.solidV)
  draw.NoTexture()
 else
  surface.SetDrawColor(gridColor)
  for _,v in ipairs(view.grid) do surface.DrawLine(v[1],v[2],v[3],v[4]) end
 end
 for _,g in ipairs(view.groups) do
  surface.SetDrawColor(g.color)
  local q=g.quads
  for i=1,#q,8 do
   for j=1,4 do local v=paintQuad[j];v.x=q[i+(j-1)*2];v.y=q[i+(j-1)*2+1] end
   surface.DrawPoly(paintQuad)
  end
 end
 for _,v in ipairs(view.rects) do surface.SetDrawColor(v.color);surface.DrawRect(v.x,v.y,v.w,v.h) end
 for _,v in ipairs(view.labels) do
  if v.area then
   -- The text and backing share the projected area's exact centre. Keep a
   -- fixed UI font size so zooming out never turns names into tiny map lines.
   surface.SetFont('FoundationTitle')
   local tw,th=surface.GetTextSize(v.text)
   local bw,bh=tw+28,th+16;local x,y=v.x-bw*.5,v.y-bh*.5
   if x>=0 and y>=0 and x+bw<=view.width and y+bh<=view.height then
    surface.SetDrawColor(areaLabelBackground);surface.DrawRect(x,y,bw,bh)
    surface.SetDrawColor(v.color);surface.DrawRect(x,y+bh-2,bw,2)
    draw.SimpleText(v.text,'FoundationTitle',v.x,v.y,areaTextColor,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
   end
  elseif not v.incident then draw.SimpleText(v.text,'FoundationMono',v.x,v.y,v.color) end
 end
 -- Alert icons remain on top of architectural labels and linework.
 for _,v in ipairs(view.labels) do if v.incident then N.PaintMapIncident(v) end end
end
function PANEL:Paint(w,h)
 N.PaintMap(self,w,h)
 local g=self.geometry
 local status=self.renderError
 if not self.solidReady then status=status or g.error or (not g.ready and ('ЧТЕНИЕ ГЕОМЕТРИИ  '..math.floor((g.next-1)/math.max(1,#g.surfaces)*100)..'%')) end
 if self.useSolid and N.Map3D then status=N.Map3D.Status() or status end
 if status then
  surface.SetDrawColor(areaLabelBackground);surface.DrawRect(18,58,w-36,42)
  draw.SimpleText(status,'FoundationText',28,65,Color(220,232,240))
 end
 local low,high=N.MapSliceBounds(self)
 local mode=low and ('Слои Z '..math.floor(low)..' … '..math.ceil(high)) or 'Все этажи'
 draw.SimpleText(mode..'  /  '..(self.threeD and '3D' or '2D')..'  /  '..(self.data and self.data.name or ''),'FoundationMono',18,h-57,Color(142,205,218))
 draw.SimpleText(self.sectionEmpty and 'На этой высоте нет стен. Измените Z или откройте весь объект.' or 'ЛКМ: вращение в 3D / сдвиг в 2D     ПКМ: сдвиг     Колесо: масштаб','FoundationMono',18,h-28,Color(174,193,204))
 if g.limited then draw.SimpleText('Достигнут лимит геометрии','FoundationMono',w-360,20,Color(255,184,92)) end
end
vgui.Register('ixFoundationMap',PANEL,'DPanel')
