local S = ix.PoseStudio
S.limit = {clips=30, frames=24, bones=96, props=3, bytes=48000, duration=120, page=24}
-- The 53 anatomical bones shared by Cellar's male/female animation skeletons.
-- Attachment, forward, twist and clothing helpers are not authoring controls.
S.humanoidBones={}
local prefix="ValveBiped.Bip01_"
for _,name in ipairs({"Pelvis","Spine","Spine1","Spine2","Spine4","Neck1","Head1"}) do S.humanoidBones[prefix..name]=name~="Pelvis" and "upper" or "lower" end
for _,side in ipairs({"L_","R_"}) do
 for _,name in ipairs({"Clavicle","UpperArm","Forearm","Hand"}) do S.humanoidBones[prefix..side..name]="upper" end
 for _,name in ipairs({"Thigh","Calf","Foot","Toe0"}) do S.humanoidBones[prefix..side..name]="lower" end
 for finger=0,4 do
  for _,joint in ipairs({"","1","2"}) do S.humanoidBones[prefix..side.."Finger"..finger..joint]="upper" end
 end
end
function S.BoneAllowed(clip,name)
 if clip.mask=="upper" then return S.humanoidBones[name]=="upper" end
 return not clip.portable or S.humanoidBones[name]~=nil
end

function S.Finite(n, low, high)
 return isnumber(n) and n == n and n >= low and n <= high
end
function S.Text(s, max)
 return isstring(s) and #s > 0 and #s <= max and not s:find("[%z\1-\31]")
end
function S.Model(s)
 return S.Text(s, 200) and s == s:lower() and s:match("^models/[%w_/%-%. ]+%.mdl$")
  and not s:find("..", 1, true)
