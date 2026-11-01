-- Offline drawing recorder. Exercises production HUDPaint; not engine rendering.
local output={}
local fonts={};local font;local color={r=255,g=255,b=255,a=255}
local matrix;local stack={};statusStats={rects=0,lines=0,fonts=0,matrices=0,rotatedFonts={},clippedGlyphs=0,glyphs=0}
screenW,screenH=1920,1080;clock=20
function ScrW() return screenW end;function ScrH() return screenH end;function RealTime() return clock end
function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
function isbool(v) return type(v)=='boolean' end
function math.atan2(y,x) return math.atan(y,x) end
function Vector(x,y,z) return {x=x,y=y,z=z} end
function Angle(p,y,r) return {p=p,y=y,r=r} end
function Matrix()
 statusStats.matrices=statusStats.matrices+1
 return {SetAngles=function(self,a) self.angle=a.y end,SetTranslation=function(self,v) self.x=v.x;self.y=v.y end}
end
cam={PushModelMatrix=function(m) stack[#stack+1]=matrix or false;matrix=m end,PopModelMatrix=function() matrix=table.remove(stack);if matrix==false then matrix=nil end end}
function string.Explode(sep,s) local r={};for v in (s..sep):gmatch('(.-)'..sep) do r[#r+1]=v end;return r end
ix.util={Include=function() end};ix.command={Add=function() end};ix.gui={};ix.option={Get=function() return reduced end}
FACTION_MTF=3;statusFaction=3
local statusCharacter={GetFaction=function() return statusFaction end}
local person={valid=true,Alive=function() return true end,GetCharacter=function() if not statusNoCharacter then return statusCharacter end end};function LocalPlayer() return person end
gui={IsGameUIVisible=function() return false end};net.ReadString=function() return statusText end;net.ReadBool=function() return true end;net.ReadUInt=function() return 4 end
TEXT_ALIGN_LEFT=0;TEXT_ALIGN_RIGHT=2
local function css(c) return 'fill="rgb('..c.r..','..c.g..','..c.b..')" fill-opacity="'..((c.a or 255)/255)..'"' end
surface={}
function surface.CreateFont(n,d) fonts[n]=d;statusStats.fonts=statusStats.fonts+1;assert(d.font=='Tahoma') end;function surface.SetFont(n) font=n end
function surface.GetTextSize(s)
 local f=fonts[font];local widths=STATUS_FONT_METRICS and STATUS_FONT_METRICS[(f.weight>=600 and 'bold' or 'normal')..f.size];local width=0
 for _,code in utf8.codes(s) do width=width+(widths and widths[tostring(code)] or f.size*.56) end
 return width,f.size
end
function surface.SetDrawColor(r,g,b,a) color=type(r)=='table' and r or Color(r,g,b,a) end
function surface.DrawRect(x,y,w,h) statusStats.rects=statusStats.rects+1;output[#output+1]=string.format('<rect x="%f" y="%f" width="%f" height="%f" %s/>',x,y,w,h,css(color)) end
function surface.DrawLine(x,y,x2,y2)
 statusStats.lines=statusStats.lines+1
 assert(math.min(x,x2)>=0 and math.max(x,x2)<=screenW and math.min(y,y2)>=0 and math.max(y,y2)<=screenH,'HUD line exceeds screen')
 output[#output+1]=string.format('<path d="M %f %f L %f %f" fill="none" stroke="rgb(%d,%d,%d)" stroke-opacity="%f" stroke-width="1"/>',x,y,x2,y2,color.r,color.g,color.b,color.a/255)
end
draw={}
function draw.SimpleText(s,n,x,y,c,align)
 -- VGUI clips before applying the model matrix. The earlier recorder only
 -- checked final coordinates, which missed negative-origin glyph clipping.
 x,y=math.ceil(x),math.ceil(y)
 surface.SetFont(n);local gw,gh=surface.GetTextSize(s)
 statusStats.glyphs=statusStats.glyphs+1
 if x<0 or y<0 or x+gw>screenW or y+gh>screenH then
  statusStats.clippedGlyphs=statusStats.clippedGlyphs+1
 end
 local px,py=x,y;local transform=''
 if matrix then
  local a=math.rad(matrix.angle);px=matrix.x+x*math.cos(a)-y*math.sin(a);py=matrix.y+x*math.sin(a)+y*math.cos(a)
  transform=string.format('transform="translate(%f %f) rotate(%f)"',matrix.x,matrix.y,matrix.angle)
  if math.abs(matrix.angle)>.05 then statusStats.rotatedFonts[n]=true end
 end
 assert(px>=0 and px<=screenW and py>=0 and py+fonts[n].size<=screenH,'HUD text exceeds screen: '..px..', '..py)
 local f=fonts[n];s=s:gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;')
 output[#output+1]=string.format('<text %s x="%f" y="%f" font-family="%s" font-size="%d" font-weight="%d" text-anchor="%s" %s>%s</text>',transform,x,y+f.size,f.font,f.size,f.weight,align==2 and 'end' or 'start',css(c),s)
end
function StatusSVG()
 return '<svg xmlns="http://www.w3.org/2000/svg" width="720" height="340" viewBox="1200 75 720 340"><defs><linearGradient id="scene" x2="1" y2="1"><stop stop-color="#151919"/><stop offset="1" stop-color="#454d4d"/></linearGradient></defs><rect x="1200" y="75" width="720" height="340" fill="url(#scene)"/>'..table.concat(output)..'</svg>'
end
function ClearStatusDrawing() assert(#stack==0 and not matrix,'Unbalanced HUD matrices');output={};statusStats.rects=0;statusStats.lines=0;statusStats.rotatedFonts={};statusStats.clippedGlyphs=0;statusStats.glyphs=0 end
function StatusDrawCount() return #output end
