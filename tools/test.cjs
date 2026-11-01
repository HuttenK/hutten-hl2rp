const fs = require('fs');
const path = require('path');
const {lua,lauxlib,lualib,to_luastring,to_jsstring} = require('fengari');
const {normalize} = require('./glua.cjs');
const root = path.resolve(__dirname,'..');
let passed = 0;
function suite(name, files, assertions, setup = '') {
  const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
  const prelude = fs.readFileSync(path.join(__dirname,'fixture.lua'),'utf8');
  const source = [prelude,setup,...files.map(file=>`do\n${normalize(fs.readFileSync(path.join(root,file),'utf8'))}\nend`),assertions].join('\n');
  const status = lauxlib.luaL_dostring(L,to_luastring(source));
  if(status !== lua.LUA_OK) throw new Error(name + ': ' + to_jsstring(lua.lua_tostring(L,-1)));
  passed++; console.log('PASS ' + name);
}
suite('XP cap, rollover, losses, donor bonus, admin idempotency and non-finite input',
 ['ixhl2rp/plugins/!!levelsystem/sv_plugin.lua'], `
 local c = character(1,0,0)
 c:AddLevelXP(250); eq(c.level,3); eq(c.xp,50); eq(c.points,4)
 c:AddLevelXP(-75); eq(c.level,2); eq(c.xp,75); eq(c.points,2)
 c:AddLevelXP(-10000); eq(c.level,1); eq(c.xp,0); eq(c.points,0)
 c:SetProgressionLevel(3,true); eq(c.points,4)
 c:SetProgressionLevel(3,true); eq(c.points,4)
 c:SetProgressionLevel(1,true); eq(c.points,0)
 c.player.donor=true; c:AddLevelXP(200); eq(c.level,3); near(c.xp,30)
 c.level=99; c.xp=99; c:AddLevelXP(100000); eq(c.level,100); eq(c.xp,0)
 c:AddLevelXP(1); eq(c.level,100); eq(c.xp,0)
 c:AddLevelXP(-20); eq(c.level,99); eq(c.xp,80)
 local xp=c.xp; eq(c:AddLevelXP(0/0),false); eq(c.xp,xp)
 eq(c:AddLevelXP(math.huge),false); eq(c.xp,xp)
 `);
suite('Skill allocation is atomic and rejects forged totals, signs, IDs, NaN and fractional costs',
 ['ixhl2rp/plugins/!!skills/sv_plugin.lua'], `
 local c=character(1,0,8); c.specials={st=4,en=4}
 local function allocate(spent, changes)
   net.amount=spent; net.payload=changes; net.handlers.ixLevelUp(256,c.player)
 end
 allocate(4,{st=8}); eq(c.specials.st,4); eq(c.points,8)
 allocate(-4,{st=-4}); eq(c.specials.st,4); eq(c.points,8)
 allocate(4,{fake=4}); eq(c.points,8)
 allocate(4,{en=1,st=3}); eq(c.points,8)
 allocate(4,{st=0/0}); eq(c.points,8)
 allocate(4,{st=4}); eq(c.specials.st,8); eq(c.points,4)
 allocate(4,{en=4}); eq(c.specials.en,8); eq(c.points,0)
 c.points=-4; allocate(-4,{en=-4}); eq(c.specials.en,4); eq(c.points,0)
 c.points=-8; allocate(-8,{st=-20}); eq(c.specials.st,8); eq(c.points,-8)
 net.handlers.ixLevelUp(256,{valid=true,GetCharacter=function() return nil end})
 `);
suite('City stock conservation, shortage fulfillment, live orders and finite prices',
 ['ixhl2rp/plugins/citysystem/sv_city.class.lua'], `
 local stock=ix.meta.CityStock:New({})
 local item=stock:GetItem('food',true)
 eq(item:GetPrice(),1)
 stock:AddItem('food',10); eq(item:GetStored(),10); eq(item:GetSupply(),10)
 eq(stock:TakeItem('food',15),10); eq(item:GetStored(),0); eq(item:GetDemand(),15)
 eq(stock:TakeItem('food',-10),0); eq(item:GetStored(),0)
 stock:AddItem('food',0/0); eq(item:GetStored(),0)
 local order=stock:AddSupplyOrder('food','trade'); order:Add(5); eq(item:GetSupply(),15)
 order:Add(-100); eq(item:GetSupply(),10)
 assert(item:GetPrice()>0 and item:GetPrice()<math.huge)
 `);
suite('Task access respects power; invalid posts and full boards preserve active work; completion is owner-only',
 ['ixhl2rp/plugins/taskboard/sv_plugin.lua'], `
 local c=character(1,0,0); local other=character(1,0,0); other.id=2
 allPlayers={c.player,other.player}; nearby={{valid=true,GetClass=function() return 'ix_taskboard' end}}
 PLUGIN.tasks={}; PLUGIN.nextID=1; PLUGIN.SaveData=function() end; PLUGIN.SyncTasks=function() end
 assert(PLUGIN:NearTerminal(c.player)); blackoutOn=true; assert(not PLUGIN:NearTerminal(c.player)); blackoutOn=false
 eq(PLUGIN:AddTask(c.player,{title={}}),false); eq(#PLUGIN.tasks,0)
 assert(PLUGIN:AddTask(c.player,{title='Job',details='Private'})); eq(#PLUGIN.tasks,1)
 assert(PLUGIN:SanitizedTasks()[1].details==nil)
 netstream.handlers['taskboard.accept'](other.player,1); eq(PLUGIN.tasks[1].status,'taken')
 clock=clock+1; netstream.handlers['taskboard.complete'](other.player,1); eq(PLUGIN.tasks[1].status,'taken')
 clock=clock+1; netstream.handlers['taskboard.complete'](c.player,1); eq(PLUGIN.tasks[1].status,'completed')
 clock=clock+1; netstream.handlers['taskboard.abandon'](other.player,1); eq(PLUGIN.tasks[1].status,'completed')
 PLUGIN.tasks={}; for i=1,100 do PLUGIN.tasks[i]={id=i,status='taken'} end
 eq(PLUGIN:AddTask(c.player,{title='Full'}),false); eq(#PLUGIN.tasks,100); eq(PLUGIN.tasks[100].id,100)
 `);
