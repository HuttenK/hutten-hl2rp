PLUGIN.name = "SCP-610 Containment"
PLUGIN.author = "Hutten"
PLUGIN.description = "Controlled SCP-610 growth and thermal decontamination."
local P=PLUGIN
P.settingRules={
 paused={false,'Приостановить размножение'},spreadEnabled={true,'Рост биомассы'},
 conversion={false,'Заражение убитых существ'},deathSpawns={false,'Потомство и перерождение после смерти'},
 zoneGrowth={true,'Рост флоры в зонах заражения'},zoneNPCs={true,'Спавн зомби в зонах заражения'},
 zoneGas={true,'Токсичный газ в зонах заражения'},
 growthInterval={180,'Интервал роста (сек.)',15,3600},maxGrowth={24,'Лимит биомассы / столбов / триподов',0,128},
 maxNPCs={20,'Лимит подвижных SCP-610',0,64},regeneration={0,'Регенерация HP/сек. (0 = выкл.)',0,20},
 fireMultiplier={8,'Множитель урона огня',1,30},fireHealthFraction={.18,'Мин. доля HP за ожог',.01,.5}
}
P.growthClasses={npc_vj_scp_610_biomass='npc_vj_scp_610_biomass',npc_vj_scp_610_pillar='npc_vj_scp_610_biomass',npc_vj_scp_610_tripod='npc_vj_scp_610_pillar'}
P.flameClasses={arc9_codww2_flamethrower=true,arc9_codww2_flammenwerfer35=true}
function P:Is610(ent) return IsValid(ent) and ent:GetClass():match('^npc_vj_scp_610_')~=nil end
function P:ValidateSetting(key,value)
 local rule=self.settingRules[key];if not rule then return end
 if isbool(rule[1]) then if isbool(value) then return value end;return end
 if not isnumber(value) or value~=value or value==math.huge or value==-math.huge then return end
 value=math.Clamp(value,rule[3],rule[4]);if key~='fireHealthFraction' then value=math.floor(value) end
 return value
end
ix.util.Include('sv_control.lua')
ix.util.Include('sv_resources.lua')
ix.util.Include('cl_control.lua')
ix.command.Add('SCP610Control',{description='Настройки размножения SCP-610 и зон заражения.',adminOnly=true,OnRun=function(_,client) P:OpenControl(client) end})
ix.command.Add('SCP610Pause',{description='Остановить размножение SCP-610 и спавн в зонах.',adminOnly=true,OnRun=function(_,client) P:SetPaused(true);return 'Размножение SCP-610 и спавн в зонах приостановлены.' end})
ix.command.Add('SCP610Resume',{description='Возобновить размножение по заданным ограничениям.',adminOnly=true,OnRun=function(_,client) P:SetPaused(false);return 'Размножение возобновлено с заданными ограничениями.' end})
ix.command.Add('SCP610Purge',{description='Удалить всех SCP-610 и остановить размножение.',adminOnly=true,OnRun=function(_,client) local n=P:Purge();return 'Удалено SCP-610: '..n..'. Размножение приостановлено.' end})
