local F=ix.Fieldlink
for p,s in pairs(F.holdingStates or {}) do
 if IsValid(p) and s.callback then p:RemoveCallback("BuildBonePositions",s.callback) end
end
local states=setmetatable({},{__mode="k"})
F.holdingStates=states
local prefix="ValveBiped.Bip01_"
-- The grip and the prop share one screen-relative frame. Hand bone axes vary
-- between rigs; use the knuckles to measure the palm instead of fixed Euler rolls.
function F.PDAReadingAngle(p) return Angle(-25,p:GetRenderAngles().y,0) end
function F.PDAHandOffset(a,side,tap)
 if side=="R" then return a:Right()*2.4-a:Forward()*5-a:Up()*.7 end
 return a:Right()*-7-a:Forward()*.8+a:Up()*(1.8+(tap or 0))
end
function F.PDADeviceFromHand(p,hand)
 local a=F.PDAReadingAngle(p)
 return hand-F.PDAHandOffset(a,"R"),a
end
function F.PDAPalmBasis(wrist,index,middle,little)
 local forward=middle-wrist
 local normal=forward:Cross(index-little)
 if forward:LengthSqr()<.0001 or normal:LengthSqr()<.0001 then return end
 forward=forward:GetNormalized();normal=normal:GetNormalized()
 return forward,normal:Cross(forward),normal
end
local function frame(forward,normal)
 local m=Matrix()
 forward=forward:GetNormalized()
 if normal:Cross(forward):LengthSqr()<.0001 then
  normal=math.abs(forward.z)<.9 and Vector(0,0,1) or Vector(0,1,0)
 end
 local across=normal:Cross(forward):GetNormalized()
 m:SetForward(forward);m:SetRight(across*-1);m:SetUp(forward:Cross(across))
 return m
