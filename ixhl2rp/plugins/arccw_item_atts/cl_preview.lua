local PLUGIN = PLUGIN
local function T(en,ru) return ix.Locale and ix.Locale.lang == "ru" and ru or en end
local red, white, muted = Color(255,67,88), Color(232,220,221), Color(173,151,157)
-- Use the same explicit horizontal FOV/aspect as the panel camera. ToScreen
-- depends on the engine's global viewport and is unsuitable for this VGUI view.
function PLUGIN:ProjectPreviewPoint(pos,eye,angle,w,h,fov)
 local delta=pos-eye
 local depth=delta:Dot(angle:Forward())
 if depth<=1 then return nil end
 local scale=w/(2*math.tan(math.rad(fov*.5)))
 return w*.5+delta:Dot(angle:Right())*scale/depth,h*.5-delta:Dot(angle:Up())*scale/depth
end

-- A private client entity hosts ARC9's model assembly methods. Never copy the
-- live weapon's caches, network accessors, models, or inventory item reference.
function PLUGIN:CreatePreviewWeapon(source, tree)
 local definition = weapons.Get(source:GetClass())
 if not definition then return end
 local carrier = ClientsideModel(definition.WorldModel or definition.ViewModel, RENDERGROUP_OPAQUE)
 if not IsValid(carrier) then return end
 carrier:SetNoDraw(true)
 local ok, err = xpcall(function()
  table.Merge(carrier:GetTable(), table.Copy(definition))
  carrier.dt = {}
  carrier.NetworkVar = function(self, kind, index, name)
   name = isstring(index) and index or name
   local value = 0
   if kind == "Bool" then value = false elseif kind == "String" then value = ""
   elseif kind == "Vector" then value = Vector() elseif kind == "Angle" then value = Angle()
   elseif kind == "Entity" then value = NULL end
   self.dt[name] = value
   self["Get"..name] = function(s) return s.dt[name] end
   self["Set"..name] = function(s,v) s.dt[name] = v end
  end
  local noop = function() end
  carrier.SetNextPrimaryFire = noop; carrier.SetNextSecondaryFire = noop
  carrier.CreateFlashlights = noop; carrier.SendWeapon = noop; carrier.CallOnClient = noop
  carrier.PostModify = noop; carrier.EmitSound = noop
  carrier.GetOwner = function() return LocalPlayer() end
  carrier.GetClass = function() return source:GetClass() end
  local clip1,clip2 = source:Clip1(),source:Clip2()
  carrier.Clip1 = function() return clip1 end; carrier.Clip2 = function() return clip2 end
  carrier.Ammo1 = function() return 0 end; carrier.Ammo2 = function() return 0 end
  carrier.ShouldLOD = function() return 0 end
  carrier.ShouldTPIK = function() return false end
  carrier.GetWM = function(s) return s.CModel and s.CModel[1] end
  carrier.GetVM = carrier.GetWM
  -- Include weapon-specific EFT accessors such as PKM belt counters.
  local setup = definition.SetupDataTables or weapons.GetStored("arc9_base").SetupDataTables
  setup(carrier)
  carrier:SetLoadedRounds(math.max(0,clip1)); carrier:SetCustomize(true)
  carrier.CustomizeDelta = 1
  carrier:DoInvalidateCache()
  carrier:BuildSubAttachments(table.Copy(tree or carrier.Attachments))
  carrier:DoInvalidateCache()
  carrier:SetupModel(true,0,true)
  if not carrier.CModel or not IsValid(carrier.CModel[1]) then error("No assembled preview model") end
 end,debug.traceback)
 if not ok then self:RemovePreviewWeapon(carrier); ErrorNoHalt("[Gunsmith preview] "..tostring(err).."\n"); return end
 return carrier
end

function PLUGIN:RemovePreviewWeapon(carrier)
 if not IsValid(carrier) then return end
 -- Includes charm and auxiliary models created before a renderer error.
 for i=#(ARC9.CSModelPile or {}),1,-1 do
  local entry=ARC9.CSModelPile[i]
  if entry.Weapon==carrier then SafeRemoveEntity(entry.Model); table.remove(ARC9.CSModelPile,i) end
 end
 carrier:Remove()
end

