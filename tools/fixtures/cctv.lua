ix.plugin.list.cctv=PLUGIN
function isangle(v) return type(v)=='table' and getmetatable(v)==getmetatable(Angle()) end
function isbool(v) return type(v)=='boolean' end
function RealTime() return clock end
MASK_VISIBLE=99;SOLID_VPHYSICS=6;MOVETYPE_VPHYSICS=6;SIMPLE_USE=3
function util.IsInWorld(v) return math.abs(v.x)<32768 and math.abs(v.y)<32768 and math.abs(v.z)<32768 end
local oldAdmin=admin
function admin()
 local p=oldAdmin();p.eyeAngle=Angle()
 function p:Alive() return not self.dead end
 function p:GetCharacter() return not self.noCharacter and {} or nil end
 function p:EyeAngles() return self.eyeAngle end
 function p:AddCleanup() end
 return p
end
undo={Create=function() end,AddEntity=function() end,SetPlayer=function() end,Finish=function() end}
local entityIndex=100
local originalEntity=entity
function entity(...)
 local e=originalEntity(...)
 function e:SetModel(v) self.model=v end
 function e:SetPos(v) self.pos=v end
 function e:SetAngles(v) self.ang=v end
 function e:ResetSequence(v) self.sequence=v end
 function e:SetCycle(v) self.cycle=v end
 function e:SetPlaybackRate(v) self.playbackRate=v end
 function e:WorldSpaceCenter() return self.pos end
 function e:IsDormant() return self.dormant==true end
 function e:GetClass() return self.class or 'prop_physics' end
 function e:IsWeapon() return false end
 function e:Remove() self.valid=false;if self.OnRemove then self:OnRemove() end;if PLUGIN.EntityRemoved then PLUGIN:EntityRemoved(self) end end
 function e:Spawn() if self.Initialize then self:Initialize() end end
 function e:Activate() end
 function e:GetPhysicsObject() return {valid=true,EnableMotion=function() end} end
 for _,key in ipairs({'PhysicsInit','SetSolid','SetMoveType','SetUseType','SetNoDraw','SetMaterial','DrawModel'}) do e[key]=function() end end
 return e
end
function ents.Create(class)
 entityIndex=entityIndex+1;local e=entity(entityIndex,'',Vector(),Angle());e.class=class
 for kind,def in pairs(ix.CCTV.kinds) do if class==def.class then e.CCTVKind=kind end end
 for k,v in pairs(ENT or {}) do if e[k]==nil then e[k]=v end end
 return e
end
function ents.FindByClass(class)
 local list={};for _,e in pairs(entities) do if IsValid(e) and e:GetClass()==class then list[#list+1]=e end end;return list
end
origins={};function AddOriginToPVS(v) origins[#origins+1]=v end
ENT={}
function makeDevice(kind,pos)
 local e=ents.Create(ix.CCTV.kinds[kind].class);e:SetPos(pos or Vector());e:Spawn()
 return PLUGIN.devices[e:GetNW2Int('ixCCTVID',0)],e
end
