local P,C=PLUGIN,ix.CCTV
local recognized=Color(104,237,207);local unknown=Color(245,198,109)
function P:RecognitionRows(feed)
 local data=feed and feed.recognition
 if not istable(data) or not istable(data.people) or not C.Number(data.ttl,0,C.recognition.ttl) then return {} end
 if RealTime()-(feed.received or 0)>=data.ttl then return {} end
 return data.people
end
function P:CaptureRecognition(feed,origin,angles,owner)
 local result={};local d=self.devices[feed.id]
 local cameraEntity=owner or (d and (d.entity or Entity(d.entityIndex or -1)))
 for i,identity in ipairs(self:RecognitionRows(feed)) do
  if i>C.recognition.limit then break end
  local p=Entity(identity.entity or -1)
  if IsValid(p) and p:IsPlayer() and p:UserID()==identity.userid then
   local box=C.VisibleFace(p,origin,angles,feed.fov,cameraEntity)
   if box then box.identity=table.Copy(identity);result[#result+1]=box end
  end
 end
 return result
end
function P:PaintRecognition(feed,slot,x,y,w,h)
 if w<48 or h<40 or not slot.updated or RealTime()-slot.updated>C.recognition.frameTTL then return end
 local grants={};for _,v in ipairs(self:RecognitionRows(feed)) do grants[v.entity]=v end
 for _,box in ipairs(slot.recognition or {}) do
  local identity=box.identity;local p=Entity(identity.entity or -1)
  if C.SameIdentity(identity,grants[identity.entity]) and IsValid(p) and p:IsPlayer() and p:UserID()==identity.userid and C.Recognizable(p) then
   local left=x+(box.x-box.w/2)*w;local top=y+(box.y-box.h/2)*h
   local size=box.w*w;local height=box.h*h
   local color=identity.level and recognized or unknown
   -- Coordinates are frozen when the texture is captured, never reprojected
   -- from a later player/bone transform while the same old frame is displayed.
   surface.SetDrawColor(color);surface.DrawOutlinedRect(left,top,size,height,1)
   local name=C.IdentityText(identity.name,48) or "НЕ ОПОЗНАН"
   local details=identity.level and ("L"..identity.level.." · "..(C.IdentityText(identity.department,32) or "")) or "НЕТ ДЕЙСТВУЮЩЕЙ КАРТЫ"
   local width=math.min(210,w-8);name=C.FitText(name,"ixCCTVSmall",width-8);details=C.FitText(details,"ixCCTVSmall",width-8)
   surface.SetFont("ixCCTVSmall");local nw=surface.GetTextSize(name);local dw=surface.GetTextSize(details);width=math.min(width,math.max(nw,dw)+8)
   local lx=math.Clamp(left,x+2,x+w-width-2)
   local ly=top+height+3;if ly+30>y+h-2 then ly=top-33 end
   ly=math.Clamp(ly,y+2,y+h-32)
   surface.SetDrawColor(2,10,14,225);surface.DrawRect(lx,ly,width,30)
   draw.SimpleText(name,"ixCCTVSmall",lx+4,ly+2,color)
   draw.SimpleText(details,"ixCCTVSmall",lx+4,ly+16,color)
  end
 end
end
