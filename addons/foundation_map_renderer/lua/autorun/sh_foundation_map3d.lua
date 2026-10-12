-- Distribution only. Loading/baking starts when an authorised terminal map opens.
if SERVER then
 local function sendTree(path)
  local files,dirs=file.Find(path.."/*","LUA")
  for _,name in ipairs(files) do if name:sub(-4)==".lua" then AddCSLuaFile(path.."/"..name) end end
  for _,name in ipairs(dirs) do sendTree(path.."/"..name) end
 end
 sendTree("ix_foundation_map3d")
 sendTree("niknaks")
 AddCSLuaFile("includes/modules/niknaks.lua")
end
