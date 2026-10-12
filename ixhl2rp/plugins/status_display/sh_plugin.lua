PLUGIN.name = "Foundation Status Display"
PLUGIN.author = "Hutten"
PLUGIN.description = "Administrator-operated helmet-style status messages."
local P=PLUGIN
P.maxBytes=1024
function P:ValidateStatus(value)
 if not isstring(value) or #value>self.maxBytes or value:find('[%z\1-\8\11\12\14-\31]') then return end
 value=string.Trim(value:gsub('\r\n','\n'):gsub('\r','\n'))
 local lines=string.Explode('\n',value)
 if #lines>8 then return end
 for _,line in ipairs(lines) do local ok,n=pcall(utf8.len,line);if not ok or not n or n>64 then return end end
 return value
end
ix.util.Include('sv_status.lua')
ix.util.Include('cl_status.lua')
local function adminAccess(_,client) return IsValid(client) and client:IsAdmin() end
ix.command.Add('StatusHUD',{
 description='Открыть редактор оперативной сводки в правом верхнем углу.',OnCheckAccess=adminAccess,
 OnRun=function(_,client) P:OpenStatusEditor(client) end
})
ix.command.Add('StatusHUDClear',{
 description='Очистить оперативную сводку у всех игроков.',OnCheckAccess=adminAccess,
 OnRun=function(_,client) if P:SetStatus(client,'',false,P.status.revision) then return 'Оперативная сводка очищена.' end end
})