local PANEL={}
function PANEL:Init()
 self.yaw=90; self.pitch=8; self.zoom=1; self.markers={}
 self:SetMouseInputEnabled(true)
 self.compare=self:Add("DButton"); self.compare:SetText(T("HOLD: CURRENT","УДЕРЖИВАТЬ: ТЕКУЩЕЕ"))
 self.compare:SetFont("ixWorkshopSmall"); self.compare:SetTextColor(white)
 self.compare.Paint=function(p,w,h) surface.SetDrawColor(p:IsDown() and Color(95,24,40) or Color(32,18,25)); surface.DrawRect(0,0,w,h) end
 self.reset=self:Add("DButton"); self.reset:SetText(T("RESET VIEW","СБРОС ВИДА")); self.reset:SetFont("ixWorkshopSmall")
 self.reset.DoClick=function() self.yaw=90; self.pitch=8; self.zoom=1 end
end
function PANEL:PerformLayout(w,h)
 self.compare:SetPos(12,h-34); self.compare:SetSize(220,26)
 self.reset:SetPos(w-132,h-34); self.reset:SetSize(120,26)
end
function PANEL:ClearModels()
 PLUGIN:RemovePreviewWeapon(self.current); PLUGIN:RemovePreviewWeapon(self.candidate)
 self.current=nil; self.candidate=nil; self.failed=nil; self.markers={}
end
function PANEL:OnRemove() self:ClearModels() end
function PANEL:SetWeapon(data)
 self:ClearModels(); self.data=data; self.choice=nil; self.address=nil
 self.source=data and Entity(data.weapon or -1)
 if not IsValid(self.source) or not self.source.ARC9 or not data.tree then return end
 self.current=PLUGIN:CreatePreviewWeapon(self.source,data.tree)
 if IsValid(self.current) then
  local mn,mx=self.current.CModel[1]:GetRenderBounds()
  self.center=(mn+mx)*0.5
  self.radius=math.max((mx-mn):Length()*0.5,8)
  if self.current.CustomizeRotateAnchor then
   self.center=Vector(self.current.CustomizeRotateAnchor)
   self.radius=math.max(8,math.abs((self.current.CustomizePos or Vector(0,40,0)).y)*0.3)
  end
 end
end
function PANEL:Select(address,id,tree)
 PLUGIN:RemovePreviewWeapon(self.candidate); self.candidate=nil
 self.address=address; self.choice=id
 if id~=nil and tree and IsValid(self.current) then
  self.candidate=PLUGIN:CreatePreviewWeapon(self.source,tree)
 end
end
function PANEL:OnMousePressed(code)
 if code~=MOUSE_LEFT then return end
 local x,y=self:CursorPos()
 for _,m in ipairs(self.markers) do
  if math.abs(m.x-x)<13 and math.abs(m.y-y)<13 then if self.OnSelectSlot then self:OnSelectSlot(m.address) end; return end
 end
 self.drag={gui.MousePos()}; self:MouseCapture(true)
end
function PANEL:OnMouseReleased() self.drag=nil; self:MouseCapture(false) end
function PANEL:OnMouseWheeled(delta) self.zoom=math.Clamp(self.zoom-delta*0.1,0.2,2.2); return true end
function PANEL:Think()
 if self.drag then
  local x,y=gui.MousePos(); self.yaw=self.yaw+(x-self.drag[1])*0.45
  self.pitch=math.Clamp(self.pitch+(y-self.drag[2])*0.35,-75,75); self.drag={x,y}
 end
