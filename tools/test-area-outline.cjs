const {run,source,finish}=require('./restored-test-runner.cjs');
const base=source(['tools/geometry-fixture.lua','helix/plugins/area/sh_geometry.lua','helix/plugins/area/cl_outline.lua'])+`
local function box(x,y,z,X,Y,Z) return {min=Vector(x,y,z),max=Vector(X,Y,Z)} end
local function area(boxes) local a={};assert(ix.area.SetVolumes(a,boxes));return a end
local function length(lines) local sum=0;for _,line in ipairs(lines) do sum=sum+(line[2]-line[1]):Length() end;return sum end
`;
function test(name,code){run(name,base+code)}
test('legacy single box retains twelve outer edges',`
 local a={startPosition=Vector(0,0,0),endPosition=Vector(4,3,2)}
 local lines=ix.area.GetOutline(a);eq(#lines,12);near(length(lines),4*(4+3+2))
`);
test('touching and overlapping boxes remove coplanar seams',`
 for _,boxes in ipairs({{box(0,0,0,2,3,2),box(2,0,0,4,3,2)}, {box(0,0,0,3,3,2),box(2,0,0,4,3,2)}}) do
  local lines=ix.area.GetOutline(area(boxes));eq(#lines,12);near(length(lines),36)
 end
`);
test('L shaped room keeps its concave corner but loses inner box borders',`
 local lines=ix.area.GetOutline(area({box(0,0,0,4,1,2),box(0,0,0,1,4,2)}))
 eq(#lines,18);near(length(lines),44)
 for _,line in ipairs(lines) do
  local m=(line[1]+line[2])*.5
  assert(not(m.x==1 and m.y>0 and m.y<1 and (m.z==0 or m.z==2)))
 end
`);
test('contained and duplicate volumes introduce no edges',`
 local lines=ix.area.GetOutline(area({box(0,0,0,4,4,4),box(1,1,1,3,3,3),box(0,0,0,4,4,4)}))
 eq(#lines,12);near(length(lines),48)
`);
test('separate areas of one volume union retain disconnected boundaries',`
 local lines=ix.area.GetOutline(area({box(0,0,0,1,1,1),box(3,0,0,4,1,1)}))
 eq(#lines,24);near(length(lines),24)
`);
test('outline cache reuses geometry and invalidates on volume replacement',`
 local a=area({box(0,0,0,4,1,2)});local first=ix.area.GetOutline(a)
 eq(ix.area.GetOutline(a),first)
 assert(ix.area.SetVolumes(a,{box(0,0,0,4,1,2),box(0,0,0,1,4,2)}))
 local next=ix.area.GetOutline(a);assert(first~=next);eq(#next,18);eq(ix.area.GetOutline(a),next)
`);
test('three dimensional steps and cavities expose only actual boundary edges',`
 local shapes={
 {box(0,0,0,4,4,1),box(0,0,1,2,2,3)},
 {box(0,0,0,4,1,3),box(0,3,0,4,4,3),box(0,1,0,1,3,3),box(3,1,0,4,3,3)},
 {box(0,0,0,1,1,1),box(1,1,0,2,2,1)}}
 for _,boxes in ipairs(shapes) do
  local a=area(boxes);local lines=ix.area.GetOutline(a)
  for _,line in ipairs(lines) do
   local direction=line[2]-line[1];local axes={}
   for _,axis in ipairs({'x','y','z'}) do if direction[axis]==0 then axes[#axes+1]=axis end end
   eq(#axes,2)
   for _,t in ipairs({.13,.47,.81}) do
    local mid=line[1]+direction*t;local count=0;local flags={}
    for _,dx in ipairs({-.0001,.0001}) do for _,dy in ipairs({-.0001,.0001}) do
     local p=Vector(mid.x,mid.y,mid.z);p[axes[1]]=p[axes[1]]+dx;p[axes[2]]=p[axes[2]]+dy
     local inside=false
     for _,b in ipairs(boxes) do if p.x>b.min.x and p.x<b.max.x and p.y>b.min.y and p.y<b.max.y and p.z>b.min.z and p.z<b.max.z then inside=true end end
     flags[#flags+1]=inside;if inside then count=count+1 end
    end end
    assert(count==1 or count==3 or (count==2 and flags[1]==flags[4]),'internal seam')
   end
  end
 end
`);
run('area editor draws only the union; volume selection still highlights its box',base+`
CLIENT=true;SERVER=false
Color=function(r,g,b,a) return {r=r,g=g,b=b,a=a} end
ColorAlpha=function(c) return c end
cam={Start2D=function() end,End2D=function() end}
draw={SimpleText=function() return 1,1 end}
local V=getmetatable(Vector());function V:ToScreen() return {x=0,y=0} end
PLUGIN.GetLocalAreaPosition=function() return Vector(),Vector(),Vector() end
local lineCount,boxCount=0,0
render={DrawLine=function() lineCount=lineCount+1 end,DrawWireframeBox=function() boxCount=boxCount+1 end}
local a=area({box(0,0,0,4,1,2),box(0,0,0,1,4,2)});a.type='area';a.properties={color={}}
ix.area.stored={test=a};ix.area.bEditing=true
`+source(['helix/plugins/area/cl_hooks.lua'])+`
PLUGIN:PostDrawTranslucentRenderables(false,false);eq(lineCount,18);eq(boxCount,0)
PLUGIN.volumePreview={min=Vector(),max=Vector(1,1,1)}
PLUGIN:PostDrawTranslucentRenderables(false,false);eq(lineCount,36);eq(boxCount,1)
ix.area.bEditing=false;PLUGIN:PostDrawTranslucentRenderables(false,false);eq(lineCount,36)
`);
finish();
