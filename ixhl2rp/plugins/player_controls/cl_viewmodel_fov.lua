local K=ix.PlayerControls
-- Restore our previous instance override before a Lua refresh installs another.
if K.RestoreWeaponFOV then K.RestoreWeaponFOV() end
local active,thirdPerson

function K.AdjustWeaponFOV(weapon,value)
 if not isnumber(value) or value~=value or math.abs(value)==math.huge then return value end
 local p=LocalPlayer()
 if thirdPerson or not K.CanAdjustFOV(p) or not IsValid(weapon) or weapon:GetOwner()~=p
  or p:GetActiveWeapon()~=weapon or weapon.GetPDAEquipped then return value end
 if weapon.GetCustomize and weapon:GetCustomize() then return value end
 if weapon.ArcCW and ArcCW and weapon.GetState and weapon:GetState()==ArcCW.STATE_CUSTOMIZE then return value end
 -- Keep the user's weapon perspective adjustment during ADS as well. The
 -- weapon still supplies its own base/sight FOV and optical world zoom.
 local offset=K.FOVPreferenceOffset()
 if offset==0 then return value end
 return math.Clamp(value+offset,1,150)
end

function K.RestoreWeaponFOV()
 local state=active; active=nil
 if not state or not IsValid(state.weapon) then return end
 local weapon=state.weapon
 if state.wrapper and weapon.GetViewModelFOV==state.wrapper then weapon.GetViewModelFOV=state.originalOwn end
 if state.applied and weapon.ViewModelFOV==state.applied then weapon.ViewModelFOV=state.restore end
end

function K.UpdateWeaponFOV(p,drawViewer)
 if drawViewer~=nil then thirdPerson=drawViewer end
 local weapon=IsValid(p) and p:GetActiveWeapon()
 if not K.CanAdjustFOV(p) or thirdPerson or not IsValid(weapon) or weapon:GetOwner()~=p or weapon.GetPDAEquipped then
  K.RestoreWeaponFOV(); return
 end
 if active and active.weapon~=weapon then K.RestoreWeaponFOV() end
 if not active then
  local state={weapon=weapon}; active=state
  local own=weapon:GetTable()
  if isfunction(weapon.GetViewModelFOV) then
   -- ARC9 renders the weapon, hands and attachments through this getter. A
   -- ViewModelFOV field alone is overwritten by its own drawing code.
   local original=weapon.GetViewModelFOV
   state.originalOwn=rawget(own,"GetViewModelFOV")
   state.wrapper=function(self,...)
    -- Protect ARC9's original getter during a transient invalid-owner frame.
    local owner=self:GetOwner()
    if not IsValid(owner) or owner~=LocalPlayer() then return isnumber(self.ViewModelFOV) and self.ViewModelFOV or 70 end
    return K.AdjustWeaponFOV(self,original(self,...))
   end
   weapon.GetViewModelFOV=state.wrapper
  else
   state.base=weapon.ViewModelFOV; state.restore=rawget(own,"ViewModelFOV")
  end
 end
 if active.wrapper then return end
 local current=weapon.ViewModelFOV
 -- A weapon may rewrite its native FOV for a sight. Never feed our previous
 -- offset back into the next frame, and retain any new weapon-owned value.
 if current~=active.applied then active.base=current; active.restore=rawget(weapon:GetTable(),"ViewModelFOV") end
 if not isnumber(active.base) then return end
 active.applied=K.AdjustWeaponFOV(weapon,active.base)
 weapon.ViewModelFOV=active.applied
end

hook.Add("Think","ixPlayerWeaponFOV",function() K.UpdateWeaponFOV(LocalPlayer()) end)
hook.Add("ShutDown","ixPlayerWeaponFOV",K.RestoreWeaponFOV)
