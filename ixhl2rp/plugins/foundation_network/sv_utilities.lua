local P=PLUGIN
local oldAction,oldPage=P.Action,P.Page
function P:Page(p,s,identity,card,route)
 local section=isstring(route) and route:match("^scip://utilities/?([a-z]*)$")
 if section~=nil and not s.public then
  section=ix.Facility and ix.Facility.pages[section] and section or "comms"
  local f=ix.plugin.list.facility_utilities
  return {route="scip://utilities/"..section,token=s.token,name=identity.name,level=card.clearanceLevel,department=card.departmentLabel,
   title="ИНФРАСТРУКТУРА / "..(ix.Facility and ix.Facility.pages[section] or "НЕТ СВЯЗИ"),rows={},
   utility=f and f:Snapshot(p,section),utilityUpdate=s.utilityUpdate==true,body=not f and "Контроллер инфраструктуры недоступен." or nil}
 end
 return oldPage(self,p,s,identity,card,route)
end
function P:Action(p,action,data)
 if not istable(data) or (action~="utilities" and action~="utilitySync" and not (action=="navigate" and isstring(data.route) and data.route:match("^scip://utilities"))) then return oldAction(self,p,action,data) end
 local s,identity,card=self:Session(p,data.token);if not s or s.public then return end
 local f=ix.plugin.list.facility_utilities;if not f then return end
 local section=ix.Facility.pages[data.section] and data.section or (isstring(data.route) and data.route:match("^scip://utilities/([a-z]+)$"))
 section=ix.Facility.pages[section] and section or "comms"
 local message
 if action=="utilities" then
  if (s.nextUtility or 0)>CurTime() then return end;s.nextUtility=CurTime()+.4
  local ok;ok,message=f:TerminalAction(p,s,data)
 end
 s.idle=CurTime()+600
 s.utilityUpdate=action=="utilitySync"
 self:SendPage(p,s,identity,card,"scip://utilities/"..section,message);s.utilityUpdate=nil
end
