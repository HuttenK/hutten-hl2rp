local S=ix.PoseStudio
S.rotationAxes={
 {name="X",field=3,color=Color(250,99,111)},
 {name="Y",field=1,color=Color(103,230,167)},
 {name="Z",field=2,color=Color(101,171,255)}
}

-- Projected polygon picking uses exactly the vertices drawn by the viewport.
function S.PickRotationRing(rings,x,y)
 local hit,best=nil,8*8
 for _,ring in ipairs(rings or {}) do
  for i=1,#ring.points-1 do
   local a,b=ring.points[i],ring.points[i+1]
   if a.visible and b.visible then
    local dx,dy=b.x-a.x,b.y-a.y
    local length=dx*dx+dy*dy
    if length>.001 then
     local t=math.Clamp(((x-a.x)*dx+(y-a.y)*dy)/length,0,1)
     local distance=(x-a.x-dx*t)^2+(y-a.y-dy*t)^2
     if distance<best then
      best=distance
      hit={ring=ring,tx=dx/math.sqrt(length),ty=dy/math.sqrt(length)}
     end
    end
   end
  end
 end
 return hit
end

-- Invert the plane's projective transform, rather than using a screen-space
-- atan2 on a tilted ellipse. Depth ratios make this perspective-correct even
-- with the non-default FOV/viewport used by DModelPanel.
function S.RotationRingAngle(ring,x,y)
 local c,u,v=ring.center,ring.u,ring.v
 local ax,ay=u.x-x*u.z,u.y-y*u.z
 local bx,by=v.x-x*v.z,v.y-y*v.z
 local det=ax*by-bx*ay
 if math.abs(det)<.001 then return end
 local dx,dy=x-c.x,y-c.y
 local s,t=(dx*by-bx*dy)/det,(ax*dy-dx*ay)/det
 if s*s+t*t<.04 then return end
 return math.deg(math.atan2(t,s))
end

function S.RotateBoneAngle(start,axis,degrees)
 local angle=Angle(unpack(start))
 local normal=axis==1 and angle:Forward() or axis==2 and -angle:Right() or angle:Up()
 -- Compose local-axis rotations. Adding an Euler component would rotate
 -- around the wrong ring after earlier rotations on the other axes.
 angle:RotateAroundAxis(normal,degrees)
 return {math.NormalizeAngle(angle.p),math.NormalizeAngle(angle.y),math.NormalizeAngle(angle.r)}
end

function S.RotationDragDelta(drag,x,y,dx,dy)
 if drag.ring.edgeOn then
  -- A ring seen exactly edge-on has no invertible projected plane. Drag
  -- along its visible tangent instead; never divide by an almost-zero plane.
  return (dx*drag.tx+dy*drag.ty)*180/(math.pi*55)
 end
 local angle=S.RotationRingAngle(drag.ring,x,y)
 local previous=drag.lastAngle
 drag.lastAngle=angle
 if angle and previous then return math.AngleDifference(angle,previous) end
 return 0
end
