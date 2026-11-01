-- Small affine-matrix implementation for offline retargeting arithmetic tests.
local V={}; V.__index=V
function Vector(x,y,z) return setmetatable({x=x or 0,y=y or 0,z=z or 0},V) end
function V.__add(a,b) return Vector(a.x+b.x,a.y+b.y,a.z+b.z) end
function V.__sub(a,b) return Vector(a.x-b.x,a.y-b.y,a.z-b.z) end
function V.__mul(a,b) return Vector(a.x*b,a.y*b,a.z*b) end
function V:Length() return math.sqrt(self.x*self.x+self.y*self.y+self.z*self.z) end
vector_origin=Vector()
local M={}; M.__index=M
function Matrix()
 local m=setmetatable({},M)
 for r=1,4 do m[r]={}; for c=1,4 do m[r][c]=r==c and 1 or 0 end end
 return m
end
function M:SetField(r,c,v) self[r][c]=v end
function M:SetTranslation(v) self[1][4]=v.x; self[2][4]=v.y; self[3][4]=v.z end
function M:GetTranslation() return Vector(self[1][4],self[2][4],self[3][4]) end
function M:GetInverse()
 local a,b=Matrix(),Matrix()
 for r=1,4 do for c=1,4 do a[r][c]=self[r][c] end end
 for c=1,4 do
  local p=c
  for r=c+1,4 do if math.abs(a[r][c])>math.abs(a[p][c]) then p=r end end
  if math.abs(a[p][c])<1e-10 then return end
  a[c],a[p]=a[p],a[c]; b[c],b[p]=b[p],b[c]
  local k=a[c][c]; for j=1,4 do a[c][j]=a[c][j]/k; b[c][j]=b[c][j]/k end
  for r=1,4 do if r~=c then
   k=a[r][c]; for j=1,4 do a[r][j]=a[r][j]-k*a[c][j]; b[r][j]=b[r][j]-k*b[c][j] end
  end end
 end
 return b
end
function M.__mul(a,b)
 local m=Matrix()
 for r=1,4 do for c=1,4 do
  m[r][c]=0; for k=1,4 do m[r][c]=m[r][c]+a[r][k]*b[k][c] end
 end end
 return m
end
function rotation(degrees)
 local a=math.rad(degrees); local m=Matrix()
 m[1][1]=math.cos(a); m[1][2]=-math.sin(a); m[2][1]=math.sin(a); m[2][2]=math.cos(a)
 return m
end
CLIENT=true; SERVER=false
ix.act={stored={}}; ix.Net={Type={Table={}},AddPlayerVar=function() end}
hook.Add=function() end; concommand={Add=function() end}
function M:GetScale() return Vector(1,1,1) end
function M:SetScale() end
function M:SetAngles() end
