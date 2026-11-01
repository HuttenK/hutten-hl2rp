-- Source-coordinate vectors and rigid matrices for offline geometry tests.
local V={};V.__index=V
function Vector(x,y,z) return setmetatable({x=x or 0,y=y or 0,z=z or 0},V) end
function V.__add(a,b) return Vector(a.x+b.x,a.y+b.y,a.z+b.z) end
function V.__sub(a,b) return Vector(a.x-b.x,a.y-b.y,a.z-b.z) end
function V.__unm(a) return a*-1 end
function V.__mul(a,b) if type(a)=='number' then a,b=b,a end;return Vector(a.x*b,a.y*b,a.z*b) end
function V.__div(a,b) return a*(1/b) end
function V:Dot(b) return self.x*b.x+self.y*b.y+self.z*b.z end
function V:Cross(b) return Vector(self.y*b.z-self.z*b.y,self.z*b.x-self.x*b.z,self.x*b.y-self.y*b.x) end
function V:LengthSqr() return self:Dot(self) end
function V:Length() return math.sqrt(self:LengthSqr()) end
function V:Distance(b) return (self-b):Length() end
function V:GetNormalized() local n=self:Length();return n>0 and self/n or Vector() end
function V:Angle() return Angle(math.deg(math.atan(-self.z,math.sqrt(self.x*self.x+self.y*self.y))),math.deg(math.atan(self.y,self.x)),0) end
function isvector(v) return getmetatable(v)==V end
local A={};A.__index=A
function Angle(p,y,r) return setmetatable({p=p or 0,y=y or 0,r=r or 0},A) end
function A:Forward() local p,y=math.rad(self.p),math.rad(self.y);return Vector(math.cos(p)*math.cos(y),math.cos(p)*math.sin(y),-math.sin(p)) end
function A:Right() local p,y,r=math.rad(self.p),math.rad(self.y),math.rad(self.r);return Vector(-math.sin(r)*math.sin(p)*math.cos(y)+math.cos(r)*math.sin(y),-math.sin(r)*math.sin(p)*math.sin(y)-math.cos(r)*math.cos(y),-math.sin(r)*math.cos(p)) end
function A:Up() return self:Forward():Cross(self:Right()*-1) end
local M={};M.__index=M
function Matrix(t) return setmetatable({x=t and t.x or Vector(1,0,0),y=t and t.y or Vector(0,1,0),z=t and t.z or Vector(0,0,1),pos=t and t.pos or Vector()},M) end
function M:ToTable() return self end
function M:SetTranslation(v) self.pos=v end
function M:GetTranslation() return self.pos end
function M:SetForward(v) self.x=v end
function M:SetRight(v) self.y=-v end
function M:SetUp(v) self.z=v end
function M:GetForward() return self.x end
function M:GetRight() return -self.y end
function M:GetUp() return self.z end
function M:SetAngles(a) self.x=a:Forward();self.y=-a:Right();self.z=a:Up() end
function M:GetAngles() return Angle(math.deg(math.atan(-self.x.z,math.sqrt(self.x.x*self.x.x+self.x.y*self.x.y))),math.deg(math.atan(self.x.y,self.x.x)),math.deg(math.atan(self.y.z,self.z.z))) end
function M:GetInverse()
 local m=Matrix();m.x=Vector(self.x.x,self.y.x,self.z.x);m.y=Vector(self.x.y,self.y.y,self.z.y);m.z=Vector(self.x.z,self.y.z,self.z.z)
 m.pos=-(m*self.pos);return m
end
function M.__mul(a,b)
 if isvector(b) then return a.x*b.x+a.y*b.y+a.z*b.z+a.pos end
 local m=Matrix();m.x=a*b.x-a.pos;m.y=a*b.y-a.pos;m.z=a*b.z-a.pos;m.pos=a*b.pos;return m
end
function A:RotateAroundAxis(axis,degrees)
 local m=Matrix();m:SetAngles(self);local c,s=math.cos(math.rad(degrees)),math.sin(math.rad(degrees));axis=axis:GetNormalized()
 local function turn(v) return v*c+axis:Cross(v)*s+axis*(axis:Dot(v)*(1-c)) end
 m.x=turn(m.x);m.y=turn(m.y);m.z=turn(m.z);local a=m:GetAngles();self.p=a.p;self.y=a.y;self.r=a.r
end
function A.__mul(a,v) local m=Matrix();m:SetAngles(a);return m*v end
function Lerp(f,a,b) return a+(b-a)*f end
function LerpVector(f,a,b) return a+(b-a)*f end
function LerpAngle(f,a,b)
 local function delta(a,b) return (b-a+180)%360-180 end
 return Angle(a.p+delta(a.p,b.p)*f,a.y+delta(a.y,b.y)*f,a.r+delta(a.r,b.r)*f)
end
vector_origin=Vector();angle_zero=Angle()
