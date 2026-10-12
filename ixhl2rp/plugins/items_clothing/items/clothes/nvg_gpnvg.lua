ITEM.name="ПНВ GPNVG"
ITEM.description="Прибор ночного видения. Занимает слот очков. Переключение через меню предмета."
ITEM.model="models/arctic_nvgs/nvg_gpnvg.mdl"
ITEM.width=1; ITEM.height=1; ITEM.equip_inv="glasses"; ITEM.equip_slot=nil
ITEM.nvgType="nvg_gpnvg"
ITEM.functions.toggleNVG={name="Поднять / опустить ПНВ",icon="icon16/lightbulb.png",
 OnCanRun=function(item) return item:IsEquipped() end,
 OnRun=function(item) if ix.field.NVG(item.player)==item then ix.field.Animate(item.player,"toggleNVG") end; return false end}
function ITEM:OnEquipped(p) ix.meta.ItemCloth.OnEquipped(self,p); ix.field.SetNVG(p,self,true) end
function ITEM:OnUnequipped(p) ix.meta.ItemCloth.OnUnequipped(self,p); ix.field.SetNVG(p,self,false) end
