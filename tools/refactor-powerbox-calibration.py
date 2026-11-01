from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
p=ROOT/'ixhl2rp/plugins/blackout/sv_plugin.lua'
s=p.read_text(encoding='utf-8')
s=s.replace('local function HasScrewdriver(client)','function PLUGIN:HasScrewdriver(client)').replace('!HasScrewdriver(client)','!self:HasScrewdriver(client)')
start=s.index('\tbox.ixRepairing = client',s.index('function PLUGIN:TryRepair'))
end=s.index('\n--\n-- Fusebox sabotage',start)
s=s[:start]+'''\treturn self:BeginFuseboxCalibration(client, box, false)
end

function PLUGIN:BeginFuseboxCalibration(client, box, sabotage)
 local facility = ix.plugin.list.facility_utilities
 if not facility or not facility.BeginFuseboxWork then
  client:Notify("Модуль ремонта недоступен. Обратитесь к администратору.")
  return false
 end
 local ok, message = facility:BeginFuseboxWork(client, box, sabotage)
 if not ok and message then client:Notify(message) end
 return ok
end

function PLUGIN:ApplyRepair(client, box)
 box:SetBroken(false)
 box:EmitSound("buttons/button1.wav")
 self:RecomputeZones()
 self:SaveFuseboxes()
 local zone = self:GetOwningZone(box:GetPos())
 if zone and zone.remoteIsolation then
  client:Notify("Электрощит починен. Цепь изолирована с терминала.")
 elseif zone and zone.active then
  client:Notify("Электрощит починен, но в зоне остались повреждённые щитки.")
 else
  client:Notify("Электрощит починен. Свет снова включён.")
 end
 if client:GetCharacter() then client:GetCharacter():UpdateSkillProgress("electric", self.repairXP) end
end
''' +s[end:]
start=s.index('\tbox.ixRepairing = client',s.index('function PLUGIN:TryBreakScrewdriver'))
end=s.index('\n-- Регистрируем щиток',start)
s=s[:start]+'''\treturn self:BeginFuseboxCalibration(client, box, true)
end
''' +s[end:]
s=s.replace('с прогресс-баром, требует навык','мини-игра, требует навык').replace('удержание E с прогресс-баром (как ремонт)','мини-игра с тремя контактами (как ремонт)')
p.write_text(s,encoding='utf-8')
p=ROOT/'ixhl2rp/plugins/blackout/sh_plugin.lua';s=p.read_text(encoding='utf-8')
s=s.replace('PLUGIN.repairTime   = 30    -- seconds of hold-E repair\n','')
s=s.replace('PLUGIN.breakTime    = 30    -- seconds of hold-E screwdriver sabotage (same bar as repair)\n','')
s=s.replace('screwdriver (hold-E) — progress bar','screwdriver (E) — three-contact minigame')
p.write_text(s,encoding='utf-8')
