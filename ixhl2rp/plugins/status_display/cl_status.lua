local P=PLUGIN
local state={text='',enabled=false,revision=-1,received=0}
local cache
local fontSets={}
local function fonts(scale)
 local size=math.max(18,math.floor(22*scale))
 if fontSets[size] then return fontSets[size] end
 local set={}
 for kind,def in pairs({Text={size,400},Title={math.max(16,math.floor(18*scale)),600},Meta={math.max(14,math.floor(14*scale)),400}}) do
  local name='ixStatusVisor'..kind..size
  surface.CreateFont(name,{font='Tahoma',size=def[1],weight=def[2],extended=true,antialias=true,blursize=0,scanlines=0,shadow=false,outline=false,additive=false})
  set[kind]=name
 end
 fontSets[size]=set
 return set
end
-- All HUD parts share this visor projection, including the corner strokes.
-- The right side rises; the vertical edge also bows gently outwards.
local function project(x,y)
 local u=x/cache.width
 local v=(y/cache.height)-.5
 return cache.left+x+10*cache.scale*u*v*v,
  cache.top+y-32*cache.scale*u*u
end
local function glyphs(text,font,y,align)
 surface.SetFont(font)
 local width,height=surface.GetTextSize(text)
 local start=align=='left' and 0 or cache.width-width
 local row={font=font}
 local prefix=''
 for _,code in utf8.codes(text) do
  local char=utf8.char(code)
  prefix=prefix..char
  local advance=surface.GetTextSize(prefix)
  local gw=surface.GetTextSize(char)
  -- Prefix measurements preserve the font's actual kerning.
  local x=start+advance-gw/2
  local px,py=project(x,y+height/2)
  local nextX,nextY=project(x+1,y+height/2)
  local angle=math.atan2(nextY-py,nextX-px)
  local cosine,sine=math.cos(angle),math.sin(angle)
  -- VGUI clips text in its drawing coordinates before the model transform.
  -- Keep the glyph (including font bearings) inside those bounds and perform
  -- centering in the matrix, never by drawing at a negative text position.
  local inset=8
  local centerX,centerY=inset+gw/2,inset+height/2
  local matrix=Matrix()
  matrix:SetAngles(Angle(0,math.deg(angle),0))
  matrix:SetTranslation(Vector(px-centerX*cosine+centerY*sine,py-centerX*sine-centerY*cosine,0))
  row[#row+1]={char=char,x=inset,y=inset,matrix=matrix}
 end
 return row
end
local function wrap(text,width,font)
 surface.SetFont(font)
 local rows={}
 for _,raw in ipairs(string.Explode('\n',text)) do
  local line=''
  for token in raw:gmatch('%S+') do
   local joined=line=='' and token or line..' '..token
   if surface.GetTextSize(joined)<=width then line=joined
   else
    if line~='' then rows[#rows+1]=line;line='' end
    -- Split only words too long to fit, and never split UTF-8 bytes.
    for _,code in utf8.codes(token) do
     local char=utf8.char(code)
     if line~='' and surface.GetTextSize(line..char)>width then rows[#rows+1]=line;line='' end
     line=line..char
    end
   end
  end
  rows[#rows+1]=line
 end
 return rows
end
local function stroke(points)
 local path={}
 for _,point in ipairs(points) do
  local x,y=project(point[1],point[2]);path[#path+1]={x=x,y=y}
 end
 return path
end
local function rebuild()
 local s=math.Clamp(ScrH()/1080,.8,1.6)
 local set=fonts(s)
 local width=math.min(ScrW()*.42,620*s)
 local lines=wrap(state.text,width,set.Text)
 local lineHeight=math.max(25,29*s)
 local height=86*s+#lines*lineHeight
 -- Long messages may need more width at small desktop resolutions.
 if height>ScrH()*.77 then
  width=math.min(ScrW()*.58,820*s);lines=wrap(state.text,width,set.Text)
  height=86*s+#lines*lineHeight
 end
 cache={scale=s,width=width,height=height,left=ScrW()-48*s-width,top=ScrH()*.13,
  screenWidth=ScrW(),screenHeight=ScrH(),rows={},paths={}}
 cache.title=glyphs('ОПЕРАТИВНАЯ СВОДКА',set.Title,0)
 cache.footer=glyphs('УВС-19F  /  SCiPNET',set.Meta,height-22*s,'left')
 cache.revision=glyphs('SYNC '..string.format('%03d',state.revision%1000),set.Meta,height-22*s)
 for i,line in ipairs(lines) do cache.rows[i]=glyphs(line,set.Text,46*s+(i-1)*lineHeight) end
 local divider={}
 for i=0,48 do divider[#divider+1]={width*i/48,32*s} end
 cache.paths[1]=stroke(divider)
 -- Rounded, open corner marks; no enclosing panel or background fill.
 for _,bottom in ipairs({false,true}) do
  local y=bottom and height+2*s or -10*s
  local sign=bottom and -1 or 1
  local points={}
  for i=0,8 do points[#points+1]={width-14*s+i*2*s,y} end
  for i=1,12 do
   local a=-math.pi/2+i*math.pi/24
   points[#points+1]={width+2*s+10*s*math.cos(a),y+sign*10*s*(1+math.sin(a))}
  end
  for i=1,8 do points[#points+1]={width+12*s,y+sign*(10+i*1.5)*s} end
  cache.paths[#cache.paths+1]=stroke(points)
 end
 local accent={}
 for i=0,12 do accent[#accent+1]={i*s,8*s+3*s*math.sin(i/12*math.pi)} end
 cache.accent=stroke(accent)
end
net.Receive('ixStatusHUD',function()
 local text=net.ReadString();local enabled=net.ReadBool();local revision=net.ReadUInt(31)
 if not P:ValidateStatus(text) then return end
 if state.revision==revision and state.text==text and state.enabled==enabled then return end
 state={text=text,enabled=enabled,revision=revision,received=RealTime()};rebuild()
end)
function P:InitPostEntity() net.Start('ixStatusHUDReady');net.SendToServer() end
local ink=Color(150,235,241)
local heading=Color(225,248,250)
local muted=Color(174,218,224)
local shadow=Color(0,0,0)
local function paintText(row,color,alpha,count)
 color.a=255*alpha;shadow.a=190*alpha
 for i=1,math.min(#row,count or #row) do
  local glyph=row[i]
  cam.PushModelMatrix(glyph.matrix,true)
  draw.SimpleText(glyph.char,row.font,glyph.x+1,glyph.y+1,shadow)
  draw.SimpleText(glyph.char,row.font,glyph.x,glyph.y,color)
  cam.PopModelMatrix()
 end
end
local function paintStroke(points,r,g,b,alpha)
 surface.SetDrawColor(r,g,b,alpha)
 for i=2,#points do
  local a,c=points[i-1],points[i];surface.DrawLine(a.x,a.y,c.x,c.y)
 end
end
function P:HUDPaint()
 if not state.enabled or state.text=='' then return end
 local client=LocalPlayer()
 if not IsValid(client) or not client:Alive() or not client:GetCharacter() then return end
 if gui.IsGameUIVisible() or (ix.gui and (IsValid(ix.gui.foundationNetwork) or IsValid(ix.gui.characterMenu) or IsValid(ix.gui.menu) or IsValid(ix.gui.fieldlink))) then return end
 if not cache or cache.screenHeight~=ScrH() or cache.screenWidth~=ScrW() then rebuild() end
 local reduced=ix.option and ix.option.Get('disableAnimations',false)
 local elapsed=RealTime()-state.received
 local reveal=reduced and 1 or math.Clamp(elapsed/.35,0,1)
 for _,path in ipairs(cache.paths) do paintStroke(path,102,211,224,135*reveal) end
 paintStroke(cache.accent,255,87,105,230*reveal)
 paintText(cache.title,heading,reveal)
 paintText(cache.footer,muted,reveal)
 paintText(cache.revision,muted,reveal)
 for index,row in ipairs(cache.rows) do
  local elapsedRow=elapsed-(index-1)*.075
  local fade=reduced and 1 or math.Clamp(elapsedRow/.3,0,1)
  local count=reduced and #row or math.max(0,math.floor(elapsedRow*100))
  paintText(row,ink,fade,count)
 end
end
net.Receive('ixStatusHUDEdit',function()
 local text=net.ReadString();local enabled=net.ReadBool();local revision=net.ReadUInt(31)
 if not LocalPlayer():IsAdmin() then return end
 if IsValid(P.editor) then P.editor:Remove() end
 local frame=vgui.Create('DFrame');P.editor=frame;frame:SetSize(660,440);frame:Center();frame:SetTitle('УВС-19F / Оперативная сводка');frame:MakePopup()
 frame.Paint=function(_,w,h)
  draw.RoundedBox(5,0,0,w,h,Color(12,8,12,252))
  surface.SetDrawColor(150,43,57,180);surface.DrawOutlinedRect(0,0,w,h)
  surface.SetDrawColor(255,53,76);surface.DrawRect(16,30,w-32,2)
 end
 local help=frame:Add('DLabel');help:Dock(TOP);help:SetTall(44);help:SetText('Сообщение для всех игроков. До 8 строк, 64 символов в строке.\nПустой текст скрывает сводку. Изменения сохраняются после перезапуска.')
 local controls=frame:Add('DPanel');controls:Dock(BOTTOM);controls:SetTall(46)
 controls.Paint=function() end
 local show=controls:Add('DCheckBoxLabel');show:Dock(LEFT);show:SetWide(300);show:SetText('Показывать оперативную сводку');show:SetValue(enabled and 1 or 0)
 local entry=frame:Add('DTextEntry');entry:Dock(FILL);entry:SetMultiline(true);entry:SetFont('DermaDefault');entry:SetText(text)
 entry.Paint=function(self,w,h)
  draw.RoundedBox(4,0,0,w,h,Color(27,12,18));surface.SetDrawColor(self:HasFocus() and Color(255,53,76) or Color(110,45,57));surface.DrawOutlinedRect(0,0,w,h)
  self:DrawTextEntryText(Color(235,223,226),Color(140,38,61),Color(255,106,120))
 end
 local save=controls:Add('DButton');save:Dock(RIGHT);save:SetWide(150);save:SetText('Опубликовать')
 save:SetTextColor(Color(255,185,194))
 save.Paint=function(self,w,h)
  draw.RoundedBox(4,0,4,w,h-8,self:IsHovered() and Color(73,23,38) or Color(39,15,25))
  surface.SetDrawColor(255,53,76,180);surface.DrawOutlinedRect(0,4,w,h-8)
 end
 save.DoClick=function()
  local value=P:ValidateStatus(entry:GetValue())
  if not value then LocalPlayer():Notify('Текст слишком длинный: до 8 строк и 1024 байт UTF-8.');return end
  net.Start('ixStatusHUDSave');net.WriteString(value);net.WriteBool(show:GetChecked());net.WriteUInt(revision,31);net.SendToServer();frame:Remove()
 end
end)
