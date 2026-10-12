-- Pose Maker hand data and model-aware edit concepts adapted for Pose Studio v3.
-- Source hashes/provenance: docs/restored-systems-sources.json.
local S=ix.PoseStudio
local ANGLE_DECIMALS=1
local FINGER_POSER = {
	flat = {
		{-4.2, -29.2}, {0, -2.1}, {0, 10.4},
		{6.3, 31.3}, {0, 10.4}, {0, 4.2},
		{0, 22.9}, {0, 35.4}, {0, 2.1},
		{-8.3, 12.5}, {0, 39.6}, {0, 25},
		{-20.8, 27.1}, {0, 8.3}, {0, 29.2}
	},
	point = {
		{31.3, -6.3}, {0, 14.6}, {0, 10.4},
		{8.3, 22.9}, {0, 10.4}, {0, 4.2},
		{-16.7, -50}, {0, -50}, {0, -50},
		{-10.4, -50}, {0, -50}, {0, -50},
		{4.2, -50}, {0, -50}, {0, -50}
	},
	thumbsUp = {
		{2.1, -20.8}, {-50, -14.6}, {-6.3, 6.3},
		{-25, -50}, {0, -50}, {0, -50},
		{-16.7, -50}, {0, -50}, {0, -50},
		{-10.4, -50}, {0, -50}, {0, -50},
		{4.2, -50}, {0, -50}, {0, -50}
	}
}

S.FINGER_SEGMENTS = {}

