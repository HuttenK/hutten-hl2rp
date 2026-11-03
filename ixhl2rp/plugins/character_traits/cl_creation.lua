local T=ix.Traits
local icons={}
function T.CraftProgress()
 local bar=ix.bar
 if not bar or (bar.actionEnd or 0)<=CurTime() or not (bar.actionText or ""):find("ИЗГОТОВЛЕНИЕ: ",1,true) then return end
 return math.Clamp((CurTime()-bar.actionStart)/math.max(.01,bar.actionEnd-bar.actionStart),0,1),bar.actionEnd-CurTime()
end
function T.Icon(id)
 local path=T.byID[id].icon
 if not icons[path] then icons[path]=Material(path,"smooth") end
 return icons[path]
end
function T.Toggle(selected,id)
 local result=table.Copy(selected or {})
 if result[id] then result[id]=nil;return result end
 local conflict=T.Conflict(result,id)
 if conflict then result[conflict]=nil end
 result[id]=(id=="one_eyed" or id=="one_legged") and "left" or true
 return result
end
function T.BuildCreation(menu)
 local U,S=ix.InterfaceOS,ix.Legends.Scale
 local selected=menu.draft.traits or {}
 local balance=T.Balance(selected)
 U.Label(menu.content,"Осталось очков: "..balance,"Heading",balance<0 and Color(211,102,91) or U.accent)
 U.Label(menu.content,"Недостатки дают очки, достоинства тратят. Можно закончить с нулём или с запасом. Ступени одной черты заменяют друг друга.","Small",U.muted)
 local function update(selection)
  local scroll=menu.content:GetVBar():GetScroll()
  menu.draft.traits=selection
  menu.draft.genetic[2]=T.ClampHeight(menu.draft.genetic[2],selection)
  menu:ShowStep()
  menu.content:InvalidateLayout(true)
  menu.content:GetVBar():SetScroll(scroll)
 end
 for _,sign in ipairs({-1,1}) do
  U.Label(menu.content,sign<0 and "ДОСТОИНСТВА" or "НЕДОСТАТКИ","Heading",U.accent)
  for _,trait in ipairs(T.list) do
   if (trait.points<0 and sign<0) or (trait.points>0 and sign>0) then
    local active=selected[trait.id]~=nil
    local conflict=T.Conflict(selected,trait.id)
    local button=U.Button(menu.content,trait.name,function() update(T.Toggle(selected,trait.id)) end)
    button:Dock(TOP);button:DockMargin(0,0,S(8),S(7));button:SetTall(S(92))
    button:SetTooltip(trait.name.."\n"..trait.description..(conflict and "\nЗаменит: "..T.byID[conflict].name or ""))
    button.Paint=function(p,w,h)
     U.ButtonFace(p,w,h,false,active)
     local mat=T.Icon(trait.id)
     if not mat:IsError() then
      surface.SetMaterial(mat);surface.SetDrawColor(255,255,255,active and 255 or 200)
      surface.DrawTexturedRect(S(12),S(17),S(50),S(50))
     end
     U.Text(U.Fit(trait.name,"Body",w-S(139)),"Body",S(74),S(13),active and U.accent or U.ink)
     U.Text((active and "✓ " or "")..(trait.points>0 and "+" or "")..trait.points,"Body",w-S(16),S(13),U.accent,TEXT_ALIGN_RIGHT)
    end
    local desc=button:Add("DLabel")
    desc:SetFont("legends.Small");desc:SetTextColor(U.muted);desc:SetText(trait.description)
    desc:SetWrap(true);desc:SetMouseInputEnabled(false)
    button.PerformLayout=function(p,w)
     local width=math.max(S(60),w-S(90))
     if p.descriptionWidth~=width then
      p.descriptionWidth=width
      local lines=ix.util.WrapText(trait.description,width,"legends.Small")
      surface.SetFont("legends.Small")
      local _,lineHeight=surface.GetTextSize("AgАя")
      local height=#lines*lineHeight+S(6)
      desc:SetPos(S(74),S(37));desc:SetSize(width,height)
      p:SetTall(math.max(S(92),height+S(50)))
     end
    end
    if active and (trait.id=="one_eyed" or trait.id=="one_legged") then
     U.Choice(menu.content,"Сторона утраты",{{value="left",label="Левая"},{value="right",label="Правая"}},selected[trait.id],function(side)
      local values=table.Copy(selected);values[trait.id]=side;update(values)
     end)
    end
   end
  end
 end
 menu.next:SetDisabled(balance<0)
end
function T.BuildSummary(parent,characterOrSelection)
 local U=ix.InterfaceOS
 local selected=characterOrSelection.GetTraits and T.Selection(characterOrSelection) or characterOrSelection
 local count=0
 for _,trait in ipairs(T.list) do
  if selected[trait.id] then
   count=count+1
   U.Label(parent,trait.name.." — "..trait.description,"Small",U.muted)
  end
 end
 if count==0 then U.Label(parent,"Нет выбранных черт.","Small",U.muted) end
end
hook.Add("CharacterVarChanged","ixTraitsClientCaches",function(character,key)
 if key~="traits" then return end
 local health=character.Health and character:Health()
 if health then health.cachedParts=nil;health:OnUpdateDiffs() end
 local genetic=character.Genetic and character:Genetic()
 if genetic then genetic.cachedDesc=nil end
 local client=character:GetPlayer()
 if IsValid(client) then client.recalculateSpeed=true end
end)