// Replay actual final registrations in order. The old alias scheme is also
// reproduced below to ensure this fixture catches the reported stack overflow.
const legacyMenu = fs.readFileSync(path.join(root,'helix/gamemode/game/ui/tabmenu.lua'),'utf8');
const registrations = legacyMenu.split('\n').filter(line => /^vgui.Register\(['"]ui\.tabmenu['".]/.test(line) && !line.includes('.btn'));
suite('TAB registration avoids shared-table base cycles and survives reload',
 ['helix/gamemode/game/ui/civic.workspace.lua'], `
 assertAcyclic('ui.tabmenu'); assertAcyclic('ui.tabmenu.legacy')
 eq(vgui.GetControlTable('ui.tabmenu').Base, 'EditablePanel')
 local current = vgui.GetControlTable('ui.tabmenu')
 assert(current.PlayerBindPress and current.VGUIMousePressed and current.OnMouseWheeled)
 vgui.Register('ui.tabmenu', current, 'EditablePanel'); assertAcyclic('ui.tabmenu')
 local old = {}
 vgui.Register('broken.legacy', old, 'EditablePanel')
 vgui.Register('broken.menu', old, 'EditablePanel')
 vgui.Register('broken.menu', {}, 'broken.legacy')
 local ok = pcall(assertAcyclic, 'broken.menu'); eq(ok, false)
 `, fs.readFileSync(path.join(__dirname,'vgui-fixture.lua'),'utf8') + '\nlocal PANEL = {}\n' + registrations.join('\n'));
const animationFiles = ['helix/gamemode/core/libs/sh_anims.lua','ixhl2rp/plugins/cellaranims.lua','helix/gamemode/core/libs/sh_autorig.lua'];
const activities = [...new Set(animationFiles.flatMap(file => fs.readFileSync(path.join(root,file),'utf8').match(/\bACT_[A-Z0-9_]+\b/g) || []))];
suite('Animation classification preserves native rigs, Cellar mappings and scoped knife fallback',
 animationFiles, `
 eq(ix.anim.GetModelClass('models/police.mdl'),'metrocop')
 eq(ix.anim.GetModelClass('models/player/example.mdl'),'player')
 eq(ix.anim.GetModelClass('models/autonomous/eurasia_nemanus/metropolice/male.mdl'),'cellarMaleMPF')
 eq(ix.anim.GetModelClass('models/autonomous/eurasia_nemanus/metropolice/female.mdl'),'cellarFemaleMPF')
 eq(ix.anim.GetModelClass('models/jq/hlvr/characters/combine_soldier/combine_soldier_new_content_player.mdl'),'cellarOTA')
 eq(ix.anim.GetModelClass('models/che_pm.mdl'),'cellarOTA')
 eq(ix.anim.ResolveHoldType('cellarMale','knife'),'melee')
 eq(ix.anim.ResolveHoldType('metrocop','knife'),'knife')
 eq(ix.anim.ResolveHoldType('player','knife'),'knife')
 eq(ix.anim.ResolveHoldType('cellarOTA','ar2'),'smg')
 eq(HOLDTYPE_TRANSLATOR.knife,'knife')
 ix.config.Get=function() return false end
 local carrier={ixAnimModelClass='citizen_male',IsWepRaised=function() return false end}
 local rifle={valid=true,ARC9=true,HoldTypeHolstered='passive',GetHoldType=function() return 'passive' end}
 eq(ix.anim.GetWeaponAnimationHoldType(carrier,rifle),'smg')
 eq(ix.anim.citizen_male[ix.anim.GetWeaponAnimationHoldType(carrier,rifle)][ACT_MP_STAND_IDLE][1],ACT_IDLE_SMG1_RELAXED)
 carrier.ixAnimModelClass='cellarMale'; eq(ix.anim.GetWeaponAnimationHoldType(carrier,rifle),'smg')
 carrier.ixAnimModelClass='player'; eq(ix.anim.GetWeaponHoldType(carrier,rifle),'passive')
 rifle.HoldTypeHolstered='normal'; carrier.ixAnimModelClass='citizen_male'
 eq(ix.anim.GetWeaponAnimationHoldType(carrier,rifle),'normal')
 PLUGIN:SetupActs(); assert(actCount > 10)
 local probes=0
 local function rig(model, available, sequenceCount)
   return {valid=true,GetModel=function() return model end,GetSequenceCount=function() return sequenceCount or 100 end,
     LookupSequence=function(_,name) probes=probes+1; return available[name] and 0 or -1 end,
     SelectWeightedSequence=function(_,act) probes=probes+1; return available[act] and 0 or -1 end}
 end
 local native={}
 for _,act in ipairs({ACT_HL2MP_IDLE,ACT_HL2MP_WALK,ACT_HL2MP_RUN,ACT_HL2MP_IDLE_CROUCH,ACT_HL2MP_WALK_CROUCH}) do native[act]=true end
 local pm=rig('models/workshop/unfamiliar_ragdoll.mdl',native)
 eq(ix.anim.GetModelClass(pm:GetModel(),pm),'player')
 local previousProbes=probes; eq(ix.anim.GetModelClass(pm:GetModel(),pm),'player'); eq(probes,previousProbes)
 local sequences={}
 local function collect(tree)
   for _,value in pairs(tree) do if type(value)=='table' then collect(value) elseif type(value)=='number' or type(value)=='string' then sequences[value]=true end end
 end
 collect(ix.anim.cellarMale)
 sequences.pwalk_all=true; sequences.pidle_normal=true
 for _,act in ipairs({ACT_HL2MP_IDLE,ACT_HL2MP_WALK,ACT_HL2MP_RUN,ACT_HL2MP_IDLE_CROUCH,ACT_HL2MP_WALK_CROUCH}) do sequences[act]=true end
 for _,entry in ipairs({{'models/humans/group01/male_01.mdl','cellarMale'}, {'models/humans/group03m/female_06.mdl','cellarFemale'}, {'models/player/group01/male_08.mdl','cellarMale'}, {'models/police.mdl','cellarMaleMPF'}}) do
   local stock=rig(entry[1],sequences); eq(ix.anim.GetModelClass(stock:GetModel(),stock),entry[2])
 end
 local ota={cidle_normal=true,cwalk_normal=true,pwalk_all=true,pidle_normal=true,combatidle1_fists=true}
 local combine=rig('models/combine_soldier.mdl',ota); eq(ix.anim.GetModelClass(combine:GetModel(),combine),'cellarOTA')
 ix.anim.ClearModelDetectionCache()
 local unmounted=rig('models/player/group01/male_08.mdl',native); eq(ix.anim.GetModelClass(unmounted:GetModel(),unmounted),'player')
 local unrelated=rig('models/workshop/custom_player.mdl',sequences); eq(ix.anim.GetModelClass(unrelated:GetModel(),unrelated),'player')
 for _,act in ipairs({ACT_HL2MP_IDLE,ACT_HL2MP_WALK,ACT_HL2MP_RUN,ACT_HL2MP_IDLE_CROUCH,ACT_HL2MP_WALK_CROUCH}) do sequences[act]=nil end
 local custom=rig('models/workshop/brand_new_citizen.mdl',sequences)
 assert(ix.anim.GetModelClass(custom:GetModel(),custom):find('cellar',1,true)==1)
 local npcSequences={}; sequences=npcSequences; collect(ix.anim.citizen_male)
 local npc=rig('models/workshop/unmapped_npc.mdl',npcSequences)
 eq(ix.anim.GetModelClass(npc:GetModel(),npc),'citizen_male')
 local late=rig('models/late.mdl',native,0)
 eq(ix.anim.DetectModelClass(late,late:GetModel()),nil)
 late.GetSequenceCount=function() return 100 end
 eq(ix.anim.DetectModelClass(late,late:GetModel()),'player')
 eq(ix.anim.DetectModelClass(pm,'models/not_applied_yet.mdl'),nil)
 ix.anim.SetModelClass(pm:GetModel(),'metrocop'); eq(ix.anim.GetModelClass(pm:GetModel(),pm),'metrocop')
 local prop=rig('models/prop.mdl',{}); eq(ix.anim.DetectModelClass(prop,prop:GetModel()),nil)
 `, activities.map((name,i) => `${name}=${i+1}`).join('\n') + `
 function Vector(x,y,z) return {x=x,y=y,z=z} end
 function Angle(p,y,r) return {p=p,y=y,r=r} end
 HOLDTYPE_TRANSLATOR={knife='knife',ar2='smg'}
 actCount=0; ix.act={Register=function() actCount=actCount+1 end}
 `);
function registeredValidator(file, name) {
  const source = normalize(fs.readFileSync(path.join(root,file),'utf8'));
  const ast = require('luaparse').parse(source,{luaVersion:'5.2',ranges:true});
  let result;
  function visit(node) {
    if (!node || typeof node !== 'object') return;
    if (node.type === 'CallExpression' && node.base.identifier?.name === 'RegisterVar' &&
        node.arguments[0]?.raw === JSON.stringify(name)) {
      const field = node.arguments[1].fields.find(field => field.key?.name === 'OnValidate');
      result = source.slice(...field.value.range);
    }
    for (const value of Object.values(node)) if (typeof value === 'object') visit(value);
  }
  visit(ast);
  if (!result) throw Error('Missing validator: '+name);
  return result;
}
suite('Character creation rejects invalid SPECIAL values and forged primary attributes', [], `
 local payload={faction=1}
 eq(validateSpecials(nil,{st=0,en=8},payload,{}).en,8)
 eq(validateSpecials(nil,{st=-4,en=12},payload,{}),false)
 eq(validateSpecials(nil,{st=0/0,en=8},payload,{}),false)
 eq(validateSpecials(nil,{st=4.5,en=3.5},payload,{}),false)
 eq(validateSpecials(nil,{fake=8},payload,{}),false)
 eq(validateSpecials(nil,{st='8'},payload,{}),false)
 eq(validateSpecials(nil,nil,payload,{}),false)
 eq(validatePrimary(nil,{st=true,en=true},payload,{}).st,true)
 eq(validatePrimary(nil,{st=true,en=true,ag=true},payload,{}),false)
 eq(validatePrimary(nil,{st='true'},payload,{}),false)
 eq(validatePrimary(nil,{fake=true},payload,{}),false)
 eq(validatePrimary(nil,nil,payload,{}),false)
 `, `validateSpecials=${registeredValidator('ixhl2rp/plugins/!!skills/sh_plugin.lua','specials')}
 validatePrimary=${registeredValidator('ixhl2rp/plugins/!character/sh_plugin.lua','primaryStat')}
 ix.specials.list.ag={}; ix.faction={indices={[1]={}}}
 hook.Run=function() return 8 end
 `);
suite('Crafting station delayed opens respect close, replacement, removal and range',
 ['ixhl2rp/plugins/ixcraft/entities/entities/ix_station.lua'], `
 local function station()
   return setmetatable({valid=true, inventory={id=1,AddReceiver=function() adds=adds+1 end,
     RemoveReceiver=function() removes=removes+1 end,SyncTo=function() end},
     GetPos=function() return {} end}, {__index=ENT})
 end
 local c={valid=true,IsPlayer=function() return true end,GetCharacter=function() return {} end,
   IsRestricted=function() return false end,Ping=function() return 25 end,Alive=function() return true end,
   GetPos=function() return {DistToSqr=function() return distance end} end}
 local s=station(); s.Tags={'forge'}; assert(s:HasTag('forge')); assert(not s:HasTag('oven'))
 s:Use(c); eq(c.ixStation,s); eq(adds,1)
 net.handlers.ixOpenStationCraft(0,c); queued(); eq(sent,0); eq(removes,1)
 clock=clock+1; s:Use(c); distance=999999; queued(); eq(sent,0); eq(c.ixStation,nil); eq(removes,2)
 distance=0; clock=clock+1; s:Use(c); local first=queued
 clock=clock+1; local other=station(); other:Use(c); first(); eq(sent,0)
 queued(); eq(sent,1); eq(c.ixStation,other)
 clock=clock+1; s:Use(c); s.valid=false; queued(); eq(sent,1)
 `, `ENT={}; adds=0; removes=0; sent=0; distance=0
 hook.Add=function() end
 timer.Simple=function(_,fn) queued=fn end
 net.Start=function() end; net.WriteEntity=function() end; net.WriteUInt=function() end
 net.Send=function() sent=sent+1 end
 table.HasValue=function(t,value) for _,v in pairs(t) do if v==value then return true end end return false end
 `);
suite('Hairstyles group base models without changing faction indices or losing orphan variants',
 ['helix/gamemode/game/character/appearance/sh_modelchoices.lua'], `
 local group={{name='First',model='models/base.mdl'},{name='Second',model='models/hair2.mdl'},{name='Missing',model='models/missing.mdl'}}
 local chargen={GetHairGroup=function(_,path) if path:lower()=='models/base.mdl' then return group end end}
 local models={'models/plain.mdl',{'models/BASE.mdl',2,'000'},'models/hair2.mdl'}
 local choices=ix.BuildCharacterModelChoices(models,chargen)
 eq(#choices,2); eq(choices[1].index,1); eq(choices[2].index,2)
 eq(#choices[2].variants,2); eq(choices[2].variants[2].index,3)
 eq(choices[2].entry[2],2)
 local orphan=ix.BuildCharacterModelChoices({'models/hair2.mdl'},chargen)
 eq(#orphan,1); eq(orphan[1].variants[1].index,1)
 eq(#ix.BuildCharacterModelChoices(models,nil),3)
 eq(#ix.BuildCharacterModelChoices({},chargen),0)
 `);
function panelMethod(file, name) {
  const source=normalize(fs.readFileSync(path.join(root,file),'utf8'));
  const ast=require('luaparse').parse(source,{luaVersion:'5.2',ranges:true});
  const node=ast.body.find(node => node.type==='FunctionDeclaration' && node.identifier?.base?.name==='PANEL' && node.identifier?.identifier?.name===name);
  if (!node) throw Error('Missing panel method: '+file+':'+name);
  return source.slice(...node.range);
}
const hudSource=normalize(fs.readFileSync(path.join(root,'helix/gamemode/core/derma/cl_bar.lua'),'utf8'));
const alphaExpression=hudSource.match(/local fraction = ([^\r\n]+)/)[1];
suite('HUD and chat tolerate menus without legacy currentAlpha and respect explicit fade state', [], `
 local menu={valid=true,GetAlpha=function() return 255 end}
 eq(hudFraction(menu),0); menu.currentAlpha=128; near(hudFraction(menu),127/255)
 eq(hudFraction(nil),1)
 local drawn
 local message={alpha=200,markup={draw=function(_,x,y,a,b,alpha) drawn=alpha end}}
 ix.gui={characterMenu=menu}; PANEL.Paint(message,100,30); near(drawn,127)
 menu.currentAlpha=nil; drawn=nil; PANEL.Paint(message,100,30); eq(drawn,nil)
 menu.GetAlpha=function() return 100 end; PANEL.Paint(message,100,30); eq(drawn,155)
 `, `local PANEL={}
 ${panelMethod('ixhl2rp/plugins/chat/derma/cl_chatmessage.lua','Paint')}
 function hudFraction(menu) return ${alphaExpression} end
 `);
suite('Performance startup and setting callbacks never issue reported blocked commands',
 ['helix/plugins/au_performance/cl_hooks.lua','helix/plugins/au_performance/sh_options.lua'], `
 PLUGIN:InitPostEntity()
 for key,entry in pairs(options) do
  assert(not blocked[key]); if entry.data.OnChanged then entry.data.OnChanged(entry.default,entry.default) end
 end
 assert(calls>0)
 `, `
 PLUGIN={}; local calls=0; local options={}
 local blocked={muzzleflash_light=true,r_teeth=true,r_worldlights=true}
 ix.type={bool=1,number=2}
 ix.option={Get=function(key,default) return default end,
  Add=function(key,kind,default,data) options[key]={default=default,data=data} end}
 function RunConsoleCommand(key,value) assert(not blocked[key],key); calls=calls+1 end
 `);
suite('SCiPNet introduction waits for input, gates reveal on readiness, and respects reduced motion',
 ['helix/gamemode/game/cl_interface_os.lua'],`
 local host=panel(); ix.InterfaceOS.Boot(host); local intro=host.terminalIntro
 eq(intro.phase,'intro'); clock=100; intro:Think(); eq(intro.phase,'intro'); eq(intro.valid,true)
 intro:OnKeyCodePressed(KEY_ENTER); eq(intro.phase,'loading'); eq(intro.button.visible,false)
 local started=intro.startedAt; clock=101; intro.button:DoClick(); eq(intro.startedAt,started)
 clock=103; intro:Think(); eq(intro.phase,'loading')
 host.playerReady=true; intro:Think(); eq(intro.phase,'reveal'); eq(intro.valid,true)
 clock=104; intro:Think(); eq(intro.valid,false)
 reduced=true; local second=panel(); second.playerReady=true; ix.InterfaceOS.Boot(second)
 second.terminalIntro:Think(); eq(second.terminalIntro.valid,true)
 second.terminalIntro:OnKeyCodePressed(KEY_SPACE); second.terminalIntro:Think(); eq(second.terminalIntro.valid,false)
 `,`local clock=0; function RealTime() return clock end
 reduced=false; ix.option={Get=function() return reduced end}
 ix.Legends={Scale=function(n) return n end,PlayUISound=function() end}; surface={CreateFont=function() end,PlaySound=function() end}
 hook.Add=function() end; FILL=5; KEY_ENTER=1; KEY_SPACE=2
 function Color(...) return {...} end
 function panel()
  local p={valid=true,visible=true}
  function p:Add() return panel() end
  function p:SetZPos() end; function p:Dock() end; function p:SetMouseInputEnabled() end
  function p:SetKeyboardInputEnabled() end; function p:SetText() end; function p:SetTall() end
  function p:SetTooltip() end; function p:RequestFocus() end
  function p:SetVisible(v) self.visible=v end
  function p:Remove() self.valid=false end
  return p
 end
 `);
suite('TAB resumes the last primary app per character and ignores stale app IDs',[],`
 local function menu(id) return setmetatable({character={GetID=function() return id end},body={Clear=function() end,SetAlpha=function() end},
 SetKeyboardInputEnabled=function() end,Equipment=function(self) self.opened='equipment' end,
 Launcher=function(self) self.opened='launcher' end},{__index=PANEL}) end
 local first=menu(7); eq(first:RememberedPage(),'launcher')
 first:ShowPage('equipment'); eq(first.opened,'equipment')
 local reopened=menu(7); reopened:ShowPage(reopened:RememberedPage()); eq(reopened.opened,'equipment')
 eq(menu(8):RememberedPage(),'launcher')
 U.lastTabByCharacter[7]='removed-module'; eq(reopened:RememberedPage(),'launcher')
 `,`local PANEL={}; local U={lastTabByCharacter={}}; local pages={{'launcher'},{'identity'},{'equipment'},{'craft'},{'assignments'},{'journal'},{'system'}}
 ix.Item={DropPreview=function() end}; ix.option={Get=function() return true end}
 ${panelMethod('helix/gamemode/game/ui/legends.workspace.lua','RememberedPage')}
 ${panelMethod('helix/gamemode/game/ui/legends.workspace.lua','ShowPage')}
 `);
suite('Embedded modules receive body dimensions before construction and cannot become detached popups', [], `
 local host={Dock=function() end,SetSize=function(self,w,h) self.w=w; self.h=h end,
  DockPadding=function() end,InvalidateLayout=function() end}
 local body={GetWide=function() return 1500 end,GetTall=function() return 650 end,
  Add=function() return host end,InvalidateLayout=function() end}
 local menu={body=body,frames={},InvalidateLayout=function() end,
  SetKeyboardInputEnabled=function(self,value) self.keyboard=value end}
 ix.UI={MenuEntries={secondary={{id='help',OnShow=function(parent,container)
  eq(container.w,1500); eq(container.h,650); container:MakePopup(); eq(parent.keyboard,true)
 end}}}}
 PANEL.OpenModule(menu,'help'); eq(menu.frames.help,host)
 `, `local PANEL={}; local U={}; FILL=5
 ${panelMethod('helix/gamemode/game/ui/legends.workspace.lua','OpenModule')}
 `);
suite('Embedded crafting columns resize with their panel, standalone station layout is preserved', [], `
 local col={valid=true,SetWide=function(self,value) self.w=value end}
 local craft={isMini=true,recipeColumn=col}
 PANEL.PerformLayout(craft,1500,650); near(col.w,710.4)
 PANEL.PerformLayout(craft,900,500); near(col.w,422.4)
 craft.isMini=false; PANEL.PerformLayout(craft,1920,1080); near(col.w,422.4)
 `, `local PANEL={}; local scale=function(n) return n end
 ${panelMethod('ixhl2rp/plugins/ixcraft/derma/cl_craft.lua','PerformLayout')}
 `);
suite('Terminal controls stay inside hitboxes with stationary text and accessible states',
 ['helix/gamemode/game/cl_legends_theme.lua'], `
 local button={GetDisabled=function() return disabled end,IsHovered=function() return hovered end,
  HasFocus=function() return false end,IsDown=function() return pressed end}
 checkBackdrop=true; ix.Legends.Backdrop(1920,1080); checkBackdrop=false
 assert(rects>=4); eq(textures,1); eq(polys,0)
 for _,size in ipairs({{100,40},{290,48},{800,52}}) do
  boundsW,boundsH=size[1],size[2]
  hovered=false; pressed=false; disabled=false; reduced=true
  local idle=ix.Legends.ButtonFace(button,boundsW,boundsH,false)
  hovered=true; local hover=ix.Legends.ButtonFace(button,boundsW,boundsH,false); eq(hover,idle)
  pressed=true; local down=ix.Legends.ButtonFace(button,boundsW,boundsH,false); eq(down,idle)
  disabled=true; eq(ix.Legends.ButtonFace(button,boundsW,boundsH,false),idle)
 end
 eq(polys,0); assert(rects>4); eq(ix.Legends.Atmosphere,nil); eq(ix.option.stored.legendsAtmosphere,nil)
 `, `
 local disabled,hovered,pressed,reduced=false,false,false,true
 local boundsW,boundsH,polys,rects=nil,nil,0,0
 local checkBackdrop=false
 local textures=0
 function Material() return {IsError=function() return false end,Width=function() return 1920 end,Height=function() return 1080 end} end
 function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
 function FrameTime() return 0.016 end
 ix.Civic={Scale=function(n) return n end}
 ix.option={stored={legendsAtmosphere={}},categories={appearance={legendsAtmosphere=true}},Get=function() return reduced end}
 hook.Add=function() end; hook.Remove=function() end
 vgui={Register=function() end}; draw={NoTexture=function() end}
 surface={SetMaterial=function() end,DrawTexturedRectUV=function(_,_,w,h,u0,v0,u1,v1)
 assert(u0>=0 and v0>=0 and u1<=1 and v1<=1); textures=textures+1 end,CreateFont=function() end,SetDrawColor=function(color)
  if checkBackdrop and type(color)=="table" then assert(color.a>=0 and color.a<=255) end
 end,DrawLine=function() end,
  DrawRect=function(x,y,w,h)
 if boundsW then assert(x>=0 and y>=0 and x+w<=boundsW and y+h<=boundsH) end
 rects=rects+1 end,DrawPoly=function(points)
   polys=polys+1
   for _,p in ipairs(points) do assert(p.x>=0 and p.x<=boundsW); assert(p.y>=0 and p.y<=boundsH) end
  end}
 `);

suite('Act capabilities: native, Cellar, hybrid, zero, missing and unloaded models',
 ['helix/plugins/act/sh_resolver.lua'], `
 local e={valid=true, names={sit_passive=0}, count=5}
 function e:GetModel() return 'arbitrary.mdl' end
 function e:GetSequenceCount() return self.count end
 function e:LookupSequence(name) return self.names[name] or -1 end
 function e:GetSequenceName(id) for name,n in pairs(self.names) do if n==id then return name end end return 'custom_seat' end
 function e:SelectWeightedSequence(act) return self.activity or -1 end
 local classes={nativeSit=true,cellar={sequence={'stances_sit01'},untimed=true}}
 eq(ix.act.Resolve(e,classes,1).sequence[1],'sit_passive')
 e.names.stances_sit01=3; eq(ix.act.Resolve(e,classes,1),classes.cellar)
 e.names={}; eq(ix.act.Resolve(e,classes,1),nil)
 e.activity=4; eq(ix.act.Resolve(e,classes,1).sequence[1],'custom_seat')
 eq(ix.act.Resolve(e,classes,2),nil)
 e.count=0; eq(ix.act.Resolve(e,classes,1),nil)
 `, `ix.act={}; ix.anim={GetModelClass=function(model,entity) assert(entity); return 'player' end}; ACT_HL2MP_SIT_PASSIVE=42`);
suite('Forced sequence cancellation restores state, accepts zero and clears callbacks/timers', [], `
 local p=setmetatable({valid=true,vars={canShoot=true},move=8},{__index=playerMeta})
 eq(p:ForceSequence('missing'),false); eq(p.move,8); eq(p.vars.forcedSequence,nil)
 local callbacks=0
 eq(p:ForceSequence('zero',function() callbacks=callbacks+1 end,2),2)
 eq(p.vars.forcedSequence,0); eq(p.move,MOVETYPE_NONE)
 p:LeaveSequence(); eq(p.move,8); eq(p.vars.canShoot,true); eq(callbacks,1); eq(pending,nil)
 p:LeaveSequence(); eq(callbacks,1)
 p:ForceSequence('zero',nil,4); p:ForceSequence('zero',nil,0); eq(pending,nil)
 p:LeaveSequence(); eq(p.move,8); eq(p.vars.canShoot,true)
 p:ForceSequence('zero',function() p:ForceSequence('zero',nil,0) end,2)
 p:LeaveSequence(); eq(p.vars.forcedSequence,0); eq(p.move,MOVETYPE_NONE)
 p:LeaveSequence(); eq(p.move,8)
 ix.sharedPoses={Resolve=function(_,name) if name=='shared' then return {base=0} elseif name=='shared_timed' then return {base=0,duration=3.5,animated=true} end end,
 Begin=function(self,pose) self.vars.sharedPose=pose end,Clear=function(self) self.vars.sharedPose=nil end}
 eq(p:ForceSequence('shared',nil,0),0); eq(p.vars.sharedPose.base,0); eq(p.vars.forcedSequence,0)
 p:LeaveSequence(); eq(p.vars.sharedPose,nil); eq(p.move,8)
 p:ForceSequence('shared',nil,0); p:ForceSequence('zero',nil,0); eq(p.vars.sharedPose,nil)
 p:LeaveSequence(); eq(p.move,8)
 eq(p:ForceSequence('shared_timed'),3.5); assert(pending); pending(); eq(p.vars.sharedPose,nil); eq(p.move,8)
 eq(p:ForceSequence('shared_timed',nil,1),1); p:LeaveSequence()
 eq(p:ForceSequence('shared_timed',nil,0),0); eq(pending,nil); p:LeaveSequence()
 `, `
 playerMeta={}; MOVETYPE_NONE=0; MOVETYPE_WALK=2
 function playerMeta:LookupSequence(name) return name=='zero' and 0 or -1 end
 function playerMeta:GetNetVar(name,default) local v=self.vars[name]; if v==nil then return default end return v end
 function playerMeta:SetNetVar(name,value) self.vars[name]=value end
 function playerMeta:GetMoveType() return self.move end
 function playerMeta:SetMoveType(value) self.move=value end
 function playerMeta:SetCycle() end; function playerMeta:SetPlaybackRate() end
 function playerMeta:EntIndex() return 1 end
 function playerMeta:SequenceDuration() return 2 end
 net.Start=function() end; net.WriteEntity=function() end; net.Broadcast=function() end
 timer.Create=function(_,_,_,fn) pending=fn end; timer.Remove=function() pending=nil end
 ${normalize(fs.readFileSync(path.join(root,"helix/gamemode/core/libs/sh_anims.lua"),"utf8").split("\tfunction playerMeta:ForceSequence")[1].split("\nelse\n\tnet.Receive(\"ixSequenceSet\"")[0].replace(/^/, "function playerMeta:ForceSequence"))}
 `);


suite('Sit server rejects unsupported/forged poses and failed playback before position or collision changes',
 ['ixhl2rp/plugins/sithelper/sv_plugin.lua'], `
 local changes=0; local available=false; local playable=false; local char={GetGender=function() return 0 end,GetID=function() return 1 end}
 local p={valid=true,Team=function() return 1 end,GetCharacter=function() return char end,
 GetNetVar=function() end, IsPilotScanner=function() return false end,NotifyLocalized=function() end,
 IsProne=function() return false end, ForceSequence=function() return playable and 0 or false end,
 SetPos=function() changes=changes+1 end,SetCollisionGroup=function() changes=changes+1 end}
 PLUGIN.ResolvePose=function(_,_,option) if available and option==22 then return 'sit_passive' end end
 PLUGIN.CanSit=function() return true end
 PLUGIN.GetPoseOffset=function() return {x=0,z=0} end
 net.option=22; net.handlers.ixPlayerSit(0,p); eq(changes,0); eq(p.ixUntimedSequence,nil)
 available=true; net.option=31; net.handlers.ixPlayerSit(0,p); eq(changes,0)
 net.option=22; net.handlers.ixPlayerSit(0,p); eq(changes,0); eq(p.latestSitPos,nil)
 char=nil; net.handlers.ixPlayerSit(0,p); eq(changes,0)
 `, `
 function Vector() return 0 end
 function Angle() return {Forward=function() return 0 end} end
 math.NormalizeAngle=function(n) return n end
 GENDER_FEMALE=1
 net.BytesLeft=function() return 0,0 end
 net.ReadVector=function() return 0 end; net.ReadAngle=function() return {y=0} end
 net.ReadUInt=function() return net.option end
 PLUGIN.sitOffsetsF={}
 `);


suite('Sit preview handshake advertises only server-resolved poses',
 ['ixhl2rp/plugins/sithelper/sv_plugin.lua'], `
 local p={valid=true,GetCharacter=function() return {} end,GetModel=function() return 'sd.mdl' end}
 PLUGIN.ResolvePose=function(_,_,id) if id==23 then return 'sit_passive' end end
 net.handlers.ixSitCapabilities(16,p)
 eq(sent[1],42); eq(sent[2],'sd.mdl'); eq(sent[3],1); eq(sent[4],23)
 net.handlers.ixSitCapabilities(16,p); eq(#sent,4)
 `, `
 sent={}; net.ReadUInt=function() return 42 end; net.Start=function() end; net.Send=function() end
 net.WriteUInt=function(v) sent[#sent+1]=v end; net.WriteString=net.WriteUInt
 `);
suite('Sit client intersects server capabilities and ignores replies after key release or model change',
 ['ixhl2rp/plugins/sithelper/cl_plugin.lua'], `
 commands['+sit'](p); eq(created,0)
 replies={1,'sd.mdl',2,1,23}; net.handlers.ixSitCapabilities(); eq(created,1)
 commands['+sit'](p); commands['-sit'](p)
 replies={2,'sd.mdl',1,23}; net.handlers.ixSitCapabilities(); eq(created,1)
 commands['+sit'](p); replies={3,'other.mdl',1,23}; net.handlers.ixSitCapabilities(); eq(created,1)
 commands['+sit'](p); replies={4,'sd.mdl',1,1}; net.handlers.ixSitCapabilities(); eq(created,1); eq(notices,1)
 PLUGIN:OpenPosePlacement(23); replies={5,'sd.mdl',2,1,23}; net.handlers.ixSitCapabilities(); eq(created,2)
 commands['-sit'](p) -- A wheel selection uses mouse confirmation, not key release.
 eq(PLUGIN:PlayerBindPress(p,'+attack2',true),true)
 eq(PLUGIN:PlayerBindPress(p,'+attack2',true),nil)
 `, `
 commands={}; concommand={Add=function(n,f) commands[n]=f end}
 function Angle(a,b,c) return {p=a,y=b,r=c} end
 created=0; notices=0; p={valid=true,GetModel=function() return 'sd.mdl' end,
 EyeAngles=function() return {y=0} end,Notify=function() notices=notices+1 end}
 function LocalPlayer() return p end
 function SafeRemoveEntity(e) if e then e.valid=false end end
 function ClientsideModel() created=created+1; return {valid=true,SetNoDraw=function() end} end
 function Material() return {} end
 timer.Simple=function() end
 net.Start=function() end; net.SendToServer=function() end; net.WriteUInt=function() end
 net.ReadUInt=function() return table.remove(replies,1) end; net.ReadString=net.ReadUInt
 PLUGIN.ResolvePose=function(_,_,id) if id==23 then return 'sit_passive' end end
 `);

suite('Sit contact epsilon accepts flat support, rejects blocked/steep/missing support and exposes native variants',
 ['helix/plugins/act/sh_resolver.lua','ixhl2rp/plugins/sithelper/sh_plugin.lua'], `
 local char={GetGender=function() return 0 end}
 local e={valid=true,names={sit_zen=0,sit_passive=1,sit_fist=2}}
 function e:GetSequenceCount() return 4 end
 function e:LookupSequence(name) return self.names[name] or -1 end
 function e:GetSequenceName(id) for name,n in pairs(self.names) do if n==id then return name end end end
 function e:Alive() return true end
 function e:InVehicle() return false end
 function e:GetLocalVar() return nil end
 function e:WaterLevel() return 0 end
 function e:EyePos() return Vector(0,0,64) end
 eq(PLUGIN:ResolvePose(e,22),'sit_zen')
 eq(PLUGIN:ResolvePose(e,23),'sit_passive')
 eq(PLUGIN:ResolvePose(e,24),'sit_fist')
 eq(PLUGIN:ResolvePose(e,31),nil)
 eq(PLUGIN:GetPoseOffset(e,22,char).z,0)
 eq(PLUGIN:GetPoseOffset(e,23,char).z,-36)
 local p=Vector(0,0,0.03125)
 assert(PLUGIN:CanSit(e,p,22,char),'floor epsilon must not reject support')
 mode='solid'; eq(PLUGIN:CanSit(e,p,22,char),false)
 mode='steep'; eq(PLUGIN:CanSit(e,p,22,char),false)
 mode='missing'; eq(PLUGIN:CanSit(e,p,22,char),false)
 mode='wall'; eq(PLUGIN:CanSit(e,p,22,char),false)
 mode='flat'; far=true; eq(PLUGIN:CanSit(e,p,22,char),false); far=false
 eq(PLUGIN:CanSit(e,p,31,char),false)
 e.names.sit_zen=nil; eq(PLUGIN:ResolvePose(e,22),nil); eq(PLUGIN:ResolvePose(e,23),'sit_passive')
 `, `
 local mt={}; mt.__index=mt
 function Vector(x,y,z) return setmetatable({x=x,y=y,z=z},mt) end
 function mt.__add(a,b) return Vector(a.x+b.x,a.y+b.y,a.z+b.z) end
 function mt.__sub(a,b) return Vector(a.x-b.x,a.y-b.y,a.z-b.z) end
 function mt.__mul(a,b) return Vector(a.x*b,a.y*b,a.z*b) end
 function mt:GetNormalized() return Vector(0,0,-1) end
 function mt:Distance() return far and 101 or 64 end
 vector_origin=Vector(0,0,0); GENDER_FEMALE=1
 ix.act={}; ix.Net={Type={Vector=1},AddPlayerVar=function() end}; ix.util={Include=function() end}
 mode='flat'
 util.TraceHull=function(data)
  return {Hit=mode~='missing' and data.endpos.z<0,HitNormal=Vector(0,0,mode=='steep' and 0.5 or 1),StartSolid=mode=='solid',AllSolid=false}
 end
 util.TraceLine=function() return {Hit=mode=='wall'} end
 `);


suite('Minimal gameplay HUD respects visibility, bounds, reserve semantics and excludes numerical readouts',
 ['ixhl2rp/plugins/zz_legends_interface/cl_anatomy.lua','ixhl2rp/plugins/zz_legends_interface/cl_gameplay.lua'], `
 local H=ix.GameplayHUD
 local health=LocalPlayer():GetCharacter():Health()
 local saved=health.hediffs
 health.hediffs={}; eq(ix.Anatomy.Read(LocalPlayer():GetCharacter()).blood,1)
 health.hediffs={{uniqueID='radiation',GetSeverity=function() return 0.9 end}}; eq(ix.Anatomy.Read(LocalPlayer():GetCharacter()).blood,1)
 health.hediffs={{uniqueID='bleeding',GetSeverity=function() return 2 end}}; eq(ix.Anatomy.Read(LocalPlayer():GetCharacter()).blood,0)
 health.hediffs=saved
 eq(H.Ratio(10,0),0); eq(H.Ratio(0/0,100),0); eq(H.Ratio(math.huge,100),0)
 eq(H.Ratio(120,100),1); eq(H.Ratio(-5,100),0)
 assert(H.Visible()); enabled=false; assert(not H.Visible()); enabled=true
 hud=false; assert(not H.Visible()); hud=true
 ix.gui.menu={valid=true}; assert(not H.Visible()); ix.gui.menu=nil
 ix.gui.characterMenu={valid=true,IsClosing=function() return false end}; assert(not H.Visible()); ix.gui.characterMenu=nil
 alive=false; assert(not H.Visible()); alive=true
 hasCharacter=false; assert(not H.Visible()); hasCharacter=true
 for _,size in ipairs({{800,600},{1280,720},{1920,1080},{3440,1440}}) do
  width,height=size[1],size[2]; texts={}; H.Draw()
  assert(texts.S,'compass direction remains visible')
  for text in pairs(texts) do assert(not string.find(text,'%d'),'no numerical HUD readouts') end
  local values=H.ReadVitals(LocalPlayer(),LocalPlayer():GetCharacter())
  eq(values.blood,0.6); eq(values.anatomy.parts[1].ratio,0.5); eq(values.food,0.2); eq(values.thirst,0.8); eq(values.stamina,0.5)
  assert(warnings>0,'low food must warn')
  ix.bar={actionStart=0,actionEnd=20,actionText='Working'}; H.Action()
 end
 ix.faction.indices[1].dontNeedFood=true; H.Draw(); local values=H.ReadVitals(LocalPlayer(),LocalPlayer():GetCharacter()); eq(values.food,nil); eq(values.thirst,nil)
 `, `
 CLIENT=true; SERVER=false
 enabled=true; hud=true; alive=true; hasCharacter=true; width=1920; height=1080; texts={}; warnings=0
 function ScrW() return width end; function ScrH() return height end
 function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
 function RealTime() return 10 end
 function math.AngleDifference(a,b) return (a-b+180)%360-180 end
 local medical={body={parts={{id=2,hitgroup=1,name='Head',health=25}}},hediffs={{uniqueID='bleeding',GetSeverity=function() return 0.4 end}},GetMaxHealth=function() return 50 end,GetPartHealth=function() return 25 end}
 local char={Health=function() return medical end,GetFaction=function() return 1 end,GetHunger=function() return 20 end,GetThirst=function() return 80 end,GetMaxStamina=function() return 100 end,GetLevel=function() error("HUD must not read level") end}
 local weapon={valid=true,DrawAmmo=true,Clip1=function() return 0 end,GetMaxClip1=function() return 30 end,GetPrimaryAmmoType=function() return 1 end,GetSecondaryAmmoType=function() return 2 end}
 local p={valid=true,GetCharacter=function() return hasCharacter and char or nil end,Alive=function() return alive end,
 GetLocalVar=function() return 50 end,GetNetVar=function() return false end,Health=function() return 100 end,GetMaxHealth=function() return 100 end,
 EyeAngles=function() return {y=180} end,GetActiveWeapon=function() error("HUD must not read ammunition") end,GetAmmoCount=function(_,id) return id==1 and 12 or 0 end}
 function LocalPlayer() return p end
 function GetConVar() return {GetBool=function() return hud end} end
 gui={IsGameUIVisible=function() return false end}
 ix.gui={}; ix.faction={indices={[1]={}}}; ix.lang={AddTable=function() end}; ix.type={bool=1}
 ix.option={Add=function() end,Get=function() return enabled end}
 ix.Legends={T=function(en) return en end,accent=Color(255,53,76),line=Color(100,30,40),Rect=function(x,y,w,h,color)
 if color.r==255 and color.g==53 then warnings=warnings+1 end
 assert(w>=0 and h>=0 and x>=0 and y>=0 and x+w<=width+1 and y+h<=height+1,'HUD outside screen') end}
 function Material() return {} end
 surface={DrawPoly=function(points) for _,p in ipairs(points) do assert(p.x>=0 and p.y>=0 and p.x<=width and p.y<=height) end end,SetMaterial=function() end,DrawTexturedRect=function(x,y,w,h)
 assert(x>=0 and y>=0 and x+w<=width+1 and y+h<=height+1,'HUD shade outside screen') end,
 SetDrawColor=function() end,DrawLine=function(x,y,xx,yy)
 assert(x>=0 and y>=0 and xx>=0 and yy>=0 and x<=width and xx<=width and y<=height and yy<=height,'HUD line outside screen') end,
 CreateFont=function() end,SetFont=function() end,GetTextSize=function(t) return #t*8 end}
 draw={NoTexture=function() end,SimpleText=function(t,font,x,y,color) texts[t]=color end}
 hook.Add=function() end
 `);

suite('Character menu waits for LocalPlayer readiness and tolerates early layout',
 ['ixhl2rp/plugins/zz_legends_interface/cl_menu.lua'], `
 local panel=setmetatable({valid=true},{__index=function(_,key) return registered[key] or widget[key] end})
 panel.ResetDraft=function() resets=resets+1 end
 panel.ShowHome=function() homes=homes+1 end
 panel.PlayMusic=function() music=music+1 end
 panel:Init(); assert(panel.controlsReady); assert(not panel.playerReady)
 panel:PerformLayout(1920,1080); panel:Think(); eq(homes,0)
 player={valid=true}; panel:Think(); eq(homes,0)
 player.GetCharacter=function() return nil end; panel:Think(); eq(homes,0)
 player.HasWhitelist=function() return true end; panel:Think()
 assert(panel.playerReady); eq(homes,1); eq(resets,1); eq(music,1); eq(created,1)
 panel:Think(); eq(homes,1); eq(created,1)
 `, `
 player={}; homes=0; resets=0; music=0; created=0
 function LocalPlayer() return player end
 function ScrW() return 1920 end; function ScrH() return 1080 end
 function isfunction(x) return type(x)=='function' end
 widget={SetSize=function(self,w,h) if self.PerformLayout then self:PerformLayout(w,h) end end,
 SetPos=function() end,SetVisible=function() end,MakePopup=function() end,
 GetWide=function() return 1920 end,GetTall=function() return 1080 end,
 Add=function() return setmetatable({valid=true},{__index=widget}) end}
 ix.gui={}; ix.Legends={Scale=function(n) return n end,T=function(en) return en end,
 Button=function() return setmetatable({valid=true},{__index=widget}) end,
 Scroll=function() return setmetatable({valid=true},{__index=widget}) end}
 vgui={Register=function(_,panel) registered=panel end}
 hook.Run=function(name) if name=='OnCharacterMenuCreated' then created=created+1 end end
 `);

suite('Anatomy hover follows rounded body contours at multiple sizes',
 ['ixhl2rp/plugins/zz_legends_interface/cl_anatomy.lua'], `
 local state={parts={}}
 for i=1,7 do state.parts[i]={id=i+10,hitgroup=i} end
 local centers={{50,17},{48,59},{48,94},{85,87},{14,90},{63,156},{34,155}}
 for _,size in ipairs({{100,240},{300,420},{150,700}}) do
  local w,h=size[1],size[2]; local scale=math.min(w/100,h/240)
  local ox,oy=20+(w-100*scale)/2,30+(h-240*scale)/2
  for i,p in ipairs(centers) do
   local hit=ix.Anatomy.HitTest(ox+p[1]*scale,oy+p[2]*scale,20,30,w,h,state)
   assert(hit,'body part must be hoverable'); eq(hit.id,i+10)
  end
  eq(ix.Anatomy.HitTest(0,0,20,30,w,h,state),nil)
  eq(ix.Anatomy.HitTest(ox+50*scale,oy+220*scale,20,30,w,h,state),nil)
 end
 eq(ix.Anatomy.HitTest(0,0,0,0,0,0,state),nil)
 `);

suite('Development preview preserves point costs, undo, deficit and submission limits', [], `
 local character={GetPrimaryStat=function(_,id) return id=='st' end,GetSpecials=function() return {st=3,en=8} end,GetSkillPoints=function() return balance end}
 local p=setmetatable({character=character,points=5,remaining=5,pending={},spent=0},{__index=PANEL})
 balance=5; p:Adjust('en',1); eq(p.remaining,1); eq(p.pending.en,4)
 assert(not p:CanAdjust('en',1)); p:Adjust('st',1); eq(p.remaining,0)
 p:Adjust('en',-1); eq(p.remaining,4); eq(p.pending.en,0)
 assert(not p:CanAdjust('en',-1)); p:Submit(); eq(sent,1); eq(amount,1); eq(payload.st,1); eq(payload.en,nil)
 p:Submit(); eq(sent,1)
 p.sent=nil; p.points=-4; p.remaining=-4; p.spent=0; p.pending={}; balance=-4
 p:Adjust('en',-1); eq(p.remaining,0); eq(p.pending.en,-4)
 assert(not p:CanAdjust('en',-1)); p:Adjust('en',1); eq(p.remaining,-4)
 assert(not p:CanAdjust('en',1)); p:Adjust('en',-1); p:Submit(); eq(amount,-4)
 `, `
 local PANEL={}; ix.specials={list={st={},en={}}}; sent=0
 net.Start=function() end; net.WriteInt=function(n) amount=n end; net.WriteTable=function(t) payload=t end; net.SendToServer=function() sent=sent+1 end
 function PANEL:Remove() end
 ${panelMethod('ixhl2rp/plugins/!!levelsystem/derma/cl_levelup.lua','CanAdjust')}
 ${panelMethod('ixhl2rp/plugins/!!levelsystem/derma/cl_levelup.lua','Adjust')}
 ${panelMethod('ixhl2rp/plugins/!!levelsystem/derma/cl_levelup.lua','Submit')}
 `);

suite('Cinematic effects omit scrolling grain even with saved settings and balance rendering state',
 ['helix/plugins/visuals/effects/cl_filmgrain.lua'], `
 local C=ix.CinematicFX
 values.cinematicGrain=100 -- Previously saved settings must not restore the removed overlay.
 assert(C.Visible()); C.Draw(); eq(pixels,0); eq(uvdraws,0); eq(depth,0); eq(camera,0)
 C.Draw(); eq(pixels,0); eq(uvdraws,0)
 ix.gui.menu={valid=true}; C.Draw(); eq(uvdraws,0); ix.gui.menu=nil
 values.cinematicEffects=false; C.Draw(); eq(uvdraws,0); values.cinematicEffects=true
 values.cinematicGrain=0; values.cinematicGrade=0; values.cinematicVignette=0
 local oldGrades=grades; C.Draw(); eq(uvdraws,0); eq(grades,oldGrades)
 values.cinematicVignette=999; eq(C.Strength('cinematicVignette'),1)
 values.cinematicVignette=0/0; eq(C.Strength('cinematicVignette'),0)
 `, `
 values={}; pixels=0; uvdraws=0; depth=0; camera=0; grades=0
 ix.gui={}; ix.lang={AddTable=function() end}; ix.type={bool=1,number=2}
 ix.option={Add=function(k,_,default) values[k]=default end,Get=function(k,default) if values[k]==nil then return default end return values[k] end}
 local player={valid=true,GetCharacter=function() return {} end,Alive=function() return true end,GetNWFloat=function() return 0 end,GetNetVar=function() return false end}
 function LocalPlayer() return player end; gui={IsGameUIVisible=function() return false end}
 function Material() return {material=true,IsError=function() return false end},0.125 end; function RealTime() return 4 end
 function ScrW() return 1920 end; function ScrH() return 1080 end
 function GetRenderTargetEx() return {GetName=function() return 'test_grain' end} end
 function CreateMaterial(_,_,params) eq(params['$vertexalpha'],'1'); eq(params['$translucent'],'1'); return {material=true} end
 render={PushRenderTarget=function() depth=depth+1 end,PopRenderTarget=function() depth=depth-1 end,Clear=function() end}
 cam={Start2D=function() camera=camera+1 end,End2D=function() camera=camera-1 end}
 surface={SetDrawColor=function(r,g,b) assert(r==g and g==b,'grain must be monochrome') end,
 DrawRect=function() pixels=pixels+1 end,SetMaterial=function(mat) assert(type(mat)=='table' and mat.material,'SetMaterial received non-material') end,DrawTexturedRect=function() end,
 DrawTexturedRectUV=function(x,y,w,h,u,v,uu,vv) near(uu-u,w/64); near(vv-v,h/64); uvdraws=uvdraws+1 end}
 function DrawColorModify() grades=grades+1 end
 hook.Add=function() end; hook.Remove=function() end
 `);

suite('Immersion bounds, steady-state exposure, equipment and weather adapters',
 ['ixhl2rp/plugins/zz_immersion/sh_context.lua'], `
 local I=ix.Immersion
 eq(I.Unit(0/0),0); eq(I.Unit(-1),0); eq(I.Unit(9),1)
 near(I.Exposure(0,0),0); near(I.Exposure(1,1),0)
 assert(I.Exposure(1,0)>0 and I.Exposure(0,1)<0)
 eq(I.Exertion(100,100,0),0); eq(I.Exertion(0,100,0),1)
 assert(I.Exertion(100,100,1)>0)
 local value=0; for n=1,100 do value=I.Approach(value,1,0.1,1) end
 assert(value>0.999 and value<=1)
 local quiet=I.FootstepMix(60,true,false); local fast=I.FootstepMix(250,false,true)
 assert(quiet<fast and fast<=1.05)
 eq(I.Equipped({},'mask'),nil)
 ix.Item={instances={[9]={immersionLens=true}}}
 local p={GetInventory=function() return {GetSlot=function() return {9} end} end}
 eq(I.Equipped(p,'mask'),ix.Item.instances[9])
 eq(I.Rain(p),0)
 gWeather={IsRaining=function() return true end,GetPrecipitation=function() return 0.7 end}
 near(I.Rain(p),0.7)
 hook.Run=function() return 0 end; eq(I.Rain(p),0)
 `);
suite('Immersion lifecycle, material safety, damage fade, suppression and weapon compatibility',
 ['ixhl2rp/plugins/zz_immersion/sh_context.lua','ixhl2rp/plugins/zz_immersion/cl_context.lua'], `
 local I=ix.Immersion
 I.Update(); eq(starts,2); assert(I.State.lens and I.State.mask)
 callbacks.RenderScreenspaceEffects(); eq(camera,0)
 net.ReadFloat=function() return 0.8 end; net.ReadBool=function() return false end
 net.handlers.ixImmersionImpact(); assert(I.State.impact)
 callbacks.RenderScreenspaceEffects(); eq(camera,0)
 local before=rectangles; now=now+2; I.State.lens=false
 callbacks.RenderScreenspaceEffects(); eq(rectangles,before)
 menu=true; I.Update(); assert(stops>=starts); eq(I.State.impact,nil)
 local count=starts; I.Update(); eq(starts,count)
 menu=false; I.Update(); assert(starts>count)
 values.immersionAmbience=0; values.immersionBreathing=0; I.Update()
 eq(stops,starts)
 values.cinematicEffects=false; eq(I.Active(),false)
 values.cinematicEffects=true; mask=false; now=now+1; I.Update(); eq(I.State.lens,false)
 local input={adds=0,Add=function(self) self.adds=self.adds+1 end}
 local angle={rotations=0,Up=function() return Vector(0,0,1) end,
 Forward=function() return Vector(1,0,0) end,RotateAroundAxis=function(self) self.rotations=self.rotations+1 end}
 I.WeaponMotion(p,{valid=true,GetPDAEquipped=function() end},input,angle); eq(input.adds,0)
 I.WeaponMotion(p,{valid=true,ArcCW=true},input,angle); eq(input.adds,0)
 I.WeaponMotion(p,{valid=true},input,angle); eq(input.adds,1)
 values.disableAnimations=true; I.WeaponMotion(p,{valid=true},input,angle); eq(input.adds,1)
 local data={Entity=p,SoundName='player/footsteps/metal1.wav',Volume=0.8,Pitch=100}
 eq(callbacks.EntityEmitSound(data),true); eq(data.SoundName,'player/footsteps/metal1.wav')
 local other={Entity={},SoundName=data.SoundName,Volume=0.8}; callbacks.EntityEmitSound(other); eq(other.Volume,0.8)
 `, `
 CLIENT=true; SERVER=false; now=10; starts=0; stops=0; rectangles=0; camera=0; mask=true; menu=false
 values={}; callbacks={}
 ix.lang={AddTable=function() end}; ix.type={number=1}
 ix.option={Add=function(k,t,v) values[k]=v end,Get=function(k,f) local v=values[k]; if v==nil then return f end return v end}
 ix.CinematicFX={Visible=function() return not menu and values.cinematicEffects~=false end}
 hook.Add=function(event,id,fn) callbacks[event]=fn end
 local mt={}; mt.__add=function(a,b) return Vector(a.x+b.x,a.y+b.y,a.z+b.z) end
 mt.__mul=function(a,b) return Vector(a.x*b,a.y*b,a.z*b) end
 function Vector(x,y,z) return setmetatable({x=x,y=y,z=z},mt) end
 function RealTime() return now end; function FrameTime() return 0.1 end
 function ScrW() return 1920 end; function ScrH() return 1080 end
 function Material() return {material=true},0.2 end
 render={GetLightColor=function() return Vector(0.3,0.3,0.3) end}
 util.TraceLine=function() return {HitSky=true,Fraction=1,Hit=false} end
 MASK_SOLID_BRUSHONLY=1; IN_ATTACK2=2; IN_WALK=3
 cam={Start2D=function() camera=camera+1 end,End2D=function() camera=camera-1 end}
 surface={SetMaterial=function(m) assert(m.material) end,SetDrawColor=function() end,
 DrawTexturedRect=function() rectangles=rectangles+1 end,DrawLine=function() end}
 function DrawColorModify() end
 function CreateSound() return {PlayEx=function() starts=starts+1 end,Stop=function() stops=stops+1 end,
 ChangeVolume=function() end,ChangePitch=function() end} end
 c={GetMaxStamina=function() return 100 end}
 p={valid=true,GetNetVar=function() return false end,GetCharacter=function() return c end,ShouldDrawLocalPlayer=function() return false end,
 GetViewEntity=function(self) return self end,GetLocalVar=function(self,key) return key=='stm' and 100 or 0 end,
 EyePos=function() return Vector(0,0,0) end,WaterLevel=function() return 0 end,
 KeyDown=function() return false end,Crouching=function() return false end,InVehicle=function() return false end,
 GetVelocity=function() return {Length2D=function() return 180 end} end,
 GetInventory=function(self,slot) if mask and slot=='mask' then return {GetSlot=function() return {1} end} end end}
 ix.Item={instances={[1]={isGasmask=true,immersionLens=true}}}
 function LocalPlayer() return p end
 `);

suite('Immersion impacts notify only damaged players and throttle duplicate events',
 ['ixhl2rp/plugins/zz_immersion/sv_context.lua'], `
 local damage={GetDamage=function() return amount end,GetAttacker=function() return attacker end}
 local victim={valid=true,IsPlayer=function() return true end,GetCharacter=function() return {} end}
 handlers.PostEntityTakeDamage(victim,damage,false); eq(sent,0)
 handlers.CharacterBodyDamaged(victim,damage); eq(sent,1); eq(directional,false); near(strength,0.5)
 handlers.PostEntityTakeDamage(victim,damage,true); eq(sent,1)
 clock=clock+0.1; amount=0; handlers.CharacterBodyDamaged(victim,damage); eq(sent,1)
 amount=600; attacker={valid=true,IsWorld=function() return false end,WorldSpaceCenter=function() return 'position' end}
 handlers.CharacterBodyDamaged(victim,damage); eq(sent,2); eq(directional,true); eq(strength,1); eq(position,'position')
 `, `
 handlers={}; sent=0; amount=30; attacker={}
 hook.Add=function(event,id,fn) handlers[event]=fn end
 net.Start=function() end; net.WriteFloat=function(v) strength=v end
 net.WriteBool=function(v) directional=v end; net.WriteVector=function(v) position=v end
 net.Send=function() sent=sent+1 end
 `);

suite('FIELDLINK CID registration, device transfer, impersonation, clearance and stale requests',
 ['ixhl2rp/plugins/site_pda/sh_fieldlink.lua','ixhl2rp/plugins/site_pda/sh_identity.lua','ixhl2rp/plugins/site_pda/sv_records.lua','ixhl2rp/plugins/site_pda/sv_fieldlink.lua'], `
 local F=ix.Fieldlink
 local function item(id,kind,data)
  return {uniqueID=kind,id=id,data=data or {},GetID=function(self) return self.id end,
   GetData=function(self,k,default) local v=self.data[k]; if v==nil then return default end return v end,
   SetData=function(self,k,v) self.data[k]=v end}
 end
 local function user(id)
  local c=character(1,0,0); c.id=id; c.data.fieldlinkEnabled=true
  local p=c.player; p.items={}; p.ragdoll=0
  local w={valid=true,ixFieldlinkCharacter=id,GetClass=function() return F.class end,GetPDAEquipped=function() return true end}
  p.HasItem=function(self) return next(self.items)~=nil end
  p.HasItemByID=function(self,key) return self.items[key]~=nil,self.items[key] end
  p.GetActiveWeapon=function() return w end; p.GetLocalVar=function(self) return self.ragdoll end
  p.GetPos=function() return {x=1,y=2,z=3} end; p.EmitSound=function() end
  return p,c,w
 end
 local p,c,w=user(1); local q,d,z=user(2)
 local device=item(101,'pda'); local card=item(102,'card',{name='Registered Owner',cid='12345',number='77'}); card.equip_inv='cid'; card.isKeycard=true; card.clearanceLevel=3
 p.GetIDCard=function() return p.items[102] end; q.GetIDCard=function() return q.items[102] end
 p.items[101]=device; p.items[102]=card; c.data.fieldlinkDevice=101; w.ixFieldlinkItem=101
 PLUGIN.Send=function(self,p,msg) self.last=self:Snapshot(p); self.message=msg end
 eq(F.Ready(p),true); eq(F.Clearance(p),0); eq(PLUGIN:Snapshot(p).registered,false)
 eq(PLUGIN:Handle(p,'notes',{device=101,text='no identity'}),false)
 eq(PLUGIN:RegisterPDA(q,device,card),false)
 card.data.revoked=true; eq(PLUGIN:RegisterPDA(p,device,card),false); card.data.revoked=nil
 card.data.number=nil; eq(PLUGIN:RegisterPDA(p,device,card),false); card.data.number='77'
 card.data.name=''; eq(PLUGIN:RegisterPDA(p,device,card),false); card.data.name='Registered Owner'
 PLUGIN.state.clearances={['cid:77']=3}
 eq(PLUGIN:RegisterPDA(p,device,card),true); eq(card.data.cid,'12345')
 eq(PLUGIN:RegisterPDA(p,device,card),false); eq(F.Clearance(p),3)
 eq(PLUGIN:Handle(p,'notes',{device=101,text='device secret'}),true); eq(c:GetData('fieldlinkNotes'),nil)
 eq(PLUGIN:Handle(p,'incident',{device=101,title='Door',body='Broken',location='A',category=4}),true)
 local incident=PLUGIN.state.incidents[1]; eq(incident.authorID,'cid:77'); eq(incident.author,'Registered Owner')
 eq(PLUGIN:Handle(p,'incident',{device=101,title='Spam',body='x',location='A',category=1}),false)
 eq(PLUGIN:Handle(p,'publish',{device=101,title='Check',body='Room',level=2}),true)
 local order=PLUGIN.state.directives[1]
 p.items[101]=nil; q.items[101]=device; d.data.fieldlinkDevice=101; z.ixFieldlinkItem=101
 eq(F.Ready(p),false); eq(F.Ready(q),true); eq(F.Clearance(q),0)
 eq(PLUGIN:Handle(q,'notes',{device=101,text='no card'}),false)
 p.items[102]=nil; q.items[102]=card; eq(F.Clearance(q),3)
 local snapshot=PLUGIN:Snapshot(q); eq(snapshot.character,'cid:77'); eq(snapshot.recipient,2); eq(snapshot.notes,'device secret')
 eq(PLUGIN:Handle(q,'claim',{device=101,kind='directive',id=order.id}),true); eq(order.ownerID,'cid:77')
 eq(PLUGIN:Handle(q,'claim',{device=101,kind='directive',id=order.id}),false)
 eq(PLUGIN:Handle(q,'resolve',{device=101,kind='directive',id=order.id}),true)
 eq(PLUGIN:Handle(q,'notes',{device=999,text='stale'}),false); eq(device.data.fieldlinkNotes,'device secret')
 eq(PLUGIN:Handle(q,'notes',{device=101,text=string.rep('x',8001)}),false)
 local blank=item(103,'pda'); q.items[103]=blank; d.data.fieldlinkDevice=103
 eq(F.Ready(q),false); z.ixFieldlinkItem=103; eq(F.Ready(q),true); eq(F.Clearance(q),0)
 eq(PLUGIN:Handle(q,'alert',{device=103,level=4,text='fake'}),false)
 eq(PLUGIN:Snapshot(q).notes,''); eq(#PLUGIN:Snapshot(q).records,0)
 d.data.fieldlinkDevice=101; z.ixFieldlinkItem=101
 PLUGIN.state.clearances['cid:77']=0; eq(F.Clearance(q),3); card.clearanceLevel=0; eq(F.Clearance(q),0); eq(#PLUGIN:Snapshot(q).directives,0)
 q.IsAdmin=function() return true end; eq(F.Clearance(q),0)
 eq(PLUGIN:Handle(q,'alert',{device=101,level=4,text='fake'}),false)
 eq(#PLUGIN:Snapshot(q).incidents,1)
 z.ixFieldlinkCharacter=999; eq(F.Ready(q),false); z.ixFieldlinkCharacter=2
 q.ragdoll=9; eq(F.Ready(q),false)
 assert(saved and saved.directives[1].status=='closed')
 local reloaded=table.Copy(PLUGIN.state); PLUGIN.state={}; PLUGIN.GetData=function() return reloaded end
 PLUGIN:LoadData(); eq(PLUGIN.state.clearances['cid:77'],0); eq(PLUGIN.state.directives[1].ownerID,'cid:77')
 `, `
 ix.command={Add=function() end}; ix.type={character=1,number=2}; ix.char={loaded={}}
 ix.plugin.list.site_pda=PLUGIN
 game={GetMap=function() return 'test_map' end}
 function PLUGIN:SetData(v) saved=table.Copy(v) end
 `);
suite('PDA animation reversals remain continuous and repeated state changes do not duplicate sounds',
 ['ixhl2rp/plugins/site_pda/entities/weapons/pdaremake1.lua'], `
 local w=setmetatable({flag=false,start=0,at=clock}, {__index=SWEP})
 function w:GetPDAEquipped() return self.flag end; function w:SetPDAEquipped(v) self.flag=v end
 function w:GetPDAStartFraction() return self.start end; function w:SetPDAStartFraction(v) self.start=v end
 function w:GetPDATransitionAt() return self.at end; function w:SetPDATransitionAt(v) self.at=v end
 function w:EmitSound() sounds=sounds+1 end
 near(w:GetPDAFraction(),0)
 w:CustomEquip(true); clock=clock+0.18; near(w:GetPDAFraction(),0.5)
 local before=w:GetPDAFraction(); w:CustomEquip(false); near(w:GetPDAFraction(),before)
 clock=clock+0.18; near(w:GetPDAFraction(),0.25)
 w:CustomEquip(true); near(w:GetPDAFraction(),0.25)
 clock=clock+0.5; near(w:GetPDAFraction(),1); eq(sounds,3)
 w:CustomEquip(true); eq(sounds,3)
 w:CustomEquip(false); clock=clock+0.5; near(w:GetPDAFraction(),0)
 `, `
 SWEP={}; sounds=0
 function AddCSLuaFile() end
 function Lerp(t,a,b) return a+(b-a)*t end
 `);

suite('PDA inventory activation grants a selectable SWEP; lowering retains it; deactivation removes it',
 ['ixhl2rp/plugins/site_pda/sh_fieldlink.lua','ixhl2rp/plugins/site_pda/sh_identity.lua','ixhl2rp/plugins/site_pda/sv_fieldlink.lua'], `
 local c=character(1,0,0); local p=c.player
 local device={valid=true,raised=false,CustomEquip=function(self,v) self.raised=v end}
 local previous={valid=true,GetClass=function() return 'ix_hands' end}
 local active=previous; local owned=false
 local inventoryItem={uniqueID="pda",GetID=function() return 101 end}
 p.HasItem=function() return item end
 p.HasItemByID=function(_,id) return item and id==101,inventoryItem end
 p.GetWeapon=function() return owned and device or nil end
 p.GetActiveWeapon=function() return active end
 p.Give=function() given=given+1; owned=true; return device end
 p.SelectWeapon=function() selected=selected+1 end
 p.StripWeapon=function() owned=false; stripped=stripped+1 end
 p.SetWepRaised=function(self,v) raised=v end
 item=false; PLUGIN:ActivatePDA(p,inventoryItem); eq(given,0)
 item=true; PLUGIN:ActivatePDA(p,inventoryItem); eq(given,1); eq(selected,0); eq(c:GetData('fieldlinkEnabled'),true)
 eq(device.ixFieldlinkCharacter,c:GetID()); eq(device.raised,false)
 PLUGIN:GrantPDA(p); eq(given,1)
 active=device; device.raised=true; PLUGIN:PdaOff(p); eq(device.raised,false); eq(raised,false); eq(stripped,0); eq(owned,true)
 PLUGIN:DeactivatePDA(p); eq(stripped,1); eq(c.data.fieldlinkEnabled,false)
 PLUGIN:GrantPDA(p); eq(given,1)
 `, `
 ix.command={Add=function() end}; ix.type={character=1,number=2}
 given=0; selected=0; stripped=0; item=false
 `);
suite('PDA screen projection follows perspective, rejects outside/degenerate quads and clips scrolled children',
 ['ixhl2rp/plugins/site_pda/cl_screen.lua'], `
 local F=ix.Fieldlink
 local function project(u,v)
  local z=1+.3*u+.15*v
  return {x=(150+900*u-60*v)/z,y=(80+40*u+550*v)/z}
 end
 local q={project(0,0),project(1,0),project(1,1),project(0,1)}
 for u=0,10 do for v=0,10 do
  local p=project(u/10,v/10); local a,b=F.ScreenUV(p.x,p.y,q)
  near(a,u/10); near(b,v/10)
 end end
 local p=project(-.1,.5); eq(F.ScreenUV(p.x,p.y,q),nil)
 eq(F.ScreenUV(0,0,{{x=0,y=0},{x=0,y=0},{x=0,y=0},{x=0,y=0}}),nil)
 local root=panel(0,0,500,300)
 local viewport=panel(20,20,100,60); root.children={viewport}
 local button=panel(0,-20,100,60,'button'); viewport.children={button}
 eq(F.ScreenHit(root,30,25),button)
 eq(F.ScreenHit(root,30,15),nil)
 button.enabled=false; eq(F.ScreenHit(root,30,25),nil); button.enabled=true
 viewport.visible=false; eq(F.ScreenHit(root,30,25),nil)
 `, `
 ix.Fieldlink={}
 function panel(x,y,w,h,control)
  return {valid=true,visible=true,enabled=true,children={},fieldlinkControl=control,
   GetPos=function() return x,y end,GetWide=function() return w end,GetTall=function() return h end,
   IsVisible=function(self) return self.visible end,IsEnabled=function(self) return self.enabled end,
   GetChildren=function(self) return self.children end}
 end
 `);
suite('PDA projected input requires matching press/release, supports focus and wheel, and blocks boot/closing input',
 ['ixhl2rp/plugins/site_pda/cl_screen.lua'], `
 local F=ix.Fieldlink
 F.screenQuad={{x=0,y=0},{x=1024,y=0},{x=1024,y=576},{x=0,y=576}}; F.screenQuadAt=clock
 F.AttachScreenInput(devicePanel)
 eq(host.screenShield,shield); eq(shield.parent,host); eq(shield.mouse,true); eq(shield.keyboard,false)
 eq(shield.z,32767)
 host.OnMousePressed(host,MOUSE_LEFT); host.OnMouseReleased(host,MOUSE_LEFT); eq(clicks,1)
 host.OnMousePressed(host,MOUSE_LEFT); cursorX=700; host.OnMouseReleased(host,MOUSE_LEFT); eq(clicks,1)
 cursorX=20; devicePanel.ready=false
 host.OnMousePressed(host,MOUSE_LEFT); host.OnMouseReleased(host,MOUSE_LEFT); eq(clicks,1)
 devicePanel.ready=true; devicePanel.closing=true
 host.OnMousePressed(host,MOUSE_LEFT); host.OnMouseReleased(host,MOUSE_LEFT); eq(clicks,1)
 devicePanel.closing=false; button.fieldlinkControl='text'
 host.OnMousePressed(host,MOUSE_LEFT); eq(focused,nil); host.Think(host); eq(focused,true); eq(caret,3)
 eq(devicePanel.parent,host); eq(devicePanel.keyboard,true); eq(button.keyboard,true)
 focused=nil; button.parent=nil; eq(F.FocusScreenEditor(host,button),false); eq(focused,nil)
 button.parent=devicePanel
 button.fieldlinkControl='button'
 host.OnMouseWheeled(host,-2); near(scrolled,3)
 -- Native VGUI dispatch goes to the shield even where hidden desktop controls
 -- overlap the upper screen. It must use projected positions and click once.
 cursorX=20; cursorY=20
 shield.OnMousePressed(shield,MOUSE_LEFT); eq(shield.capture,true)
 shield.OnMouseReleased(shield,MOUSE_LEFT); eq(shield.capture,false); eq(clicks,2)
 shield.OnMouseWheeled(shield,-2); near(scrolled,3)
 F.screenQuadAt=clock-1
 host.OnMousePressed(host,MOUSE_LEFT); host.OnMouseReleased(host,MOUSE_LEFT); eq(clicks,2)
 `, `
 ix.Fieldlink={}; function RealTime() return clock end
 MOUSE_LEFT=107; KEY_ESCAPE=70; cursorX=20; cursorY=20; clicks=0; scrolled=0
 function ScrW() return 1920 end; function ScrH() return 1080 end
 input={GetCursorPos=function() return cursorX,cursorY end,IsMouseDown=function() return false end}
 utf8={len=function(s) return #s end}
 host=setmetatable({valid=true},{__index=function() return function() end end})
 shield=setmetatable({valid=true,SetZPos=function(self,z) self.z=z end,
 SetMouseInputEnabled=function(self,v) self.mouse=v end,SetKeyboardInputEnabled=function(self,v) self.keyboard=v end,
 MouseCapture=function(self,v) self.capture=v end},{__index=function() return function() end end})
 vgui={Create=function(class,parent) if class=='DPanel' then shield.parent=parent; return shield end return host end}
 button={valid=true,fieldlinkControl='button',IsVisible=function() return true end,GetChildren=function() return {} end,
 GetPos=function() return 0,0 end,GetWide=function() return 100 end,GetTall=function() return 100 end,
 GetParent=function(self) return self.parent end,SetKeyboardInputEnabled=function(self,v) self.keyboard=v end,
 DoClick=function() clicks=clicks+1 end,RequestFocus=function(self) assert(self.parent.parent==host); focused=true end,
 GetValue=function() return 'abc' end,SetCaretPos=function(_,v) caret=v end}
 devicePanel={valid=true,ready=true,IsVisible=function() return true end,
 SetParent=function(self,p) self.parent=p end,GetParent=function(self) return self.parent end,SetPos=function() end,
 SetKeyboardInputEnabled=function(self,v) self.keyboard=v end,
 GetWide=function() return 1024 end,GetTall=function() return 576 end,
 GetChildren=function() return {button} end,IsDeviceReady=function(self) return self.ready end,
 body={GetVBar=function() return {AddScroll=function(_,v) scrolled=v end} end}}
 button.parent=devicePanel
 `);
suite('PDA screen rendering unwinds camera and render target even when a child paint fails',
 ['ixhl2rp/plugins/site_pda/cl_device.lua'], `
 hooks.PostRender.FieldlinkDeviceScreen()
 eq(cameraDepth,0); eq(targetDepth,0); eq(errors,1); eq(painted,1)
 hooks.PostRender.FieldlinkDeviceScreen()
 eq(cameraDepth,0); eq(targetDepth,0); eq(errors,1); eq(painted,2)
 `, `
 ix.Fieldlink={class='pdaremake1',screenHeight=576}; ix.gui={fieldlink={valid=true,PaintManual=function() painted=painted+1; error('test paint failure') end}}
 cameraDepth=0; targetDepth=0; errors=0; painted=0; hooks={}
 hook.Add=function(event,id,fn) hooks[event]=hooks[event] or {}; hooks[event][id]=fn end
 hook.Remove=function() end; concommand={Add=function() end}
 local w={valid=true,GetClass=function() return 'pdaremake1' end,GetPDAEquipped=function() return true end}
 local p={valid=true,GetCharacter=function() return {} end,Alive=function() return true end,
 GetLocalVar=function() return 0 end,GetActiveWeapon=function() return w end,HasItem=function() return true end}
 function LocalPlayer() return p end
 function GetRenderTarget() return {GetName=function() return 'test' end} end
 function CreateMaterial() return {SetMatrix=function() end} end
 function Matrix() return {SetField=function() end} end
 render={PushRenderTarget=function() targetDepth=targetDepth+1 end,PopRenderTarget=function() targetDepth=targetDepth-1 end,Clear=function() end}
 cam={Start2D=function() cameraDepth=cameraDepth+1 end,End2D=function() cameraDepth=cameraDepth-1 end}
 function Vector(...) return {...} end
 function ErrorNoHalt() errors=errors+1 end
 `);
suite('Shared poses preserve sampled rotation across different reference poses and scale pelvis displacement without stretching limbs',
 ['tools/fixtures/sharedposes.lua','helix/plugins/act/sh_sharedposes.lua'], `
 local R=ix.sharedPoses
 local donor={name='ValveBiped.Bip01_L_Calf',localBind=rotation(30)}
 donor.localBind:SetTranslation(Vector(25,0,0))
 local target={name=donor.name,localBind=rotation(90)}; target.localBind:SetTranslation(Vector(12,0,0))
 local pose=rotation(75); pose:SetTranslation(Vector(25,0,0))
 local result=R.RetargetLocal(target,donor,pose,.75)
 near(result[1][1],math.cos(math.rad(75))); near(result[2][1],math.sin(math.rad(75)))
 near(result:GetTranslation().x,12); near(pose:GetTranslation().x,25)
 donor.name='ValveBiped.Bip01_Pelvis'; target.name=donor.name
 donor.localBind=Matrix(); donor.localBind:SetTranslation(Vector(0,0,40))
 target.localBind=Matrix(); target.localBind:SetTranslation(Vector(0,0,30))
 pose=Matrix(); pose:SetTranslation(Vector(0,0,25))
 result=R.RetargetLocal(target,donor,pose,.75); near(result:GetTranslation().z,18.75)
 `);
suite('Shared pose resolution preserves native clips and stays static-only when Pose Studio is absent',
 ['tools/fixtures/sharedposes.lua','helix/plugins/act/sh_sharedposes.lua','helix/plugins/act/sh_resolver.lua'], `
 local R=ix.sharedPoses
 local required={'Pelvis','Spine','Spine1','Spine2','Neck1','Head1','L_UpperArm','L_Forearm','L_Hand','R_UpperArm','R_Forearm','R_Hand','L_Thigh','L_Calf','L_Foot','R_Thigh','R_Calf','R_Foot'}
 local rig={height=30,bones={},names={}}
 for i,name in ipairs(required) do local name='ValveBiped.Bip01_'..name; rig.bones[i]={name=name,parent=-1}; rig.names[name]=i end
 local bad=table.Copy(rig); bad.names['ValveBiped.Bip01_Head1']=nil
 eq(R.Compatible(rig,bad),false); eq(R.Compatible(rig,rig),true)
 bad=table.Copy(rig); bad.height=100; eq(R.Compatible(rig,bad),false)
 ix.act.stored.Test={human={untimed=true,sequence={'pose_allowed'},start={'pose_start'}}}
 ix.act.stored.Dynamic={human={sequence={'dynamic_clip'}}}
 eq(R.Allowed('pose_allowed'),true); eq(R.Allowed('dynamic_clip'),false); eq(R.Allowed('arbitrary_net_input'),false)
 eq(R.Allowed('pose_start'),false)
 local closes=0
 file={Open=function() return {Size=function() return 500 end,Read=function() return 'NOPE' end,Close=function() closes=closes+1 end} end}
 eq(R.Rig('bad.mdl'),nil); eq(closes,1)
 R.Rig=function(model) return model=='unsupported.mdl' and bad or rig end
 R.Probe=function() return {valid=true,LookupSequence=function(_,name) return name=='stances_sit01' and 0 or -1 end} end
 local e={valid=true,native=false,model='compatible.mdl',GetSequenceCount=function() return 10 end,
 GetModel=function(self) return self.model end,GetSequenceName=function() return 'stances_sit01' end,
 LookupSequence=function(self,name) return (name=='idle' or (self.native and name=='stances_sit01')) and 0 or -1 end}
 local name,id,shared=ix.act.Sequence(e,{'stances_sit01'}); eq(name,'stances_sit01'); eq(id,0); assert(shared)
 e.native=true; name,id,shared=ix.act.Sequence(e,{'stances_sit01'}); eq(id,0); eq(shared,nil)
 e.native=false; e.model='unsupported.mdl'; eq(ix.act.Sequence(e,{'stances_sit01'}),nil)
 `);

suite('Shared pose renderer installs one callback, transfers the preview skeleton, and releases it on exit/model changes',
 ['tools/fixtures/sharedposes.lua','helix/plugins/act/sh_sharedposes.lua'], `
 local R=ix.sharedPoses
 local names={'Pelvis','Spine','Spine1','Spine2','Neck1','Head1','L_UpperArm','L_Forearm','L_Hand','R_UpperArm','R_Forearm','R_Hand','L_Thigh','L_Calf','L_Foot','R_Thigh','R_Calf','R_Foot'}
 local rig={height=30,count=#names,names={},bones={}}
 for i,name in ipairs(names) do
  name='ValveBiped.Bip01_'..name; local m=Matrix(); m:SetTranslation(Vector(0,0,40+i-1))
  rig.names[name]=i-1; rig.bones[i-1]={name=name,parent=-1,localBind=m,bind=m}
 end
 R.Rig=function() return rig end
 local donor={valid=true,LookupSequence=function() return 0 end,ResetSequence=function() end,SetCycle=function() end,
 SetPlaybackRate=function() end,InvalidateBoneCache=function() end,SetupBones=function() end,
 GetBoneMatrix=function(_,i) local m=Matrix(); m:SetTranslation(Vector(0,0,28+i)); return m end}
 R.Probe=function() return donor end
 local e={valid=true,model='test.mdl',added=0,removed=0,output={}}
 function e:GetModel() return self.model end
 function e:AddCallback(_,fn) self.callback=fn; self.added=self.added+1; return 42 end
 function e:RemoveCallback(_,id) eq(id,42); self.removed=self.removed+1; self.callback=nil end
 function e:InvalidateBoneCache() end
 function e:GetBoneMatrix(i) return rig.bones[i].bind end
 function e:GetBoneName(i) return rig.bones[i].name end
 function e:GetPos() return Vector(10,20,0) end
 function e:GetRenderAngles() return nil end
 function e:GetAngles() return {} end
 function e:GetModelScale() return 1 end
 function e:SetBoneMatrix(i,m) self.output[i]=m end
 function ErrorNoHalt(err) error(err) end
 local pose={model='donor.mdl',target='test.mdl',sequence='stances_sit01'}
 eq(R.Apply(e,pose),true); eq(e.added,1); e.callback(e)
 near(e.output[0]:GetTranslation().z,28); near(e.output[0]:GetTranslation().x,10)
 near(e.output[1]:GetTranslation().z,41)
 eq(R.Apply(e,pose),true); eq(e.added,1)
 e.model='changed.mdl'; eq(R.Apply(e,pose),false)
 R.Clear(e); eq(e.removed,1); eq(e.callback,nil)
 R.Clear(e); eq(e.removed,1)
 `);

require('./test-pda-media.cjs')(suite);
require('./test-ragdolls.cjs')(suite);
require('./test-gasmasks.cjs')(suite);
require('./test-downed.cjs')(suite);
require('./test-amputation.cjs')(suite);
require('./test-holsters.cjs')(suite);
require('./test-sd-creation.cjs')(suite);
require('./test-arc9-helperbones.cjs')(suite);
require('./test-arc9-sd-pose.cjs')(suite);
const arc9HoldResolver = fs.readFileSync(path.join(root, 'helix/gamemode/core/libs/sh_anims.lua'), 'utf8')
  .split('function ix.anim.GetWeaponHoldType')[1].split('function ix.anim.ResolveHoldType')[0];
suite('ARC9 uses live raised stances, distinct lowered pistol/rifle poses and respects roleplay/attachment blocks',
 ['ixhl2rp/plugins/arc9_compat.lua'], `
 eq(arc9HUDHidden,true)
 local p={valid=true,raised=false,vars={},character=true}
 function p:IsPlayer() return true end
 function p:GetCharacter() return self.character end
 function p:IsWepRaised() return self.raised end
 function p:GetNetVar(key) return self.vars[key] end
 local w={valid=true,ARC9=true,HoldType='rpg',HoldTypeHolstered='normal',current='rpg'}
 function w:GetHoldType() return self.current end
 function w:GetOwner() return p end
 function w:SetHoldType(value) self.current=value; self.sets=(self.sets or 0)+1 end
 function w:SetShouldHoldType() self.restores=(self.restores or 0)+1; self.current=self.arcState or 'rpg' end
 eq(ix.anim.GetWeaponHoldType(p,w),'normal')
 eq(PLUGIN:ARC9_Hook_BlockTPIK(w),true)
 eq(w.current,'normal')
 w.HoldTypeHolstered='passive'; eq(ix.anim.GetWeaponHoldType(p,w),'passive')
 eq(PLUGIN:ARC9_Hook_BlockTPIK(w),nil); eq(w.current,'passive')
 p.ixAnimModelClass='citizen_male'; eq(PLUGIN:ARC9_Hook_BlockTPIK(w),true)
 p.ixAnimModelClass='cellarMale'; eq(PLUGIN:ARC9_Hook_BlockTPIK(w),true)
 p.ixAnimModelClass='player'; eq(PLUGIN:ARC9_Hook_BlockTPIK(w),nil)
 local sets=w.sets; PLUGIN:ARC9_Hook_Think(w); eq(w.sets,sets)
 w.current='rpg'; PLUGIN:ARC9_Hook_Think(w); eq(w.current,'passive')
 p.raised=true; PLUGIN:ARC9_Hook_Think(w); eq(ix.anim.GetWeaponHoldType(p,w),'rpg')
 eq(w.restores,1); PLUGIN:ARC9_Hook_Think(w); eq(w.restores,1)
 p.ixAnimModelClass='cellarMale'; eq(PLUGIN:ARC9_Hook_BlockTPIK(w),nil)
 p.ixAnimModelClass='player'
 eq(PLUGIN:ARC9_Hook_BlockTPIK(w),nil)
 w.current='slam'; eq(ix.anim.GetWeaponHoldType(p,w),'slam')
 w.current='normal'; eq(ix.anim.GetWeaponHoldType(p,w),'normal')
 p.vars.forcedSequence=0; eq(PLUGIN:ARC9_Hook_BlockTPIK(w),true)
 p.vars.forcedSequence=nil; p.vars.sharedPose={}; eq(PLUGIN:ARC9_Hook_BlockTPIK(w),true)
 p.vars.sharedPose=nil; p.raised=false; alwaysRaised=true
 eq(ix.anim.GetWeaponHoldType(p,w),'normal'); eq(PLUGIN:ARC9_Hook_BlockTPIK(w),nil)
 alwaysRaised=false; PLUGIN:ARC9_Hook_Think(w); eq(w.current,'passive')
 w.arcState='slam'; alwaysRaised=true
 eq(PLUGIN:ARC9_Hook_BlockTPIK(w),nil); eq(w.current,'slam'); eq(w.restores,2)
 alwaysRaised=false; p.character=nil; eq(PLUGIN:ARC9_Hook_BlockTPIK(w),nil)
 w.ARC9=false; eq(ix.anim.GetWeaponHoldType(p,w),'rpg'); eq(PLUGIN:ARC9_Hook_BlockTPIK(w),nil)
 w.valid=false; eq(ix.anim.GetWeaponHoldType(p,w),'normal'); eq(PLUGIN:ARC9_Hook_BlockTPIK(w),nil)
 `, 'ix.anim={CanUseARC9LoweredPose=function(p,w) return (p.ixAnimModelClass or "player")=="player" and w:GetHoldType()=="passive" end}\nix.config.Get=function() return alwaysRaised or false end\n' +
 'function GetConVar(name) assert(name=="arc9_hud_force_disable") return {SetBool=function(_,v) arc9HUDHidden=v end} end\n' + normalize('function ix.anim.GetWeaponHoldType' + arc9HoldResolver));
const arc9Translate = fs.readFileSync(path.join(root, 'helix/gamemode/core/hooks/sh_hooks.lua'), 'utf8')
 .split('function GM:TranslateActivity')[1].split('\nif SERVER then')[0];
suite('ARC9 native lowered poses bypass Cellar labels only when movement clips and arm bones exist',
 ['helix/gamemode/core/libs/sh_arc9poses.lua','ixhl2rp/plugins/arc9_compat.lua'], `
 local p={valid=true,model='hybrid.mdl',count=30,ground=true,vars={},ixAnimModelClass='cellarMale',probes=0}
 function p:IsPlayer() return true end
 function p:GetCharacter() return true end
 function p:GetTable() return self end
 function p:IsWepRaised() return self.raised end
 function p:InVehicle() return self.vehicle end
 function p:OnGround() return self.ground end
 function p:GetNetVar(k) return self.vars[k] end
 function p:GetModel() return self.model end
 function p:GetSequenceCount() return self.count end
 function p:LookupBone(name) if name==self.missingBone then return nil end return 0 end
 function p:SelectWeightedSequence(act) self.probes=self.probes+1; return act==self.missingAct and -1 or 0 end
 local w={valid=true,ARC9=true,HoldTypeHolstered='passive',current='passive'}
 function w:GetOwner() return p end
 function w:GetHoldType() return self.current end
 function w:SetHoldType(v) self.current=v end
 function w:SetShouldHoldType() self.current='rpg' end
 function p:GetActiveWeapon() return w end
 assert(ix.anim.CanUseARC9LoweredPose(p,w))
 eq(PLUGIN:ARC9_Hook_BlockTPIK(w),nil)
 p.CalcSeqOverride=77
 eq(GM:TranslateActivity(p,ACT_MP_STAND_IDLE),200); eq(p.CalcSeqOverride,-1)
 eq(GM:TranslateActivity(p,ACT_MP_CROUCH_IDLE),203)
 eq(GM:TranslateActivity(p,ACT_MP_CROUCHWALK),204)
 eq(p.ixAnimModelClass,'cellarMale')
 local probes=p.probes; assert(ix.anim.CanUseARC9LoweredPose(p,w)); eq(p.probes,probes)
 p.model='npc_only.mdl'; p.missingAct=203
 assert(ix.anim.CanUseARC9LoweredPose(p,w))
 p.CalcIdeal=ACT_MP_CROUCH_IDLE
 eq(ix.anim.CanUseARC9LoweredPose(p,w),false); eq(PLUGIN:ARC9_Hook_BlockTPIK(w),true)
 p.CalcIdeal=ACT_MP_STAND_IDLE
 p.model='missing_bone.mdl'; p.missingAct=nil; p.missingBone='ValveBiped.Bip01_L_Forearm'
 eq(ix.anim.CanUseARC9LoweredPose(p,w),false)
 p.model='late.mdl'; p.missingBone=nil; p.count=0
 eq(ix.anim.CanUseARC9LoweredPose(p,w),false)
 p.count=30; assert(ix.anim.CanUseARC9LoweredPose(p,w))
 w.HoldTypeHolstered='normal'; eq(GM:TranslateActivity(p,ACT_MP_STAND_IDLE),100)
 eq(PLUGIN:ARC9_Hook_BlockTPIK(w),nil); eq(w.current,'normal')
 p.vars.forcedSequence=0; eq(PLUGIN:ARC9_Hook_BlockTPIK(w),true)
 p.vars.forcedSequence=nil; p.vars.sharedPose={}; eq(ix.anim.CanUseARC9LoweredPose(p,w),false)
 p.vars.sharedPose=nil; p.vehicle=true; eq(ix.anim.CanUseARC9LoweredPose(p,w),false)
 p.vehicle=false; p.ground=false; eq(ix.anim.CanUseARC9LoweredPose(p,w),false)
 p.ground=true; p.raised=true; eq(ix.anim.CanUseARC9LoweredPose(p,w),false)
 p.raised=false; w.ARC9=false; eq(ix.anim.CanUseARC9LoweredPose(p,w),false)
 w.ARC9=true; p.missingAct=100; ix.anim.ClearARC9PoseCache()
 eq(ix.anim.CanUseARC9LoweredPose(p,w),false)
 -- Raised/ADS uses the weapon's actual activity map, even on a Cellar-labelled rig.
 p.raised=true; p.missingAct=nil; p.model='hybrid_aim.mdl'
 w.NonTPIKAnimReload=ACT_HL2MP_GESTURE_RELOAD_REVOLVER
 w.ActivityTranslate={[1]=400,[2]=401,[3]=402,[4]=403,[5]=404}
 eq(GM:TranslateActivity(p,ACT_MP_STAND_IDLE),400)
 eq(PLUGIN:ARC9_Hook_BlockTPIK(w),nil)
 eq(ix.anim.ARC9NeedsPistolFallback(p,w),false)
 w.ActivityTranslate={[1]=500,[2]=501,[3]=502,[4]=503,[5]=504}
 eq(GM:TranslateActivity(p,ACT_MP_CROUCH_IDLE),503)
 -- A genuinely NPC-only model gets its pistol table and ordinary hand anchor.
 p.model='npc_aim.mdl'; p.missingAct=503; p.CalcIdeal=ACT_MP_CROUCH_IDLE
 ix.anim.cellarMale={pistol={}}
 eq(ix.anim.ARC9NeedsPistolFallback(p,w),true)
 eq(ix.anim.GetWeaponAnimationHoldType(p,w),'pistol')
 eq(PLUGIN:ARC9_Hook_BlockTPIK(w),true)
 w.NonTPIKAnimReload=999; eq(ix.anim.ARC9NeedsPistolFallback(p,w),false)
 -- Rifles need the same guard; this must not be a pistol-only fix.
 eq(PLUGIN:ARC9_Hook_BlockTPIK(w),true)
 eq(ix.anim.ResolveMainSequence(p,503,-1),nil)
 p.missingAct=nil
 eq(ix.anim.ResolveMainSequence(p,503,77),0)
 eq(ix.anim.ResolveMainSequence(p,nil,42),42)
 eq(ix.anim.ResolveMainSequence(p,nil,-1),nil)

 `, 'ix.anim={}\nix.config.Get=function() return false end\nGM={}\nGetConVar=function() return nil end\n' +
 'ACT_MP_STAND_IDLE=1; ACT_MP_WALK=2; ACT_MP_RUN=3; ACT_MP_CROUCH_IDLE=4; ACT_MP_CROUCHWALK=5; ACT_HL2MP_IDLE=100; ACT_HL2MP_IDLE_PASSIVE=200; ACT_HL2MP_GESTURE_RELOAD_REVOLVER=300\n' +
 normalize('function ix.anim.GetWeaponHoldType' + arc9HoldResolver) +
 normalize('function GM:TranslateActivity' + arc9Translate));

const toolMethods=fs.readFileSync(path.join(root,'ixhl2rp/plugins/ixcraft/libs/sh_crafting.lua'),'utf8').split('-- Tool capabilities')[1].split('local function ValidateItem')[0];
suite('Crafting accepts legacy tools and capability-tagged EFT tools without accepting unrelated items',[],`
 local old={uniqueID='wm_screwdriver'}
 local hammer={uniqueID='selected_eft_melee_hultafors',craftingTools={wm_hammer=true,wm_pickaxe=true}}
 local other={uniqueID='food'}
 local p={GetItems=function() return {old,hammer,other} end}
 assert(Craft:HasTool(p,'wm_screwdriver')); assert(Craft:HasTool(p,'wm_hammer'))
 eq(Craft:FindTools(p,'wm_pickaxe')[1],hammer); eq(Craft:HasTool(p,'wm_wrench'),false)
 `,'Craft={}\n'+normalize(toolMethods.slice(toolMethods.indexOf('function Craft:'))));
require('./test-arc9-inventory.cjs')(suite);
require('./test-weapon-slots.cjs')(suite);
require('./test-holster-mirror.cjs')(suite);
require('./test-weapon-persistence.cjs')(suite);
require('./test-gunsmith.cjs')(suite);
require('./test-medicine.cjs')(suite);
require('./test-scp-medical.cjs')(suite);

const registerSource=fs.readFileSync(path.join(root,'helix/gamemode/game/items/sh_item.lua'),'utf8').split('function Item:Register')[1].split('function Item:Load(')[0];
suite('Inventory action network IDs use stable ordering in both realms', [], `
 local a={functions={unequip={},equip={},drop={}},combine={register={},attach={}}}
 Item:Register('a',a)
 local b={functions={},combine={}}
 b.functions.drop={}; b.functions.equip={}; b.functions.unequip={}
 b.combine.attach={}; b.combine.register={}
 Item:Register('b',b)
 eq(a.functions.equip.index,2); eq(a.functions_id[2],'equip')
 for i,key in ipairs(a.functions_id) do eq(b.functions_id[i],key); eq(b.functions[key].index,i) end
 eq(a.combine_id[1],'attach'); eq(b.combine_id[1],'attach')
 `, 'Item={stored={}}\ntable.Count=function(t) local n=0 for _ in pairs(t) do n=n+1 end return n end\nnet.ChooseOptimalBits=function() return 3 end\n' +
 'function SortedPairs(t) local keys={} for k in pairs(t) do keys[#keys+1]=k end table.sort(keys) local i=0 return function() i=i+1 local k=keys[i] if k then return k,t[k] end end end\n' + normalize('function Item:Register'+registerSource));
suite('Datafile shutdown saves safely before load and deduplicates existing dirty records',
 ['ixhl2rp/plugins/datafile/sv_hooks.lua'], `
 assert(type(PLUGIN.datafiles_save)=='table')
 PLUGIN:SaveData(); eq(#writes,0)
 PLUGIN.datafiles_save=nil; PLUGIN:SaveData(); eq(#writes,0)
 PLUGIN.stored[7]={'Citizen','123','456',{}, {}, {}}
 PLUGIN.datafiles_save={7,7,999}; PLUGIN:SaveData()
 eq(#writes,1); eq(writes[1].id,7); eq(writes[1].character_name,'Citizen')
 eq(#PLUGIN.datafiles_save,0)
 PLUGIN:SaveData(); eq(#writes,1)
 `, `
 PLUGIN={}; writes={}; netstream={Hook=function() end}
 util.TableToJSON=function() return '[]' end
 mysql={Update=function()
  local q={}
  function q:Where(_,id) self.id=id end
  function q:Update(k,v) self[k]=v end
  function q:Execute() writes[#writes+1]=self end
  return q
 end}
 `);
const appearanceSource=fs.readFileSync(path.join(root,'helix/gamemode/game/cl_legends_theme.lua'),'utf8').split('function U.ApplyCharacterAppearance')[1].split('local PANEL = {}')[0];
suite('Portraits follow live bodygroups and skin, reset inactive groups and never copy another character',[],`
 local character={GetData=function(_,key,default) if key=='bgcache' then return {['1']=2} elseif key=='skin' then return 3 end return default end}
 local e={model='sd.mdl',groups={[0]=9,[1]=9,[2]=9},GetModel=function(self) return self.model end,
 GetNumBodyGroups=function() return 3 end,SetSkin=function(self,v) self.skin=v end,
 SetBodygroup=function(self,k,v) self.groups[k]=v end}
 live={valid=true,character=character,GetCharacter=function(self) return self.character end,
 GetModel=function() return 'sd.mdl' end,GetSkin=function() return 4 end,GetBodygroup=function(_,id) return id end}
 U.ApplyCharacterAppearance(e,character); eq(e.skin,4); eq(e.groups[2],2)
 live.GetBodygroup=function() return 0 end
 U.ApplyCharacterAppearance(e,character); eq(e.groups[2],0)
 live.character={}; U.ApplyCharacterAppearance(e,character)
 eq(e.skin,3); eq(e.groups[0],0); eq(e.groups[1],2); eq(e.groups[2],0)
 `,'U={}\nfunction LocalPlayer() return live end\n'+normalize('function U.ApplyCharacterAppearance'+appearanceSource));
const downedShading=fs.readFileSync(path.join(root,'ixhl2rp/plugins/downed_state/cl_downed.lua'),'utf8').split('-- Procedural eyelid gradient:')[1].split('local x, y = w / 2')[0];
suite('Downed eyelid shading draws without materials or texture APIs',[],`
 assert(rectangles==128)
 `, `local rectangles=0; local w,h,breath,reveal=1920,1080,.5,1
 surface={SetDrawColor=function(r,g,b,a) assert(a>=0 and a<=255) end,
 DrawRect=function(x,y,width,height) assert(x>=0 and y>=0 and y+height<=h+1); rectangles=rectangles+1 end}
 `+normalize('-- Procedural eyelid gradient:'+downedShading));
require('./test-zones.cjs')(suite);
require('./test-shaders.cjs')(suite);
require('./test-broadcast.cjs')(suite);
require('./test-tv-player.cjs');
require('./test-voice.cjs')(suite);
require('./test-faction-recognition.cjs')(suite);
require('./test-field-equipment.cjs')(suite);
require('./test-foundation-network.cjs')(suite);
require('./test-credentials.cjs')(suite);
suite('GLua normalization protects strings and comments', [], `assert(true)`);
const sample = 'local a = "! continue != //" -- !\nif !a && a != 1 then continue end';
if(!normalize(sample).includes('"! continue != //"') || !normalize(sample).includes('if not a  and  a ~= 1 then break end')) throw Error('lexical normalization');


suite('Movement camera bounds, aiming exclusion, landing recovery and reduced motion',
 ['ixhl2rp/plugins/zz_immersion/sh_context.lua','ixhl2rp/plugins/zz_immersion/cl_camera.lua'], `
 local I=ix.Immersion
 for n=1,120 do I.UpdateCamera() end
 local z,s,p,r=I.CameraOffsets();assert(math.abs(z)<=.3 and math.abs(s)<=.18 and math.abs(r)<=.16)
 aiming=true;I.UpdateCamera();z,s,p,r=I.CameraOffsets();eq(z,0);eq(s,0);eq(p,0);eq(r,0)
 aiming=false;ground=false;velocity.z=-500;I.UpdateCamera();ground=true;velocity.z=0;I.UpdateCamera()
 z=I.CameraOffsets();assert(z<0)
 for n=1,200 do I.UpdateCamera() end
 values.immersionCameraReduced=true;z,s,p,r=I.CameraOffsets();eq(r,0);assert(math.abs(z)<=.08)
 values.immersionCamera=0;eq(I.CameraEnabled(),false);I.UpdateCamera();z,s,p,r=I.CameraOffsets();eq(z,0)
 values.immersionCamera=50;values.disableAnimations=true;eq(I.CameraEnabled(),false)
 values.disableAnimations=false;ix.Downed={Crawling=function() return true end};eq(I.CameraActive(player),false)
 `, `
 values={};aiming=false;ground=true;velocity={x=180,y=0,z=0};function velocity:Length2D() return 180 end
 MOVETYPE_WALK=2;IN_ATTACK2=2;IN_SPEED=4
 ix.lang={AddTable=function() end};ix.type={number=1,bool=2};ix.option={Add=function() end,Get=function(k,d) if values[k]~=nil then return values[k] end return d end}
 ix.Immersion={Active=function() return true end};hook.Add=function() end
 local char={};player={valid=true,InVehicle=function() return false end,GetMoveType=function() return 2 end,WaterLevel=function() return 0 end,
 GetLocalVar=function(_,k,d) return d end,GetCharacter=function() return char end,GetVelocity=function() return velocity end,
 OnGround=function() return ground end,GetActiveWeapon=function() return nil end,Crouching=function() return false end,
 KeyDown=function(_,key) return key==IN_ATTACK2 and aiming end}
 function LocalPlayer() return player end;function FrameTime() return 1/60 end
 `);

const factionSources = ['citizen','foundation','mtf'].flatMap(name => ['factions','classes'].map(kind => `ixhl2rp/schema/${kind}/sh_${name}.lua`));
suite('SCP factions: exactly three, stale files ignored, Citizen-only server creation and safe transfers',
 ['ixhl2rp/schema/libs/sh_00_factionpolicy.lua','helix/gamemode/core/libs/sh_faction.lua','helix/gamemode/core/libs/sh_class.lua'], `
 ix.faction.LoadFromDir('ixhl2rp/schema/factions')
 ix.class.LoadFromDir('ixhl2rp/schema/classes')
 eq(table.Count(ix.faction.teams),3); eq(#ix.faction.indices,3); eq(#ix.class.list,3)
 eq(ix.faction.teams.administration,nil); eq(ix.faction.teams.metropolice,nil)
 local admin={HasWhitelist=function() return true end}
 eq(validateFaction(nil,FACTION_CITIZEN,{},admin),FACTION_CITIZEN)
 eq(validateFaction(nil,FACTION_FOUNDATION,{},admin),false)
 eq(validateFaction(nil,FACTION_MTF,{},admin),false)
 eq(validateFaction(nil,999,{},admin),false)
 eq(validateFaction(nil,nil,{},admin),false)
 for _,id in ipairs({FACTION_CITIZEN,FACTION_FOUNDATION,FACTION_MTF}) do
   assert(id>0); assert(id~=FACTION_MPF and id~=FACTION_OTA and id~=FACTION_ADMIN)
   local c={model='preserved',inventory='preserved',SetClass=function(self,v) self.class=v end}
   ix.faction.indices[id]:OnTransferred(c)
   eq(ix.class.list[c.class].faction,id);eq(c.model,'preserved');eq(c.inventory,'preserved')
 end
 ix.faction.teams.foundation.showCreationMenu=true
 eq(validateFaction(nil,FACTION_FOUNDATION,{},admin),false)
 `, `
 Schema={};GM={};PLUGIN=nil;D_HT=1;D_NU=2
 function Color(...) return {...} end;function Material(p) return p end
 function table.Count(t) local n=0 for _ in pairs(t) do n=n+1 end return n end
 team={SetUp=function() end,Valid=function(id) return ix.faction.indices[id]~=nil end}
 util.PrecacheModel=function() end;function ErrorNoHalt(s) error(s) end
 file={Find=function(dir) return {'sh_administration.lua','sh_citizen.lua','sh_foundation.lua','sh_metropolice.lua','sh_mtf.lua'} end}
 local includes={}
 ${factionSources.map(f => `includes[${JSON.stringify(f)}]=function()\n${normalize(fs.readFileSync(path.join(root,f),'utf8'))}\nend`).join('\n')}
 ix.util={Include=function(p) assert(includes[p],'Unexpected/stale include '..p)() end}
 validateFaction=${registeredValidator('helix/gamemode/core/libs/sh_character.lua','faction')}
 `);

require('./test-terminal-v6.cjs')(suite);
require('./test-map-areas.cjs')(suite);
require('./test-foundation-update.cjs')(suite);
require('./test-admin-permissions.cjs')(suite);
require('./test-flame-stack.cjs')(suite);
require('./test-arc9-view-ownership.cjs')(suite);
require('./test-pda-sync.cjs')(suite);
require('./test-eft-smoke.cjs')(suite);
require('./test-pose-studio.cjs')(suite);
require('./test-shared-pose-sources.cjs')(suite);
require('./test-pose-starters.cjs')(suite);
require('./test-contextual-chat.cjs')(suite);
require('./test-tv-channels.cjs')(suite);
require('./test-cctv.cjs')(suite);
require('./test-facility.cjs')(suite);
require('./test-powerbox.cjs')(suite);
require('./test-blackout-areas.cjs')(suite);
require('./test-blackout-electronics.cjs')(suite);
require('./test-map-keycards.cjs')(suite);
require('./test-blackout-lighting.cjs')(suite);
require('./test-character-skills.cjs')(suite);
require('./test-map3d-native.cjs')(suite);

require('./test-melee-holsters.cjs')(suite);
require('./test-body-drag.cjs')(suite);
require('./test-body-drag-render.cjs')(suite);
require('./test-cart-patients.cjs')(suite);
require('./test-cart-arms.cjs')(suite);
require('./test-item-model-update.cjs')(suite);
require('./test-character-height.cjs')(suite);
require('./test-scp-compat.cjs')(suite);
console.log(`${passed} regression suites passed. These run in a Lua VM with mocked GMod APIs, not the game engine.`);
