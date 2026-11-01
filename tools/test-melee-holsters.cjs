module.exports = suite => suite('EFT melee profiles anchor small weapons at the belt and two-handed weapons at either back slot',
 ['ixhl2rp/plugins/ammo_cringe/cl_weapon_holsters.lua'], `
 local W=ix.WeaponSlots
 local data={character=1,items={}}
 local yaw,scale,active=0,1,nil
 local expectedBone='ValveBiped.Bip01_Pelvis'
 local client={GetNetVar=function() return data end,
  GetCharacter=function() return {GetID=function() return 1 end} end,
  GetActiveWeapon=function() return active end,GetModelScale=function() return scale end,
  GetRenderAngles=function() return Angle(0,yaw,0) end,
  LookupBone=function(_,bone) eq(bone,expectedBone);return 1 end,
  GetBoneMatrix=function() return {GetTranslation=function() return Vector(100,200,50) end,
   GetAngles=function() return Angle(60,75,90) end} end}
 local fallback={};local plugin={HolsterProfile=function() return fallback end,
  HolsterBoneFrame=function() return Angle(0,yaw,0) end}
 eq(W.HolsterProfile(plugin,'arc9_eft_glock17',true),fallback)
 eq(W.HolsterProfile(plugin,'arc9_eft_melee_6x5',false),fallback)
 local specs={
  {'6x5',-.1744,11.8992,true}, {'crowbar',-.2128,27.8398,false},
  {'gladius',-6.3578,27.4127,true}, {'hultafors',-12.2537,27.0802,false},
  {'kukri',-5.555,16.623,true}}
 for id,spec in ipairs(specs) do
  bounds={Vector(-2,-1,spec[2]),Vector(3,1,spec[3])}
  data.items[3]={id=id,class='arc9_eft_melee_'..spec[1],model=spec[1]..'.mdl'}
  for _,size in ipairs({1,.8,1.2}) do
   for _,heading in ipairs({0,90,180}) do
    scale,yaw=size,heading
    W.DrawHolsters(plugin,client)
    eq(lastModel.scale,1)
    near(lastModel.ang:Up().z,spec[4] and -1 or 1)
    -- Transform the actual world-mesh end points. The upper end stays at
    -- belt height; a long crowbar cannot straddle the waist horizontally.
    local top,bottom=-math.huge,math.huge
    for _,z in ipairs({spec[2],spec[3]}) do
     local point=lastModel.pos + lastModel.ang:Forward()*.5+lastModel.ang:Up()*z
     top=math.max(top,point.z);bottom=math.min(bottom,point.z)
    end
    near(top,50+2*scale);near(top-bottom,spec[3]-spec[2])
    local anchor=Vector(.5,0,spec[4] and spec[2] or spec[3])
    local world=lastModel.pos+lastModel.ang:Forward()*anchor.x-lastModel.ang:Right()*anchor.y+lastModel.ang:Up()*anchor.z
    local expected=LocalToWorld(Vector(-2,-8,2)*scale,angle_zero,Vector(100,200,50),Angle(0,yaw,0))
    near(world.x,expected.x);near(world.y,expected.y);near(world.z,expected.z)
   end
  end
 end
 local before=draws
 active={valid=true,GetNWInt=function() return 5 end};W.DrawHolsters(plugin,client);eq(draws,before)
 active=nil;expectedBone='ValveBiped.Bip01_Spine1'
 for _,spec in ipairs({specs[2],specs[3],specs[4]}) do
  bounds={Vector(-2,-1,spec[2]),Vector(3,1,spec[3])}
  for slot=1,2 do
   data.items={[slot]={id=10+slot,class='arc9_eft_melee_'..spec[1],model=spec[1]..'.mdl'}}
   for _,size in ipairs({.8,1,1.2}) do
    scale=size;W.DrawHolsters(plugin,client)
    near(lastModel.ang:Up().z,spec[1]=='gladius' and -1 or 1)
    eq(lastModel.scale,1)
    local anchor=Vector(.5,0,(spec[2]+spec[3])*.5)
    local world=lastModel.pos+lastModel.ang:Forward()*anchor.x-lastModel.ang:Right()*anchor.y+lastModel.ang:Up()*anchor.z
    local expected=LocalToWorld(Vector(-3.5*scale,(slot==2 and 5.5 or -5.5)*math.max(1,scale),9*scale),angle_zero,Vector(100,200,50),Angle(0,yaw,0))
    near(world.x,expected.x);near(world.y,expected.y);near(world.z,expected.z)
   end
  end
 end
 W.ClearHolsters(client);assert(not lastModel.valid)
 `, `
 CLIENT=true;SERVER=false;ix.WeaponSlots={count=3};hook.Add=function() end
 local V={};V.__index=V
 function Vector(x,y,z) return setmetatable({x=x or 0,y=y or 0,z=z or 0},V) end
 V.__add=function(a,b) return Vector(a.x+b.x,a.y+b.y,a.z+b.z) end
 V.__sub=function(a,b) return Vector(a.x-b.x,a.y-b.y,a.z-b.z) end
 V.__mul=function(a,b) return Vector(a.x*b,a.y*b,a.z*b) end
 local A={};A.__index=A
 function Angle(p,y,r) return setmetatable({p=p or 0,y=y or 0,r=r or 0},A) end
 function A:Forward() local p,y=math.rad(self.p),math.rad(self.y);return Vector(math.cos(p)*math.cos(y),math.cos(p)*math.sin(y),-math.sin(p)) end
 function A:Right() local y=math.rad(self.y);return Vector(math.sin(y),-math.cos(y),0) end
 function A:Up() local p,y=math.rad(self.p),math.rad(self.y);return Vector(math.sin(p)*math.cos(y),math.sin(p)*math.sin(y),math.cos(p)) end
 function LocalToWorld(p,a,origin,b)
  return origin+b:Forward()*p.x-b:Right()*p.y+b:Up()*p.z,Angle(a.p,a.y+b.y,a.r)
 end
 angle_zero=Angle();vector_origin=Vector();draws=0
 ix.arc9Inventory={IsClass=function() return true end}
 ix.WeaponAssembly={Get=function() error('Melee must use its complete world mesh, not the firearm preview anchor') end,Remove=function() end}
 util.IsValidModel=function() return true end
 function ClientsideModel()
  local model={valid=true}
  function model:SetNoDraw() end;function model:SetupBones() end
  function model:SetModelScale(s) self.scale=s end
  function model:GetRenderBounds() return bounds[1],bounds[2] end
  function model:SetPos(p) self.pos=p end;function model:SetAngles(a) self.ang=a end
  function model:DrawModel() draws=draws+1 end
  function model:Remove() self.valid=false end
  lastModel=model;return model
 end
 `);