end
function PANEL:Paint(w,h)
 surface.SetDrawColor(8,8,12,255); surface.DrawRect(0,0,w,h)
 surface.SetDrawColor(55,30,40,120)
 for x=0,w,48 do surface.DrawLine(x,0,x,h) end
 for y=0,h,48 do surface.DrawLine(0,y,w,y) end
 self.markers={}
 local weapon=IsValid(self.candidate) and not self.compare:IsDown() and self.candidate or self.current
 if not IsValid(weapon) or self.failed==weapon then
  draw.SimpleText(T("3D preview unavailable for this weapon","3D-осмотр этого оружия недоступен"),"ixWorkshopBody",w/2,h/2,muted,1,1); return
 end
 local sx,sy=self:LocalToScreen(0,0)
 local center=self.center or Vector()
 local angle=Angle(self.pitch,self.yaw,0)
 local distance=(self.radius or 32)*3.3*self.zoom*math.max(1,w/math.max(h,1))
 local eye=center-angle:Forward()*distance
 local oldPreset=ARC9.PresetCam
 ARC9.PresetCam=true
 cam.Start({type="3D",origin=eye,angles=angle,fov=35,aspect=w/h,x=sx,y=sy,w=w,h=h,znear=1,zfar=4096,subrect=true})
 render.ClearDepth()
 render.SuppressEngineLighting(true); render.SetLightingOrigin(center)
 render.ResetModelLighting(0.55,0.55,0.6)
 render.SetModelLighting(0,1,0.85,0.8); render.SetModelLighting(4,0.6,0.65,0.8)
 local ok,err=xpcall(function()
  weapon:DrawCustomModel(true,Vector(),Angle())
  -- Structural paths keep original slot identities across staged address changes.
  do
   for _,slot in ipairs(self.data.slots or {}) do
    local full
    local nodes=weapon.Attachments
    for _,index in ipairs(slot.path or {}) do full=nodes and nodes[index]; nodes=full and full.SubAttachments end
    if not slot.path then full=weapon:LocateSlotFromAddress(slot.address) end
    if full and full.Pos and full.Bone and not full.Hidden and weapon.CModel[1]:LookupBone(full.Bone) then
     local pos,attang,offset=weapon:GetAttachmentPos(full,true,false,true,Vector(),Angle())
     local att=weapon:GetFinalAttTable(full)
     offset=(offset or Vector())+(att.IconOffset or att.Icon_Offset or Vector())
     local icon=pos+attang:Forward()*offset.x+attang:Right()*offset.y+attang:Up()*offset.z
     local px,py=PLUGIN:ProjectPreviewPoint(icon,eye,angle,w,h,35)
     local ax,ay=PLUGIN:ProjectPreviewPoint(pos,eye,angle,w,h,35)
     if px and px>14 and px<w-14 and py>42 and py<h-42 then
      self.markers[#self.markers+1]={x=px,y=py,ax=ax,ay=ay,address=slot.address,name=slot.name}
     end
    end
   end
  end
 end,debug.traceback)
 render.SetColorModulation(1,1,1); render.SetBlend(1); render.MaterialOverride(nil)
 render.SuppressEngineLighting(false); cam.End3D(); ARC9.PresetCam=oldPreset
 if not ok then self.failed=weapon; ErrorNoHalt("[Gunsmith preview] "..tostring(err).."\n") end
 local mx,my=self:CursorPos()
 for _,m in ipairs(self.markers) do
  local hover=math.abs(mx-m.x)<13 and math.abs(my-m.y)<13
  surface.SetDrawColor(m.address==self.address and red or muted); surface.DrawOutlinedRect(m.x-9,m.y-9,18,18)
  if m.ax and m.ax>=0 and m.ax<=w and m.ay>=0 and m.ay<=h then surface.DrawLine(m.x,m.y,m.ax,m.ay); surface.DrawRect(m.ax-1,m.ay-1,3,3) end
  draw.SimpleText("+","ixWorkshopBody",m.x,m.y,white,1,1)
  if hover then draw.SimpleText((ARC9:GetPhrase(m.name) or m.name),"ixWorkshopBody",math.Clamp(m.x,100,w-100),m.y+18,white,1,0) end
 end
 local staged=weapon==self.candidate
 draw.SimpleText(staged and T("PREVIEW / NOT INSTALLED","ПРИМЕРКА / НЕ УСТАНОВЛЕНО") or T("CURRENT CONFIGURATION","ТЕКУЩАЯ КОНФИГУРАЦИЯ"),"ixWorkshopSmall",12,12,staged and red or muted)
 draw.SimpleText(T("DRAG: ROTATE   WHEEL: ZOOM","ПЕРЕТАЩИТЬ: ПОВОРОТ   КОЛЕСО: МАСШТАБ"),"ixWorkshopSmall",12,30,muted)
 if self.choice~=nil and not IsValid(self.candidate) then
  draw.SimpleText(self.waiting and T("Loading part preview…","Загрузка примерки…") or T("Part preview unavailable — current weapon shown","Примерка недоступна — показано текущее оружие"),"ixWorkshopSmall",12,50,red)
 end
end
vgui.Register("ixARC9AssemblyPreview",PANEL,"DPanel")
