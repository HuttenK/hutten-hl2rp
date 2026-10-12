local N=ix.FoundationNet
N.siteTemplates=N.siteTemplates or {{'portal','Портал служб'},{'reference','Инженерный центр'},{'bulletin','Научный бюллетень'}}
N.siteThemes={{'crimson','Кармин'},{'cyan','Бирюза'},{'amber','Янтарь'},{'slate','Графит'},{'green','Фосфор'}}
local accents={crimson=Color(220,64,88),cyan=Color(39,161,166),amber=Color(223,151,50),slate=Color(104,123,148),green=Color(99,198,127)}
surface.CreateFont('FoundationWebHero',{font='Bahnschrift',size=62,weight=600,extended=true,antialias=true})
surface.CreateFont('FoundationWebSerif',{font='Georgia',size=54,weight=500,extended=true,antialias=true})
function N.SiteSections(body)
 local sections={};local current
 for _,line in ipairs(string.Explode('\n',body or '')) do
  if line:sub(1,2)=='# ' then current={title=line:sub(3),lines={}};sections[#sections+1]=current
  elseif line~='' then
   if not current then current={title='Информация',lines={}};sections[#sections+1]=current end
   current.lines[#current.lines+1]=line
  end
 end
 return sections
end
local function text(parent,value,font,color,margin)
 local l=parent:Add('DLabel');l:Dock(TOP);l:DockMargin(0,0,0,margin or 18);l:SetFont(font);l:SetTextColor(color);l:SetText(value or '')
 l:SetWrap(true);l:SetAutoStretchVertical(true);return l
end
local function fit(p,min,padding)
 p.Think=function(s)
  local height=padding
  for _,c in ipairs(s:GetChildren()) do if c:IsVisible() then local _,top,_,bottom=c:GetDockMargin();height=height+c:GetTall()+top+bottom end end
  height=math.max(min,height);if s:GetTall()~=height then s:SetTall(height) end
 end
end
local function block(parent,bg,min,pad)
 local p=parent:Add('DPanel');p:Dock(TOP);p:DockMargin(0,0,0,20);p:SetTall(min);p:DockPadding(pad,pad,pad,pad)
 p.Paint=function(_,w,h) surface.SetDrawColor(bg);surface.DrawRect(0,0,w,h) end
 fit(p,min,pad*2);return p
end
local function link(parent,v,accent,go,light)
 local b=parent:Add('DButton');b:Dock(TOP);b:DockMargin(0,0,0,12);b:SetTall(78);b:SetText('');b.foundationControl='button'
 b.Paint=function(s,w,h)
  local t=N.Hover(s)
  surface.SetDrawColor(light and Color(223-12*t,228-8*t,223-5*t) or Color(23+8*t,43+12*t,52+12*t));surface.DrawRect(0,0,w,h)
  N.Icon(v.url:match('scip://([^/]+)'),16,22,32,accent)
  surface.SetDrawColor(accent);surface.DrawRect(0,h-2,w*(.08+t*.92),2)
  draw.SimpleText('↗','FoundationTitle',w-48,22,accent)
 end
 local label=text(b,v.title,'FoundationDocumentMeta',light and Color(28,44,49) or Color(239,246,248),0)
 b:DockPadding(64,24,70,12)
 b.Think=function(s) local h=math.max(78,label:GetTall()+40);if s:GetTall()~=h then s:SetTall(h) end end
 b.DoClick=function() if ix.Fieldlink and ix.Fieldlink.Sound then ix.Fieldlink.Sound('click') end;go(v.url) end
 return b
end
N.SiteUI={text=text,fit=fit,block=block,link=link,accents=accents}
function N.RenderSite(parent,data,go)
 return N.RenderSourceSite(parent,data,go)
end
