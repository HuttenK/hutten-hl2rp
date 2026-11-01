-- Additional engine boundaries for hardware previews/tests. Shared adapter stays unchanged.
KEY_ESCAPE=70;MOUSE_LEFT=107
ix.config.Add=function() end
input={IsMouseDown=function() return false end,IsKeyDown=function() return false end,LookupBinding=function() return "v" end}
gui={IsGameUIVisible=function() return false end,IsConsoleVisible=function() return false end}
surface.PlaySound=function() end
local create=vgui.Create
vgui.Create=function(class,...)
 local panel=create(class,...)
 if class=="DFrame" then hardwarePreviewFrame=panel end
 return panel
end
net.WriteInt=function(v) net.packet.integers=net.packet.integers or {};table.insert(net.packet.integers,v) end
function HardwareFind(panel,key,value)
 if panel[key]==value then return panel end
 for _,child in ipairs(panel:GetChildren()) do local result=HardwareFind(child,key,value);if result then return result end end
end
