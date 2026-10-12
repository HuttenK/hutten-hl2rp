local P,B=PLUGIN,ix.bodycams
B.models=B.models or {}
local lamp=Material("sprites/light_glow02_add")
local function remove(p)
 if IsValid(B.models[p]) then B.models[p]:Remove() end
 B.models[p]=nil
end
-- Bone matrices are world-space. This accessory follows the current model's
-- actual head instead of a model-specific fixed height.
-- https://wiki.facepunch.com/gmod/Entity:GetBoneMatrix
function P:PostPlayerDraw(p)
 if p:GetNW2Int("ixHelmetCamera",0)==0 or not p:Alive() or (ix.CCTV and ix.CCTV.captureOwner==p) then return end
 local head,headAngles=B.HeadFrame(p,true)
 if not head then return end
 local m=B.models[p]
 if IsValid(m) and m:GetModel()~=B.model then remove(p);m=nil end
 if not IsValid(m) then
  m=ClientsideModel(B.model,RENDERGROUP_OPAQUE)
  if not IsValid(m) then return end
  m:SetNoDraw(true);m:SetModelScale(B.mount.scale,0);B.models[p]=m
 end
 local origin,angle,light=B.MountTransform(head,headAngles)
 m:SetPos(origin);m:SetAngles(angle);m:SetupBones();m:DrawModel()
 render.SetMaterial(lamp)
 render.DrawSprite(light,.65,.65,p:GetNW2Bool("ixHelmetCameraOn",false) and Color(238,55,64) or Color(70,83,89))
end
function P:Think()
 if (self.nextBodycamClean or 0)>RealTime() then return end;self.nextBodycamClean=RealTime()+1
 for p in pairs(B.models) do
  if not IsValid(p) or not p:Alive() or p:GetNW2Int("ixHelmetCamera",0)==0 or p:IsDormant() then remove(p) end
 end
end
function P:PopulateItemTooltip(tooltip,item)
 if not B.Compatible(item) or not B.Attached(item) then return end
 local row=tooltip:AddRow("helmetCamera")
 row:SetText(B.Enabled(item) and "Камера: ВКЛ · передаёт только на надетом шлеме" or "Камера: ВЫКЛ")
 row:SizeToContents()
end
function P:OnUnload()
 for p in pairs(B.models) do remove(p) end
end
