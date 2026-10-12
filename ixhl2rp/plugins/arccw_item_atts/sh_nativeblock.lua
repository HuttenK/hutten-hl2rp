local PLUGIN = PLUGIN
-- Guard real weapon instances before predicted input/HUD creation. Preview
-- carriers are client models and deliberately keep their customization state.
local function CloseNative(weapon)
 if weapon.GetCustomize and weapon:GetCustomize() then weapon:SetCustomize(false) end
 weapon.CustomizeDelta = 0
 if CLIENT and IsValid(weapon.CustomizeHUD) then
  weapon.CustomizeHUD:SetVisible(false)
  weapon:RemoveCustomizeHUD()
 end
end
function PLUGIN:BlockNativeCustomization(weapon)
 if not IsValid(weapon) or not weapon:IsWeapon() or not weapon.ARC9 then return end
 if not weapon.ixNativeCustomizationBlocked then
  weapon.ixNativeCustomizationBlocked = true
  weapon.ToggleCustomize = CloseNative
  if CLIENT then
   weapon.CreateCustomizeHUD = CloseNative
   weapon.DrawCustomizeHUD = CloseNative
  end
 end
 CloseNative(weapon)
end
if CLIENT then
 function PLUGIN:PreDrawViewModel(viewModel, client, weapon)
  self:BlockNativeCustomization(weapon)
 end
end
