-- In-world document renderer. No website chrome, external URLs or source credits.
local N=ix.FoundationNet
local U=N.SiteUI
local text,block=U.text,U.block
N.catalogRenderers={}
surface.CreateFont('FoundationDocumentBody',{font='Tahoma',size=32,weight=500,extended=true,antialias=true})
surface.CreateFont('FoundationDocumentMeta',{font='Bahnschrift',size=26,weight=600,extended=true,antialias=true})
surface.CreateFont('FoundationDocumentTitle',{font='Bahnschrift',size=58,weight=650,extended=true,antialias=true})
surface.CreateFont('FoundationDocumentCode',{font='Bahnschrift',size=78,weight=650,extended=true,antialias=true})
surface.CreateFont('FoundationDocumentTerminal',{font='Consolas',size=32,weight=500,extended=true,antialias=true})
N.documentPalette={background=Color(9,17,25),panel=Color(17,31,43),text=Color(239,246,248),muted=Color(194,212,224)}
local accents={crimson=Color(255,139,148),cyan=Color(119,227,230),amber=Color(255,209,121),slate=Color(171,203,244),green=Color(140,241,172)}
local ledger={engineering=true,reference=true,security=true,logistics=true}
local clinical={research=true,medical=true}
local archive={records=true,bulletin=true,scp173=true,scp096=true,scp3114=true,scp049=true}
local function columns(parent)
 local row=parent:Add('DPanel');row:Dock(TOP);row:SetTall(380);row:DockMargin(0,0,0,26);row.Paint=function() end
 local a=block(row,Color(0,0,0,0),0,0);a:Dock(NODOCK);a:DockMargin(0,0,0,0);a.Paint=function() end
 local b=block(row,Color(0,0,0,0),0,0);b:Dock(NODOCK);b:DockMargin(0,0,0,0);b.Paint=function() end
 row.PerformLayout=function(_,w) local first=math.floor((w-40)*.56);a:SetPos(0,0);a:SetWide(first);b:SetPos(first+40,0);b:SetWide(w-first-40) end
 row.Think=function(s) local h=math.max(a:GetTall(),b:GetTall(),380);if s:GetTall()~=h then s:SetTall(h) end end
 return a,b
end
local function illustration(parent,d,accent)
 local p=parent:Add('DPanel');p:Dock(TOP);p:SetTall(370);p:DockMargin(0,0,0,24)
 p.Paint=function(_,w,h)
  surface.SetDrawColor(3,9,13);surface.DrawRect(0,0,w,h)
  N.Art(d.image,10,10,w-20,h-20,255,true)
  if d.code then
   surface.SetDrawColor(0,0,0,36);for y=10,h-10,4 do surface.DrawRect(10,y,w-20,1) end
   surface.SetDrawColor(96,122,111,20);surface.DrawRect(10,10,w-20,h-20)
  end
  surface.SetDrawColor(accent);surface.DrawRect(0,h-3,w,3)
 end
end
local function jump(scroll,anchor)
 if not IsValid(scroll) or not IsValid(anchor) or not scroll.GetCanvas or not scroll.GetVBar then return end
 local _,y=anchor:LocalToScreen(0,0);local _,top=scroll:GetCanvas():LocalToScreen(0,0)
 scroll:GetVBar():SetScroll(math.max(0,y-top))
end
function N.RenderSourceSite(parent,d,go)
 local palette=N.documentPalette
 local accent=accents[d.theme] or accents.cyan
 local machine=d.template=='scp079'
 local paper=archive[d.template]
 local bg=machine and Color(6,19,15) or palette.background
 local p=block(parent,bg,500,34)
 local mast=block(p,clinical[d.template] and Color(18,47,58) or Color(18,35,46),94,20)
 text(mast,'УВС-19F  /  '..(d.code and 'АРХИВ ОБЪЕКТОВ' or 'СЛУЖЕБНАЯ ДОКУМЕНТАЦИЯ'),'FoundationDocumentMeta',accent,12)
 local info=(d.publicAccess and 'ОТКРЫТЫЙ ДОСТУП' or 'ДОПУСК '..(d.accessLabel or 'L'..(d.level or 1)))..'   /   РЕДАКЦИЯ '..(d.revision or 1)
 if d.classification then info=info..'   /   '..d.classification end
 text(mast,info,'FoundationDocumentMeta',palette.muted,0)
 if d.disruption and d.risk then text(mast,'КЛАСС ПОМЕХ: '..d.disruption..'   /   РИСК: '..d.risk,'FoundationDocumentMeta',palette.muted,0) end
 local head=p
 if d.image and d.image~='none' and N.artwork[d.image] then
  local left,right=columns(p);head=left;illustration(right,d,accent)
 end
 text(head,d.code or d.title,'FoundationDocumentCode',palette.text,20)
 if d.status then text(head,d.status,'FoundationDocumentMeta',accent,20) end
 if d.summary and d.summary~='' then text(head,d.summary,'FoundationDocumentMeta',palette.muted,20) end
 local sections=N.SiteSections(d.body)
 local targets={}
 if #sections>3 then
  local toggle=p:Add('DButton');toggle:Dock(TOP);toggle:SetTall(66);toggle:DockMargin(0,0,0,18);toggle:SetText('');toggle.foundationControl='button'
  local toc=block(p,Color(14,28,38),0,18);toc:SetVisible(false)
  toggle.Paint=function(s,w,h)
   N.ButtonFace(s,w,h,toc:IsVisible())
   draw.SimpleText((toc:IsVisible() and '−' or '+')..'  СОДЕРЖАНИЕ / '..#sections..' РАЗДЕЛОВ','FoundationDocumentMeta',20,h/2,accent,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
  end
  toggle.DoClick=function() toc:SetVisible(not toc:IsVisible());p:InvalidateLayout(true) end
  for index,section in ipairs(sections) do
   U.link(toc,{title=string.format('%02d  ',index)..section.title,url='scip://document'},accent,function() jump(parent,targets[index]) end,false)
  end
 end
 for index,section in ipairs(sections) do
  local pane=block(p,machine and Color(10,29,22) or palette.panel,0,30);targets[index]=pane
  pane.Paint=function(_,w,h)
   surface.SetDrawColor(machine and Color(10,29,22) or palette.panel);surface.DrawRect(0,0,w,h)
   surface.SetDrawColor(accent)
   if paper then surface.DrawRect(0,0,w,3) else surface.DrawRect(0,0,4,h) end
  end
  local title=section.title
  if ledger[d.template] then title=string.format('%02d   ',index)..title end
  text(pane,title,'FoundationDocumentTitle',palette.text,24)
  -- Individual paragraphs preserve lists and keep long appendices within normal label bounds.
  for _,line in ipairs(section.lines) do text(pane,line,machine and 'FoundationDocumentTerminal' or 'FoundationDocumentBody',palette.text,20) end
 end
 if #(d.links or {})>0 then
  text(p,'СВЯЗАННЫЕ ДОКУМЕНТЫ','FoundationDocumentMeta',accent,20)
  for _,v in ipairs(d.links) do U.link(p,v,accent,go,false) end
 end
 text(p,'КОНЕЦ ДОКУМЕНТА  /  УВС-19F','FoundationDocumentMeta',palette.muted,0)
 return p
end
for _,v in ipairs(N.siteTemplates) do N.catalogRenderers[v[1]]=N.RenderSourceSite end
