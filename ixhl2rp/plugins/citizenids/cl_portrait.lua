local PANEL={}
function PANEL:Init()
 self:SetMouseInputEnabled(false)
end
function PANEL:SetPortrait(data,paper)
 self.paper=paper; self.snapshot=istable(data) and table.Copy(data) or nil
 if IsValid(self.model) then self.model:Remove() end
 if not self.snapshot or not self.snapshot.model or not util.IsValidModel(self.snapshot.model) then return end
 local model=self:Add("DModelPanel"); self.model=model
 model:SetMouseInputEnabled(false)
 model:SetModel(self.snapshot.model); model:SetAnimated(false)
 local entity=model:GetEntity()
 if not IsValid(entity) then model:Remove(); self.model=nil; return end
 entity:SetSkin(tonumber(self.snapshot.skin) or 0)
 for i=0,entity:GetNumBodyGroups()-1 do entity:SetBodygroup(i,tonumber((self.snapshot.bodygroups or {})[tostring(i)]) or 0) end
 entity:SetAngles(Angle(0,0,0))
 -- Player models often need the HL2MP activity, not sequence zero (bind pose).
 local sequence=entity:SelectWeightedSequence(ACT_HL2MP_IDLE)
 if not sequence or sequence<0 then
  for _,name in ipairs({"idle_all_01","idle_all","idle_unarmed","idle_passive","idle_subtle","idle"}) do
   local candidate=entity:LookupSequence(name)
   if candidate and candidate>=0 then sequence=candidate; break end
  end
 end
 if not sequence or sequence<0 then sequence=entity:SelectWeightedSequence(ACT_IDLE) end
 local function pose(ent)
  if sequence and sequence>=0 then ent:ResetSequence(sequence) end
  ent:SetCycle(.1); ent:SetPlaybackRate(0)
  ent:SetPoseParameter("head_pitch",0); ent:SetPoseParameter("head_yaw",0)
  ent:SetPoseParameter("aim_pitch",0); ent:SetPoseParameter("aim_yaw",0)
  ent:InvalidateBoneCache(); ent:SetupBones()
 end
 pose(entity)
 model:SetFOV(30)
 model:SetAmbientLight(Color(150,150,150)); model:SetDirectionalLight(BOX_FRONT,Color(230,223,213)); model:SetDirectionalLight(BOX_RIGHT,Color(130,125,125))
 model.LayoutEntity=function(panel,ent)
  -- Re-evaluate once the client model is render-ready; initial bone reads can be zero.
  pose(ent)
  local mins,maxs=ent:GetRenderBounds()
  local head=ent:LookupBone("ValveBiped.Bip01_Head1")
  local matrix=head and ent:GetBoneMatrix(head)
  local pos=matrix and matrix:GetTranslation()
  if not pos or pos.z<=mins.z+(maxs.z-mins.z)*.45 then
   pos=Vector(0,0,mins.z+(maxs.z-mins.z)*.88)
  end
  local focus=Vector(pos.x,pos.y,pos.z-3)
  panel:SetLookAt(focus); panel:SetCamPos(focus+Vector(40,0,0))
 end
 self:InvalidateLayout(true)
end
function PANEL:PerformLayout(w,h)
 -- A consistent 3:4 photo prevents tall document columns from zooming out to full body.
 local height=math.max(1,math.min(h-36,(w-14)*4/3))
 local width=height*3/4
 self.photoX=(w-width)/2; self.photoWidth=width; self.photoHeight=height
 if IsValid(self.model) then self.model:SetPos(self.photoX,7); self.model:SetSize(width,height) end

end
function PANEL:Paint(w,h)
 local paper=self.paper
 local x=(self.photoX or 7)-7; local width=(self.photoWidth or w-14)+14; local height=(self.photoHeight or h-36)+36
 surface.SetDrawColor(paper and Color(197,195,182) or Color(13,17,23)); surface.DrawRect(x,0,width,height)
 surface.SetDrawColor(paper and Color(103,105,94,110) or Color(197,55,77,100)); surface.DrawOutlinedRect(x,0,width,height)
 if not IsValid(self.model) then draw.SimpleText("ФОТО НЕ ЗАРЕГИСТРИРОВАНО","DermaDefault",w/2,height/2,Color(160,148,148),TEXT_ALIGN_CENTER) end
 local at=self.snapshot and tonumber(self.snapshot.registered)
 draw.SimpleText(at and os.date("%d.%m.%Y",at) or "ТРЕБУЕТСЯ РЕГИСТРАЦИЯ","DermaDefault",w/2,height-19,paper and Color(75,75,65) or Color(181,151,155),TEXT_ALIGN_CENTER)
end
vgui.Register("ixCredentialPortrait",PANEL,"DPanel")