end
local function array(t, max, allowEmpty)
 if not istable(t) or #t > max or (not allowEmpty and #t == 0) then return false end
 local n = 0
 for k in pairs(t) do
  if not S.Finite(k, 1, #t) or k ~= math.floor(k) then return false end
  n = n + 1
 end
 return n == #t
end
local function triple(t, bound)
 if not array(t, 3) or #t ~= 3 then return end
 local out = {}
 for i=1,3 do
  if not S.Finite(t[i], -bound, bound) then return end
  out[i] = math.Round(t[i] * 1000) / 1000
 end
 return out
end
function S.Transform(t, positionBound)
 if not istable(t) then return end
 local a, p = triple(t.a, 180), triple(t.p, positionBound)
 if a and p then return {a=a, p=p} end
end
function S.Identity() return {a={0,0,0}, p={0,0,0}} end
-- Sitting from a standing base needs a larger bounded pelvis offset.
function S.BonePositionLimit(name) return name=="ValveBiped.Bip01_Pelvis" and 64 or 12 end

-- A clip carries a compact anatomical rig and its frozen base, not an external
-- model dependency. Parents are earlier rows; helpers collapse into these 53
-- bones. Matrices/entities never cross the network or enter persisted data.
function S.ValidateReference(raw,clip)
 if not istable(raw) or raw.version~=1 or raw.model~=clip.model or not S.Model(raw.rigModel or raw.model) or raw.base~=clip.base or raw.cycle~=clip.cycle
  or not array(raw.bones,53) then return end
 local out={version=1,model=raw.model,rigModel=raw.rigModel or raw.model,base=raw.base,cycle=raw.cycle,bones={},recovered=raw.recovered==true}
 local names={}
 for index,row in ipairs(raw.bones) do
  if not istable(row) or not S.humanoidBones[row.name] or names[row.name]
   or not S.Finite(row.parent,-1,index-2) or row.parent~=math.floor(row.parent) then return end
  local bind,base=S.Transform(row.bind,128),S.Transform(row.base,128)
  if not bind or not base then return end
  -- Frozen animations may move their pelvis, but cannot inject huge per-bone
  -- offsets through the reference instead of the normal edit limits.
  local limit=S.BonePositionLimit(row.name)
  for axis=1,3 do if math.abs(base.p[axis]-bind.p[axis])>limit then return end end
  names[row.name]=true
  out.bones[index]={name=row.name,parent=row.parent,bind=bind,base=base}
 end
 return out
end

-- This is the only persisted/networked clip format. No Lua, entities or file paths
-- supplied by clients are executed. Runtime model/ownership checks live on server.
function S.Validate(raw)
 if not istable(raw) or not S.Text(raw.name, 96) or not S.Model(raw.model)
  or not S.Text(raw.base, 96) or not S.Finite(raw.cycle, 0, 1)
  or not array(raw.frames, S.limit.frames) or not array(raw.props, S.limit.props, true) then
  return nil, "Некорректный формат анимации."
 end
 if (raw.mask~=nil and raw.mask~="full" and raw.mask~="upper") or (raw.portable~=nil and type(raw.portable)~="boolean") then
  return nil,"Некорректный режим анимации."
 end
 local clip = {version=3, name=string.Trim(raw.name), model=raw.model, base=raw.base,portable=raw.portable==true,mask=raw.mask or "full",
  cycle=raw.cycle, loop=raw.loop==true, smooth=raw.smooth~=false, frames={}, props={}}
 if clip.name == "" then return nil, "Укажите название." end
 if raw.reference~=nil then
  clip.reference=S.ValidateReference(raw.reference,clip)
  if not clip.reference then return nil,"Некорректная сохранённая основа скелета." end
  clip.version=4
 end
 local duration = 0
 for _,frame in ipairs(raw.frames) do
  if not istable(frame) or not S.Finite(frame.duration, .1, 5) or not istable(frame.bones) then
   return nil, "Длительность кадра: 0.1–5 секунд."
  end
  duration = duration + frame.duration
  local clean, count = {duration=frame.duration, bones={}}, 0
  for name, transform in pairs(frame.bones) do
   count = count + 1
   local value = S.Transform(transform, S.BonePositionLimit(name))
   if count > S.limit.bones or not S.Text(name, 96) or not value then
    return nil, "Некорректная кость или смещение (12 единиц; для таза — 64)."
   end
   if not S.BoneAllowed(clip,name) then return nil,"Кость не входит в выбранную область тела: "..name end
   clean.bones[name] = value
  end
  clip.frames[#clip.frames+1] = clean
 end
 if duration > S.limit.duration then return nil, "Анимация слишком длинная." end
 for _,prop in ipairs(raw.props) do
  local value = S.Transform(prop, 48)
  if not value or not S.Model(prop.model) or not S.Text(prop.bone, 96)
   or not S.Finite(prop.scale, .25, 2) or not S.Finite(prop.skin, 0, 32)
   or prop.skin ~= math.floor(prop.skin) then return nil, "Некорректный реквизит." end
  if not S.BoneAllowed(clip,prop.bone) then return nil,"Кость реквизита не входит в выбранную область тела." end
  value.model, value.bone, value.scale, value.skin = prop.model, prop.bone, prop.scale, prop.skin
  clip.props[#clip.props+1] = value
 end
 return clip
end

function S.Duration(clip)
 local duration = 0
 for _,frame in ipairs(clip.frames) do duration = duration + frame.duration end
 return duration
end
-- A keyframe's duration is its transition to the next frame. The last frame
-- holds for its duration in one-shot playback, or blends to frame 1 in a loop.
function S.Sample(clip, elapsed)
 local total = S.Duration(clip)
 local time = math.max(elapsed, 0)
 if clip.loop then time = time % total else time = math.min(time, total) end
 local index, fraction = #clip.frames, 1
 for i,frame in ipairs(clip.frames) do
  if time < frame.duration then index=i; fraction=time/frame.duration; break end
  time = time - frame.duration
 end
 local nextIndex = index == #clip.frames and (clip.loop and 1 or index) or index+1
 if clip.smooth then fraction = fraction*fraction*(3-2*fraction) end
 local from, to = clip.frames[index].bones, clip.frames[nextIndex].bones
 local keys, result = {}, {}
 for name in pairs(from) do keys[name]=true end
 for name in pairs(to) do keys[name]=true end
 for name in pairs(keys) do
  local a, b = from[name] or S.Identity(), to[name] or S.Identity()
  local out = S.Identity()
  for k=1,3 do
   local delta = (b.a[k]-a.a[k]+180)%360-180
   out.a[k] = a.a[k]+delta*fraction
   out.p[k] = a.p[k]+(b.p[k]-a.p[k])*fraction
  end
  result[name]=out
 end
 return result, index
end
