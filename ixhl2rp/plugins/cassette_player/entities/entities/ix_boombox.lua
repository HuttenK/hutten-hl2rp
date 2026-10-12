-- Compatibility registration; logic lives in the ix_boombox directory.
if SERVER then
 AddCSLuaFile("ix_boombox/shared.lua")
 AddCSLuaFile("ix_boombox/cl_init.lua")
 include("ix_boombox/init.lua")
else
 include("ix_boombox/cl_init.lua")
end
