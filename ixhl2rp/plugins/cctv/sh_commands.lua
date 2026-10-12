local P=PLUGIN
ix.command.Add("CCTVAdmin",{adminOnly=true,description="Установка и настройка камер, мониторов и пультов CCTV.",OnRun=function(_,p)
 if SERVER and IsValid(p) and p:IsAdmin() then P:OpenAdmin(p) end
end})
for _,kind in ipairs({"camera","monitor","terminal"}) do
 local selected=kind
 ix.command.Add("CCTV"..kind,{adminOnly=true,description="Разместить устройство CCTV: "..kind,OnRun=function(_,p)
  if SERVER and IsValid(p) and p:IsAdmin() then P:OpenAdmin(p,selected) end
 end})
end
