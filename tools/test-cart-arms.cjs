const fs=require('fs');
const toLua=v=>Array.isArray(v)?'{'+v.map(toLua).join(',')+'}':v&&typeof v==='object'?'{'+Object.entries(v).map(([k,x])=>'['+JSON.stringify(k)+']='+toLua(x)).join(',')+'}':JSON.stringify(v);
const rigs=JSON.parse(fs.readFileSync('tools/fixtures/pose-starter-rigs.json','utf8'));
const setup=['sharedposes','pose-gizmo','body-drag'].map(f=>fs.readFileSync('tools/fixtures/'+f+'.lua','utf8')).join('\n')+`
CLIENT=true;SERVER=false;vector_up=Vector(0,0,1)
function Color(r,g,b,a) return {r=r,g=g,b=b,a=a} end
function FrameTime() return .25 end
function math.Approach(a,b,s) return a<b and math.min(a+s,b) or math.max(a-s,b) end
function CreateClientConVar() return {GetBool=function() return false end} end
function EyePos() return Vector() end
function LerpVector(t,a,b) return a+(b-a)*t end
local M=getmetatable(Matrix());local multiply=M.__mul
function M.__mul(a,b)
 if b.x then return Vector(a[1][1]*b.x+a[1][2]*b.y+a[1][3]*b.z+a[1][4],a[2][1]*b.x+a[2][2]*b.y+a[2][3]*b.z+a[2][4],a[3][1]*b.x+a[3][2]*b.y+a[3][3]*b.z+a[3][4]) end
 return multiply(a,b)
end
ix.PushCart={Kin={},carts={}}
function ix.PushCart:BodyYaw() return 0 end
function ix.PushCart:GetPushedCart(p) return p.cart end
rigData=${toLua(rigs)}
function actor(data,scale)
 scale=scale or 1
 local p={valid=true,model=data.name,bones=data.bones,matrices={},names={},callbacks={}}
 for n,b in ipairs(data.bones) do
  local inverse=Matrix();for r=1,3 do for c=1,4 do inverse:SetField(r,c,b.inverse[(r-1)*4+c]) end end
  p.names[b.name]=n-1;p.matrices[n-1]=rotation(90)*inverse:GetInverse()
  for r=1,3 do for c=1,4 do p.matrices[n-1]:SetField(r,c,p.matrices[n-1][r][c]*scale) end end
 end
 function p:GetModel() return self.model end
 function p:GetBoneCount() return self.partialCount or #self.bones end
 function p:LookupBone(n) return self.names[n] end
 function p:GetBoneParent(i) if self.partialParents and i>23 then return -1 end return self.bones[i+1].parent end
 function p:GetBoneName(i) return self.bones[i+1].name end
 function p:GetBoneMatrix(i) return self.matrices[i] end
 function p:SetBoneMatrix(i,m) self.matrices[i]=m end
 function p:GetPos() return Vector() end
 function p:EyeAngles() return Angle() end
 function p:IsPlayer() return true end
 function p:Alive() return true end
 function p:AddCallback(_,f) self.callbacks[#self.callbacks+1]=f;return #self.callbacks end
 function p:RemoveCallback(_,i) self.callbacks[i]=nil end
 local cart={valid=true};function cart:GetPusher() return p end
 function cart:GetDrawPose() return Vector(52,0,15.96365),Angle(0,0,0) end
 p.cart=cart;ix.PushCart.carts={[cart]=true}
 return p
end
`;
module.exports=function(suite){
 suite('Cart grips preserve arm lengths at 155, 180 and 190 cm on eight compiled rigs', ['ixhl2rp/plugins/pushcart/libs/sh_bootstrap.lua','ixhl2rp/plugins/pushcart/sh_kinematics.lua','ixhl2rp/plugins/pushcart/cl_ik.lua'], `
 for _,data in ipairs(rigData) do for _,height in ipairs({155,180,190}) do
  local p=actor(data,height/180);local lengths={}
  for _,side in ipairs({'R','L'}) do
   local function pos(part) return p:GetBoneMatrix(p:LookupBone('ValveBiped.Bip01_'..side..'_'..part)):GetTranslation() end
   lengths[side]={pos('UpperArm'):Distance(pos('Forearm')),pos('Forearm'):Distance(pos('Hand'))}
  end
  fire('Think');p.callbacks[1](p)
  for _,side in ipairs({'R','L'}) do
   local function pos(part) return p:GetBoneMatrix(p:LookupBone('ValveBiped.Bip01_'..side..'_'..part)):GetTranslation() end
   near(pos('UpperArm'):Distance(pos('Forearm')),lengths[side][1],.001)
   near(pos('Forearm'):Distance(pos('Hand')),lengths[side][2],.001)
   local cp,ca=p.cart:GetDrawPose();local P=ix.PushCart
   local grip=LocalToWorld(side=='R' and P.GRIP_RIGHT or P.GRIP_LEFT,angle_zero,cp,ca)
   assert(math.abs(pos('Finger2'):Distance(grip)-P.WRAP_RADIUS)<.05,data.name..' '..height..' '..side..' cannot reach cart')
  end
 end end
 `,setup);
 for (const className of ['ix_medical_gurney','ix_medical_wheelchair']) suite(className+' hands use its own handles across character heights and compiled rigs', ['ixhl2rp/plugins/pushcart/libs/sh_bootstrap.lua','ixhl2rp/plugins/pushcart/sh_kinematics.lua','ixhl2rp/plugins/pushcart/cl_ik.lua'], `
  function LocalToWorld(v,a,p,ang) return p+ang:Forward()*v.x-ang:Right()*v.y+ang:Up()*v.z,Angle(a.p+ang.p,a.y+ang.y,a.r+ang.r) end
  for _,data in ipairs(rigData) do for _,height in ipairs({155,180,190}) do
   local p=actor(data,height/180);p.cart.ClassName='${className}'
   local profile=ix.PushCart:Transport(p.cart);local K=profile.kin
   function p.cart:GetDrawPose() return Vector(K.REACH,0,-K.WHEEL_BOTTOM),Angle(0,180+profile.yaw,0) end
   local lengths={}
   for _,side in ipairs({'R','L'}) do
    local function pos(part) return p:GetBoneMatrix(p:LookupBone('ValveBiped.Bip01_'..side..'_'..part)):GetTranslation() end
    lengths[side]={pos('UpperArm'):Distance(pos('Forearm')),pos('Forearm'):Distance(pos('Hand'))}
   end
   fire('Think');p.callbacks[1](p)
   for _,side in ipairs({'R','L'}) do
    local function pos(part) return p:GetBoneMatrix(p:LookupBone('ValveBiped.Bip01_'..side..'_'..part)):GetTranslation() end
    near(pos('UpperArm'):Distance(pos('Forearm')),lengths[side][1],.001)
    near(pos('Forearm'):Distance(pos('Hand')),lengths[side][2],.001)
    local cp,ca=p.cart:GetDrawPose();local grip=LocalToWorld(side=='R' and profile.gripRight or profile.gripLeft,angle_zero,cp,ca)
    assert(math.abs(pos('Finger2'):Distance(grip)-ix.PushCart.WRAP_RADIUS)<.1,data.name..' '..height..' '..side..' cannot reach transport')
   end
  end end
 `,setup);
 suite('Cart rig recovers when named fingers precede the full bone count or parent hierarchy', ['ixhl2rp/plugins/pushcart/libs/sh_bootstrap.lua','ixhl2rp/plugins/pushcart/sh_kinematics.lua','ixhl2rp/plugins/pushcart/cl_ik.lua'], `
 local p=actor(rigData[1]);p.partialCount=24;fire('Think');p.callbacks[1](p)
 p.partialCount=nil;p.partialParents=true;p.callbacks[1](p)
 p.partialParents=false;p.callbacks[1](p)
 local pos,ang=p.cart:GetDrawPose();local P=ix.PushCart
 for _,side in ipairs({'R','L'}) do
  local hand=p:GetBoneMatrix(p:LookupBone('ValveBiped.Bip01_'..side..'_Hand')):GetTranslation()
  local finger=p:GetBoneMatrix(p:LookupBone('ValveBiped.Bip01_'..side..'_Finger2')):GetTranslation()
  local grip=LocalToWorld(side=='R' and P.GRIP_RIGHT or P.GRIP_LEFT,angle_zero,pos,ang)
  assert(finger:Distance(hand)<5,'Detached fingers survived the rig transition')
  near(finger:Distance(grip),P.WRAP_RADIUS,.001)
 end
 `,setup);
 suite('Refreshing cart IK removes old callbacks and releases residual body-facing state', ['ixhl2rp/plugins/pushcart/libs/sh_bootstrap.lua','ixhl2rp/plugins/pushcart/sh_kinematics.lua','ixhl2rp/plugins/pushcart/cl_ik.lua'], `
 local p=actor(rigData[1]);allPlayers={p};fire('Think');assert(p.ixPushCartIK)
 ix.PushCart.CleanupIK();eq(p.ixPushCartIK,nil);eq(p.ixPushCartIKCart,nil);eq(p.ixPushCartIKWeight,0)
 eq(next(p.callbacks),nil);fire('Think');assert(p.ixPushCartIK);eq(p.ixPushCartIKWeight,1)
 `,setup);
 suite('Cart hands reach the rail on eight compiled humanoid skeletons', ['ixhl2rp/plugins/pushcart/libs/sh_bootstrap.lua','ixhl2rp/plugins/pushcart/sh_kinematics.lua','ixhl2rp/plugins/pushcart/cl_ik.lua'], `
 local P=ix.PushCart
 for _,data in ipairs(rigData) do
  local p=actor(data);fire('Think');assert(p.callbacks[1]);p.callbacks[1](p)
  for _,side in ipairs({'R','L'}) do
   local name='ValveBiped.Bip01_'..side..'_Finger2';local knuckle=p:GetBoneMatrix(p:LookupBone(name)):GetTranslation()
   local pos,ang=p.cart:GetDrawPose();local grip=LocalToWorld(side=='R' and P.GRIP_RIGHT or P.GRIP_LEFT,angle_zero,pos,ang)
   local expected=grip+ang:Forward()*(P.WRAP_RADIUS*math.sin(math.rad(P.KNUCKLE_ANGLE)))+ang:Up()*(P.WRAP_RADIUS*math.cos(math.rad(P.KNUCKLE_ANGLE)))
   local error=knuckle:Distance(expected)
   assert(error<.001,data.name..' '..side..' grip error '..error)
  end
 end
 `,setup);
};


