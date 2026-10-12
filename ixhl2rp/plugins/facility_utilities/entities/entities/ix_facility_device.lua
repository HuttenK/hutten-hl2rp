ENT.Type="anim"
ENT.Base="base_anim"
ENT.RenderGroup=RENDERGROUP_BOTH
ENT.PrintName="Facility equipment"
ENT.Category="Foundation / Инфраструктура"
ENT.Spawnable=false
ENT.AdminOnly=true
ENT.bNoPersist=true
if SERVER then
 function ENT:Initialize()
  local def=ix.Facility.kinds[self.FacilityKind];if not def then self:Remove();return end
  self:SetModel(def.model);self:SetUseType(SIMPLE_USE)
  if self.FacilityKind=="panel" then self:SetSolid(SOLID_NONE);self:SetMoveType(MOVETYPE_NONE)
  else
   self:PhysicsInit(SOLID_VPHYSICS);self:SetSolid(SOLID_VPHYSICS);self:SetMoveType(MOVETYPE_VPHYSICS)
   local ph=self:GetPhysicsObject();if IsValid(ph) then
    local source=self.FacilityKind=="generator" or self.FacilityKind=="battery"
    ph:EnableMotion(source)
    if source then ph:SetMass(self.FacilityKind=="battery" and 8 or 18);ph:Wake() end
   end
  end
  local plugin=ix.plugin.list.facility_utilities
  if not plugin or not plugin:RegisterDevice(self,self.FacilityKind) then self:Remove() end
 end
 function ENT:Use(p)
  if (self.nextUse or 0)>CurTime() then return end;self.nextUse=CurTime()+.5
  local P=ix.plugin.list.facility_utilities;if P then P:UseDevice(p,self) end
 end
 function ENT:OnRemove() local P=ix.plugin.list.facility_utilities;if P then P:DeviceRemoved(self) end end
 function ENT:SpawnFunction(p,tr)
  if not IsValid(p) or not p:IsAdmin() then return end
  local P=ix.plugin.list.facility_utilities;if not P then return end
  local ok,msg,id=P:Place(p,self.FacilityKind,tr)
  p:Notify(msg);local d=id and P.store.devices[id];return d and d.entity
 end
else
 function ENT:Initialize()
  if self.FacilityKind=="panel" then self:SetRenderBounds(Vector(-128,-128,-128),Vector(128,128,128)) end
 end
 function ENT:Draw(flags)
  if self.FacilityKind~="panel" then self:DrawModel(flags) end
 end
 -- Screens and indicators emit light; the equipment casing does not.
 function ENT:DrawTranslucent()
  if ix.CCTV and ix.CCTV.rendering or EyePos():DistToSqr(self:GetPos())>600^2 then return end
  local F=ix.Facility
  if F.IsScreen(self) then
   local N=ix.FoundationNet;if not N or not self:GetNW2Bool("ixFacilityPowered",false) then return end
   local pos,a,scale=F.PanelGeometry(self)
   cam.Start3D2D(pos,a,scale)
   local ok,err=xpcall(function()
    if N.DrawSurface(self) then return end
    surface.SetDrawColor(5,16,22);surface.DrawRect(0,0,1920,1120)
    draw.SimpleText(self:GetNW2String("ixFacilityName","SCiPNET / ИНФРАСТРУКТУРА"),"FoundationTitle",960,450,Color(92,229,201),TEXT_ALIGN_CENTER)
    draw.SimpleText("[ E ]  ПРИЛОЖИТЕ КЛЮЧ-КАРТУ","FoundationText",960,580,color_white,TEXT_ALIGN_CENTER)
   end,debug.traceback)
   cam.End3D2D();if not ok and not self.screenError then self.screenError=true;ErrorNoHalt(err.."\n") end
  elseif F.Hardware and EyePos():DistToSqr(self:GetPos())<180^2 then
   F.Hardware.DrawDevicePlate(self,self.FacilityKind)
  end
 end
end
