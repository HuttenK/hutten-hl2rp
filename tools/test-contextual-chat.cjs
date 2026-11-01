const fs=require('fs');
const {normalize}=require('./glua.cjs');
module.exports=suite=>{
 const foundation=['tools/fixtures/medicine.lua','tools/fixtures/contextual-chat.lua','helix/gamemode/core/libs/sh_chatbox.lua'];
 const medical=[...foundation,'ixhl2rp/plugins/medical/libs/sh_catalog.lua','ixhl2rp/plugins/medical/sh_treatment.lua','ixhl2rp/plugins/medical/sv_treatment.lua','ixhl2rp/plugins/chat/sv_contextual.lua'];
 const consumption=[...foundation,'ixhl2rp/plugins/food/items/base/food.lua','ixhl2rp/plugins/food/items/base/drinks.lua','ixhl2rp/plugins/chat/sv_contextual.lua'];
 suite('Contextual treatment starts once with the actual animation, uses local chat and does not claim cancelled healing',medical,`
  local p,nearby,far=initNearbyChat(); local item=medicalItem(p,'eft_surgery',5)
  p.character.hp:AddHediff('fracture',4,{severity=5})
  ix.Medicine.Begin(item,p,0); local session=p.ixMedicalSession; assert(session); eq(#packets,0)
  clock=clock+.2; session.weapon:Think(); eq(#packets,1)
  local sent=packets[1]; eq(sent.strings[1],'me'); assert(sent.strings[2]:find('свою левую руку',1,true))
  eq(#sent.receivers,2); eq(sent.receivers[1],p); eq(sent.receivers[2],nearby)
  ix.Medicine.AnnounceTreatment(p,session); eq(#packets,1)
  ix.Medicine.Finish(p,false); flush(); eq(item.uses,5); eq(#packets,1)
  ix.Medicine.AnnounceTreatment(p,session); eq(#packets,1)
  clock=clock+3; p.badSequence=true; ix.Medicine.Begin(item,p,4); session=p.ixMedicalSession
  clock=clock+.2; session.weapon:Think(); eq(#packets,1); flush()
  p.badSequence=false; p.failGive=true; ix.Medicine.Begin(item,p,4); eq(#packets,1); flush()
  p.failGive=false; file.Exists=function() return false end; ix.Medicine.Begin(item,p,4); eq(#packets,1)
 `);
 suite('Every medical item has contextual self/patient narration without exposing patient identity',medical,`
  local p=initNearbyChat(); local patient=newChatter(30); local count=0
  for id,def in pairs(ix.Medicine.Catalog) do
   for _,target in ipairs({p,patient}) do
    clock=clock+3
    local h=target.character.hp; h.hediffs={}
    h:AddHediff('fracture',6,{severity=5}); h:AddHediff('cut',4,{severity=20})
    local item=medicalItem(p,id)
    hook.Run('MedicalTreatmentStarted',p,{item=item,target=target,patient=target.character,hitgroup=0})
    count=count+1; eq(#packets,count)
    local text=packets[count].strings[2]
    assert(not text:find('Secret identity',1,true))
    if target==patient then assert(text:find('пациент',1,true)) end
    if id=='eft_surgery' or id=='eft_splint' then assert(text:find('левую ногу',1,true)) end
   end
  end
  for _,id in ipairs({'bloodbag','ivbag','bloodbag_empty'}) do
   clock=clock+3; p.character.hp.hediffs={}
   if id~='bloodbag_empty' then p.character.hp:AddHediff('bleeding',0,{severity=.3}) end
   ix.Medicine.Begin(medicalItem(p,id),p,0); assert(p.ixMedicalSession)
   count=count+1; eq(#packets,count)
   ix.Medicine.Finish(p,false); flush()
  end
 `);
 suite('Food/drink partial and complete consumption narrates the named item once and preserves amounts; empty/open/pour remain silent',consumption,`
  local p=initNearbyChat()
  for _,kind in ipairs({'food','drink'}) do
   packets={}
   local item=newConsumable(p,kind,120,'Лимонад «Байкал»')
   item.functions.use.OnRun(item); eq(#packets,1)
   eq(packets[1].strings[2],(kind=='food' and 'ест' or 'пьёт')..' «Лимонад «Байкал»».')
   eq(item.reagents.volume,kind=='food' and 70 or 54)
   eq(p.character.thirst,kind=='food' and 50 or 66)
   item.functions.useall.OnRun(item); eq(#packets,2); assert(item.depleted)
   eq(packets[2].strings[2],(kind=='food' and 'съедает' or 'допивает')..' «Лимонад «Байкал»».')
   item.functions.use.OnRun(item); item.functions.useall.OnRun(item); eq(#packets,2)
   item=newConsumable(p,kind,10,'Рацион')
   item.functions.use.OnRun(item); eq(#packets,3); assert(item.depleted)
   item=newConsumable(p,kind,120,'Рацион'); item.stats.container=true; item.data.closed=true
   eq(item.functions.use.OnCanRun(item),false); item.functions.open.OnRun(item); eq(#packets,3)
   if kind=='drink' then item.functions.pour.OnRun(item); eq(#packets,3); assert(item.depleted) end
  end
 `);
 suite('Contextual chat rejects non-consumption and isolates chat failures from item use',consumption,`
  local p=initNearbyChat(); local item=newConsumable(p,'drink',200,'Сок<font>\\nяблочный')
  for _,n in ipairs({0,-1,0/0,math.huge}) do hook.Run('PlayerConsumedItem',p,item,'drink',n,false) end
  hook.Run('PlayerConsumedItem',p,item,'pour',20,false); eq(#packets,0)
  item.functions.use.OnRun(item); eq(#packets,1); assert(not packets[1].strings[2]:find('[<>%c]'))
  hook.Add('PlayerMessageSend','fail',function(speaker) assert(speaker.ixContextualEmote); error('Broken addon') end)
  item.functions.useall.OnRun(item); assert(item.depleted); eq(p.ixContextualEmote,nil); eq(#warnings,1)
 `);
 suite('Private /itpm uses native chat delivery to exactly the selected distant player, including dead admins; no implicit audience',
 [...foundation,'ixhl2rp/plugins/chat/sh_commands.lua'],`
  local admin,nearby,target=initNearbyChat(); admin.admin=true; admin.dead=true; target.distance=50000
  local cmd=commands.itpm; assert(cmd.adminOnly); eq(cmd.arguments[1],ix.type.player)
  cmd:OnRun(admin,target,'  Слышен тихий стук.  '); eq(#packets,1)
  local sent=packets[1]; eq(sent.strings[1],'itpm'); eq(sent.strings[2],'Слышен тихий стук.')
  eq(#sent.receivers,1); eq(sent.receivers[1],target); eq(sent.anonymous,true); eq(#admin.notices,1)
  ix.chat.Send(admin,'itpm','No explicit receiver'); eq(#packets,1)
  cmd:OnRun(nearby,target,'Forbidden'); eq(#packets,1)
  ix.chat.Send(nearby,'itpm','Bypass',true,{target}); eq(#packets,1)
  cmd:OnRun(admin,target,'   '); cmd:OnRun(admin,target,{}); cmd:OnRun(admin,nil,'Invalid'); eq(#packets,1)
  target.character=nil; cmd:OnRun(admin,target,'No character'); eq(#packets,1)
  local captured
  ix.chat.classes.it={OnChatAdd=function(_,speaker,text,anonymous) captured={text,anonymous} end}
  ix.chat.classes.itpm:OnChatAdd(admin,'Description',true,{}); eq(captured[1],'Description'); eq(captured[2],true)
  SERVER=false; cmd:OnRun(admin,nearby,'Client call'); eq(#packets,1)
 `);
 const xp=normalize(fs.readFileSync('ixhl2rp/plugins/!!levelsystem/sv_hooks.lua','utf8').split('function PLUGIN:PlayerMessageSend')[1]);
 suite('Automatic /me and private /itpm do not award social XP; normal conversation still does',consumption,`
  local p,nearby=initNearbyChat(); PLUGIN.SocialXPConfig={blacklist={}}
  PLUGIN.socialXP={Award=function() return 5 end}
  local earned=0; function nearby.character:AddLevelXP(n) earned=earned+n end
  hook.Add('PlayerMessageSend','xp',function(...) return PLUGIN:PlayerMessageSend(...) end)
  local item=newConsumable(p,'food',10,'Рацион'); item.functions.use.OnRun(item); eq(earned,0)
  eq(p.ixContextualEmote,nil)
  PLUGIN:PlayerMessageSend(p,'itpm','text',true,{nearby}); eq(earned,0)
  ix.chat.Send(p,'me','waves'); eq(earned,5)
 `, 'function PLUGIN:PlayerMessageSend'+xp);
};