for finger = 0, 4 do
	for part = 0, 2 do
		S.FINGER_SEGMENTS[#S.FINGER_SEGMENTS + 1] = "Finger" .. finger .. (part > 0 and part or "")
	end
end

local function Blend(first, second, fraction)
	local result = {}

	for i, pair in ipairs(first) do
		result[i] = {Lerp(fraction, pair[1], second[i][1]), Lerp(fraction, pair[2], second[i][2])}
	end

	return result
end

--- Сборная кисть: части пальцев из разных пресетов (index - номер сегмента).
local function Compose(base, overrides)
	local result = {}

	for i, pair in ipairs(base) do
		result[i] = overrides[i] or pair
	end

	return result
end

-- Кулак - пальцы из «палец вверх», большой из «указать»: там он лежит на среднем.
local fist = Compose(FINGER_POSER.thumbsUp, {FINGER_POSER.point[1], FINGER_POSER.point[2], FINGER_POSER.point[3]})

local twoFingers = Compose(fist, {
	[4] = {10, 31.3}, [5] = FINGER_POSER.flat[5], [6] = FINGER_POSER.flat[6],
	[7] = {-8, 22.9}, [8] = FINGER_POSER.flat[8], [9] = FINGER_POSER.flat[9]
})

local HAND_SOURCES = {
	{id = "flat", label = "Ладонь", pairs = FINGER_POSER.flat},
	{id = "relaxed", label = "Расслабленная", pairs = Blend(FINGER_POSER.flat, fist, 0.35)},
	{id = "grip", label = "Хват", pairs = Blend(FINGER_POSER.flat, fist, 0.6)},
	{id = "fist", label = "Кулак", pairs = fist},
	{id = "point", label = "Указать", pairs = FINGER_POSER.point},
	{id = "thumbsUp", label = "Палец вверх", pairs = FINGER_POSER.thumbsUp},
	{id = "two", label = "Два пальца", pairs = twoFingers}
}

S.HAND_PRESETS = {}

for _, source in ipairs(HAND_SOURCES) do
	local angles = {}

	for i, pair in ipairs(source.pairs) do
		local spread, curl = math.Round(pair[1], ANGLE_DECIMALS), math.Round(pair[2], ANGLE_DECIMALS)

		-- Сегменты 1-3 - большой палец.
		angles[i] = i <= 3 and {curl, spread, 0} or {spread, curl, 0}
	end

	S.HAND_PRESETS[#S.HAND_PRESETS + 1] = {id = source.id, label = source.label, angles = angles}
end

--- {полное имя кости = {p, y, r}} пресета для руки side ("L" / "R").
function S.GetPresetAngles(preset, side)
	local result = {}

	for i, segment in ipairs(S.FINGER_SEGMENTS) do
		result["ValveBiped.Bip01_" .. side .. "_" .. segment] = preset.angles[i]
	end

	return result
end


function S.MirrorBoneName(name)
 local side,part=name:match("^ValveBiped%.Bip01_([LR])_(.+)$")
 return side and "ValveBiped.Bip01_"..(side=="L" and "R" or "L").."_"..part or name
end
local function rotation(matrix)
 local result=Matrix()
 for r=1,3 do for c=1,3 do result:SetField(r,c,matrix:GetField(r,c)) end end
 return result
end
local function deltaMatrix(value)
 local delta=Matrix();delta:SetAngles(Angle(unpack(value.a)));delta:SetTranslation(Vector(unpack(value.p)));return delta
end
local function transform(matrix,name)
 local a,p=matrix:GetAngles(),matrix:GetTranslation()
 return S.Transform({a={math.NormalizeAngle(a.p),math.NormalizeAngle(a.y),math.NormalizeAngle(a.r)},p={p.x,p.y,p.z}},S.BonePositionLimit(name))
end
-- Same geometric reflection as measured Pose Maker axes, using this model's
-- bind matrices. Matrix conjugation also handles swapped/nonparallel L/R axes;
-- fixed Euler signs cannot do that. Only authored offsets are reflected.
function S.MirrorBoneDelta(rig,source,target,value)
 local a,b=rig.names[source],rig.names[target]
 if a==nil or b==nil then return end
 local reflect=Matrix();reflect:SetField(2,2,-1)
 local basis=rotation(rig.bones[b].bind):GetInverse()*reflect*rotation(rig.bones[a].bind)
 local mirrored=basis*deltaMatrix(value)*basis:GetInverse()
 return transform(mirrored,target)
end
-- Live symmetry reflects only this edit, never the previous opposite-side
-- result. Use the sampled base axes: a bent/asymmetric base must not silently
-- become a different pose when symmetry is enabled.
function S.MirrorEditedBones(reference,clip,bones,edited)
 local result=table.Copy(bones);local pairsToMirror,seen={},{}
 for _,name in ipairs(edited or {}) do
  local target=S.MirrorBoneName(name)
  if name~=target and not seen[name] and S.EditableBone(clip,name) and S.EditableBone(clip,target) then
   pairsToMirror[#pairsToMirror+1]={name,target};seen[name]=true;seen[target]=true
  end
 end
 if #pairsToMirror==0 then return result,nil,0,0 end
 if not reference or not reference.rig then return nil,"Симметрия: скелет ещё загружается. Повторите через секунду." end
 local rig=reference.rig;local baseRig={names=rig.names,bones={}};local world={}
 for i=0,rig.count-1 do
  local bone=rig.bones[i];local pose=reference.locals[bone.name] or bone.localBind
  local parent=bone.parent>=0 and world[bone.parent] or Matrix()
  if pose and parent then world[i]=parent*pose;baseRig.bones[i]={bind=world[i]} end
 end
 local count,skipped=0,0
 for _,pair in ipairs(pairsToMirror) do
  local name,target=pair[1],pair[2];local a,b=rig.names[name],rig.names[target]
  if a~=nil and b~=nil and baseRig.bones[a] and baseRig.bones[b] then
   local value=bones[name]
   if value then
    local mirrored=S.MirrorBoneDelta(baseRig,name,target,value)
    if not mirrored then return nil,"Симметрия: смещение парной кости превышает лимит. Уменьшите смещение." end
    result[target]=mirrored
   else result[target]=nil end
   count=count+1
  else skipped=skipped+1 end
 end
 return result,nil,count,skipped
end
local function descendant(rig,index,root)
 while index>=0 do if index==root then return true end;index=rig.bones[index].parent end
 return false
end
function S.MirrorPoseBones(reference,clip,bones,selected)
 local rig=reference and reference.rig
 if not rig then return nil,"Скелет модели ещё не готов." end
 local root=selected and rig.names[selected]
 if selected and (root==nil or not S.EditableBone(clip,selected)) then return nil,"Выберите кость тела или кисти." end
 local result=table.Copy(bones);local changed,skipped=0,0
 for i=0,rig.count-1 do
  local name=rig.bones[i].name;local target=S.MirrorBoneName(name)
  if S.EditableBone(clip,name) and (not root or descendant(rig,i,root)) then
   if rig.names[target]~=nil and S.EditableBone(clip,target) then
    local value=bones[name]
    if value then
     local mirrored=S.MirrorBoneDelta(rig,name,target,value)
     if not mirrored then return nil,"Зеркальное смещение выходит за пределы формата позы. Уменьшите смещение кости." end
     result[target]=mirrored;changed=changed+1
    elseif bones[target] then result[target]=nil;changed=changed+1 end
   elseif bones[name] then skipped=skipped+1 end
  end
 end
 if changed==0 then return nil,"В выбранной области нет правок с доступной парной костью." end
 return result,nil,changed,skipped
end
-- Recovered SolvePreset equation: desired = reference * preset;
-- v3 playback composes base * delta, so delta = inverse(base) * desired.
-- Read the actual source model/base; never manipulate the preview or player.
function S.ApplyHandPreset(reference,clip,bones,presetID,sides)
 local preset;for _,value in ipairs(S.HAND_PRESETS) do if value.id==presetID then preset=value;break end end
 if not preset or not reference or not reference.rig then return nil,"Пресет или скелет недоступен." end
 local result=table.Copy(bones);local changed,skipped=0,0;local rig=reference.rig;local edited={}
 for _,side in ipairs(sides or {}) do
  if side~="L" and side~="R" then return nil,"Неизвестная кисть." end
  for name,a in pairs(S.GetPresetAngles(preset,side)) do
   local index=rig.names[name];local base=reference.locals[name]
   if index~=nil and base and S.EditableBone(clip,name) then
    local desired=rotation(rig.bones[index].localBind);local presetRotation=Matrix();presetRotation:SetAngles(Angle(unpack(a)))
    local solved=rotation(base):GetInverse()*desired*presetRotation
    local angle=solved:GetAngles();local value=table.Copy(bones[name] or S.Identity())
    value.a={math.NormalizeAngle(angle.p),math.NormalizeAngle(angle.y),math.NormalizeAngle(angle.r)}
    result[name]=S.Transform(value,S.BonePositionLimit(name));if not result[name] then return nil,"Пресет выходит за пределы формата позы." end
    changed=changed+1;edited[#edited+1]=name
   else skipped=skipped+1 end
  end
 end
 if changed==0 then return nil,"В этой модели нет доступных костей пальцев выбранной кисти." end
 return result,nil,changed,skipped,edited
end
local hinges={Forearm={parent="UpperArm",child="Hand",label="Локоть",max=150},Calf={parent="Thigh",child="Foot",label="Колено",max=150}}
function S.HingeGuidance(reference,bones,name)
 local side,part=(name or ""):match("^ValveBiped%.Bip01_([LR])_(.+)$");local info=hinges[part]
 if not info or not reference then return end
 local rig=reference.rig;local world={}
 for i=0,rig.count-1 do
  local b=rig.bones[i];local pose=reference.locals[b.name]
  if pose then
   if bones[b.name] then pose=pose*deltaMatrix(bones[b.name]) end
   local parent
   if b.parent>=0 then parent=world[b.parent] else parent=Matrix() end
   if parent then world[i]=parent*pose end
  end
 end
 local prefix="ValveBiped.Bip01_"..side.."_"
 local a,j,b=world[rig.names[prefix..info.parent]],world[rig.names[name]],world[rig.names[prefix..info.child]]
 if not a or not j or not b then return end
 local upper,lower=j:GetTranslation()-a:GetTranslation(),b:GetTranslation()-j:GetTranslation()
 if upper:Length()<.01 or lower:Length()<.01 then return end
 local bend=math.deg(math.acos(math.Clamp(upper:GetNormalized():Dot(lower:GetNormalized()),-1,1)))
 return {label=info.label,degrees=bend,max=info.max,outside=bend>info.max}
end
