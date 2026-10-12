ENT.Type="anim"
ENT.Base="base_anim"
ENT.PrintName="Foundation SCiPNet Terminal"
ENT.Category="Foundation"
ENT.Spawnable=true
ENT.AdminOnly=true
ENT.Model="models/props/cs_office/TV_plasma.mdl"
if SERVER then
 function ENT:Initialize()
  self:SetModel(self.Model);self:PhysicsInit(SOLID_VPHYSICS);self:SetSolid(SOLID_VPHYSICS);self:SetUseType(SIMPLE_USE)
  local physics=self:GetPhysicsObject();if IsValid(physics) then physics:EnableMotion(false) end
 end
 function ENT:Use(p)
  local plugin=ix.plugin.list.foundation_network
  if plugin and IsValid(p) and p:IsPlayer() then plugin:Open(p,self) end
 end
 function ENT:SpawnFunction(p,tr,class)
  if not tr.Hit then return end
  local ent=ents.Create(class);ent:SetPos(tr.HitPos+tr.HitNormal*8);ent:SetAngles(Angle(0,p:EyeAngles().y+180,0));ent:Spawn();return ent
 end
else
 function ENT:Draw()
  self:DrawModel()
  local blackout=ix.plugin.list.blackout
  if EyePos():DistToSqr(self:GetPos())>500^2 or (blackout and blackout:IsEntityBlackedOut(self)) then return end
  local N=ix.FoundationNet
  local pos,a=N.ScreenGeometry(self)
  local panel=ix.gui.foundationNetwork
  local active=IsValid(panel) and panel.entity==self and panel.surfaceReady
  cam.Start3D2D(pos,a,active and N.screenScale or .07)
  local ok,err=xpcall(function()
  if active and N.DrawSurface(self) then return end
  surface.SetDrawColor(12,13,15);surface.DrawRect(0,0,800,466)
  surface.SetDrawColor(185,48,59);surface.DrawRect(30,66,740,2)
  draw.SimpleText("SCiPNet // FOUNDATION","FoundationTitle",32,25,Color(224,224,215))
  if ix.Fieldlink and ix.Fieldlink.DrawSCP then ix.Fieldlink.DrawSCP(330,110,130,Color(180,183,180)) end
  draw.SimpleText(self.PublicTerminal and "ИНФОРМАЦИЯ ДЛЯ КЛАССА D" or "ВНУТРЕННЯЯ СЕТЬ ФОНДА","FoundationTitle",400,285,color_white,TEXT_ALIGN_CENTER)
  draw.SimpleText(self.PublicTerminal and "[ E ]  ОТКРЫТЬ БИБЛИОТЕКУ / БЕЗ КАРТЫ" or "[ E ]  ДОСТУП ПО КЛЮЧ-КАРТЕ","FoundationText",400,350,Color(205,175,107),TEXT_ALIGN_CENTER)
  draw.SimpleText("SECURE. CONTAIN. PROTECT.","FoundationMono",32,425,Color(145,148,147))
  end,debug.traceback)
  cam.End3D2D()
  if not ok and not self.screenError then self.screenError=true;ErrorNoHalt(err.."\n") end
 end
end
