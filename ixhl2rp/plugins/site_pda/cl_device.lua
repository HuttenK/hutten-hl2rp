local F=ix.Fieldlink
-- Remove the old panel-capture hooks during Lua refresh; no global mouse-coordinate overrides.
for event,ids in pairs({Think={"ixPdaToggleKey","ixPdaDatafile"},CalcViewModelView={"ixPdaPose"},
 PostRender={"ixPdaDatafileScreen"},PreDrawViewModel={"ixPdaDatafileScreen"},
 GUIMousePressed={"ixPdaDatafileScreen","ixPdaBack"},GUIMouseReleased={"ixPdaDatafileScreen"},HUDPaint={"ixPdaDatafileCalib"}}) do
 for _,id in ipairs(ids) do hook.Remove(event,id) end
end
local function Device()
 local p=LocalPlayer()
 if not IsValid(p) or not p:GetCharacter() or not p:Alive() or p:GetLocalVar("ragdoll",0)~=0 then return end
 if p.HasItem and not p:HasItem("pda") then return end
 local w=p:GetActiveWeapon()
 if IsValid(w) and w:GetClass()==F.class and w.GetPDAEquipped then return w end
end
local base=FindMetaTable("Player")
F.baseCanOverrideView=F.baseCanOverrideView or ixPdaBaseCanOverrideView or base.CanOverrideView
function base:CanOverrideView()
 if self==LocalPlayer() and Device() then return false end
 if F.baseCanOverrideView then return F.baseCanOverrideView(self) end
end
local nextSync=0
local sessionCharacter
local sessionDevice
hook.Add("Think","FieldlinkDevice",function()
 local blocked=gui.IsConsoleVisible() or gui.IsGameUIVisible() or IsValid(ix.gui.menu) or IsValid(ix.gui.characterMenu)
 local p=LocalPlayer(); local c=IsValid(p) and p:GetCharacter()
 local w=Device()
 local valid=w and w:GetPDAEquipped() and c and not blocked
 if not valid or (sessionCharacter and sessionCharacter~=c:GetID()) or (sessionDevice and sessionDevice~=c:GetData("fieldlinkDevice")) then
  if IsValid(ix.gui.fieldlink) then ix.gui.fieldlink:Remove() end
  if blocked and w and w:GetPDAEquipped() then net.Start("ixFieldlinkClose"); net.SendToServer() end
  sessionCharacter=nil; sessionDevice=nil; return
 end
 if not IsValid(ix.gui.fieldlink) and w.GetPDAFraction and w:GetPDAFraction()>0.94 and RealTime()>=(F.closeUntil or 0) then
  ix.gui.fieldlink=vgui.Create("ixFieldlink"); sessionCharacter=c:GetID(); sessionDevice=c:GetData("fieldlinkDevice"); nextSync=RealTime()+6
 elseif IsValid(ix.gui.fieldlink) and not ix.gui.fieldlink.closing and RealTime()>=nextSync then
  F.Request("sync"); nextSync=RealTime()+6
 end
end)
hook.Add("CreateMove","FieldlinkDevice",function(cmd)
 if IsValid(ix.gui.fieldlink) then
  if F.camera then cmd:RemoveKey(IN_ATTACK); cmd:RemoveKey(IN_ATTACK2)
  else cmd:ClearMovement(); cmd:ClearButtons() end
 end
end)
concommand.Add("ix_pda_close",function()
 if IsValid(ix.gui.fieldlink) then ix.gui.fieldlink:Remove() end
 net.Start("ixFieldlinkClose"); net.SendToServer()
end)
-- The complete application is painted into the actual screen material.
local rt,material
local appliedVM,appliedIndex,original
local function Restore()
 if IsValid(appliedVM) then appliedVM:SetSubMaterial(appliedIndex,original or "") end
 appliedVM=nil; appliedIndex=nil; original=nil; F.screenQuad=nil
