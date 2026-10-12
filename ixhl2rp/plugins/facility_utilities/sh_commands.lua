ix.command.Add("FacilityAdmin",{adminOnly=true,description="Настройка связи, дверей, резервного питания и работ.",OnRun=function(_,p)
 ix.plugin.list.facility_utilities:SendUI(p,"admin")
end})
for command,kind in pairs({FacilitySpeaker="speaker",FacilityIntercom="intercom",FacilityReceiver="receiver",FacilityAnnouncement="announcement",FacilityGenerator="generator",FacilityBattery="battery",FacilityWorkpoint="workpoint",FacilityPanel="panel",FacilityTerminal="terminal",FacilityDoorConsole="doorconsole",FacilityPowerConsole="powerconsole"}) do
 local deviceKind=kind
 ix.command.Add(command,{adminOnly=true,description="Разместить оборудование инфраструктуры по прицелу.",OnRun=function(_,p)
  local P=ix.plugin.list.facility_utilities;local ok,msg,id=P:AdminAction(p,{command="place",kind=deviceKind});P:SendUI(p,"admin",id,msg)
 end})
end
ix.command.Add("FacilityDoor",{adminOnly=true,description="Добавить дверь под прицелом в диспетчерский пульт.",OnRun=function(_,p)
 local P=ix.plugin.list.facility_utilities;local ok,msg,id=P:AdminAction(p,{command="bindDoor"});P:SendUI(p,"admin",id,msg,"door")
end})
ix.command.Add("Maintenance",{description="Заявки на обслуживание и принятые работы.",OnRun=function(_,p) ix.plugin.list.facility_utilities:SendUI(p,"jobs") end})
ix.command.Add("MaintenanceWork",{description="Начать принятую работу у оборудования.",OnRun=function(_,p)
 local P=ix.plugin.list.facility_utilities
 for _,j in pairs(P.store.jobs) do if j.status=="assigned" and j.owner==p:GetCharacter():GetID() then
  local e=P:JobTarget(j);if ix.Facility.Near(p,e,110) then local ok,msg=P:BeginWork(p,j);return msg end
 end end
 return "Рядом нет оборудования из принятых заявок."
end})
