-- Offline Source-axis vector/angle arithmetic for the editor gizmo tests.
local V=getmetatable(Vector())
function V.__unm(a) return Vector(-a.x,-a.y,-a.z) end
function V:Dot(b) return self.x*b.x+self.y*b.y+self.z*b.z end
function V:Cross(b) return Vector(self.y*b.z-self.z*b.y,self.z*b.x-self.x*b.z,self.x*b.y-self.y*b.x) end
function V:GetNormalized() return self*(1/math.max(self:Length(),1e-12)) end
math.atan2=math.atan
function math.NormalizeAngle(a) return (a+180)%360-180 end
function math.AngleDifference(a,b) return math.NormalizeAngle(a-b) end
local A={}; A.__index=A
function Angle(p,y,r) return setmetatable({p=p or 0,y=y or 0,r=r or 0},A) end
function A:Forward()
 local p,y=math.rad(self.p),math.rad(self.y)
 return Vector(math.cos(p)*math.cos(y),math.cos(p)*math.sin(y),-math.sin(p))
end
function A:Right()
 local p,y,r=math.rad(self.p),math.rad(self.y),math.rad(self.r)
 return -Vector(math.sin(r)*math.sin(p)*math.cos(y)-math.cos(r)*math.sin(y),
  math.sin(r)*math.sin(p)*math.sin(y)+math.cos(r)*math.cos(y),math.sin(r)*math.cos(p))
end
function A:Up()
 local p,y,r=math.rad(self.p),math.rad(self.y),math.rad(self.r)
 return Vector(math.cos(r)*math.sin(p)*math.cos(y)+math.sin(r)*math.sin(y),
  math.cos(r)*math.sin(p)*math.sin(y)-math.sin(r)*math.cos(y),math.cos(r)*math.cos(p))
end
function A:RotateAroundAxis(n,degrees)
 near(n:Length(),1)
 local theta=math.rad(degrees)
 local function rotate(v) return v*math.cos(theta)+n:Cross(v)*math.sin(theta)+n*(n:Dot(v)*(1-math.cos(theta))) end
 local f,l,u=rotate(self:Forward()),rotate(-self:Right()),rotate(self:Up())
 self.p=math.deg(math.atan(-f.z,math.sqrt(f.x*f.x+f.y*f.y)))
 self.y=math.deg(math.atan(f.y,f.x)); self.r=math.deg(math.atan(l.z,u.z))
end
function V:Angle() return Angle(math.deg(math.atan(-self.z,math.sqrt(self.x*self.x+self.y*self.y))),math.deg(math.atan(self.y,self.x)),0) end
function vectorNear(a,b) near(a.x,b.x); near(a.y,b.y); near(a.z,b.z) end
