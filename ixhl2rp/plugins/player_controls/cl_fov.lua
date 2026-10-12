local K=ix.PlayerControls
local desired=GetConVar("fov_desired")
local function native() return desired and desired:GetFloat() or 90 end
local default=math.Clamp(native(),75,150)
local function clean(value)
 value=tonumber(value)
 if not value or value~=value or math.abs(value)==math.huge then value=default end
 return math.Clamp(math.Round(value),75,150)
end
-- Remove the old console-writing implementation during Lua refresh as well.
cvars.RemoveChangeCallback("fov_desired","ixPlayerFOV")
hook.Remove("InitPostEntity","ixPlayerFOV")
ix.lang.AddTable("ru",{playerCamera="Камера",["option.playerFOV"]="Угол обзора (FOV)",
 ["option.playerFOV.desc"]="Угол обзора камеры и оружия от 75 до 150°. Применяется сразу. Прицелы сохраняют своё приближение."})
ix.lang.AddTable("en",{playerCamera="Camera",["option.playerFOV"]="Field of view (FOV)",
 ["option.playerFOV.desc"]="Camera FOV from 75 to 150°, with matching weapon perspective. Applies immediately; sights retain their zoom."})
ix.option.Add("playerFOV",ix.type.number,default,{category="playerCamera",min=75,max=150,decimals=0,
 OnChanged=function(_,value) local bounded=clean(value); if value~=bounded then ix.option.Set("playerFOV",bounded) end end})

function K.CanAdjustFOV(p)
 if not IsValid(p) or p~=LocalPlayer() or not p:Alive() or not p:GetCharacter()
  or p:InVehicle() or p:GetViewEntity()~=p or p:GetMoveType()==MOVETYPE_NOCLIP
  or p:GetLocalVar("knocked",false) or p:GetNetVar("ixObserve",false)
  or (ix.Downed and ix.Downed.Crawling(p)) or (p.IsPilotScanner and p:IsPilotScanner())
  or IsValid(ix.gui.intro) or IsValid(ix.gui.ending)
  or (IsValid(ix.gui.characterMenu) and ix.gui.characterMenu:IsVisible()) then return false end
 local ragdoll=p:GetLocalVar("ragdoll",0)
 if ragdoll and ragdoll~=0 or IsValid(p:GetRagdollEntity()) then return false end
 return true
end
function K.FOVOffset(p,weapon,current)
 local base=native()
 current=tonumber(current) or base
 local amount=1
 if IsValid(weapon) and weapon:GetOwner()==p then
  if weapon.ARC9 and weapon.GetSightAmount then amount=1-math.Clamp(weapon:GetSightAmount(),0,1)
  elseif weapon.ArcCW and weapon.GetSightDelta then amount=math.Clamp(weapon:GetSightDelta(),0,1)
  elseif p:KeyDown(IN_ATTACK2) or current<base-1 then amount=0 end
 elseif p:KeyDown(IN_ATTACK2) or current<base-1 then amount=0 end
 return K.FOVPreferenceOffset()*amount
end
function K.FOVPreferenceOffset()
 return clean(ix.option.Get("playerFOV",default))-native()
end
-- Called once on the completed CalcView result by Helix's hook dispatcher.
-- Do not compete with camera hooks or write the Lua-blocked fov_desired cvar.
function K.ApplyViewFOV(view,p,origin,angles,incoming)
 if not istable(view) then return view end
 if p==LocalPlayer() and K.UpdateWeaponFOV then K.UpdateWeaponFOV(p,view.drawviewer==true) end
 if not K.CanAdjustFOV(p) then return view end
 local current=tonumber(view.fov) or tonumber(incoming) or native()
 local result=table.Copy(view)
 result.fov=math.Clamp(current+K.FOVOffset(p,p:GetActiveWeapon(),current),1,150)
 return result
end
