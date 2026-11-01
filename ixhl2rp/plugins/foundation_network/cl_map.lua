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
function N.MapHeightRange(panel)
 local e=N.Map3D and N.Map3D.engine
 local low,high
 if e and e.Bake.IsReady() and N.Map3D.MapBounds then low,high=N.Map3D.MapBounds(false)
 elseif panel.geometry then low,high=panel.geometry.detailLow or panel.geometry.low,panel.geometry.detailHigh or panel.geometry.high end
 local bottom,top
 if low and high and finite(low.z) and finite(high.z) and high.z>=low.z then
  bottom,top=low.z-8,high.z+8
 else
  bottom=((panel.data and panel.data.origin or {})[3] or 0)-128;top=bottom+8192
 end
 local limit=panel.data and panel.data.canSetHeight~=true and finite(panel.data.maxHeight) or nil
 return bottom,math.max(bottom+1,top),limit
end
function N.MapMaxSliceSpan(panel)
 local low,high=N.MapHeightRange(panel);return high-low
end
function N.MapSliceBounds(panel)
 if not panel.center then return end
 local low,top,limit=N.MapHeightRange(panel)
 local high=panel.cutaway and finite(panel.sliceTop,math.min(low+minimumSlice,top)) or top
 high=math.Clamp(high,math.min(low+minimumSlice,top),top)
 if limit then high=math.min(high,limit) end
 -- Even a full-map/reset button cannot remove the player's configured cap.
 if not panel.cutaway and high>=top then return end
 return math.min(low,high-1),high
end
local PANEL={}
function PANEL:Init()
 self:SetTall(660);self.foundationControl='map';self.layers={areas=true,power=true,infection=true,terminals=true}
 self.useSolid=N.Map3D~=nil;self.mapProps=true
 self.yaw=45;self.pitch=55;self.orbitZoom=1;self.threeD=self.useSolid;self.cutaway=true;self.nextSync=RealTime()+5
 self.geometry=N.BeginMapGeometry()
end
function PANEL:SetData(data) self.data=data;self.dirty=true;if not self.center then self:Home() end end
function PANEL:Home()
 if not self.data then return end
 local o=self.data.origin;self.center=Vector(o[1],o[2],o[3]);self.radius=1400;self.orbitZoom=1;self.cutaway=true;self.sliceTop=nil;self.bottomFrame=true;self.dirty=true
end
function PANEL:MaxLayerFraction()
 local bottom,top,limit=N.MapHeightRange(self);local first=math.min(bottom+minimumSlice,top)
 return limit and math.sqrt(math.Clamp((limit-first)/math.max(1,top-first),0,1)) or 1
end
function PANEL:SetLayerFraction(value)
 value=math.Clamp(finite(value,0),0,self:MaxLayerFraction());self.cutaway=value<1
 local bottom,top=N.MapHeightRange(self);local first=math.min(bottom+minimumSlice,top)
 self.sliceTop=first+(top-first)*value^2
 self.dirty=true
end
function PANEL:GetLayerFraction()
 local bottom,top=N.MapHeightRange(self);local first=math.min(bottom+minimumSlice,top)
 local _,height=N.MapSliceBounds(self)
 return math.sqrt(math.Clamp(((height or top)-first)/math.max(1,top-first),0,1))
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
  local info=low and ('Снизу до Z '..math.ceil(high)) or 'Весь объект'
  local saved=panel.data and finite(panel.data.maxHeight)
  if saved then info=info..'  /  предел игроков: '..math.floor(saved) end
  draw.SimpleText('ВИДИМЫЕ ЭТАЖИ','FoundationMono',24,2,c)
  draw.SimpleText(info,'FoundationMono',w-24,2,Color(207,228,236),TEXT_ALIGN_RIGHT)
  local x=24+(w-48)*panel:GetLayerFraction()
  surface.SetDrawColor(31,60,72);surface.DrawRect(24,36,w-48,4)
  local bottom,top=N.MapHeightRange(panel);local first=math.min(bottom+minimumSlice,top)
  if saved then
   local cap=24+(w-48)*math.sqrt(math.Clamp((saved-first)/math.max(1,top-first),0,1))
   surface.SetDrawColor(148,73,63);surface.DrawRect(cap,36,w-24-cap,4);surface.DrawRect(cap-1,27,2,22)
  end
  surface.SetDrawColor(c);surface.DrawRect(24,36,x-24,4);surface.DrawRect(x-5,28,10,20)
  draw.SimpleText('Нижний этаж','FoundationMono',24,52,Color(174,193,204))
  draw.SimpleText('Все этажи','FoundationMono',w-24,52,Color(174,193,204),TEXT_ALIGN_RIGHT)
 end