end
function F.PDAOrientPalm(hand,index,middle,little,forward,normal,side)
 if not index or not middle or not little then return hand:GetAngles() end
 local sourceForward,_,sourceNormal=F.PDAPalmBasis(hand:GetTranslation(),index:GetTranslation(),middle:GetTranslation(),little:GetTranslation())
 if not sourceForward then return hand:GetAngles() end
 -- ValveBiped finger layouts are mirrored. Index-to-little measures the back
 -- of the RIGHT hand, but the palm of the LEFT hand (verified on SD's SMD).
 if side=="R" then sourceNormal=sourceNormal*-1 end
 local inverse=frame(sourceForward,sourceNormal):GetInverse()
 if not inverse then return hand:GetAngles() end
 local rotation=Matrix(hand:ToTable());rotation:SetTranslation(vector_origin)
 return (frame(forward,normal)*inverse*rotation):GetAngles()
end
function F.PDASwing(from,to)
 from=from:GetNormalized();to=to:GetNormalized()
 local dot=math.Clamp(from:Dot(to),-1,1);local axis=from:Cross(to)
 if axis:LengthSqr()<.000001 then
  if dot>0 then return Matrix() end
  axis=from:Cross(math.abs(from.z)<.9 and Vector(0,0,1) or Vector(0,1,0))
 end
 local angle=Angle(0,0,0);angle:RotateAroundAxis(axis:GetNormalized(),math.deg(math.acos(dot)))
 local matrix=Matrix();matrix:SetAngles(angle);return matrix
end
function F.PDAPoseFinger(chain,delta,forward,normal,curl,fraction)
 -- Rebuild all phalanges. Inheriting the SLAM finger locals leaves a closed,
 -- downward-facing grip even after the palm has been correctly aligned.
 if not chain[1] or not chain[2] or not chain[3] then return end
 local result={};local position=(delta*chain[1]):GetTranslation()
 for j=1,3 do
  local source=chain[j]
  local nextBone=chain[math.min(j+1,3)]
  local oldDirection=j<3 and nextBone:GetTranslation()-source:GetTranslation() or source:GetTranslation()-chain[2]:GetTranslation()
  if oldDirection:LengthSqr()<.0001 then return end
  local bend=math.rad(curl*(j-1)/2)
  local direction=(forward*math.cos(bend)+normal*math.sin(bend)):GetNormalized()
  local inherited=delta*source
  local inheritedDirection=delta*oldDirection-delta:GetTranslation()
  local rotation=Matrix(inherited:ToTable());rotation:SetTranslation(vector_origin)
  local target=F.PDASwing(inheritedDirection,direction)*rotation
  local posed=Matrix(inherited:ToTable())
  posed:SetTranslation(LerpVector(fraction,inherited:GetTranslation(),position))
  posed:SetAngles(LerpAngle(fraction,inherited:GetAngles(),target:GetAngles()))
  result[j]=posed
  position=position+direction*oldDirection:Length()
 end
 return result
end
function F.HoldingWeapon(p)
 if not IsValid(p) or not p:Alive() or p:InVehicle() or p:GetLocalVar("ragdoll",0)~=0 or
  p:GetLocalVar("knocked",false) or p:GetNetVar("forcedSequence") or p:GetNetVar("sharedPose") then return end
 if ix.Downed and ix.Downed.Crawling(p) then return end
 local w=p:GetActiveWeapon()
 if IsValid(w) and w:GetClass()==F.class and w.GetPDAFraction and w:GetPDAFraction()>.001 then return w end
end
function F.SolvePDAArm(root,target,pole,upper,fore)
 if upper<.001 or fore<.001 then return end
 local d=target-root;local direction=d:GetNormalized()
 if d:LengthSqr()<.000001 then direction=Vector(1,0,0) end
 local distance=math.Clamp(d:Length(),math.abs(upper-fore)+.001,upper+fore-.001)
 local along=(upper*upper-fore*fore+distance*distance)/(2*distance)
 local bend=pole-direction*pole:Dot(direction)
 if bend:LengthSqr()<.000001 then
  local axis=math.abs(direction.z)<.9 and Vector(0,0,1) or Vector(0,1,0)
  bend=axis-direction*axis:Dot(direction)
 end
 return root+direction*along+bend:GetNormalized()*math.sqrt(math.max(0,upper*upper-along*along)),root+direction*distance
end
function F.ApplyHolding(p,state)
 local w=F.HoldingWeapon(p)
 if not w or p:GetModel()~=state.model then return end
 local chest=p:GetBoneMatrix(state.chest);if not chest then return end
 local original={}
 for i=0,p:GetBoneCount()-1 do local m=p:GetBoneMatrix(i);if m then original[i]=Matrix(m:ToTable()) end end
 local f=w:GetPDAFraction();local a=Angle(0,p:GetRenderAngles().y,0)
 local center=chest:GetTranslation()+a:Forward()*13+Vector(0,0,1.5)
 local screenAngle=F.PDAReadingAngle(p)
 local tapAt=w:GetNW2Float("fieldlinkTap",0);local phase=math.Clamp((CurTime()-tapAt)/.45,0,1)
 local tap=-math.sin(phase*math.pi)*.65
 local changed={}
 if state.head and original[state.head] then
  local head=Matrix(original[state.head]:ToTable());local angle=head:GetAngles()
  angle:RotateAroundAxis(a:Right(),-14*f);head:SetAngles(angle);changed[state.head]=head
 end
 for _,side in ipairs({"R","L"}) do
  local b=state[side];local u,e,h=original[b[1]],original[b[2]],original[b[3]]
  if u and e and h then
   local root=u:GetTranslation();local sign=side=="R" and 1 or -1
   local goal=center+F.PDAHandOffset(screenAngle,side,tap)
   local elbow,hand=F.SolvePDAArm(root,goal,a:Right()*sign-Vector(0,0,1),root:Distance(e:GetTranslation()),e:GetTranslation():Distance(h:GetTranslation()))
   if elbow then
    local upperAngle=(F.PDASwing(e:GetTranslation()-root,elbow-root)*u):GetAngles()
    local foreAngle=(F.PDASwing(h:GetTranslation()-e:GetTranslation(),hand-elbow)*e):GetAngles()
    local um=Matrix(u:ToTable());um:SetAngles(LerpAngle(f,u:GetAngles(),upperAngle))
    local em=Matrix(e:ToTable());em:SetTranslation(LerpVector(f,e:GetTranslation(),elbow));em:SetAngles(LerpAngle(f,e:GetAngles(),foreAngle))
    local fingers=b.fingers or {}
    local palmAngle=F.PDAOrientPalm(h,original[fingers[1]],original[fingers[2]],original[fingers[3]],
     side=="R" and screenAngle:Forward() or screenAngle:Right(),screenAngle:Up()*(side=="R" and 1 or -1),side)
    local hm=Matrix(h:ToTable());hm:SetTranslation(LerpVector(f,h:GetTranslation(),hand));hm:SetAngles(LerpAngle(f,h:GetAngles(),palmAngle))
    changed[b[1]]=um;changed[b[2]]=em;changed[b[3]]=hm
    local inverse=h:GetInverse()
    if inverse then
     local delta=hm*inverse
     for finger,ids in pairs(b.chains or {}) do
      local direction=side=="R" and screenAngle:Forward() or screenAngle:Right()
      if finger==0 then direction=(screenAngle:Forward()*.4+screenAngle:Right()*(side=="R" and -1 or 1)):GetNormalized() end
      local normal=screenAngle:Up()*(side=="R" and 1 or -1)
      local curl=side=="L" and (finger==1 and 5 or 35) or 25
      local posed=F.PDAPoseFinger({original[ids[1]],original[ids[2]],original[ids[3]]},delta,direction,normal,curl,f)
      if posed then for j=1,3 do changed[ids[j]]=posed[j] end end
     end
    end
   end
  end
 end
 -- Let helper bones and any unsupported fingers follow their changed parent, preserving
 -- local transforms. No permanent bone manipulation, no writes outside bone build.
 local visited={}
 local function inherit(i)
  if visited[i] or i<0 then return end;visited[i]=true
  local parent=p:GetBoneParent(i);if parent>=0 then inherit(parent) end
  if not changed[i] and changed[parent] and original[parent] and original[i] then
   local inverse=original[parent]:GetInverse();if inverse then changed[i]=changed[parent]*inverse*original[i] end
  end
 end
 for i=0,p:GetBoneCount()-1 do inherit(i) end
 for i,m in pairs(changed) do
  if p:GetBoneName(i)~="__INVALIDBONE__" then p:SetBoneMatrix(i,m) end
 end
end
local function remove(p,s)
 if IsValid(p) and s.callback then p:RemoveCallback("BuildBonePositions",s.callback) end
 states[p]=nil
end
hook.Add("Think","FieldlinkHolding",function()
 for p,s in pairs(states) do if not F.HoldingWeapon(p) or p:GetModel()~=s.model then remove(p,s) end end
 for _,p in ipairs(player.GetAll()) do
  if not states[p] and F.HoldingWeapon(p) then
   local s={model=p:GetModel(),chest=p:LookupBone(prefix.."Spine2"),head=p:LookupBone(prefix.."Head1")}
   local valid=s.chest~=nil
   for _,side in ipairs({"R","L"}) do
    s[side]={p:LookupBone(prefix..side.."_UpperArm"),p:LookupBone(prefix..side.."_Forearm"),p:LookupBone(prefix..side.."_Hand")}
    s[side].fingers={p:LookupBone(prefix..side.."_Finger1"),p:LookupBone(prefix..side.."_Finger2"),p:LookupBone(prefix..side.."_Finger4")}
    s[side].chains={}
    for finger=0,4 do
     local name=prefix..side.."_Finger"..finger
     s[side].chains[finger]={p:LookupBone(name),p:LookupBone(name.."1"),p:LookupBone(name.."2")}
    end
    for i=1,3 do if s[side][i]==nil then valid=false end end
   end
   if valid then s.callback=p:AddCallback("BuildBonePositions",function(ent) F.ApplyHolding(ent,s) end);states[p]=s end
  end
 end
end)
hook.Add("ShutDown","FieldlinkHolding",function() for p,s in pairs(states) do remove(p,s) end end)
if concommand then concommand.Add("ix_pda_pose_status",function()
 local p=LocalPlayer();if not IsValid(p) then return end
 local w=p:GetActiveWeapon()
 print("[PDA pose-v6] model="..p:GetModel().."; class="..tostring(p.ixAnimModelClass).."; sequence="..p:GetSequenceName(p:GetSequence()))
 print("[PDA pose-v6] weapon="..(IsValid(w) and w:GetClass() or "none").."; hold="..(IsValid(w) and w:GetHoldType() or "none").."; raised="..tostring(p:IsWepRaised()).."; bone pose="..tostring(states[p]~=nil))
 print("[PDA pose-v6] crouch="..tostring(p:Crouching()).."; speed="..math.Round(p:GetVelocity():Length2D(),2).."; eye="..tostring(p:EyeAngles()).."; render="..tostring(p:GetRenderAngles()))
 print("[PDA pose-v6] forced="..tostring(p:GetNetVar("forcedSequence")).."; shared="..tostring(p:GetNetVar("sharedPose")).."; ideal="..tostring(p.CalcIdeal).."; override="..tostring(p.CalcSeqOverride))
end) end