end
local function Ensure()
 if rt then return end
 rt=GetRenderTarget("fieldlink_interactive_lcd_v2",1024,1024)
 material=CreateMaterial("fieldlink_interactive_lcd_v2","UnlitGeneric",{
  ["$basetexture"]=rt:GetName(),["$nolod"]="1",["$model"]="1"})
 -- Bounds measured from the MI_PDA_Screen mesh's VVD texture coordinates.
 local u0,u1,v0,v1=0.00099945,0.517578125,0.424560547,0.998535156
 local m=Matrix()
 local height=F.screenHeight/1024
 m:SetField(1,1,1/(u1-u0)); m:SetField(2,2,height/(v1-v0))
 m:SetField(1,4,-u0/(u1-u0)); m:SetField(2,4,-height*v0/(v1-v0))
 material:SetMatrix("$basetexturetransform",m)
end
hook.Add("PostRender","FieldlinkDeviceScreen",function()
 if F.renderingCamera then return end
 local weapon=Device()
 if not weapon then Restore(); return end
 if F.RenderCamera then F.RenderCamera() end
 Ensure()
 render.PushRenderTarget(rt); render.Clear(12,8,12,255,true,true); cam.Start2D()
 -- Paint at 1:1 pixels into the top 576 rows of the square RT. The material
 -- selects that region. Keeping paint unscaled preserves VGUI scroll clipping.
 local ok,err=xpcall(function()
  local panel=ix.gui.fieldlink
  if IsValid(panel) then
   panel:PaintManual(true)
  elseif weapon:GetPDAFraction()>0.05 then
   F.DrawSCP(480,168,64,F.colors.red)
   draw.SimpleText("FIELDLINK","FieldlinkTitle",512,255,F.colors.text,TEXT_ALIGN_CENTER)
   draw.SimpleText("Secure. Contain. Protect.","FieldlinkMono",512,289,F.colors.muted,TEXT_ALIGN_CENTER)
   draw.SimpleText(weapon:GetPDAEquipped() and "WAKING…" or "STANDBY","FieldlinkMono",512,320,F.colors.accent,TEXT_ALIGN_CENTER)
  end
 end,debug.traceback)
 cam.End2D(); render.PopRenderTarget()
 if not ok and not F.screenError then F.screenError=true; ErrorNoHalt(err.."\n") end
end)
hook.Add("PreDrawViewModel","FieldlinkDeviceScreen",function(vm,p,w)
 if p~=LocalPlayer() or not IsValid(w) or w:GetClass()~=F.class or not IsValid(vm) then return end
 Ensure()
 if appliedVM~=vm then Restore() end
 if appliedIndex==nil then
  for n,path in ipairs(vm:GetMaterials()) do
   if string.find(string.lower(path),"screen",1,true) then
    appliedVM=vm; appliedIndex=n-1; original=vm:GetSubMaterial(appliedIndex); break
   end
  end
 end
 if appliedIndex~=nil then vm:SetSubMaterial(appliedIndex,"!fieldlink_interactive_lcd_v2") end
end)
-- Bind-pose screen corners transformed into jnt_offset bone-local space.
-- Derived from all 56 screen vertices, rather than desktop pixel calibration.
local corners={Vector(-2.55167,-4.80662,0.18889),Vector(-2.54453,4.35658,0.18888),
 Vector(2.54434,4.35608,0.18888),Vector(2.53719,-4.80712,0.18889)}
hook.Add("PostDrawViewModel","FieldlinkDeviceProjection",function(vm,p,w)
 if p~=LocalPlayer() or not IsValid(w) or w:GetClass()~=F.class or not w:GetPDAEquipped() then return end
 local bone=vm:LookupBone("jnt_offset")
 local matrix=bone and vm:GetBoneMatrix(bone)
 if not matrix then F.screenQuad=nil; return end
 local q={}
 -- This hook has the engine's viewmodel projection/FOV already active.
 -- Starting a new camera here would use a different projection from the mesh.
 for i,v in ipairs(corners) do
  local point=(matrix*v):ToScreen()
  if not point.visible then F.screenQuad=nil; return end
  q[i]={x=point.x,y=point.y}
 end
 F.screenQuad=q; F.screenQuadAt=RealTime()
end)
hook.Add("ShutDown","FieldlinkDeviceScreen",Restore)