end
function PANEL:ResetOrbit(full)
 self.bottomFrame=nil
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
 self.bottomFrame=nil
 if not self.threeD or self.panMode or key==MOUSE_RIGHT then
  local right,up=N.MapAxes(self.threeD and self.yaw or -90,self.threeD and self.pitch or 90)
  local pixels=math.max(1,self:GetTall()-70)
  self.center=self.center+(up*dy-right*dx)*(2*self.radius/self.orbitZoom/pixels)
 else self.yaw=(self.yaw+dx*.3)%360;self.pitch=math.Clamp(self.pitch+dy*.25,5,89) end
 self.dirty=true
end
function PANEL:Floor(delta)
 if not self.center then return end
 local bottom,top,limit=N.MapHeightRange(self);local _,current=N.MapSliceBounds(self)
 self.sliceTop=math.Clamp((current or top)+delta*128,math.min(bottom+minimumSlice,top),top)
 if limit then self.sliceTop=math.min(self.sliceTop,limit) end
 self.cutaway=true;self.dirty=true
end
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
 if panel.bottomFrame and sliceLow and (g.ready or (N.Map3D and N.Map3D.engine and N.Map3D.engine.Bake.IsReady())) then
  -- Starting at the lowest storey must also frame it when the terminal is
  -- upstairs. Wait for real bounds, then leave subsequent camera pans alone.
  panel.center.z=(sliceLow+sliceHigh)*.5;panel.bottomFrame=nil
 end
 local sky=N.Map3D and N.Map3D.SkyFilter and N.Map3D.SkyFilter()
 local key=table.concat({'terminal-map-v11',w,h,panel.radius,panel.yaw,panel.pitch,panel.orbitZoom,panel.center.x,panel.center.y,panel.center.z,tostring(sliceLow),tostring(sliceHigh),tostring(sky),tostring(panel.threeD),tostring(panel.cutaway),tostring(panel.useSolid),tostring(panel.layers.areas),tostring(panel.layers.power),tostring(panel.layers.infection),tostring(panel.layers.terminals)},':')
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
  if sliceLow and not panel.threeD and sliceHigh-sliceLow<=minimumSlice then
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
    if sliceLow then
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
  local areaLabels={}
  if panel.layers.areas then for _,z in ipairs(panel.data.areas or {}) do
   local a,b=world(z.min),world(z.max);local c=colors.areas
   if z.color then c=Color(math.Clamp(tonumber(z.color[1]) or 102,80,255),math.Clamp(tonumber(z.color[2]) or 231,80,255),math.Clamp(tonumber(z.color[3]) or 208,80,255)) end
   if (not sky or ((a+b)*.5):Dot(sky.normal)>=sky.distance) and (not sliceLow or (b.z>=sliceLow and a.z<=sliceHigh)) then
    local height=sliceLow and math.Clamp(section,a.z,b.z) or a.z
    local corners={Vector(a.x,a.y,height),Vector(b.x,a.y,height),Vector(b.x,b.y,height),Vector(a.x,b.y,height)}
    ink(c);for i=1,4 do line(corners[i],corners[i%4+1],2.2) end
    local x,y=project(Vector((a.x+b.x)*.5,(a.y+b.y)*.5,height))
    if x>=0 and y>=0 and x<=w and y<=h then
     -- Snapshot entries are volumes, not separate named areas. Label the
     -- largest visible volume once; hidden floors/offscreen additions cannot
     -- claim its label, and concave areas keep the name inside a real volume.
     local size=(b.x-a.x)*(b.y-a.y)
     local polygon={}
     for _,corner in ipairs(corners) do local px,py=project(corner);polygon[#polygon+1]={x=px,y=py} end
     local entry=areaLabels[z.name]
     if not entry then
      entry={text=z.name,x=x,y=y,color=c,area=true,size=size,polygon=polygon}
      areaLabels[z.name]=entry;view.labels[#view.labels+1]=entry
     elseif size>entry.size then
      entry.x,entry.y,entry.color,entry.size,entry.polygon=x,y,c,size,polygon
     end
    end
   end
  end end
  for _,v in ipairs(panel.data.alerts or {}) do
   if v.active==true and (v.kind=='power' or v.kind=='infection') and panel.layers[v.kind] then
    local pos=world(v.pos);local low,high=v.low or pos.z,v.high or pos.z
    if not sliceLow or (high>=sliceLow and low<=sliceHigh) then
     if sliceLow then pos.z=math.Clamp(pos.z,math.max(low,sliceLow),math.min(high,sliceHigh)) end
     marker(pos,v.name..(v.kind=='power' and ' / НЕТ ПИТАНИЯ' or ' / ЗАРАЖЕНИЕ'),colors[v.kind],v.kind)
    end
   end
  end
  if panel.layers.terminals then for i,t in ipairs(panel.data.terminals or {}) do
   local pos=world(t.pos);if not sliceLow or (pos.z>=sliceLow and pos.z<=sliceHigh) then marker(pos,'T'..i..(t.off and ' / OFF' or ''),colors.terminals,'terminals') end
  end end
  local playerPos=world(panel.data.origin)
  if not sliceLow or (playerPos.z>=sliceLow and playerPos.z<=sliceHigh) then marker(playerPos,'ВЫ',Color(255,255,255)) end
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

local areaFonts={'FoundationMapArea22','FoundationMapArea20','FoundationMapArea18'}
-- Width of a centred label rectangle entirely inside the projected room,
-- including oblique views. Every edge supplies one half-plane constraint.
function N.MapAreaLabelWidth(label,height,w,h)
 local half=math.min(label.x-8,w-label.x-8,180)
 if label.y-height*.5<8 or label.y+height*.5>h-8 then return 0 end
 for i,a in ipairs(label.polygon) do
  local b=label.polygon[i%#label.polygon+1];local dx,dy=b.x-a.x,b.y-a.y
  local distance=math.abs(dx*(label.y-a.y)-dy*(label.x-a.x))-5*math.sqrt(dx*dx+dy*dy)
  local room=distance-math.abs(dx)*height*.5
  if room<0 then return 0 end
  if math.abs(dy)>.001 then half=math.min(half,room/math.abs(dy)) end
 end
 return math.max(0,half*2)
end
local function wrapAreaName(text,width,maxLines)
 local lines,line={},''
 for word in text:gmatch('%S+') do
  if surface.GetTextSize(word)>width then return end
  local trial=line=='' and word or line..' '..word
  if surface.GetTextSize(trial)>width then
   lines[#lines+1]=line;line=word
   if #lines>=maxLines then return end
  else line=trial end
 end
 if line~='' then lines[#lines+1]=line end
 if #lines>0 then return lines end
end
function N.LayoutMapAreaLabels(view)
 if not N.mapAreaFontsReady then
  for i,size in ipairs({22,20,18}) do surface.CreateFont(areaFonts[i],{font='Roboto',size=size,weight=600,extended=true}) end
  N.mapAreaFontsReady=true
 end
 local candidates,occupied={},{}
 for _,v in ipairs(view.labels) do
  if v.area then candidates[#candidates+1]=v
  elseif v.incident then occupied[#occupied+1]={x=v.x-40,y=v.y-40,w=80,h=80} end
 end
 table.sort(candidates,function(a,b) if a.size==b.size then return a.text<b.text end;return a.size>b.size end)
 local result={}
 for _,v in ipairs(candidates) do
  local chosen
  for _,font in ipairs(areaFonts) do
   surface.SetFont(font);local _,lineHeight=surface.GetTextSize('Ag')
   for count=1,3 do
    local height=lineHeight*count+8;local width=N.MapAreaLabelWidth(v,height,view.width,view.height)
    local lines=width>=48 and wrapAreaName(v.text,width-12,count)
    if lines then
     local tw=0;for _,line in ipairs(lines) do tw=math.max(tw,surface.GetTextSize(line)) end
     local bw,bh=tw+12,#lines*lineHeight+8
     local box={x=v.x-bw*.5,y=v.y-bh*.5,w=bw,h=bh}
     local free=true
     for _,other in ipairs(occupied) do
      if box.x<other.x+other.w+4 and box.x+box.w+4>other.x and box.y<other.y+other.h+4 and box.y+box.h+4>other.y then free=false;break end
     end
     if free then
      chosen={box=box,lines=lines,font=font,lineHeight=lineHeight,color=v.color,source=v}
      break
     end
    end
   end
   if chosen then break end
  end
  if chosen then result[#result+1]=chosen;occupied[#occupied+1]=chosen.box end
 end
 view.areaLayout=result;return result
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
 for _,v in ipairs(view.areaLayout or N.LayoutMapAreaLabels(view)) do
  local b=v.box
  surface.SetDrawColor(areaLabelBackground);surface.DrawRect(b.x,b.y,b.w,b.h)
  surface.SetDrawColor(v.color);surface.DrawRect(b.x,b.y+b.h-2,b.w,2)
  for i,line in ipairs(v.lines) do
   draw.SimpleText(line,v.font,b.x+b.w*.5,b.y+4+(i-1)*v.lineHeight,areaTextColor,TEXT_ALIGN_CENTER)
  end
 end
 for _,v in ipairs(view.labels) do
  if not v.area and not v.incident then draw.SimpleText(v.text,'FoundationMono',v.x,v.y,v.color) end
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
 draw.SimpleText(self.sectionEmpty and 'На этой высоте нет стен. Поднимите верхнюю границу.' or 'ЛКМ: вращение / сдвиг     ПКМ: сдвиг     Колесо: масштаб и названия малых зон','FoundationMono',18,h-28,Color(174,193,204))
 if g.limited then draw.SimpleText('Достигнут лимит геометрии','FoundationMono',w-360,20,Color(255,184,92)) end
end
vgui.Register('ixFoundationMap',PANEL,'DPanel')
