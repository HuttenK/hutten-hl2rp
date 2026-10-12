ITEM.name = "Канистра огнесмеси"
ITEM.description = "Топливо для M2 и Flammenwerfer 35. Возьмите огнемёт в руки и выберите «Заправить» у канистры. Неиспользованный остаток сохраняется."
ITEM.model = "models/props_junk/gascan001a.mdl"
ITEM.width = 2
ITEM.height = 2
ITEM.category = "Снаряжение"
ITEM.noBusiness = true
ITEM:AddData("fuel", {Transmit=ix.transmit.owner})
function ITEM:OnInstanced(created) if created then self:SetData("fuel",1000) end end
function ITEM:GetFuel() return math.Clamp(tonumber(self:GetData("fuel",1000)) or 0,0,1000) end
function ITEM:RefuelWeapon()
 local client=self.player
 if not IsValid(client) or not client:Alive() or not client:GetCharacter() or IsValid(self:GetEntity()) then return end
 local owned=false
 for _,item in pairs(client:GetItems()) do if item==self then owned=true;break end end
 if not owned or self:GetFuel()<=0 then return end
 local weapon=client:GetActiveWeapon()
 if not IsValid(weapon) or weapon:GetOwner()~=client then return end
 if weapon.ARC9CODWW2UnlimitedFuel then return end
 local class=weapon:GetClass()
 if class~="arc9_codww2_flamethrower" and class~="arc9_codww2_flammenwerfer35" then return end
 if client:KeyDown(IN_ATTACK) or weapon:Clip1()>=1000 then return end
 -- The ARC9 inventory binding lives on the server. Do not hide the client
 -- action merely because its SWEP has no server-only ixItem/ready fields.
 if CLIENT then return weapon end
 if not weapon.ixInventoryReady then return end
 local item=weapon.ixItem
 if not item or not item.isFlamethrower or not item:IsEquipped() then return end
 return weapon
end
ITEM.functions.refuel={
 name="Заправить",icon="icon16/arrow_refresh.png",
 OnCanRun=function(item) return IsValid(item:RefuelWeapon()) end,
 OnRun=function(item)
  local weapon=item:RefuelWeapon();if not IsValid(weapon) then return false end
  local client=item.player
  if CurTime()<(client.ixFlameRefuelAt or 0) then return false end
  client.ixFlameRefuelAt=CurTime()+1
  local before=math.max(0,weapon:Clip1());local transfer=math.min(1000-before,item:GetFuel())
  if transfer<=0 then return false end
  weapon:SetClip1(before+transfer);weapon:SetLoadedRounds(before+transfer)
  weapon.ixItem:SetData("ammo",before+transfer)
  item:SetData("fuel",item:GetFuel()-transfer)
  client:Notify("Заправлено: "..transfer..". Бак: "..(before+transfer).." / 1000.")
  client:EmitSound("items/ammo_pickup.wav",60)
  if item:GetFuel()<=0 then item:Remove() end
  return false
 end
}
if CLIENT then
 function ITEM:PopulateTooltip(tooltip)
  local row=tooltip:AddRowAfter("name");row:SetText("Огнесмесь: "..self:GetFuel().." / 1000")
 end
end
