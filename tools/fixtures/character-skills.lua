-- Additional native VGUI methods needed by the character page preview/tests.
local make=vnew
function vnew(...)
 local p=make(...)
 function p:SetMouseInputEnabled(v) self.mouse=v end
 function p:SetTooltip(v) self.tooltip=v end
 function p:SetHideButtons() end
 function p:GetDisabled() return false end
 function p:IsDown() return false end
 function p:LocalCursorPos() return -1,-1 end
 return p
end
local controls={}
vgui.Register=function(name,p) controls[name]=p end
vgui.GetControlTable=function(name) return controls[name] or {} end
hook.Add=function() end;hook.Remove=function() end
ix.Locale={lang='ru'}
ix.action={Register=function() end}
function L(v) return v end
function ScrW() return previewWidth or 1920 end
function ScrH() return previewHeight or 1080 end
ix.Civic={Scale=function(v) return math.floor(v*math.Clamp(math.min(ScrW()/1600,ScrH()/900),.7,1.6)+.5) end,
 Snapshot=function() return {faction='Служба безопасности',name='Thomas',level=12,money='250 жет.'} end}
ix.Anatomy={Read=function() return {blood=1,health={hediffs={}},parts={}} end,Color=function() return Color(80,200,160) end,
 HitTest=function() end,Draw=function(x,y,w,h)
  -- Silhouette is substituted; the production health layout and all skills paint run.
  surface.SetDrawColor(56,29,38);surface.DrawRect(x+w*.35,y+h*.2,w*.3,h*.45)
  surface.DrawRect(x+w*.39,y+h*.02,w*.22,h*.15)
  surface.DrawRect(x+w*.34,y+h*.65,w*.12,h*.33);surface.DrawRect(x+w*.55,y+h*.65,w*.12,h*.33)
 end}
function SkillsPreview()
 local panel=vnew('Panel')
 for k,v in pairs(vgui.GetControlTable('ui.tabmenu')) do panel[k]=v end
 panel.Paint=nil;panel.PerformLayout=nil;panel.Think=nil
 panel:SetSize(ScrW(),ScrH())
 panel.body=panel:Add('Panel');panel.body:SetPos(ix.Civic.Scale(40),ix.Civic.Scale(186))
 panel.body:SetSize(ScrW()-ix.Civic.Scale(80),ScrH()-ix.Civic.Scale(268))
 panel.character={skills={electric={3,85},medicine={10,0},guns={2,30}}}
 function panel.character:GetSkills() return self.skills end
 function panel.character:GetSkillModified(id) return (self.skills[id] and self.skills[id][1] or 0)+(id=='electric' and 1 or 0) end
 panel:Identity()
 return panel
end
