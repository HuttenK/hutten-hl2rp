module.exports = suite => suite('Back holsters stand vertically at symmetric shoulder positions and preserve the hip',
 ['ixhl2rp/plugins/ammo_cringe/cl_weapon_holsters.lua'], `
 local W=ix.WeaponSlots
 local first,a=W.HolsterMount(1);local second,b=W.HolsterMount(2);local hip,h=W.HolsterMount(3)
 eq(first.x,-3.5);eq(first.y,-5.5);eq(first.z,9)
 near(a:Forward().z,1);near(b:Forward().z,1)
 near(a:Forward().x,0);near(a:Forward().y,0);near(b:Forward().x,0);near(b:Forward().y,0)
 -- Verify mount separation; actual attachment clearance is checked in game.
 near(second.y-first.y,11)
 eq(hip.x,0);eq(hip.y,-8);eq(hip.z,-4);eq(h.p,90);eq(h.y,0);eq(h.r,0)
 -- Use Source's actual angle basis, including roll, rather than comparing
 -- Euler numbers alone: both barrels remain parallel to the torso's up axis.
 for _,point in ipairs({{20,0},{45,0},{-15,0},{0,-6}}) do
  local f,u=a:Forward(),a:Up();local mf,mu=b:Forward(),b:Up()
  near(second.x+mf.x*point[1]+mu.x*point[2],first.x+f.x*point[1]+u.x*point[2])
  near(second.y+mf.y*point[1]+mu.y*point[2],-first.y-f.y*point[1]-u.y*point[2])
  near(second.z+mf.z*point[1]+mu.z*point[2],first.z+f.z*point[1]+u.z*point[2])
 end
 for _,angle in ipairs({Angle(-65,90,0),Angle(-20,8,13),Angle(32,-135,42)}) do
  local mirror=W.MirrorHolsterAngle(angle)
  for _,method in ipairs({'Forward','Up'}) do
   local v,m=angle[method](angle),mirror[method](mirror)
   near(m.x,v.x);near(m.y,-v.y);near(m.z,v.z)
  end
  local twice=W.MirrorHolsterAngle(mirror)
  eq(twice.p,angle.p);eq(twice.y,angle.y);eq(twice.r,angle.r)
 end
 `, `
 ix.WeaponSlots={};hook.Add=function() end
 function Vector(x,y,z) return {x=x or 0,y=y or 0,z=z or 0} end
 local A={};A.__index=A
 function Angle(p,y,r) return setmetatable({p=p or 0,y=y or 0,r=r or 0},A) end
 function A:Forward()
  local p,y=math.rad(self.p),math.rad(self.y)
  return Vector(math.cos(p)*math.cos(y),math.cos(p)*math.sin(y),-math.sin(p))
 end
 function A:Up()
  local p,y,r=math.rad(self.p),math.rad(self.y),math.rad(self.r)
  return Vector(math.cos(r)*math.sin(p)*math.cos(y)+math.sin(r)*math.sin(y),
   math.cos(r)*math.sin(p)*math.sin(y)-math.sin(r)*math.cos(y),math.cos(r)*math.cos(p))
 end
 `);
