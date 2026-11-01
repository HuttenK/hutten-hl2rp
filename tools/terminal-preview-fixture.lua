-- Offline layout/paint adapter. Runs the production Derma builders, then exports
-- their paint calls as SVG. It is not an engine renderer or a replacement UI.
function Lerp(f,a,b) return a+(b-a)*f end
function string.Explode(separator,value) local out={} local start=1 while true do local a,b=value:find(separator,start,true);if not a then out[#out+1]=value:sub(start);break end;out[#out+1]=value:sub(start,a-1);start=b+1 end;return out end
CLIENT=true;SERVER=false;TOP=1;LEFT=2;RIGHT=3;BOTTOM=4;FILL=5;NODOCK=0
TEXT_ALIGN_LEFT=0;TEXT_ALIGN_CENTER=1;TEXT_ALIGN_RIGHT=2
function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
color_white=Color(255,255,255)
function RealTime() return 10 end
function FrameTime() return 1/60 end
ix.gui={};ix.FoundationNet={screenWidth=1920,screenHeight=1120};ix.option={Get=function() return false end}
local fonts={};surface={CreateFont=function(name,font) fonts[name]=font end}
local font='FoundationText';local color=Color(255,255,255);local mat
local svg={};local ox,oy=0,0
local function esc(s) return tostring(s):gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;'):gsub('"','&quot;') end
local function fill(c) return string.format('rgb(%.0f,%.0f,%.0f)',c.r,c.g,c.b) end
local function add(s) svg[#svg+1]=s end
function surface.SetDrawColor(r,g,b,a) color=type(r)=='table' and r or Color(r,g,b,a) end
function surface.DrawRect(x,y,w,h) if w>0 and h>0 then add(string.format('<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" fill="%s" opacity="%.3f"/>',ox+x,oy+y,w,h,fill(color),color.a/255)) end end
function surface.DrawOutlinedRect(x,y,w,h) local c=color;add(string.format('<rect x="%f" y="%f" width="%f" height="%f" fill="none" stroke="%s"/>',ox+x,oy+y,w,h,fill(c))) end
function surface.DrawLine(x,y,x2,y2) add(string.format('<path d="M %.2f %.2f L %.2f %.2f" fill="none" stroke="%s" opacity="%.3f" stroke-width="1.5"/>',ox+x,oy+y,ox+x2,oy+y2,fill(color),color.a/255)) end
function surface.DrawCircle(x,y,r,c) add(string.format('<circle cx="%f" cy="%f" r="%f" fill="none" stroke="%s" stroke-width="1.5"/>',ox+x,oy+y,r,fill(c))) end
function surface.DrawPoly(points) local s={} for _,p in ipairs(points) do s[#s+1]=(ox+p.x)..','..(oy+p.y) end;add('<polygon points="'..table.concat(s,' ')..'" fill="'..fill(color)..'"/>') end
function surface.SetFont(f) font=f end
local function advance(f) return f and f.font=='Consolas' and .61 or .52 end
function surface.GetTextSize(s) return (utf8.len(s) or #s)*(fonts[font] and fonts[font].size or 26)*advance(fonts[font]),(fonts[font] and fonts[font].size or 26) end
function Material(path) local wide=path:find('facility',1,true) or path:find('biosafety',1,true);return {path=path,IsError=function() return false end,Width=function() return wide and 2172 or 1536 end,Height=function() return wide and 724 or 1024 end} end
function surface.SetMaterial(m) mat=m end
function surface.DrawTexturedRectUV(x,y,w,h) add(string.format('<svg x="%f" y="%f" width="%f" height="%f" viewBox="0 0 %f %f"><image href="../addons/foundation_terminal_assets/materials/%s" x="0" y="0" width="%f" height="%f" preserveAspectRatio="xMidYMid slice" opacity="%f"/></svg>',ox+x,oy+y,w,h,w,h,mat.path,w,h,color.a/255)) end
function surface.DrawTexturedRect(x,y,w,h) surface.DrawTexturedRectUV(x,y,w,h) end
draw={NoTexture=function() end}
function draw.SimpleText(value,f,x,y,c,ax,ay)
 local t=fonts[f] or {size=26,font='Bahnschrift'}
 local anchor=ax==1 and 'middle' or (ax==2 and 'end' or 'start')
 local baseline=ay==1 and t.size*.32 or t.size*.83
 add(string.format('<text x="%f" y="%f" font-family="%s" font-size="%d" font-weight="%d" text-anchor="%s" fill="%s" opacity="%f">%s</text>',ox+x,oy+y+baseline,t.font,t.size,t.weight or 500,anchor,fill(c),c.a/255,esc(value)))
end
function draw.RoundedBox(r,x,y,w,h,c) add(string.format('<rect x="%f" y="%f" width="%f" height="%f" rx="%f" fill="%s" opacity="%f"/>',ox+x,oy+y,w,h,r,fill(c),c.a/255)) end
local classes={};local P={};P.__index=P;local creationOrder=0
local function nop() end
function vnew(class,parent)
 creationOrder=creationOrder+1
 local p=setmetatable({class=class,valid=true,w=64,h=24,x=0,y=0,children={},margin={0,0,0,0},pad={0,0,0,0},visible=true,text='',z=0}, {__index=function(_,k) return classes[class] and classes[class][k] or P[k] end})
 p.creationOrder=creationOrder
 if parent then p.parent=parent;parent.children[#parent.children+1]=p end
 if class=='DScrollPanel' then p.canvas=vnew('Panel',p);p.bar=vnew('Panel',p);p.bar.visible=false;p.bar.btnUp=vnew('Panel');p.bar.btnDown=vnew('Panel');p.bar.btnGrip=vnew('Panel') end
 if p.Init then p:Init() end;return p
end
vgui={Register=function(name,p) classes[name]=p end,Create=vnew}
function P:Add(c) return vnew(c,self.canvas or self) end
function P:Clear() (self.canvas or self).children={} end
function P:Remove() self.valid=false;self.visible=false end
function P:GetChildren() return self.children end
function P:GetParent() return self.parent end
function P:SetSize(w,h) self.w=w;self.h=h end
function P:GetSize() return self.w,self.h end
function P:SetPos(x,y) self.x=x;self.y=y end
function P:GetPos() return self.x,self.y end
function P:SetWide(w) self.w=w end
function P:SetTall(h) self.h=h end
function P:GetWide() return self.w end
function P:GetTall() return self.h end
function P:Dock(d) self.dock=d end
function P:DockMargin(...) self.margin={...} end
function P:GetDockMargin() return table.unpack(self.margin) end
function P:DockPadding(...) self.pad={...} end
function P:SetText(s) self.text=tostring(s) end
function P:GetValue() return self.text end
function P:SetFont(f) self.font=f end
function P:SetTextColor(c) self.ink=c end
function P:SetWrap(v) self.wrap=v end
function P:SetAutoStretchVertical(v) self.auto=v end
function P:SetVisible(v) self.visible=v end
function P:SetZPos(v) self.z=v end
function P:GetZPos() return self.z end
function P:IsVisible() return self.visible end
function P:IsEnabled() return true end
function P:HasFocus() return false end
function P:IsHovered() return false end
function P:GetVBar() return self.bar end
function P:SetSpaceX(v) self.sx=v end
function P:SetSpaceY(v) self.sy=v end
function P:SetScroll(v) self.scroll=v end
function P:SetAlpha(v) self.alpha=v end
P.SetPaintedManually=nop;P.SetCursorColor=nop;P.SetHighlightColor=nop;P.SetMultiline=nop;P.SetPlaceholderText=nop;P.SetEditable=nop;P.Stop=nop;P.AlphaTo=nop;P.InvalidateLayout=nop
P.Center=nop;P.MakePopup=nop
function P:SetTitle(text) self.title=text;self:DockPadding(8,32,8,8) end
function P:LocalToScreen(x,y) local p=self;while p do x=x+p.x;y=y+p.y;p=p.parent end;return x,y end
function P:Layout()
 if self.class~='DIconLayout' then return end
 local x,y,row=0,0,0
 for _,c in ipairs(self.children) do
  if x>0 and x+c.w>self.w+.1 then x=0;y=y+row+(self.sy or 0);row=0 end
  c:SetPos(x,y);x=x+c.w+(self.sx or 0);row=math.max(row,c.h)
 end
 self.h=y+row
end
local function words(s,width,size,f)
 local lines={};local line='';local count=0;local max=math.max(2,math.floor(width/(size*advance(fonts[f]))))
 for paragraph in (s..'\n'):gmatch('(.-)\n') do
  line='';count=0
  for word in paragraph:gmatch('%S+') do local len=utf8.len(word) or #word
   if count>0 and count+len+1>max then lines[#lines+1]=line;line='';count=0 end
   line=line..(count>0 and ' ' or '')..word;count=count+len+1
  end
  lines[#lines+1]=line
 end
 return lines
end
local function arrange(p)
 if p.PerformLayout then p:PerformLayout(p.w,p.h) end
 if p.class=='DScrollPanel' then p.canvas:SetSize(p.w-12,10000);p.canvas:SetPos(0,-(p.bar.scroll or 0)) end
 local l,t,r,b=table.unpack(p.pad);local right,bottom=p.w-r,p.h-b
 for _,c in ipairs(p.children) do if c.visible then
  local ml,mt,mr,mb=table.unpack(c.margin)
  if c.dock==TOP or c.dock==BOTTOM then
   c.w=right-l-ml-mr
   if c.auto then c.h=#words(c.text,c.w,(fonts[c.font] or {size=26}).size,c.font)*(fonts[c.font] or {size=26}).size*1.24 end
   if c.dock==TOP then c.x=l+ml;c.y=t+mt;t=c.y+c.h+mb else c.x=l+ml;c.y=bottom-c.h-mb;bottom=c.y-mt end
  elseif c.dock==LEFT then c.x=l+ml;c.y=t+mt;c.h=bottom-t-mt-mb;l=c.x+c.w+mr
  elseif c.dock==RIGHT then c.x=right-c.w-mr;c.y=t+mt;c.h=bottom-t-mt-mb;right=c.x-ml
  elseif c.dock==FILL then c.x=l+ml;c.y=t+mt;c.w=right-l-ml-mr;c.h=bottom-t-mt-mb end
  arrange(c)
 end end
 if p.class=='DIconLayout' then p:Layout() end
 if p~=previewRoot and p.Think then p:Think() end
end
local serial=0
local function paint(p,l,t,r,b)
 if not p.visible or not p.valid then return end
 local x,y=p:LocalToScreen(0,0);l=math.max(l,x);t=math.max(t,y);r=math.min(r,x+p.w);b=math.min(b,y+p.h)
 if r<=l or b<=t then return end
 serial=serial+1;local id='c'..serial
 add(string.format('<defs><clipPath id="%s"><rect x="%f" y="%f" width="%f" height="%f"/></clipPath></defs><g clip-path="url(#%s)">',id,l,t,r-l,b-t,id))
 ox=x;oy=y
 if p.Paint then p:Paint(p.w,p.h) end
 if p.class=='DLabel' or (p.class=='DButton' and p.text~='') or p.class=='DTextEntry' then
  local f=p.font or 'FoundationText';local size=(fonts[f] or {size=26}).size
  for i,line in ipairs(words(p.text,p.w,size,f)) do draw.SimpleText(line,f,0,(i-1)*size*1.24,p.ink or Color(229,240,239)) end
 end
 table.sort(p.children,function(a,b) if a.z==b.z then return a.creationOrder<b.creationOrder end;return a.z<b.z end)
 for _,c in ipairs(p.children) do paint(c,l,t,r,b) end
 ox=x;oy=y;if p.PaintOver then p:PaintOver(p.w,p.h) end
 add('</g>')
end
function P:DrawTextEntryText() end
function PreviewSVG(p)
 previewRoot=p;for i=1,12 do arrange(p) end
 svg={};serial=0;paint(p,0,0,p.w,p.h)
 return '<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1120" viewBox="0 0 1920 1120">'..table.concat(svg)..'</svg>'
end
function PreviewLayout(p) previewRoot=p;for i=1,16 do arrange(p) end end
net.Receive=function() end
