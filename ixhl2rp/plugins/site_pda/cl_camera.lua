local F=ix.Fieldlink
local cameraRT,cameraMaterial,monoMaterial
local nextFrame,nextScan=0,0
F.photoMaterials={}
local incoming={}
function F.SetCamera(enabled)
 local panel=ix.gui.fieldlink
 if enabled and (not IsValid(panel) or not panel.data or not panel.data.registered) then return end
 F.camera=enabled; F.capturePending=nil; F.scan=nil; F.cameraInputArmed=false
 if not IsValid(panel) or not IsValid(panel.inputHost) then return end
 local host=panel.inputHost
 if enabled then
  host:SetMouseInputEnabled(false); host:SetKeyboardInputEnabled(false)
  host.screenShield:SetMouseInputEnabled(false); gui.EnableScreenClicker(false)
 else
  host:MakePopup(); host.screenShield:SetMouseInputEnabled(true); host.screenShield:SetKeyboardInputEnabled(false)
  panel:SetMouseInputEnabled(false); panel:SetKeyboardInputEnabled(true)
  panel:Navigate("camera")
 end
end
function F.UploadPhoto(bytes)
 local panel=ix.gui.fieldlink
 if not IsValid(panel) or not panel.data or not F.PhotoJPEG(bytes) then
  if IsValid(panel) then panel.toast="Ошибка захвата снимка." end
  return
 end
 local device=panel.data.device; local offset=0; local character=LocalPlayer():GetCharacter():GetID()
 panel.toast="Сохранение снимка…"; F.uploading=true
 local function send()
  local p=LocalPlayer(); local c=IsValid(p) and p:GetCharacter()
  if not c or c:GetID()~=character or c:GetData("fieldlinkDevice")~=device or not F.Ready(p) then F.uploading=false; return end
  local chunk=bytes:sub(offset+1,offset+F.photoChunk)
  net.Start("ixFieldlinkUpload"); net.WriteUInt(device,32); net.WriteUInt(#bytes,18); net.WriteUInt(offset,18)
  net.WriteUInt(#chunk,16); net.WriteData(chunk,#chunk); net.SendToServer()
  offset=offset+#chunk
  if offset<#bytes then timer.Simple(.12,send) else F.uploading=false end
 end
 send()
end
function F.CameraThink()
 if not F.camera then return end
 local panel=ix.gui.fieldlink
 if not IsValid(panel) or not F.Ready(LocalPlayer()) then F.SetCamera(false); return end
 local left,right=input.IsMouseDown(MOUSE_LEFT),input.IsMouseDown(MOUSE_RIGHT)
 if not left and not right then F.cameraInputArmed=true end
 if F.cameraInputArmed then
  if right and not F.cameraRight then F.SetCamera(false); return end
  if left and not F.cameraLeft and RealTime()>=(F.nextCapture or 0) and not F.uploading then
   if #(panel.data.photos or {})>=F.photoLimit then panel.toast="Альбом заполнен. Удалите снимок."; F.Sound("error")
   else F.capturePending=true; F.nextCapture=RealTime()+4 end
  end
 end
 F.cameraLeft=left; F.cameraRight=right
 if RealTime()>nextScan then net.Start("ixFieldlinkScan"); net.SendToServer(); nextScan=RealTime()+.75 end
end
function F.RenderCamera()
 if not F.camera or F.renderingCamera or RealTime()<nextFrame then return end
 nextFrame=RealTime()+.1 -- bound the cost of the second world render to 10 Hz
 if not cameraRT then
  -- Power-of-two backing texture, with a 640x360 viewport and matching UVs.
  cameraRT=GetRenderTarget("fieldlink_camera_scene",1024,512)
  cameraMaterial=CreateMaterial("fieldlink_camera_display","UnlitGeneric",{["$basetexture"]=cameraRT:GetName()})
  monoMaterial=CreateMaterial("fieldlink_camera_mono","g_colourmodify",{
   ["$fbtexture"]=cameraRT:GetName(),["$pp_colour_colour"]=0,["$pp_colour_contrast"]=1,
   ["$pp_colour_brightness"]=0,["$pp_colour_addr"]=0,["$pp_colour_addg"]=0,["$pp_colour_addb"]=0,
   ["$pp_colour_mulr"]=0,["$pp_colour_mulg"]=0,["$pp_colour_mulb"]=0,["$pp_colour_inv"]=0})
 end
 F.renderingCamera=true
 render.PushRenderTarget(cameraRT,0,0,640,360); render.Clear(0,0,0,255,true,true)
 local drawing=false
 local ok,err=xpcall(function()
  local p=LocalPlayer()
  render.RenderView({origin=p:EyePos(),angles=p:EyeAngles(),x=0,y=0,w=640,h=360,fov=70,aspectratio=640/360,
   drawviewmodel=false,drawhud=false,dopostprocess=false})
  -- Copy to a separate texture before grayscale shading (no read/write feedback).
  F.cameraCopy=F.cameraCopy or GetRenderTarget("fieldlink_camera_copy",1024,512)
  render.CopyRenderTargetToTexture(F.cameraCopy)
  monoMaterial:SetTexture("$fbtexture",F.cameraCopy)
  cam.Start2D(); drawing=true
  surface.SetDrawColor(255,255,255,255); surface.SetMaterial(monoMaterial)
  surface.DrawTexturedRectUV(0,0,640,360,0,0,640/1024,360/512)
  cam.End2D(); drawing=false
  if F.capturePending then
   F.capturePending=nil
   local bytes=render.Capture({format="jpeg",quality=65,x=0,y=0,w=640,h=360})
   F.UploadPhoto(bytes); F.Sound("click"); F.cameraFlash=RealTime()
  end
 end,debug.traceback)
 if drawing then cam.End2D() end
 render.PopRenderTarget(); F.renderingCamera=false
 if not ok then F.capturePending=nil; F.SetCamera(false); ErrorNoHalt("FIELDLINK camera: "..err.."\n") end
end
function F.PaintCamera(w,h)
 surface.SetDrawColor(7,7,7,255); surface.DrawRect(0,0,w,h)
 if cameraMaterial then
  surface.SetDrawColor(255,255,255,255); surface.SetMaterial(cameraMaterial)
  surface.DrawTexturedRectUV(0,0,w,h,0,0,640/1024,360/512)
 end
 local c=Color(236,236,236)
 draw.SimpleText("FIELDLINK / MONO CAMERA","FieldlinkMono",24,20,c)
 surface.SetDrawColor(240,240,240,200)
 surface.DrawLine(w/2-12,h/2,w/2+12,h/2); surface.DrawLine(w/2,h/2-12,w/2,h/2+12)
 draw.SimpleText("ЛКМ / СНИМОК     ПКМ / НАЗАД","FieldlinkHeading",24,h-38,c)
 local scan=F.scan
 if scan and RealTime()-scan.at<1.5 then
  draw.RoundedBox(0,20,h-130,w*.64,76,Color(0,0,0,190))
  draw.SimpleText(scan.name,"FieldlinkHeading",32,h-117,c)
  draw.SimpleText("CID / "..scan.cid.."   CARD / "..scan.serial,"FieldlinkMono",32,h-86,c)
 end
 local panel=ix.gui.fieldlink
 if IsValid(panel) and panel.toast then draw.SimpleText(panel.toast,"FieldlinkSmall",24,48,c) end
 local flash=math.max(0,1-(RealTime()-(F.cameraFlash or -10))/.15)
 if flash>0 then surface.SetDrawColor(255,255,255,flash*150); surface.DrawRect(0,0,w,h) end
end
net.Receive("ixFieldlinkScan",function()
 local device,found=net.ReadUInt(32),net.ReadBool()
 local scan=found and {name=net.ReadString(),cid=net.ReadString(),serial=net.ReadString(),at=RealTime()}
 local panel=ix.gui.fieldlink
 if F.camera and IsValid(panel) and panel.data and panel.data.device==device then F.scan=scan end
end)
function F.PhotoMaterial(id)
 if F.photoMaterials[id] then return F.photoMaterials[id] end
 if not isstring(id) or #id~=64 or not id:match("^[a-f0-9]+$") then return end
 if (F.photoRequestAt or 0)<RealTime() and not incoming[id] then
  if F.Request("photo",{id=id}) then F.photoRequestAt=RealTime()+1.5 end
 end
end
net.Receive("ixFieldlinkPhoto",function()
 local device,id,total,offset,size=net.ReadUInt(32),net.ReadString(),net.ReadUInt(18),net.ReadUInt(18),net.ReadUInt(16)
 local panel=ix.gui.fieldlink
 if not IsValid(panel) or not panel.data or panel.data.device~=device or #id~=64 or not id:match("^[a-f0-9]+$") or total>F.photoBytes or size>F.photoChunk or size<1 then return end
 if offset==0 then incoming[id]={device=device,total=total,offset=0,parts={},at=RealTime()} end
 local state=incoming[id]
 if not state or state.device~=device or state.total~=total or state.offset~=offset or offset+size>total then incoming[id]=nil; return end
 state.parts[#state.parts+1]=net.ReadData(size); state.offset=offset+size
 if state.offset==total then
  incoming[id]=nil; local bytes=table.concat(state.parts)
  if not F.PhotoJPEG(bytes) or util.SHA256(bytes)~=id then return end
  file.CreateDir("fieldlink_cache"); file.Write("fieldlink_cache/"..id..".jpg",bytes)
  F.photoMaterials[id]=Material("../data/fieldlink_cache/"..id..".jpg","smooth")
 end
end)
hook.Add("Think","FieldlinkPhotoTimeout",function()
 for id,state in pairs(incoming) do if RealTime()-state.at>10 then incoming[id]=nil end end
end)
