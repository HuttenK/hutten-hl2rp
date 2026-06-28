ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Сканер контрабанды"
ENT.Author = "Claude"
ENT.Category = "Helix"
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_BOTH -- неон рисуется как полупрозрачное свечение

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "ScanWidth")
	self:NetworkVar("Float", 1, "ScanHeight")
	self:NetworkVar("Float", 2, "ScanDepth")
	self:NetworkVar("Bool", 0, "Alarming")
end
