ENT.Type="anim"
ENT.Base="ix_facility_device"
ENT.PrintName="Душ деконтаминации"
ENT.Category="Foundation / Инфраструктура"
ENT.Spawnable=true
ENT.AdminOnly=true
ENT.FacilityKind="decon_shower"
if SERVER then
 function ENT:Use(p) local plugin=ix.plugin.list.decontamination;if plugin then plugin:Use(p,self) end end
else
 function ENT:Draw() if ix.Decon then ix.Decon.Draw(self) else self:DrawModel() end end
end
