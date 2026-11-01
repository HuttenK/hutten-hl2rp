-- Isolated real-VGUI test with synthetic game data. NOT a full-schema test.
timer.Simple(8, function()
    ix={gui={},UI={MenuEntries={primary={},secondary={}}},Item={instances={},DropPreview=function() end},
        Locale={stored={}},faction={indices={{name='Civilian / Sector 24'}}},currency={Get=function(n) return n..' TOKENS' end}}
    function ix.Locale:AddTable(lang,t) self.stored[lang]=t end
    function L(key,...) return string.format(ix.Locale.stored.en[key] or key,...) end
    include('civic/utf8.lua')
    local char={}
    function char:GetID() return 1 end
    function char:GetName() return 'Alexei Morozov' end
    function char:GetFaction() return 1 end
    function char:GetMoney() return 1240 end
    function char:GetLevel() return 12 end
    function char:GetLevelXP() return 640 end
    function char:GetSkillPoints() return 3 end
    function char:GetHunger() return 68 end
    function char:GetThirst() return 21 end
    function char:GetMaxStamina() return 100 end
    function char:GetSkillMemory() return 540 end
    function char:GetMaxSkillMemory() return 750 end
    function char:GetData(_,default) return default end
    function char:Health() return {GetPercent=function() return 0.86 end} end
    local meta=FindMetaTable('Player')
    function meta:GetCharacter() return char end
    function meta:GetLocalVar(_,default) return 76 end
    function meta:GetNetVar(_,default) return default end
    local board={tasks={{id=1,title='Restore the workshop circuit',summary='The eastern workshop has lost power. An electrician is needed to inspect the fusebox.',posterName='Civil Workers Union',posterID=2,status='open',reward='Payment by arrangement'}},details={}}
    ix.plugin={Get=function(id)
        if id=='taskboard' then return board end
        if id=='!!levelsystem' then return {GetRequiredLevelXP=function() return 1200 end} end
        if id=='blackout' then return {zones={},IsPosBlackedOut=function() return false end} end
    end}
    netstream={Start=function() end}
    ix.util={TabFocus=function() end,TabRequestFocus=function() end}
    vgui.Register('ui.tabmenu.legacy',{VGUIMousePressed=function() end,PlayerBindPress=function() end},'EditablePanel')
    include('civic/theme.lua')
    include('civic/dashboard.lua')
    include('civic/workspace.lua')
    gui.HideGameUI()
    local menu=vgui.Create('ui.tabmenu')
    print('[CIVIC SMOKE] workspace created')
    local function capture(name)
        hook.Add('PostRender','civic.capture',function()
            hook.Remove('PostRender','civic.capture')
            local data=render.Capture({format='png',x=0,y=0,w=ScrW(),h=ScrH(),alpha=false})
            if data then file.Write('civic-'..name..'.png',data) end
            print('[CIVIC SMOKE] captured '..name)
        end)
    end
    timer.Simple(3,function() capture('overview') end)
    timer.Simple(5,function() menu:ShowPage('assignments') end)
    timer.Simple(7,function() capture('assignments') end)
    timer.Simple(9,function() menu:ShowPage('journal') end)
    timer.Simple(11,function() capture('journal') end)
    timer.Simple(13,function() menu:Close(); print('[CIVIC SMOKE] close passed') end)
    timer.Simple(15,function() RunConsoleCommand('quit') end)
end)
